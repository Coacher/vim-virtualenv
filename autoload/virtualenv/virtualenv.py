def virtualenv_status(internal=True):
    if ('__virtualenv_saved_sys_path' in globals() and
        ('__virtualenv_saved_os_path' in globals() and
         '__virtualenv_saved_py_path' in globals() or
         not internal)):
        print('armed')
    else:
        print('standby')


def virtualenv_update_syspath(syspath):
    import sys

    global __virtualenv_saved_sys_path

    __virtualenv_saved_sys_path = list(sys.path)

    new_sys_path = eval(syspath)

    if '_vim_path_' not in new_sys_path:
        new_sys_path.append('_vim_path_')

    sys.path[:] = new_sys_path


def virtualenv_activate(activate_this, update_pythonpath=True):
    import os
    import sys

    os.environ['VIRTUAL_ENV'] = os.path.dirname(os.path.dirname(activate_this))

    global __virtualenv_saved_sys_path
    global __virtualenv_saved_os_path
    global __virtualenv_saved_py_path

    __virtualenv_saved_sys_path = list(sys.path)
    __virtualenv_saved_os_path = os.environ.get('PATH', None)
    __virtualenv_saved_py_path = os.environ.get('PYTHONPATH', None)

    with open(activate_this) as fhandle:
        exec(compile(fhandle.read(), activate_this, 'exec'),
             dict(__file__=activate_this))

    sys_path_diff = [
        x for x in list(sys.path)
        if x not in __virtualenv_saved_sys_path
    ]

    if sys_path_diff and update_pythonpath:
        os.environ['PYTHONPATH'] = os.pathsep.join(sys_path_diff)

        if __virtualenv_saved_py_path:
            os.environ['PYTHONPATH'] += os.pathsep + __virtualenv_saved_py_path


def virtualenv_deactivate(internal=True):
    try:
        import sys

        global __virtualenv_saved_sys_path

        sys.path[:] = __virtualenv_saved_sys_path

        del __virtualenv_saved_sys_path

        if internal:
            import os

            global __virtualenv_saved_os_path
            global __virtualenv_saved_py_path

            if __virtualenv_saved_os_path is not None:
                os.environ['PATH'] = __virtualenv_saved_os_path
            else:
                os.environ.pop('PATH', None)

            if __virtualenv_saved_py_path is not None:
                os.environ['PYTHONPATH'] = __virtualenv_saved_py_path
            else:
                os.environ.pop('PYTHONPATH', None)

            os.environ.pop('VIRTUAL_ENV', None)

            del __virtualenv_saved_py_path
            del __virtualenv_saved_os_path
    except NameError:
        pass
