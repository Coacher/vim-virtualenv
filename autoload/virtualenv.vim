function! virtualenv#init()
    " make g:virtualenv_directory path absolute
    let g:virtualenv_directory = fnamemodify(g:virtualenv_directory, ':p')

    " normalize g:virtualenv_directory path
    let g:virtualenv_directory = s:normpath(g:virtualenv_directory)

    if !isdirectory(g:virtualenv_directory)
        call s:Error('incorrect value of ''g:virtualenv_directory'' variable: '
                    \.g:virtualenv_directory.' is not a directory')
        return 1
    endif
endfunction

function! virtualenv#activate(...)
    if (a:0 > 0)
        let name = s:normpath(a:1)
        if empty(name)
            call s:Error('empty virtualenv name')
            return 1
        endif

        let virtualenv_path = [g:virtualenv_directory, getcwd(), '/']
        for directory in virtualenv_path
            let virtualenvs = virtualenv#find(directory, name)
            if !empty(virtualenvs)
                let [target; rest] = virtualenvs
                let target = s:normpath(target)
                if !empty(rest)
                    call s:Warning('multiple virtualenvs under the name '
                                  \.name.' were found in '.directory)
                    call s:Warning('processing '.target)
                endif
                return virtualenv#deactivate() ||
                     \ virtualenv#force_activate(target)
            endif
        endfor

        call s:Warning('virtualenv '.name.' was not found in '
                      \.string(virtualenv_path))
        return 1
    else
        if empty($VIRTUAL_ENV) || (exists('s:virtualenv_directory_') &&
                                  \$VIRTUAL_ENV ==# s:virtualenv_directory_)
            " if either $VIRTUAL_ENV is not set, or it is set and
            " equals to the value of s:virtualenv_directory_ variable,
            " then try to determine virtualenv from the current file path
            let current_file_directory = expand('%:p:h')
            let target = s:virtualenv_from_path(current_file_directory)
            if !empty(target)
                if exists('s:virtualenv_directory_') &&
                  \target ==# s:virtualenv_directory_
                    call s:Warning('virtualenv '.target.' is already active')
                    return
                else
                    return virtualenv#deactivate() ||
                         \ virtualenv#force_activate(target)
                endif
            else
                call s:Warning('unable to determine virtualenv
                              \ from the current file path')
                return
            endif
        else
            " otherwise it is an externally activated virtualenv
            call s:Warning('externally activated virtualenv detected,
                          \ it cannot be deactivated via this plugin')
            let s:virtualenv_name = fnamemodify($VIRTUAL_ENV, ':t')
            return
        endif
    endif
endfunction

function! virtualenv#force_activate(target)
    if !s:is_virtualenv(a:target)
        call s:Error(a:target.' is not a valid virtualenv')
        return 1
    endif

    if !virtualenv#is_supported(a:target)
        return 1
    endif

    try
        let s:virtualenv_return_dir = getcwd()

        let s:virtualenv_directory_ = a:target
        let s:virtualenv_name = fnamemodify(a:target, ':t')

        call s:execute_python_command('virtualenv_activate',
                \s:joinpath(s:virtualenv_directory_, 'bin/activate_this.py'))
    catch
        return 1
    endtry

    command! -nargs=0 -bar VirtualEnvCdvirtualenv call virtualenv#cdvirtualenv()

    if g:virtualenv_cdvirtualenv_on_activate
        if !s:issubdir(s:virtualenv_return_dir, s:virtualenv_directory_) ||
          \g:virtualenv_force_cdvirtualenv_on_activate
            call virtualenv#cdvirtualenv()
        endif
    endif
endfunction

function! virtualenv#deactivate()
    if !exists('s:virtualenv_name') || !virtualenv#is_armed()
        call s:Warning('deactivation is not possible')
        return
    endif

    return virtualenv#force_deactivate()
endfunction

function! virtualenv#force_deactivate()
    try
        call s:execute_python_command('virtualenv_deactivate')
    catch
        return 1
    endtry

    unlet! s:virtualenv_name
    unlet! s:virtualenv_directory_

    delcommand VirtualEnvCdvirtualenv

    if g:virtualenv_return_on_deactivate && exists('s:virtualenv_return_dir')
        execute 'cd' fnameescape(s:virtualenv_return_dir)
    endif

    unlet! s:virtualenv_return_dir
    unlet! s:python_version
endfunction

function! virtualenv#cdvirtualenv()
    if exists('s:virtualenv_directory_')
        execute 'cd' fnameescape(s:virtualenv_directory_)
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
    let pattern = (a:0 > 0) ? (a:1) : '*'
    let tail = matchstr(pattern, '[/]\+$')
    let pattern = s:joinpath(pattern, '/')
    for target in globpath(a:directory, pattern, 0, 1)
        if !s:is_virtualenv(target)
            continue
        endif
        call add(virtualenvs, fnamemodify(target, ':h').tail)
    endfor
    return virtualenvs
endfunction

function! virtualenv#is_supported(target)
    if !exists('g:virtualenv_force_python_version')
        let pythons = globpath(a:target, 'lib/python?.?/', 0, 1)
        if !empty(pythons)
            let [python; rest] = pythons
            if !empty(rest)
                call s:Warning('multiple python installations were found in '
                              \.a:target)
                call s:Warning('processing '.python)
            endif
        else
            call s:Error('no python installations were found in '.a:target)
            return
        endif
        let python_major_version = python[-4:][0]
    else
        let python_major_version = g:virtualenv_force_python_version
        call s:Warning('python version for '.a:target.' is set to'
                      \.g:virtualenv_force_python_version)
    endif
    if !s:is_python_available(python_major_version)
        call s:Error(a:target.' requires python'.python_major_version.' support')
        return
    endif
    let s:python_version = l:python_major_version
    return 1
endfunction

function! virtualenv#is_armed()
    redir => output
        silent call s:execute_python_command('virtualenv_is_armed')
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


function! s:is_virtualenv(target)
    return isdirectory(a:target) &&
         \ filereadable(s:joinpath(a:target, 'bin/activate_this.py'))
endfunction

function! s:virtualenv_from_path(path)
    if s:issubdir(a:path, g:virtualenv_directory)
        let target = g:virtualenv_directory
        let tail = substitute(a:path, '^'.g:virtualenv_directory.'/', '', '')
    else
        let target = '/'
        let tail = fnamemodify(a:path, ':p')
    endif
    for part in split(tail, '/')
        let target = s:joinpath(target, part)
        if s:is_virtualenv(target)
            return target
        endif
    endfor
    return ''
endfunction


function! s:issubdir(subdirectory, directory)
    let directory = s:normpath(a:subdirectory)
    let pattern = '^'.s:normpath(a:directory).'/'

    return (directory =~ pattern)
endfunction

function! s:joinpath(first, last)
    if (a:first !~ '^$')
        let prefix = substitute(a:first, '[/]\+$', '', '')
        let suffix = substitute(a:last, '^[/]\+', '', '')
        return prefix.'/'.suffix
    else
        return a:last
    endif
endfunction

function! s:normpath(path)
    let path = a:path
    if !empty(path)
        if (path =~ '^\~')
            let user = matchstr(path, '^\~[^/]*')
            let home_directory = fnamemodify(user, ':p:h')
            let path = substitute(path, '^\'.user, home_directory, '')
        endif
        let path = simplify(path)
        let path = substitute(path, '^[/]\+', '/', '')
        let path = substitute(path, '[/]\+$', '', '')
        return path
    else
        return ''
    endif
endfunction


function! s:is_python_available(version)
    if !exists('s:is_python'.a:version.'_available')
        try
            let command = (a:version != 3) ? 'pyfile' : 'py3file'
            execute command fnameescape(g:virtualenv_python_script)
            execute 'let s:is_python'.a:version.'_available = 1'
        catch
            execute 'let s:is_python'.a:version.'_available = 0'
        endtry
    endif
    execute 'return s:is_python'.a:version.'_available'
endfunction

function! s:execute_python_command(command, ...)
    if exists('s:python_version')
        let interpreter = (s:python_version != 3) ? 'python' : 'python3'
        execute interpreter a:command s:construct_arguments(a:0, a:000)
    endif
endfunction

function! s:construct_arguments(number, list)
    let arguments = '('
    if (a:number > 0)
        let first_arguments = (a:number > 1) ? a:list[:(a:number - 2)] : []
        for argument in first_arguments
            let arguments .= s:process_argument(argument).', '
        endfor
        let last_argument = a:list[(a:number - 1)]
        if type(last_argument) != type({})
            let arguments .= s:process_argument(last_argument)
        else
            for [key, value] in items(last_argument)
                let arguments .= key.'='.s:process_argument(value).', '
            endfor
        endif
    endif
    let arguments .= ')'
    return arguments
endfunction

function! s:process_argument(argument)
    if type(a:argument) == type(0) || type(a:argument) == type(0.0)
        return a:argument
    else
        return string(a:argument)
    endif
endfunction
