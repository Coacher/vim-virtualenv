import sys
import os


if sys.version_info.major == 3:
    def execfile(filename, globals = globals(), locals = locals()):
        with open(filename) as f:
            exec(compile(f.read(), filename, 'exec'), globals, locals)


def virtualenv_activate(activate_this):
    global __virtualenv_saved_sys_path
    global __virtualenv_saved_os_path
    global __virtualenv_saved_os_pythonpath
    __virtualenv_saved_sys_path = list(sys.path)
    __virtualenv_saved_os_path = os.environ.get('PATH', '')
    __virtualenv_saved_os_pythonpath = os.environ.get('PYTHONPATH', '')

    execfile(activate_this, dict(__file__=activate_this))

    # sys.path is replaced in activate_this.py, update PYTHONPATH accordingly
    os.environ['PYTHONPATH'] = os.pathsep.join(list(sys.path))

def virtualenv_deactivate():
    try:
        global __virtualenv_saved_sys_path
        global __virtualenv_saved_os_path
        global __virtualenv_saved_os_pythonpath
        sys.path[:] = __virtualenv_saved_sys_path
        os.environ['PATH'] = __virtualenv_saved_os_path
        os.environ['PYTHONPATH'] = __virtualenv_saved_os_pythonpath
        del __virtualenv_saved_sys_path
        del __virtualenv_saved_os_path
        del __virtualenv_saved_os_pythonpath
    except NameError:
        pass
