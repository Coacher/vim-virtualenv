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

call virtualenv#init()

command! -nargs=? -bar -complete=dir VirtualEnvList
            \ call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,s:CompleteVirtualEnv VirtualEnvActivate
            \ call virtualenv#activate(<f-args>)
command! -nargs=0 -bar VirtualEnvCdvirtualenv
            \ call virtualenv#cdvirtualenv()
command! -nargs=0 -bar VirtualEnvDeactivate
            \ call virtualenv#deactivate()

function! s:CompleteVirtualEnv(arglead, cmdline, cursorpos)
    if (a:arglead !~ '/\+')
        let virtualenvs = virtualenv#find(g:virtualenv_directory, a:arglead.'*')
        let virtualenvs = map(virtualenvs,
                    \"substitute(v:val, '^'.g:virtualenv_directory.'/', '', '')")
        return map(virtualenvs, 'fnameescape(v:val)')
    else
        let directory = fnamemodify(a:arglead, ':h')
        let pattern = fnamemodify(a:arglead, ':t')

        let virtualenvs = virtualenv#find(directory, pattern.'*/')

        if !empty(virtualenvs)
            return map(virtualenvs, 'fnameescape(v:val)')
        else
            return map(globpath(directory, pattern.'*/', 0, 1), 'fnameescape(v:val)')
        endif
    endif
endfunction

if g:virtualenv_auto_activate
    call virtualenv#activate()
endif

let &cpo = s:save_cpo
