if exists('g:loaded_virtualenv')
    finish
endif

if !exists('g:virtualenv#force_python_version')
    if !(has('python') || has('python3'))
        echoerr 'vim-virtualenv requires python or python3 feature to be enabled'
        finish
    endif
else
    let python = 'python'.((g:virtualenv#force_python_version != 3) ? '' : '3')
    if !has(python)
        echoerr 'vim-virtualenv requires the '.python.' feature to be enabled'
        finish
    endif
endif

let g:loaded_virtualenv = 1

let s:save_cpo = &cpo
set cpo&vim

let g:virtualenv#directory =
        \ get(g:, 'virtualenv#directory',
        \     !isdirectory($WORKON_HOME) ? '~/.virtualenvs' : $WORKON_HOME)
let g:virtualenv#auto_activate =
        \ get(g:, 'virtualenv#auto_activate', 1)
let g:virtualenv#auto_activate_everywhere =
        \ get(g:, 'virtualenv#auto_activate_everywhere', 0)
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

if (g:virtualenv#auto_activate_everywhere)
    autocmd BufFilePost,BufNewFile,BufRead * call virtualenv#activate()
elseif (g:virtualenv#auto_activate)
    execute 'autocmd BufFilePost,BufNewFile,BufRead '
           \.g:virtualenv#directory.'/* call virtualenv#activate()'
endif

command! -nargs=? -bar -complete=dir VirtualEnvList
        \ call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,s:completion VirtualEnvActivate
        \ call virtualenv#activate(<f-args>)
command! -nargs=0 -bar VirtualEnvDeactivate
        \ call virtualenv#deactivate()

function! s:completion(arglead, cmdline, cursorpos)
    let arglead = fnameescape(a:arglead)

    if (arglead !~ '/')
        let pattern = arglead.'*'
        let directory = getcwd()
        let virtualenvs = s:relvirtualenvlist(g:virtualenv#directory, pattern)
        if (g:virtualenv#directory !=# directory)
            call s:appendcwdlist(virtualenvs,
                                \s:relvirtualenvlist(directory, pattern))
        endif

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            if (arglead !~ '^\~')
                let pattern .= '/'
                let globs = s:relgloblist(g:virtualenv#directory, pattern)
                if (g:virtualenv#directory !=# directory)
                    call s:appendcwdlist(globs,
                                        \s:relgloblist(directory, pattern))
                endif
                return s:fnameescapelist(globs)
            else
                return [fnamemodify(arglead, ':p')]
            endif
        endif
    else
        if (arglead =~ '^[\.\~/]')
            let pattern = fnamemodify(arglead, ':t').'*'
            let directory = fnamemodify(arglead, ':h')
            let virtualenvs = virtualenv#find(directory, pattern)
        else
            let pattern = arglead.'*'
            let directory = getcwd()
            let virtualenvs =
                    \ s:relvirtualenvlist(g:virtualenv#directory, pattern)
            if (g:virtualenv#directory !=# directory)
                call s:appendcwdlist(virtualenvs,
                                    \s:relvirtualenvlist(directory, pattern))
            endif
        endif

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            let pattern .= '/'
            if (arglead =~ '^[\.\~/]')
                return s:fnameescapelist(globpath(directory, pattern, 0, 1))
            else
                let globs = s:relgloblist(g:virtualenv#directory, pattern)
                if (g:virtualenv#directory !=# directory)
                    call s:appendcwdlist(globs,
                                        \s:relgloblist(directory, pattern))
                endif
                return s:fnameescapelist(globs)
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

function! s:relvirtualenvlist(directory, pattern)
    return s:relpathlist(virtualenv#find(a:directory, a:pattern), a:directory)
endfunction

function! s:appendcwdlist(list, cwdlist)
    for entry in a:cwdlist
        if (index(a:list, entry) == -1)
            call add(a:list, entry)
        else
            call add(a:list, './'.entry)
        endif
    endfor
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
