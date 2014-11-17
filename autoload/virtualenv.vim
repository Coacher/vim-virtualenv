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
            let current_file_directory = expand('%:p:h')
            if s:issubdir(current_file_directory, g:virtualenv_directory)
                let name = split(substitute(current_file_directory,
                            \ g:virtualenv_directory, '', ''), '/')[0]
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

    let virtualenv_path = [g:virtualenv_directory, getcwd(), '']
    for directory in virtualenv_path
        let target = s:cleanpath(fnamemodify(s:joinpath(directory, name), ':p'))
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

    if g:virtualenv_return_on_deactivate && exists('s:virtualenv_return_dir')
        execute 'cd' s:virtualenv_return_dir
    endif

    unlet! s:virtualenv_return_dir
    unlet! s:python_version
endfunction

function! virtualenv#cdvirtualenv()
    if exists('s:virtualenv_dir')
        execute 'cd' s:virtualenv_dir
    endif
endfunction

function! virtualenv#list(...)
    let directory = (a:0 > 0) ? (a:1) : g:virtualenv_directory
    for virtualenv in virtualenv#find(directory)
        echo virtualenv
    endfor
endfunction

function! virtualenv#statusline()
    if exists('s:virtualenv_name')
        return substitute(g:virtualenv_stl_format, '\C%n', s:virtualenv_name, 'g')
    else
        return ''
    endif
endfunction


function! virtualenv#find(directory, ...)
    let virtualenvs = []
    let pattern = (a:0 > 0) ? (a:1) : '*/'
    for target in globpath(a:directory, pattern, 0, 1)
        if !isdirectory(target)
            continue
        endif
        let script = target.'/bin/activate_this.py'
        if !filereadable(script)
            continue
        endif
        call add(virtualenvs, target)
    endfor
    return virtualenvs
endfunction

function! virtualenv#is_armed()
    redir => output
        silent call s:execute_python_command('virtualenv_is_armed()')
    redir END
    return (output =~ 'armed')
endfunction


function! s:Error(message)
    echohl ErrorMsg | echo 'vim-virtualenv: '.string(a:message) | echohl None
endfunction

function! s:Warning(message)
    if g:virtualenv_debug
        echohl WarningMsg | echo 'vim-virtualenv: '.string(a:message) | echohl None
    endif
endfunction


function! s:issubdir(subdirectory, directory)
    let directory = s:cleanpath(a:subdirectory)
    let pattern = '^'.s:cleanpath(a:directory).'/'

    return (directory =~ pattern)
endfunction

function! s:joinpath(first, last)
    if !empty(a:first)
        let prefix = s:cleanpath(a:first)
        let suffix = s:cleanpath(a:last)

        return s:cleanpath(prefix.'/'.suffix)
    else
        return s:cleanpath(a:last)
    endif
endfunction

function! s:cleanpath(path)
    let path = a:path
    if !empty(path)
        if path =~ '^\~'
            let user = split(path, '/')[0]
            let home_directory = fnamemodify(user, ':p:h')
            let path = substitute(path, '\'.user, home_directory, '')
        endif
        let path = simplify(path)
        if path =~ '^\@!/$'
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
    let pythons = globpath(a:target, 'lib/python?.?', 0, 1)
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
