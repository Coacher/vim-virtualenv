if exists('g:virtualenv_loaded')
    finish
endif

if (!has('python') && !has('python3'))
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
    let g:virtualenv_directory =
            \ !isdirectory($WORKON_HOME) ? '~/.virtualenvs' : $WORKON_HOME
endif

if !exists('g:virtualenv_python_script')
    let g:virtualenv_python_script =
            \ expand('<sfile>:p:h:h').'/autoload/virtualenv/virtualenv.py'
endif

if virtualenv#init()
    finish
endif

if (g:virtualenv_auto_activate)
    execute 'autocmd BufFilePost,BufNewFile,BufRead '
           \.g:virtualenv_directory.'/* call virtualenv#activate()'
endif

command! -nargs=? -bar -complete=dir VirtualEnvList
            \ call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,s:virtualenv_completion
            \ VirtualEnvActivate call virtualenv#activate(<f-args>)
command! -nargs=0 -bar VirtualEnvDeactivate
            \ call virtualenv#deactivate()

function! s:virtualenv_completion(arglead, cmdline, cursorpos)
    if (a:arglead !~ '/')
        let pattern = a:arglead.'*'
        let directory = getcwd()
        let virtualenvs = s:relvirtualenvlist(g:virtualenv_directory, pattern)
        if (g:virtualenv_directory !=# directory)
            call s:appendcwdlist(virtualenvs,
                                \s:relvirtualenvlist(directory, pattern))
        endif

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            if (a:arglead !~ '^\~')
                let pattern .= '/'
                let globs = s:relgloblist(g:virtualenv_directory, pattern)
                if (g:virtualenv_directory !=# directory)
                    call s:appendcwdlist(globs,
                                        \s:relgloblist(directory, pattern))
                endif
                return s:fnameescapelist(globs)
            else
                return [fnamemodify(a:arglead, ':p')]
            endif
        endif
    else
        if (a:arglead =~ '^[\.\~/]')
            let pattern = fnamemodify(a:arglead, ':t').'*'
            let directory = fnamemodify(a:arglead, ':h')
            let virtualenvs = virtualenv#find(directory, pattern)
        else
            let pattern = a:arglead.'*'
            let directory = getcwd()
            let virtualenvs = s:relvirtualenvlist(g:virtualenv_directory, pattern)
            if (g:virtualenv_directory !=# directory)
                call s:appendcwdlist(virtualenvs,
                                    \s:relvirtualenvlist(directory, pattern))
            endif
        endif

        if !empty(virtualenvs)
            return s:fnameescapelist(virtualenvs)
        else
            let pattern .= '/'
            if (a:arglead =~ '^[\.\~/]')
                return s:fnameescapelist(globpath(directory, pattern, 0, 1))
            else
                let globs = s:relgloblist(g:virtualenv_directory, pattern)
                if (g:virtualenv_directory !=# directory)
                    call s:appendcwdlist(globs, s:relgloblist(directory, pattern))
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
