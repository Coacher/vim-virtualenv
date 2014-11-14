function! virtualenv#activate(...)
    if (a:0 > 0)
        let name = a:1
        if empty(name)
            call s:Error('empty virtualenv name')
            return 1
        endif
    else
        if !isdirectory($VIRTUAL_ENV)
            " try to determine virtualenv from the current file path
            let dir = expand('%:p:h')
            let pat = '^'.g:virtualenv_directory.'/'
            if dir =~ pat
                let name = split(substitute(dir, pat, '', ''), '/')[0]
            else
                call s:Warning('unable to determine virtualenv
                            \ from the current file path')
                return
            endif
        else
            " if $VIRTUAL_ENV is set, then we are inside an active virtualenv
            call s:Warning('active virtualenv detected,
                        \ it cannot be deactivated via this plugin')
            let s:virtualenv_name = fnamemodify($VIRTUAL_ENV, ':t')
            return
        endif
    endif

    call virtualenv#deactivate()

    let virtualenv_path = [g:virtualenv_directory, expand('%:p:h'), getcwd(), '']
    for dir in virtualenv_path
        let target = fnamemodify(s:joinpath(dir, name), ':p')
        if isdirectory(target)
            return virtualenv#force_activate(target)
        endif
    endfor

    call s:Warning('virtualenv "'.name.'" was not found in '.string(virtualenv_path))
    return 1
endfunction

function! virtualenv#force_activate(target)
    if !isdirectory(a:target)
        call s:Error('"'.a:target.'" is not a directory')
        return 1
    endif

    let script = a:target.'/bin/activate_this.py'
    if !filereadable(script)
        call s:Error('"'.script.'" is not found or is not readable')
        return 1
    endif

    if !(s:is_virtualenv_supported(a:target))
        return 1
    endif

    let s:virtualenv_return_dir = getcwd()

    call s:execute_python_command('virtualenv_activate("'.script.'")')

    if g:virtualenv_cdvirtualenv_on_activate
        if (!s:issubdir(s:virtualenv_return_dir, a:target)
            \ || g:virtualenv_force_cdvirtualenv_on_activate)
            execute 'cd' a:target
        endif
    endif

    let $VIRTUAL_ENV = a:target
    let s:virtualenv_dir = a:target
    let s:virtualenv_name = fnamemodify(a:target, ':t')
endfunction

function! virtualenv#deactivate()
    if !exists('s:virtualenv_name') || !virtualenv#is_armed()
        call s:Warning('deactivation is not possible')
        return
    endif

    call s:execute_python_command('virtualenv_deactivate()')

    unlet! s:virtualenv_name
    unlet! s:virtualenv_dir
    let $VIRTUAL_ENV = ''
    unlet! s:python_version

    if g:virtualenv_return_on_deactivate && exists('s:virtualenv_return_dir')
        execute 'cd' s:virtualenv_return_dir
        unlet s:virtualenv_return_dir
    endif
endfunction

function! virtualenv#cdvirtualenv()
    if exists('s:virtualenv_dir')
        execute 'cd' s:virtualenv_dir
    endif
endfunction

function! virtualenv#list()
    for name in virtualenv#names(g:virtualenv_directory)
        echo name
    endfor
endfunction

function! virtualenv#statusline()
    if exists('s:virtualenv_name')
        return substitute(g:virtualenv_stl_format, '\C%n', s:virtualenv_name, 'g')
    else
        return ''
    endif
endfunction

function! virtualenv#names(dir, ...)
    let venvs = []
    let prefix = (a:0 > 0) ? (a:1) : ''
    for dir in glob(s:cleanpath(a:dir).'/'.prefix.'*', 0, 1)
        if !isdirectory(dir)
            continue
        endif
        let fn = dir.'/bin/activate_this.py'
        if !filereadable(fn)
            continue
        endif
        call add(venvs, fnamemodify(dir, ':t'))
    endfor
    return venvs
endfunction

function! virtualenv#is_armed()
    redir => output
        silent call s:execute_python_command('virtualenv_is_armed()')
    redir END
    return (output =~ 'armed')
endfunction


function! s:Error(message)
    echohl ErrorMsg | echo 'vim-virtualenv: '.a:message | echohl None
endfunction

function! s:Warning(message)
    if g:virtualenv_debug
        echohl WarningMsg | echo 'vim-virtualenv: '.a:message | echohl None
    endif
endfunction


function! s:issubdir(subdir, dir)
    let dir = s:cleanpath(a:subdir)
    let pat = '^'.s:cleanpath(a:dir).'/'

    return (dir =~ pat)
endfunction

function! s:joinpath(first, last)
    let prefix = s:cleanpath(a:first)
    let suffix = s:cleanpath(a:last)

    return s:cleanpath(prefix.'/'.suffix)
endfunction

function! s:cleanpath(path)
    let path = a:path
    if !empty(path)
        if path =~ '^\~'
            let path = $HOME.'/'.path[1:]
        endif
        let path = simplify(path)
        if path =~ '/$'
            let path = path[:-2]
        endif
        return path
    endif
    return ''
endfunction


function! s:is_python_available(version)
    if !exists('s:is_python'.a:version.'_available')
        try
            let command = (a:version == 3) ? 'py3file' : 'pyfile'
            execute command fnameescape(g:virtualenv_python_script)
            execute 'let s:is_python'.a:version.'_available = 1'
        catch
            execute 'let s:is_python'.a:version.'_available = 0'
        endtry
    endif
    execute 'return s:is_python'.a:version.'_available'
endfunction

function! s:is_virtualenv_supported(target)
    let pythons = globpath(a:target.'/lib', 'python?.?', 0, 1)
    if empty(pythons)
        call s:Error('"'.a:target.'" appears to have no python installations')
        return
    endif
    let python_major_version = pythons[0][-3:][0]
    if !(s:is_python_available(python_major_version))
        call s:Error('"'.a:target.'" requires
                    \ python'.python_major_version.' support')
        return
    endif
    let s:python_version = l:python_major_version
    return 1
endfunction

function! s:execute_python_command(command)
    if exists('s:python_version')
        let interpreter = (s:python_version == 3) ? 'python3' : 'python'
        execute interpreter a:command
    endif
endfunction
