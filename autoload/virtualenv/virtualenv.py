def virtualenv_is_armed():
    if all(('__virtualenv_saved_sys_path' in globals(),
            '__virtualenv_saved_os_path' in globals())):
        print('armed')


def virtualenv_activate(activate_this):
    import os, sys

    os.environ['VIRTUAL_ENV'] = os.path.dirname(os.path.dirname(activate_this))

    global __virtualenv_saved_sys_path
    global __virtualenv_saved_os_path

    __virtualenv_saved_sys_path = list(sys.path)
    __virtualenv_saved_os_path = os.environ.get('PATH', None)

    with open(activate_this) as f:
        exec(compile(f.read(), activate_this, 'exec'),
             dict(__file__ = activate_this))


def virtualenv_deactivate():
    try:
        import os, sys

        global __virtualenv_saved_sys_path
        global __virtualenv_saved_os_path

        sys.path[:] = __virtualenv_saved_sys_path

        if __virtualenv_saved_os_path is not None:
            os.environ['PATH'] = __virtualenv_saved_os_path
        else:
            os.environ.pop('PATH', None)

        os.environ.pop('VIRTUAL_ENV', None)

        del __virtualenv_saved_os_path
        del __virtualenv_saved_sys_path
    except NameError:
        pass
