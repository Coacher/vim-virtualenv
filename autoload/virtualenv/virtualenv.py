def virtualenv_is_armed():
    if all(('__virtualenv_saved_sys_path' in globals(),
            '__virtualenv_saved_os_path' in globals(),
            '__virtualenv_saved_python_path' in globals())):
        print('armed')


def virtualenv_activate(activate_this):
    import os
    import sys

    os.environ['VIRTUAL_ENV'] = os.path.dirname(os.path.dirname(activate_this))

    global __virtualenv_saved_sys_path
    global __virtualenv_saved_os_path
    global __virtualenv_saved_python_path

    __virtualenv_saved_sys_path = list(sys.path)
    __virtualenv_saved_os_path = os.environ.get('PATH', None)
    __virtualenv_saved_python_path = os.environ.get('PYTHONPATH', None)

    with open(activate_this) as f:
        exec(compile(f.read(), activate_this, 'exec'),
             dict(__file__ = activate_this))

    sys_path_diff = [sp for sp in list(sys.path) if sp not in __virtualenv_saved_sys_path]
    if sys_path_diff:
        os.environ['PYTHONPATH'] = os.pathsep.join(sys_path_diff)

        if __virtualenv_saved_python_path:
            os.environ['PYTHONPATH'] += os.pathsep + __virtualenv_saved_python_path


def virtualenv_deactivate():
    try:
        import os
        import sys

        global __virtualenv_saved_sys_path
        global __virtualenv_saved_os_path
        global __virtualenv_saved_python_path

        sys.path[:] = __virtualenv_saved_sys_path

        if __virtualenv_saved_os_path is not None:
            os.environ['PATH'] = __virtualenv_saved_os_path
        else:
            os.environ.pop('PATH', None)

        if __virtualenv_saved_python_path is not None:
            os.environ['PYTHONPATH'] = __virtualenv_saved_python_path
        else:
            os.environ.pop('PYTHONPATH', None)

        os.environ.pop('VIRTUAL_ENV', None)

        del __virtualenv_saved_python_path
        del __virtualenv_saved_os_path
        del __virtualenv_saved_sys_path
    except NameError:
        pass
