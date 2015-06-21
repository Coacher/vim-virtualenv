function! virtualenv#init()
    let g:virtualenv#directory =
            \ s:normpath(fnamemodify(g:virtualenv#directory, ':p'))

    if !isdirectory(g:virtualenv#directory)
        call s:Error(string(g:virtualenv#directory).' is not a directory')
        return 1
    endif

    if (exists('g:virtualenv#force_python_version') &&
      \ (index([2,3], g:virtualenv#force_python_version) == -1))
        call s:Error('invalid value for g:virtualenv#force_python_version: '
                    \.string(g:virtualenv#force_python_version))
        return 1
    endif

    let s:state = {}
endfunction

function! virtualenv#activate(...)
    if (a:0)
        let name = s:normpath(a:1)
        if empty(name)
            call s:Error('empty virtualenv name')
            return 1
        endif

        let virtualenv_path = [g:virtualenv#directory, getcwd(), '/']
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
                return (virtualenv#deactivate() ||
                      \ virtualenv#force_activate(target))
            endif
        endfor

        call s:Warning('virtualenv '.name.' was not found in '
                      \.string(virtualenv_path))
        return 1
    else
        if (empty($VIRTUAL_ENV) ||
          \ (has_key(s:state, 'virtualenv_directory') &&
          \  ($VIRTUAL_ENV ==# s:state['virtualenv_directory'])))
            " if either $VIRTUAL_ENV is not set, or it is set and
            " equals to the value of s:state['virtualenv_directory'],
            " then search upwards from the directory of the current file
            let current_file_directory = expand('%:p:h')
            let target = virtualenv#origin(current_file_directory)

            if !empty(target)
                if (has_key(s:state, 'virtualenv_directory') &&
                  \ (target ==# s:state['virtualenv_directory']))
                    call s:Warning('virtualenv '.target.' is already active')
                    return
                else
                    return (virtualenv#deactivate() ||
                          \ virtualenv#force_activate(target))
                endif
            else
                call s:Warning('virtualenv of the current file was not found')
                return
            endif
        else
            " otherwise it is an externally activated virtualenv
            return virtualenv#force_activate($VIRTUAL_ENV, 'external')
        endif
    endif
endfunction

function! virtualenv#force_activate(target, ...)
    if !s:isvirtualenv(a:target)
        call s:Error(a:target.' is not a valid virtualenv')
        return 1
    endif

    let internal = !(a:0 && (a:1 ==# 'external'))
    let pyversion = virtualenv#supported(a:target, (internal) ? '' : 'external')

    if !(pyversion)
        call s:Error(a:target.' is not supported')
        return 1
    endif

    let s:state['python_version'] = pyversion
    let s:state['virtualenv_internal'] = internal
    let s:state['virtualenv_directory'] = a:target
    let s:state['virtualenv_return_dir'] = getcwd()
    let s:state['virtualenv_name'] = fnamemodify(a:target, ':t')

    try
        if (s:state['virtualenv_internal'])
            call s:execute_python_command(
                    \'virtualenv_activate',
                    \s:joinpath(s:state['virtualenv_directory'],
                    \           'bin/activate_this.py'),
                    \g:virtualenv#update_pythonpath)
        else
            let [syspath] = s:execute_system_python_command(
                    \'import sys; print(list(sys.path))')
            call s:execute_python_command('virtualenv_update_syspath', syspath)
        endif
    catch
        unlet! s:state['virtualenv_name']
        unlet! s:state['virtualenv_return_dir']
        unlet! s:state['virtualenv_directory']
        unlet! s:state['virtualenv_internal']
        unlet! s:state['python_version']

        call s:Error(v:throwpoint)
        call s:Error(v:exception)

        return 1
    endtry

    command! -nargs=0 -bar VirtualEnvCD call virtualenv#cdvirtualenv()

    if (g:virtualenv#cdvirtualenv_on_activate &&
      \ !s:issubdir(s:state['virtualenv_return_dir'],
      \             s:state['virtualenv_directory']))
        call virtualenv#cdvirtualenv()
    endif
endfunction

function! virtualenv#deactivate()
    if (!has_key(s:state, 'virtualenv_name') || !virtualenv#armed())
        call s:Warning('deactivation is not possible')
        return
    endif
    return virtualenv#force_deactivate()
endfunction

function! virtualenv#force_deactivate()
    if (g:virtualenv#return_on_deactivate &&
      \ has_key(s:state, 'virtualenv_return_dir'))
        execute 'cd' fnameescape(s:state['virtualenv_return_dir'])
    endif

    delcommand VirtualEnvCD

    try
        call s:execute_python_command('virtualenv_deactivate',
                                     \s:state['virtualenv_internal'])
    catch
        return 1
    endtry

    unlet! s:state['virtualenv_name']
    unlet! s:state['virtualenv_return_dir']
    unlet! s:state['virtualenv_directory']
    unlet! s:state['virtualenv_internal']
    unlet! s:state['python_version']
endfunction

function! virtualenv#cdvirtualenv()
    if has_key(s:state, 'virtualenv_directory')
        execute 'cd' fnameescape(s:state['virtualenv_directory'])
    endif
endfunction

function! virtualenv#list(...)
    let directory = !(a:0) ? g:virtualenv#directory : a:1
    for virtualenv in virtualenv#find(directory)
        echo virtualenv
    endfor
endfunction

function! virtualenv#statusline()
    if has_key(s:state, 'virtualenv_name')
        return substitute(g:virtualenv#statusline_format, '\C%n',
                         \s:state['virtualenv_name'], 'g')
    else
        return ''
    endif
endfunction

" helper functions
function! virtualenv#find(directory, ...)
    let virtualenvs = []
    let pattern = (a:0) ? a:1 : '*'
    let tail = matchstr(pattern, '[/]\+$')
    let pattern = s:joinpath(pattern, '/')
    for target in globpath(a:directory, pattern, 0, 1)
        if !s:isvirtualenv(target)
            continue
        endif
        call add(virtualenvs, fnamemodify(target, ':h').tail)
    endfor
    return virtualenvs
endfunction

function! virtualenv#supported(target, ...)
    if !exists('g:virtualenv#force_python_version')
        let internal = !(a:0 && (a:1 ==# 'external'))
        let python_major_version =
                \ (internal) ? virtualenv#supported_internal(a:target)
                \            : virtualenv#supported_external(a:target)
    else
        let python_major_version = g:virtualenv#force_python_version
        call s:Warning('Python version for '.a:target.' is set to '
                      \.g:virtualenv#force_python_version)
        if !s:python_available(python_major_version)
            call s:Error(a:target.' requires python'.python_major_version)
            return
        endif
    endif
    return python_major_version
endfunction

function! virtualenv#supported_internal(target)
    let pythons = globpath(a:target, 'lib/python?.?/', 0, 1)
    if !empty(pythons)
        let [python; rest] = pythons
        if !empty(rest)
            call s:Warning('multiple Python versions were found in '.a:target)
            call s:Warning('processing '.python)
        endif
    else
        call s:Error('no Python installations were found in '.a:target)
        return
    endif
    let python_major_version = python[-4:][0]
    if !s:python_available(python_major_version)
        call s:Error(a:target.' requires python'.python_major_version)
        return
    endif
    return python_major_version
endfunction

function! virtualenv#supported_external(target)
    let [extpython] = s:execute_system_python_command(
            \'import sys; print(u".".join(str(x) for x in sys.version_info))')
    let python_major_version = extpython[0]
    if !s:python_available(python_major_version)
        call s:Error(a:target.' requires python'.python_major_version)
        return
    endif
    let [vimpython] = s:execute_pythonX_command(
            \python_major_version,
            \'import sys; print(u".".join(str(x) for x in sys.version_info))')
    if (vimpython !=# extpython)
        call s:Error('Python version mismatch')
        call s:Error(a:target.' version: '.extpython)
        call s:Error('Vim version: '.vimpython)
        return
    endif
    return python_major_version
endfunction

function! virtualenv#armed()
    if !has_key(s:state, 'virtualenv_internal')
        return
    endif
    let [status] = s:execute_python_command('virtualenv_status',
                                           \s:state['virtualenv_internal'])
    return (status ==# 'armed')
endfunction

function! virtualenv#origin(path)
    if s:issubdir(a:path, g:virtualenv#directory)
        let target = g:virtualenv#directory
        let tail = substitute(a:path, '^'.g:virtualenv#directory.'/', '', '')
    else
        let target = '/'
        let tail = fnamemodify(a:path, ':p')
    endif
    for part in split(tail, '/')
        let target = s:joinpath(target, part)
        if s:isvirtualenv(target)
            return target
        endif
    endfor
    return ''
endfunction

function! virtualenv#state(...)
    function! Query(key)
        echo a:key.' = '.get(s:state, a:key, '__undefined__')
    endfunction

    if (a:0)
        call Query(a:1)
    else
        for key in keys(s:state)
            call Query(key)
        endfor
    endif
endfunction

" misc functions
function! s:isvirtualenv(target)
    return (isdirectory(a:target) &&
          \ filereadable(s:joinpath(a:target, 'bin/activate_this.py')))
endfunction

" debug functions
function! s:Error(message)
    echohl ErrorMsg | echo 'vim-virtualenv: '.a:message | echohl None
endfunction

function! s:Warning(message)
    if (g:virtualenv#debug)
        echohl WarningMsg | echo 'vim-virtualenv: '.a:message | echohl None
    endif
endfunction

" paths machinery
function! s:issubdir(subdirectory, directory)
    let directory = s:normpath(a:subdirectory)
    let pattern = '^'.s:normpath(a:directory).'/'
    return (directory =~# fnameescape(pattern))
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

" python machinery
function! s:python_available(version)
    if !has_key(s:state, 'python'.a:version.'_available')
        try
            let command = (a:version != 3) ? 'pyfile' : 'py3file'
            execute command fnameescape(g:virtualenv#python_script)
            execute 'let s:state["python'.a:version.'_available"] = 1'
        catch
            execute 'let s:state["python'.a:version.'_available"] = 0'
        endtry
    endif
    execute 'return s:state["python'.a:version.'_available"]'
endfunction

function! s:execute_system_python_command(command)
    return systemlist('python -c '.string(a:command))
endfunction

function! s:execute_python_command(command, ...)
    let interpreter = (s:state['python_version'] != 3) ? 'python' : 'python3'
    let command = a:command.((a:0) ? s:construct_arguments(a:0, a:000) : '')
    redir => output
        silent execute interpreter command
    redir END
    return split(output, '\n')
endfunction

function! s:execute_pythonX_command(version, command, ...)
    let interpreter = (a:version != 3) ? 'python' : 'python3'
    let command = a:command.((a:0) ? s:construct_arguments(a:0, a:000) : '')
    redir => output
        silent execute interpreter command
    redir END
    return split(output, '\n')
endfunction

function! s:construct_arguments(number, list)
    let arguments = '('
    if (a:number)
        let first_arguments = (a:number > 1) ? a:list[:(a:number - 2)] : []
        for argument in first_arguments
            let arguments .= s:process_argument(argument).', '
        endfor
        let last_argument = a:list[(a:number - 1)]
        if (type(last_argument) != type({}))
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
    if ((type(a:argument) == type(0)) || (type(a:argument) == type(0.0)))
        return a:argument
    elseif (type(a:argument) == type(''))
        return '"""'.a:argument.'"""'
    else
        return string(a:argument)
    endif
endfunction
