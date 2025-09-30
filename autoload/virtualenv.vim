function! virtualenv#init()
    let s:state = {}

    let s:vim_major = and(v:python3_version >> 24, 0xff)
    let s:vim_minor = and(v:python3_version >> 16, 0xff)

    let s:custom_project_finder = 'virtualenv#gutentags_project_root_finder'

    try
        execute 'py3file' fnameescape(g:virtualenv#python_script)
    catch
        return s:Error('failed to load Python virtual environment manager')
    endtry

    if (g:virtualenv#directory !=# v:null)
        let g:virtualenv#directory =
            \ s:normpath(fnamemodify(g:virtualenv#directory, ':p'))

        if !isdirectory(g:virtualenv#directory)
            return s:Error('invalid value for g:virtualenv#directory: '.
                          \string(g:virtualenv#directory))
        endif

        if empty($WORKON_HOME)
            let $WORKON_HOME = g:virtualenv#directory
        endif
    endif
endfunction

function! virtualenv#activate(...)
    if (a:0)
        let l:name = s:normpath(a:1)
        if empty(l:name)
            return s:Error('requested virtualenv with an empty name')
        endif

        let l:virtualenv_path = [g:virtualenv#directory, getcwd(), '/']
        for l:directory in l:virtualenv_path
            let l:virtualenvs = virtualenv#find(l:directory, l:name)
            if !empty(l:virtualenvs)
                let [l:target; l:rest] = l:virtualenvs
                let l:target = s:normpath(l:target)
                if !empty(l:rest)
                    call s:Warning('multiple virtualenvs under the name '.
                                  \l:name.' were found in '.l:directory)
                    call s:Warning('processing '.l:target)
                endif
                return virtualenv#deactivate() ||
                     \ virtualenv#force_activate(l:target)
            endif
        endfor

        call s:Warning('requested virtualenv '.l:name.
                      \' was not found in '.string(l:virtualenv_path))
        return 1
    else
        if empty($VIRTUAL_ENV) ||
         \ (has_key(s:state, 'virtualenv_directory') &&
         \  ($VIRTUAL_ENV ==# s:state['virtualenv_directory']))
            " if either $VIRTUAL_ENV is not set, or it is set and
            " equals to the value of s:state['virtualenv_directory'],
            " then use the topmost virtualenv of the current directory

            let l:virtualenv_path = [expand('%:p:h'), getcwd()]
            for l:directory in l:virtualenv_path
                let l:target = virtualenv#origin(l:directory)
                if !empty(l:target)
                    if has_key(s:state, 'virtualenv_directory') &&
                     \ (l:target ==# s:state['virtualenv_directory'])
                        return s:Warning('virtualenv of the current directory '.
                                        \'is already active')
                    else
                        return virtualenv#deactivate() ||
                             \ virtualenv#force_activate(l:target)
                    endif
                endif
            endfor

            return s:Warning('virtualenv of the current directory was not found')
        else
            " otherwise it is an externally activated virtualenv
            return virtualenv#deactivate() ||
                 \ virtualenv#force_activate($VIRTUAL_ENV, 'external')
        endif
    endif
endfunction

function! virtualenv#force_activate(target, ...)
    if !s:is_virtualenv(a:target)
        return s:Error(a:target.' is not a valid virtualenv')
    endif

    let l:internal = !(a:0 && (a:1 ==# 'external'))
    let l:pyversion =
        \ virtualenv#supported(a:target, l:internal ? '' : 'external')

    if !(l:pyversion)
        return s:Error(a:target.' is not supported')
    endif

    let s:state['virtualenv_internal'] = l:internal
    let s:state['virtualenv_directory'] = a:target
    let s:state['virtualenv_return_dir'] = getcwd()
    let s:state['virtualenv_name'] = fnamemodify(a:target, ':t')

    doautocmd <nomodeline> User VirtualEnvActivatePre

    try
        if s:state['virtualenv_internal']
            call s:execute_python_command(
                \ 'VirtualEnvManager.activate',
                \ s:state['virtualenv_directory'],
                \ g:virtualenv#update_pythonpath)
        else
            let [l:sys_path, l:sys_prefix, l:sys_exec_prefix] =
                \ s:execute_system_python_command(
                \  'import sys; '.
                \  'print(sys.path, sys.prefix, sys.exec_prefix, sep="\n")')
            call s:execute_python_command(
                \ 'VirtualEnvManager.extactivate',
                \ l:sys_path,
                \ l:sys_prefix,
                \ l:sys_exec_prefix)
        endif
    catch
        unlet! s:state['virtualenv_name']
        unlet! s:state['virtualenv_return_dir']
        unlet! s:state['virtualenv_directory']
        unlet! s:state['virtualenv_internal']

        call s:Error(v:throwpoint)
        call s:Error(v:exception)

        return 1
    endtry

    command! -nargs=0 -bar VirtualEnvCD call virtualenv#cdvirtualenv()

    if g:virtualenv#cdvirtualenv_on_activate &&
     \ !s:is_subdir(
     \  s:state['virtualenv_return_dir'],
     \  s:state['virtualenv_directory'])
        call virtualenv#cdvirtualenv()
    endif

    if g:virtualenv#enable_gutentags_support &&
     \ empty(g:gutentags_project_root_finder)
        let g:gutentags_project_root_finder = s:custom_project_finder
    endif

    doautocmd <nomodeline> User VirtualEnvActivatePost
endfunction

function! virtualenv#gutentags_project_root_finder(path)
    if has_key(s:state, 'virtualenv_directory') &&
     \ (s:normpath(a:path) =~# '^'.s:state['virtualenv_directory'])
        return s:state['virtualenv_directory']
    endif
    return gutentags#default_get_project_root(a:path)
endfunction

function! virtualenv#deactivate()
    if !has_key(s:state, 'virtualenv_name')
        return s:Warning('no active virtualenv to deactivate')
    endif
    return virtualenv#force_deactivate()
endfunction

function! virtualenv#force_deactivate()
    doautocmd <nomodeline> User VirtualEnvDeactivatePre

    if g:virtualenv#return_on_deactivate &&
     \ has_key(s:state, 'virtualenv_return_dir')
        execute 'cd' fnameescape(s:state['virtualenv_return_dir'])
    endif

    delcommand VirtualEnvCD

    if g:virtualenv#enable_gutentags_support &&
     \ g:gutentags_project_root_finder ==# s:custom_project_finder
        let g:gutentags_project_root_finder = ''
    endif

    try
        call s:execute_python_command('VirtualEnvManager.deactivate()')
    catch
        return 1
    endtry

    doautocmd <nomodeline> User VirtualEnvDeactivatePost

    unlet! s:state['virtualenv_name']
    unlet! s:state['virtualenv_return_dir']
    unlet! s:state['virtualenv_directory']
    unlet! s:state['virtualenv_internal']
endfunction

function! virtualenv#cdvirtualenv()
    if has_key(s:state, 'virtualenv_directory')
        execute 'cd' fnameescape(s:state['virtualenv_directory'])
    endif
endfunction

function! virtualenv#list(...)
    let l:directory = !(a:0) ? g:virtualenv#directory : a:1
    for l:virtualenv in virtualenv#find(l:directory)
        echo l:virtualenv
    endfor
endfunction

function! virtualenv#statusline()
    return has_key(s:state, 'virtualenv_name')
         \ ? substitute(
         \    g:virtualenv#statusline_format, '\C%n',
         \    s:state['virtualenv_name'], 'g')
         \ : ''
endfunction

" helper functions
function! virtualenv#find(directory, ...)
    let l:virtualenvs = []
    let l:pattern = (a:0) ? a:1 : '*'
    let l:pattern = s:joinpath(l:pattern, '/')
    for l:target in globpath(a:directory, l:pattern, 0, 1)
        if !s:is_virtualenv(l:target)
            continue
        endif
        call add(l:virtualenvs, fnamemodify(l:target, ':h'))
    endfor
    return l:virtualenvs
endfunction

function! virtualenv#supported(target, ...)
    let l:internal = !(a:0 && (a:1 ==# 'external'))
    let l:python_major_version =
        \ l:internal ? virtualenv#supported_internal(a:target)
        \            : virtualenv#supported_external(a:target)
    return l:python_major_version
endfunction

function! virtualenv#supported_internal(target)
    let l:pythons = globpath(a:target, 'lib/python?.?*/', 0, 1)
    if !empty(l:pythons)
        let [l:python; l:rest] = l:pythons
        if !empty(l:rest)
            call s:Warning('multiple Python versions were found in '.a:target)
            call s:Warning('processing '.l:python)
        endif
    else
        call s:Error('no Python installations were found in '.a:target)
        return
    endif
    let l:python = split(fnamemodify(s:normpath(l:python), ':t'), '\.')
    return l:python[0][-1:]
endfunction

function! virtualenv#supported_external(target)
    let [l:extpython] =
        \ s:execute_system_python_command(
        \  'import sys; print(u".".join(str(x) for x in sys.version_info))')
    let l:python_major_version = l:extpython[0]
    let [l:vimpython] =
        \ s:execute_python_command(
        \  'import sys; print(u".".join(str(x) for x in sys.version_info))')
    if (l:vimpython !=# l:extpython)
        call s:Error('Python version mismatch')
        call s:Error(a:target.' version: '.l:extpython)
        call s:Error('Vim version: '.l:vimpython)
        return
    endif
    return l:python_major_version
endfunction

function! virtualenv#origin(path)
    if s:is_subdir(a:path, g:virtualenv#directory)
        let l:target = g:virtualenv#directory
        let l:tail = substitute(a:path, '^'.g:virtualenv#directory.'/', '', '')
    else
        let l:target = '/'
        let l:tail = fnamemodify(a:path, ':p')
    endif
    for l:part in split(l:tail, '/')
        let l:target = s:joinpath(l:target, l:part)
        if s:is_virtualenv(l:target)
            return l:target
        endif
    endfor
    return ''
endfunction

function! virtualenv#state(...)
    if (a:0)
        echo a:1.' = '.get(s:state, a:1, '__undefined__')
    else
        for [l:key, l:value] in items(s:state)
            echo l:key.' = '.l:value
        endfor
    endif
endfunction

" misc functions
function! s:is_virtualenv(target)
    return isdirectory(a:target) &&
        \ (filereadable(s:joinpath(a:target, 'pyvenv.cfg')) ||
        \  filereadable(s:joinpath(a:target, 'bin/activate_this.py')))
endfunction

function! s:is_python_supported(pyversion)
    let [l:major, l:minor] = a:pyversion
    if has('python3_stable')
        return (l:major >= s:vim_major) && (l:minor >= s:vim_minor)
    else
        return (l:major == s:vim_major) && (l:minor == s:vim_minor)
    endif
endfunction

" debug functions
function! s:Error(message)
    echohl ErrorMsg | echomsg 'vim-virtualenv: '.a:message | echohl None
    return 1
endfunction

function! s:Warning(message)
    if g:virtualenv#debug
        echohl WarningMsg | echomsg 'vim-virtualenv: '.a:message | echohl None
    endif
    return 0
endfunction

" paths machinery
function! s:is_subdir(subdirectory, directory)
    let l:directory = s:normpath(a:subdirectory)
    let l:pattern = '^'.s:normpath(a:directory).'/'
    return (l:directory =~# fnameescape(l:pattern))
endfunction

function! s:joinpath(first, last)
    if !empty(a:first) && !empty(a:last)
        let l:prefix = substitute(a:first, '[/]\+$', '', '')
        let l:suffix = substitute(a:last, '^[/]\+', '', '')
        return l:prefix.'/'.l:suffix
    else
        return empty(a:first) ? a:last : a:first
    endif
endfunction

function! s:normpath(path)
    let l:path = a:path
    if !empty(l:path)
        if (l:path =~# '^\~')
            " Expand user directories, but otherwise keep the path relative.
            let l:user = matchstr(l:path, '^\~[^/]*')
            let l:home_directory = fnamemodify(l:user, ':p:h')
            let l:path = substitute(l:path, '^\'.l:user, l:home_directory, '')
        endif
        let l:path = simplify(l:path)
        let l:path = substitute(l:path, '^[/]\+', '/', '')
        let l:path = substitute(l:path, '[/]\+$', '', '')
    endif
    return l:path
endfunction

" python machinery
function! s:execute_system_python_command(command)
    return systemlist('python -c '.string(a:command))
endfunction

function! s:execute_python_command(command, ...)
    let l:command = a:command.((a:0) ? s:build_arguments(a:000) : '')
    return split(execute('python3 '.l:command), '\n')
endfunction

function! s:build_arguments(arguments)
    let l:arguments = '('
    for l:argument in a:arguments
        let l:arguments .= s:process_argument(l:argument).', '
    endfor
    let l:arguments .= ')'
    return l:arguments
endfunction

function! s:process_argument(argument)
    let l:argtype = type(a:argument)
    if (l:argtype == v:t_number) || (l:argtype == v:t_float)
        return a:argument
    elseif (l:argtype == v:t_string)
        return '"""'.a:argument.'"""'
    else
        return string(a:argument)
    endif
endfunction

call virtualenv#init()
