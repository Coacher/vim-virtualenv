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
            let fn = expand('%:p:h')
            let pat = '^'.g:virtualenv_directory.'/'
            if fn =~ pat
                let name = split(substitute(fn, pat, '', ''), '/')[0]
            else
                call s:Warning('unable to determine virtualenv
                            \ from the current file path')
                return 1
            endif
        else
            " if $VIRTUAL_ENV is set, then we are inside an active virtualenv
            call s:Warning('active virtualenv detected,
                        \ it cannot be deactivated via this plugin')
            call s:set_python_major_version_from($VIRTUAL_ENV)
            let g:virtualenv_name = fnamemodify($VIRTUAL_ENV, ':t')
            return
        endif
    endif

    call virtualenv#deactivate()

    call virtualenv#force_activate(g:virtualenv_directory.'/'.name)
endfunction

function! virtualenv#force_activate(target)
    let s:virtualenv_return_dir = getcwd()

    let script = a:target.'/bin/activate_this.py'
    if !filereadable(script)
        call s:Error('"'.script.'" is not found or is not readable')
        return 1
    endif

    call s:set_python_major_version_from(a:target)

    call s:execute_python_command('virtualenv_activate()')

    if g:virtualenv_cdvirtualenv_on_activate
        execute 'cd' a:target
    endif

    let $VIRTUAL_ENV = a:target
    let g:virtualenv_name = fnamemodify(a:target, ':t')
endfunction

function! virtualenv#deactivate()
    if empty($VIRTUAL_ENV) || !exists('s:python_major_version')
        return
    endif

    call s:execute_python_command('virtualenv_deactivate()')

    unlet! g:virtualenv_name
    let $VIRTUAL_ENV = ''
    unlet! s:python_major_version

    if g:virtualenv_return_on_deactivate && exists('s:virtualenv_return_dir')
        execute 'cd' s:virtualenv_return_dir
        unlet s:virtualenv_return_dir
    endif
endfunction

function! virtualenv#list()
    for name in virtualenv#names('')
        echo name
    endfor
endfunction

function! virtualenv#statusline()
    if exists('g:virtualenv_name')
        return substitute(g:virtualenv_stl_format, '\C%n', g:virtualenv_name, 'g')
    else
        return ''
    endif
endfunction

function! virtualenv#names(prefix)
    let venvs = []
    for dir in glob(g:virtualenv_directory.'/'.a:prefix.'*', 0, 1)
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


function! s:Error(message)
    echohl ErrorMsg | echo 'vim-virtualenv: '.a:message | echohl None
endfunction

function! s:Warning(message)
    echohl WarningMsg | echo 'vim-virtualenv: '.a:message | echohl None
endfunction


function! s:is_python_available(version)
    if !exists('s:is_python'.a:version.'_available')
        try
            let command = (a:version == 2) ? 'pyfile' : 'py3file'
            execute command fnameescape(g:virtualenv_python_script)
            execute 'let s:is_python'.a:version.'_available = 1'
        catch
            execute 'let s:is_python'.a:version.'_available = 0'
        endtry
    endif
    execute 'return s:is_python'.a:version.'_available'
endfunction

function! s:set_python_major_version_from(target)
    let python_path = globpath(a:target.'/lib', 'python?.?', 0, 1)[0]
    let python_major_version = python_path[-3:][0]
    if !(s:is_python_available(python_major_version))
        call s:Error('"'.a:target.'" requires python'.python_major_version.' support')
        return 1
    endif
    let s:python_major_version = l:python_major_version
endfunction

function! s:execute_python_command(command)
    let interpreter = (s:python_major_version == 2) ? 'python' : 'python3'
    execute interpreter a:command
endfunction
