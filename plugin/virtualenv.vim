if exists('g:virtualenv_loaded')
    finish
endif

if !has('python') && !has('python3')
    echoerr 'vim-virtualenv requires python or python3 support enabled'
    finish
endif

let g:virtualenv_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:virtualenv_auto_activate')
    let g:virtualenv_auto_activate = 1
endif

if !exists('g:virtualenv_cdvirtualenv_on_activate')
    let g:virtualenv_cdvirtualenv_on_activate = 1
endif

if !exists('g:virtualenv_force_cdvirtualenv_on_activate')
    let g:virtualenv_force_cdvirtualenv_on_activate = 0
endif

if !exists('g:virtualenv_return_on_deactivate')
    let g:virtualenv_return_on_deactivate = 1
endif

if !exists('g:virtualenv_debug')
    let g:virtualenv_debug = 0
endif

if !exists('g:virtualenv_stl_format')
    let g:virtualenv_stl_format = '%n'
endif

if !exists('g:virtualenv_directory')
    if isdirectory($WORKON_HOME)
        let g:virtualenv_directory = $WORKON_HOME
    else
        let g:virtualenv_directory = '~/.virtualenvs'
    endif
endif

if !exists('g:virtualenv_python_script')
  let g:virtualenv_python_script = expand('<sfile>:p:h:h').'/autoload/virtualenv/virtualenv.py'
endif

if virtualenv#init()
    finish
endif

command! -nargs=? -bar -complete=dir VirtualEnvList
            \ call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,s:CompleteVirtualEnv
            \ VirtualEnvActivate call virtualenv#activate(<f-args>)
command! -nargs=0 -bar VirtualEnvDeactivate
            \ call virtualenv#deactivate()

function! s:CompleteVirtualEnv(arglead, cmdline, cursorpos)
    if (a:arglead !~ '/')
        let pattern = a:arglead.'*'
        let virtualenvs = s:relvirtualenvlist(g:virtualenv_directory, pattern)

        let directory = getcwd()
        if g:virtualenv_directory != directory
            let virtualenvs += s:relvirtualenvlist(directory, pattern)
        endif
        let pattern .= '/'

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            if a:arglead =~ '^\~'
                return [fnamemodify(a:arglead, ':p')]
            else
                return s:fnameescapelist(s:relgloblist(directory, pattern))
            endif
        endif
    else
        let directory = fnamemodify(a:arglead, ':h')
        let pattern = fnamemodify(a:arglead, ':t').'*'
        let virtualenvs = virtualenv#find(directory, pattern)
        let pattern .= '/'

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            return s:fnameescapelist(globpath(directory, pattern, 0, 1))
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


if g:virtualenv_auto_activate
    execute 'autocmd BufFilePost,BufNewFile,BufRead '
                \.g:virtualenv_directory.'/* call virtualenv#activate()'
endif

let &cpo = s:save_cpo
