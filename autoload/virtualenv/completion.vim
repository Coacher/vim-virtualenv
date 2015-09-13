function! virtualenv#completion#do(arglead, ...)
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
