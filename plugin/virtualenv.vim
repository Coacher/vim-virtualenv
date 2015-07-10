if exists('g:loaded_virtualenv')
    finish
endif

if !exists('g:virtualenv#force_python_version')
    if !(has('python') || has('python3'))
        echoerr 'vim-virtualenv requires python or python3 feature to be enabled'
        finish
    endif
else
    let s:python = 'python'.((g:virtualenv#force_python_version != 3) ? '' : '3')
    if !has(s:python)
        echoerr 'vim-virtualenv requires the '.s:python.' feature to be enabled'
        finish
    endif
endif

let g:loaded_virtualenv = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let g:virtualenv#directory =
    \ get(g:, 'virtualenv#directory',
    \     !isdirectory($WORKON_HOME) ? '~/.virtualenvs' : $WORKON_HOME)
let g:virtualenv#auto_activate =
    \ get(g:, 'virtualenv#auto_activate', 1)
let g:virtualenv#auto_activate_everywhere =
    \ get(g:, 'virtualenv#auto_activate_everywhere', 0)
let g:virtualenv#update_pythonpath =
    \ get(g:, 'virtualenv#update_pythonpath', 1)
let g:virtualenv#cdvirtualenv_on_activate =
    \ get(g:, 'virtualenv#cdvirtualenv_on_activate', 1)
let g:virtualenv#return_on_deactivate =
    \ get(g:, 'virtualenv#return_on_deactivate', 1)
let g:virtualenv#statusline_format =
    \ get(g:, 'virtualenv#statusline_format', '%n')
let g:virtualenv#debug =
    \ get(g:, 'virtualenv#debug', 0)
let g:virtualenv#python_script =
    \ get(g:, 'virtualenv#python_script',
    \     expand('<sfile>:p:h:h').'/autoload/virtualenv/virtualenv.py')

if virtualenv#init()
    finish
endif

augroup VirtualEnvAutoActivate
if g:virtualenv#auto_activate
    execute 'autocmd! BufFilePost,BufNewFile,BufRead '.
            \g:virtualenv#directory.'/* call virtualenv#activate()'
elseif g:virtualenv#auto_activate_everywhere
    autocmd! BufFilePost,BufNewFile,BufRead * call virtualenv#activate()
endif
augroup END

command! -nargs=? -bar -complete=dir VirtualEnvList
    \ call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,s:completion VirtualEnvActivate
    \ call virtualenv#activate(<f-args>)
command! -nargs=0 -bar VirtualEnvDeactivate
    \ call virtualenv#deactivate()

" the rest of this file is the VirtualEnvActivate completion machinery
function! s:completion(arglead, ...)
    let l:arglead = fnameescape(a:arglead)

    if (l:arglead !~# '/')
        " not a path was specified
        let l:pattern = l:arglead.'*'
        let l:directory = getcwd()
        " first search inside g:virtualenv#directory
        let l:virtualenvs = s:relvenvlist(g:virtualenv#directory, l:pattern)
        " then search inside the current directory
        if (g:virtualenv#directory !=# l:directory)
            call s:appendcwdlist(l:virtualenvs, s:relvenvlist(l:directory, l:pattern))
        endif

        if !empty(l:virtualenvs)
            return s:fnameescapelist(l:virtualenvs)
        else
            " if no virtualenvs were found, then return a list of directories
            if (l:arglead !~# '^\~')
                let l:pattern .= '/'
                let l:globs = s:relgloblist(g:virtualenv#directory, l:pattern)
                if (g:virtualenv#directory !=# l:directory)
                    call s:appendcwdlist(l:globs, s:relgloblist(l:directory, l:pattern))
                endif
                return s:fnameescapelist(l:globs)
            else
                return [fnamemodify(l:arglead, ':p')]
            endif
        endif
    else
        " a path was specified
        if (l:arglead =~# '^[\.\~/]')
            " a path can be unambiguously expanded
            let l:pattern = fnamemodify(l:arglead, ':t').'*'
            let l:directory = fnamemodify(l:arglead, ':h')
            let l:virtualenvs = virtualenv#find(l:directory, l:pattern)
        else
            " a path without an unambiguous prefix was specified
            let l:pattern = l:arglead.'*'
            let l:directory = getcwd()
            " first search inside g:virtualenv#directory
            let l:virtualenvs = s:relvenvlist(g:virtualenv#directory, l:pattern)
            " then search inside the current directory
            if (g:virtualenv#directory !=# l:directory)
                call s:appendcwdlist(l:virtualenvs, s:relvenvlist(l:directory, l:pattern))
            endif
        endif

        if !empty(l:virtualenvs)
            return s:fnameescapelist(l:virtualenvs)
        else
            " if no virtualenvs were found, then return a list of directories
            let l:pattern .= '/'
            if (l:arglead =~# '^[\.\~/]')
                return s:fnameescapelist(globpath(l:directory, l:pattern, 0, 1))
            else
                let l:globs = s:relgloblist(g:virtualenv#directory, l:pattern)
                if (g:virtualenv#directory !=# l:directory)
                    call s:appendcwdlist(l:globs, s:relgloblist(l:directory, l:pattern))
                endif
                return s:fnameescapelist(l:globs)
            endif
        endif
    endif
endfunction

function! s:fnameescapelist(list)
    return map(a:list, 'fnameescape(v:val)')
endfunction

function! s:relpathlist(list, directory)
    return map(a:list, 'substitute(v:val, ''^'.a:directory.'/'', '''', '''')')
endfunction

function! s:relgloblist(directory, pattern)
    return s:relpathlist(globpath(a:directory, a:pattern, 0, 1), a:directory)
endfunction

function! s:relvenvlist(directory, pattern)
    return s:relpathlist(virtualenv#find(a:directory, a:pattern), a:directory)
endfunction

function! s:appendcwdlist(list, cwdlist)
    for l:entry in a:cwdlist
        if (index(a:list, l:entry) == -1)
            call add(a:list, l:entry)
        else
            call add(a:list, './'.l:entry)
        endif
    endfor
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
