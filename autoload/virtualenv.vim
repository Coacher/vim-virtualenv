function! virtualenv#init()
    let s:state = {}

    let s:vim_major = and(v:python3_version >> 24, 0xff)
    let s:vim_minor = and(v:python3_version >> 16, 0xff)

    let s:custom_project_finder = 'virtualenv#gutentags_project_root_finder'

    try
        execute 'py3file' fnameescape(g:virtualenv#python_script)
    catch
        return s:error('failed to load Python virtual environment manager')
    endtry

    if !empty(g:virtualenv#directory)
        let g:virtualenv#directory =
            \ s:normalize_path(fnamemodify(g:virtualenv#directory, ':p'))

        if !isdirectory(g:virtualenv#directory)
            return s:error('invalid value for g:virtualenv#directory: '.
                          \string(g:virtualenv#directory))
        endif
    endif
endfunction

function! virtualenv#activate(...)
    if (a:0)
        let l:name = s:normalize_path(a:1)
        if empty(l:name)
            return s:error('requested virtualenv with an empty name')
        endif

        let l:virtualenv_path = [g:virtualenv#directory, getcwd(), '/']
        for l:directory in l:virtualenv_path
            let l:virtualenvs = virtualenv#find(l:directory, l:name)
            if !empty(l:virtualenvs)
                let [l:target; l:rest] = l:virtualenvs
                let l:target = s:normalize_path(l:target)
                if !empty(l:rest)
                    call s:warning('multiple virtualenvs under the name '.
                                  \l:name.' were found in '.l:directory)
                    call s:warning('processing '.l:target)
                endif
                return virtualenv#deactivate() ||
                     \ virtualenv#force_activate(l:target)
            endif
        endfor

        return s:error('requested virtualenv '.l:name.
                      \' was not found in '.string(l:virtualenv_path))
    else
        if empty($VIRTUAL_ENV) ||
         \ ($VIRTUAL_ENV ==# virtualenv#state('virtualenv_directory'))
            " if either $VIRTUAL_ENV is not set, or it is set and
            " equals to the value of s:state['virtualenv_directory'],
            " then use the innermost virtualenv of the current directory

            let l:virtualenv_path = [expand('%:p:h'), getcwd()]
            for l:directory in l:virtualenv_path
                let l:target = virtualenv#origin(l:directory)
                if !empty(l:target)
                    if (l:target ==# virtualenv#state('virtualenv_directory'))
                        return s:warning('virtualenv of the current directory '.
                                        \'is already active')
                    else
                        return virtualenv#deactivate() ||
                             \ virtualenv#force_activate(l:target)
                    endif
                endif
            endfor

            return s:warning('virtualenv of the current directory was not found')
        else
            " otherwise it is an externally activated virtualenv
            return virtualenv#deactivate() ||
                 \ virtualenv#force_activate($VIRTUAL_ENV, 'external')
        endif
    endif
endfunction

function! virtualenv#force_activate(target, ...)
    let l:target = s:normalize_path(a:target)

    let l:env_type = s:get_env_type(l:target)
    if empty(l:env_type)
        return s:error(l:target.' is not a valid virtualenv')
    endif

    if (l:env_type ==# 'virtualenv')
        let l:project_link = l:target.'/.project'
        if filereadable(l:project_link)
            let [l:project] = readfile(l:project_link, '', 1)
        endif
    elseif (l:env_type ==# 'uv')
        let l:project = l:target
        let l:target .= '/.venv'
    endif

    let l:internal = !(a:0 && (a:1 ==# 'external'))
    let l:pyversion = s:get_pyversion(l:target, l:internal)

    if !s:is_python_supported(l:pyversion)
        let [l:major, l:minor] = l:pyversion
        call s:error('Python version mismatch')
        call s:error('Environment version: '.l:major.'.'.l:minor)
        call s:error('Vim version: '.s:vim_major.'.'.s:vim_minor)
        return s:error(l:target.' is not supported')
    endif

    let s:state['virtualenv_type'] = l:env_type
    let s:state['virtualenv_internal'] = l:internal
    let s:state['virtualenv_python'] = join(l:pyversion, '.')
    let s:state['virtualenv_directory'] = l:target
    let s:state['virtualenv_return_dir'] = getcwd()
    let s:state['virtualenv_name'] =
        \ fnamemodify((l:env_type !=# 'uv') ? l:target : l:project, ':t')

    if exists('l:project')
        let s:state['virtualenv_project_dir'] = l:project
    endif

    doautocmd <nomodeline> User VirtualEnvActivatePre

    try
        if l:internal
            call s:execute_python_command(
                \ 'VirtualEnvManager.activate', l:target)
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
        unlet! s:state['virtualenv_project_dir']
        unlet! s:state['virtualenv_name']
        unlet! s:state['virtualenv_return_dir']
        unlet! s:state['virtualenv_directory']
        unlet! s:state['virtualenv_python']
        unlet! s:state['virtualenv_internal']
        unlet! s:state['virtualenv_type']

        call s:error(v:throwpoint)
        call s:error(v:exception)

        return 1
    endtry

    command! -nargs=0 -bar VirtualEnvCD call virtualenv#cdvirtualenv()

    if g:virtualenv#cdvirtualenv_on_activate &&
     \ !s:is_subdir(getcwd(), l:target)
        call virtualenv#cdvirtualenv()
    endif

    if g:virtualenv#enable_gutentags_support &&
     \ empty(g:gutentags_project_root_finder)
        let g:gutentags_project_root_finder = s:custom_project_finder
    endif

    doautocmd <nomodeline> User VirtualEnvActivatePost
endfunction

function! virtualenv#deactivate()
    if !has_key(s:state, 'virtualenv_name')
        return s:warning('no active virtualenv to deactivate')
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
     \ (g:gutentags_project_root_finder ==# s:custom_project_finder)
        let g:gutentags_project_root_finder = ''
    endif

    try
        call s:execute_python_command('VirtualEnvManager.deactivate()')
    catch
        return 1
    endtry

    doautocmd <nomodeline> User VirtualEnvDeactivatePost

    unlet! s:state['virtualenv_project_dir']
    unlet! s:state['virtualenv_name']
    unlet! s:state['virtualenv_return_dir']
    unlet! s:state['virtualenv_directory']
    unlet! s:state['virtualenv_python']
    unlet! s:state['virtualenv_internal']
    unlet! s:state['virtualenv_type']
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

" helper functions
function! virtualenv#find(directory, ...)
    let l:virtualenvs = []
    let l:pattern = (a:0) ? a:1 : '*'
    let l:pattern = s:join_path(l:pattern, '/')
    for l:target in globpath(a:directory, l:pattern, 0, 1)
        if empty(s:get_env_type(l:target))
            continue
        endif
        call add(l:virtualenvs, fnamemodify(l:target, ':h'))
    endfor
    return l:virtualenvs
endfunction

function! virtualenv#origin(path)
    let l:path = s:normalize_path(fnamemodify(a:path, ':p'))
    let l:prev = ''
    while (l:path !=# l:prev)
        if !empty(s:get_env_type(l:path))
            return l:path
        endif
        let l:prev = l:path
        let l:path = fnamemodify(l:path, ':h')
    endwhile
    return ''
endfunction

function! virtualenv#state(...)
    if (a:0)
        return get(s:state, a:1, '')
    endif
    for [l:key, l:value] in items(s:state)
        echo l:key.' = '.l:value
    endfor
endfunction

" external integration functions
function! virtualenv#gutentags_project_root_finder(path)
    let l:virtualenv_directory = virtualenv#state('virtualenv_directory')
    if !empty(l:virtualenv_directory) &&
     \ s:is_subdir(a:path, l:virtualenv_directory)
        return l:virtualenv_directory
    else
        return gutentags#default_get_project_root(a:path)
    endif
endfunction

" misc functions
function! s:get_env_type(target)
    if !isdirectory(a:target)
        return ''
    elseif filereadable(s:join_path(a:target, 'bin/activate_this.py'))
        return 'virtualenv'
    elseif filereadable(s:join_path(a:target, '.venv/pyvenv.cfg'))
        return 'uv'
    elseif filereadable(s:join_path(a:target, 'pyvenv.cfg'))
        return 'venv'
    endif
    return ''
endfunction

function! s:get_pyversion(target, internal)
    return a:internal
         \ ? s:get_pyversion_internal(a:target)
         \ : s:get_pyversion_external(a:target)
endfunction

function! s:get_pyversion_internal(target)
    let l:pythons = globpath(a:target, 'lib/python?.?*/', 0, 1)
    if !empty(l:pythons)
        let [l:python; l:rest] = l:pythons
        if !empty(l:rest)
            call s:warning('multiple Python versions were found in '.a:target)
            call s:warning('processing '.l:python)
        endif
    else
        call s:warning('no Python installations were found in '.a:target)
        return []
    endif
    let [l:major, l:minor] =
        \ split(fnamemodify(s:normalize_path(l:python), ':t'), '\.')
    return [l:major[-1:], l:minor]
endfunction

function! s:get_pyversion_external(...)
    return s:execute_system_python_command(
         \  'import sys; print(*sys.version_info[:2], sep="\n")')
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
function! s:error(message)
    echohl ErrorMsg | echomsg 'vim-virtualenv: '.a:message | echohl None
    return 1
endfunction

function! s:warning(message)
    if g:virtualenv#debug
        echohl WarningMsg | echomsg 'vim-virtualenv: '.a:message | echohl None
    endif
    return 0
endfunction

" paths machinery
function! s:is_subdir(subdirectory, directory)
    let l:directory = s:normalize_path(a:subdirectory)
    let l:pattern = '^'.s:normalize_path(a:directory).'/'
    return (l:directory =~# fnameescape(l:pattern))
endfunction

function! s:join_path(first, last)
    if !empty(a:first) && !empty(a:last)
        let l:prefix = substitute(a:first, '[/]\+$', '', '')
        let l:suffix = substitute(a:last, '^[/]\+', '', '')
        return l:prefix.'/'.l:suffix
    else
        return empty(a:first) ? a:last : a:first
    endif
endfunction

function! s:normalize_path(path)
    " Normalize path:
    " - expand user directories,
    " - simplify as much as possible,
    " - keep a single leading slash,
    " - remove any trailing slashes.
    let l:path = a:path
    if !empty(l:path)
        if (l:path =~# '^\~')
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
