function! virtualenv#init()
    let g:virtualenv#directory = s:normpath(fnamemodify(g:virtualenv#directory, ':p'))

    if !isdirectory(g:virtualenv#directory)
        call s:Error(string(g:virtualenv#directory).' is not a directory')
        return 1
    endif

    if exists('g:virtualenv#force_python_version') &&
     \ (index([2,3], g:virtualenv#force_python_version) == -1)
        call s:Error('invalid value for g:virtualenv#force_python_version: '.
                     \string(g:virtualenv#force_python_version))
        return 1
    endif

    if empty($WORKON_HOME)
        let $WORKON_HOME = g:virtualenv#directory
    endif

    let s:state = {}
endfunction

function! virtualenv#activate(...)
    if (a:0)
        let l:name = s:normpath(a:1)
        if empty(l:name)
            call s:Error('empty virtualenv name')
            return 1
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
                return virtualenv#deactivate() || virtualenv#force_activate(l:target)
            endif
        endfor

        call s:Warning('virtualenv '.l:name.' was not found in '.string(l:virtualenv_path))
        return 1
    else
        if empty($VIRTUAL_ENV) ||
         \ (has_key(s:state, 'virtualenv_directory') &&
         \  ($VIRTUAL_ENV ==# s:state['virtualenv_directory']))
            " if either $VIRTUAL_ENV is not set, or it is set and
            " equals to the value of s:state['virtualenv_directory'],
            " then search upwards from the directory of the current file
            let l:current_file_directory = expand('%:p:h')
            let l:target = virtualenv#origin(l:current_file_directory)

            if !empty(l:target)
                if has_key(s:state, 'virtualenv_directory') &&
                 \ (l:target ==# s:state['virtualenv_directory'])
                    call s:Warning('virtualenv '.l:target.' is already active')
                    return
                else
                    return virtualenv#deactivate() || virtualenv#force_activate(l:target)
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

    let l:internal = !(a:0 && (a:1 ==# 'external'))
    let l:pyversion = virtualenv#supported(a:target, l:internal ? '' : 'external')

    if !(l:pyversion)
        call s:Error(a:target.' is not supported')
        return 1
    endif

    let s:state['python_version'] = l:pyversion
    let s:state['virtualenv_internal'] = l:internal
    let s:state['virtualenv_directory'] = a:target
    let s:state['virtualenv_return_dir'] = getcwd()
    let s:state['virtualenv_name'] = fnamemodify(a:target, ':t')

    try
        if s:state['virtualenv_internal']
            call s:execute_python_command(
                \ 'VirtualEnvPlugin.activate',
                \ s:joinpath(s:state['virtualenv_directory'], 'bin/activate_this.py'),
                \ g:virtualenv#update_pythonpath)
        else
            let [l:syspath] =
                \ s:execute_system_python_command('import sys; print(list(sys.path))')
            call s:execute_python_command('VirtualEnvPlugin.extactivate', l:syspath)
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

    if g:virtualenv#cdvirtualenv_on_activate &&
     \ !s:issubdir(s:state['virtualenv_return_dir'], s:state['virtualenv_directory'])
        call virtualenv#cdvirtualenv()
    endif
endfunction

function! virtualenv#deactivate()
    if !has_key(s:state, 'virtualenv_name')
        call s:Warning('deactivation is not possible')
        return
    endif
    return virtualenv#force_deactivate()
endfunction

function! virtualenv#force_deactivate()
    if g:virtualenv#return_on_deactivate && has_key(s:state, 'virtualenv_return_dir')
        execute 'cd' fnameescape(s:state['virtualenv_return_dir'])
    endif

    delcommand VirtualEnvCD

    try
        call s:execute_python_command('VirtualEnvPlugin.deactivate()')
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
    let l:directory = !(a:0) ? g:virtualenv#directory : a:1
    for l:virtualenv in virtualenv#find(l:directory)
        echo l:virtualenv
    endfor
endfunction

function! virtualenv#statusline()
    return has_key(s:state, 'virtualenv_name') ?
         \ substitute(g:virtualenv#statusline_format, '\C%n', s:state['virtualenv_name'], 'g') :
         \ ''
endfunction

" helper functions
function! virtualenv#find(directory, ...)
    let l:virtualenvs = []
    let l:pattern = (a:0) ? a:1 : '*'
    let l:tail = matchstr(l:pattern, '[/]\+$')
    let l:pattern = s:joinpath(l:pattern, '/')
    for l:target in globpath(a:directory, l:pattern, 0, 1)
        if !s:isvirtualenv(l:target)
            continue
        endif
        call add(l:virtualenvs, fnamemodify(l:target, ':h').l:tail)
    endfor
    return l:virtualenvs
endfunction

function! virtualenv#supported(target, ...)
    if !exists('g:virtualenv#force_python_version')
        let l:internal = !(a:0 && (a:1 ==# 'external'))
        let l:python_major_version =
            \ l:internal ? virtualenv#supported_internal(a:target)
            \            : virtualenv#supported_external(a:target)
    else
        let l:python_major_version = g:virtualenv#force_python_version
        call s:Warning('Python version for '.a:target.' is set to '.
                       \g:virtualenv#force_python_version)
        if !s:python_available(l:python_major_version)
            call s:Error(a:target.' requires python'.l:python_major_version)
            return
        endif
    endif
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
    let l:python_major_version = l:python[0][-1:]
    if !s:python_available(l:python_major_version)
        call s:Error(a:target.' requires python'.l:python_major_version)
        return
    endif
    return l:python_major_version
endfunction

function! virtualenv#supported_external(target)
    let [l:extpython] =
        \ s:execute_system_python_command(
        \     'import sys; print(u".".join(str(x) for x in sys.version_info))')
    let l:python_major_version = l:extpython[0]
    if !s:python_available(l:python_major_version)
        call s:Error(a:target.' requires python'.l:python_major_version)
        return
    endif
    let [l:vimpython] =
        \ s:execute_pythonX_command(
        \     l:python_major_version,
        \     'import sys; print(u".".join(str(x) for x in sys.version_info))')
    if (l:vimpython !=# l:extpython)
        call s:Error('Python version mismatch')
        call s:Error(a:target.' version: '.l:extpython)
        call s:Error('Vim version: '.l:vimpython)
        return
    endif
    return l:python_major_version
endfunction

function! virtualenv#origin(path)
    if s:issubdir(a:path, g:virtualenv#directory)
        let l:target = g:virtualenv#directory
        let l:tail = substitute(a:path, '^'.g:virtualenv#directory.'/', '', '')
    else
        let l:target = '/'
        let l:tail = fnamemodify(a:path, ':p')
    endif
    for l:part in split(l:tail, '/')
        let l:target = s:joinpath(l:target, l:part)
        if s:isvirtualenv(l:target)
            return l:target
        endif
    endfor
    return ''
endfunction

function! virtualenv#state(...)
    function! s:Query(key)
        echo a:key.' = '.get(s:state, a:key, '__undefined__')
    endfunction

    if (a:0)
        call s:Query(a:1)
    else
        for l:key in keys(s:state)
            call s:Query(l:key)
        endfor
    endif
endfunction

" misc functions
function! s:isvirtualenv(target)
    return isdirectory(a:target) && filereadable(s:joinpath(a:target, 'bin/activate_this.py'))
endfunction

" debug functions
function! s:Error(message)
    echohl ErrorMsg | echo 'vim-virtualenv: '.a:message | echohl None
endfunction

function! s:Warning(message)
    if g:virtualenv#debug
        echohl WarningMsg | echo 'vim-virtualenv: '.a:message | echohl None
    endif
endfunction

" paths machinery
function! s:issubdir(subdirectory, directory)
    let l:directory = s:normpath(a:subdirectory)
    let l:pattern = '^'.s:normpath(a:directory).'/'
    return (l:directory =~# fnameescape(l:pattern))
endfunction

function! s:joinpath(first, last)
    if (a:first !~# '^$')
        let l:prefix = substitute(a:first, '[/]\+$', '', '')
        let l:suffix = substitute(a:last, '^[/]\+', '', '')
        return l:prefix.'/'.l:suffix
    else
        return a:last
    endif
endfunction

function! s:normpath(path)
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
        return l:path
    else
        return ''
    endif
endfunction

" python machinery
function! s:python_available(version)
    if !has_key(s:state, 'python'.a:version.'_available')
        try
            let l:command = (a:version != 3) ? 'pyfile' : 'py3file'
            execute l:command fnameescape(g:virtualenv#python_script)
            execute 'let s:state[''python'.a:version.'_available''] = 1'
        catch
            execute 'let s:state[''python'.a:version.'_available''] = 0'
        endtry
    endif
    execute 'return s:state[''python'.a:version.'_available'']'
endfunction

function! s:execute_system_python_command(command)
    return systemlist('python -c '.string(a:command))
endfunction

function! s:execute_python_command(command, ...)
    let l:interpreter = (s:state['python_version'] != 3) ? 'python' : 'python3'
    let l:command = a:command.((a:0) ? s:construct_arguments(a:0, a:000) : '')
    redir => l:output
        silent execute l:interpreter l:command
    redir END
    return split(l:output, '\n')
endfunction

function! s:execute_pythonX_command(version, command, ...)
    let l:interpreter = (a:version != 3) ? 'python' : 'python3'
    let l:command = a:command.((a:0) ? s:construct_arguments(a:0, a:000) : '')
    redir => l:output
        silent execute l:interpreter l:command
    redir END
    return split(l:output, '\n')
endfunction

function! s:construct_arguments(number, list)
    let l:arguments = '('
    if (a:number)
        let l:first_arguments = (a:number > 1) ? a:list[:(a:number - 2)] : []
        for l:argument in l:first_arguments
            let l:arguments .= s:process_argument(l:argument).', '
        endfor
        let l:last_argument = a:list[(a:number - 1)]
        if (type(l:last_argument) != type({}))
            let l:arguments .= s:process_argument(l:last_argument)
        else
            for [l:key, l:value] in items(l:last_argument)
                let l:arguments .= l:key.'='.s:process_argument(l:value).', '
            endfor
        endif
    endif
    let l:arguments .= ')'
    return l:arguments
endfunction

function! s:process_argument(argument)
    if (type(a:argument) == type(0)) || (type(a:argument) == type(0.0))
        return a:argument
    elseif (type(a:argument) == type(''))
        return '"""'.a:argument.'"""'
    else
        return string(a:argument)
    endif
endfunction

call virtualenv#init()
