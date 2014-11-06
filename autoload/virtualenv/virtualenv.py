import sys
import os


if sys.version_info.major == 3:
    def execfile(filename, globals = globals(), locals = locals()):
        with open(filename) as f:
            exec(compile(f.read(), filename, 'exec'), globals, locals)


def virtualenv_is_armed():
    if (
            ('__virtualenv_saved_sys_path' in globals())
            and
            ('__virtualenv_saved_os_path' in globals())
    ):
        print('armed')


def virtualenv_activate(activate_this):
    global __virtualenv_saved_sys_path
    global __virtualenv_saved_os_path
    __virtualenv_saved_sys_path = list(sys.path)
    __virtualenv_saved_os_path = os.environ.get('PATH', '')

    execfile(activate_this, dict(__file__=activate_this))


def virtualenv_deactivate():
    try:
        global __virtualenv_saved_sys_path
        global __virtualenv_saved_os_path
        sys.path[:] = __virtualenv_saved_sys_path
        os.environ['PATH'] = __virtualenv_saved_os_path
        del __virtualenv_saved_sys_path
        del __virtualenv_saved_os_path
    except NameError:
        pass
