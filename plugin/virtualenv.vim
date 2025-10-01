if exists('g:loaded_virtualenv')
    finish
endif

if !has('python3')
    echoerr 'vim-virtualenv requires python3 feature to be enabled'
    finish
endif

let g:loaded_virtualenv = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let g:virtualenv#directory =
    \ get(g:, 'virtualenv#directory',
    \     !isdirectory($WORKON_HOME) ? v:null : $WORKON_HOME)
let g:virtualenv#auto_activate =
    \ get(g:, 'virtualenv#auto_activate', 1)
let g:virtualenv#auto_activate_everywhere =
    \ get(g:, 'virtualenv#auto_activate_everywhere', 0)
let g:virtualenv#cdvirtualenv_on_activate =
    \ get(g:, 'virtualenv#cdvirtualenv_on_activate', 1)
let g:virtualenv#return_on_deactivate =
    \ get(g:, 'virtualenv#return_on_deactivate', 1)
let g:virtualenv#debug =
    \ get(g:, 'virtualenv#debug', 0)
let g:virtualenv#enable_gutentags_support =
    \ get(g:, 'virtualenv#enable_gutentags_support', 0)
let g:virtualenv#python_script =
    \ get(g:, 'virtualenv#python_script',
    \     expand('<sfile>:p:h:h').'/autoload/virtualenv/virtualenv.py')

augroup vim-virtualenv-internal
autocmd! User VirtualEnv* :
augroup END

augroup VirtualEnvAutoActivate
if g:virtualenv#auto_activate && (g:virtualenv#directory !=# v:null)
    execute 'autocmd! BufEnter,BufFilePost '.
            \g:virtualenv#directory.'/* call virtualenv#activate()'
elseif g:virtualenv#auto_activate_everywhere
    autocmd! BufEnter,BufFilePost * call virtualenv#activate()
endif
augroup END

command! -nargs=? -bar -complete=dir
    \ VirtualEnvList call virtualenv#list(<f-args>)
command! -nargs=? -bar -complete=customlist,virtualenv#completion#do
    \ VirtualEnvActivate call virtualenv#activate(<f-args>)
command! -nargs=0 -bar
    \ VirtualEnvDeactivate call virtualenv#deactivate()

let &cpoptions = s:save_cpo
unlet s:save_cpo
