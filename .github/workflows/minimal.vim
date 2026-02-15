set nocompatible
let &runtimepath = expand('$GITHUB_WORKSPACE')..','..&runtimepath

let g:virtualenv#auto_activate_everywhere = 1

function! g:ExitTest()
    for l:err in v:errors | echo l:err | endfor
    execute 'cquit! '..!empty(v:errors)
endfunction
