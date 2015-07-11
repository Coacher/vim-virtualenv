class VirtualEnvPlugin(object):
    __slots__ = ('internal', 'prev_sys_path', 'prev_os_path', 'prev_py_path',)

    def __init__(self):
        for attr in self.__slots__:
            setattr(self, attr, None)

    def activate(self, activate_this, update_pythonpath=True):
        import os
        import sys

        self.internal = True

        os.environ['VIRTUAL_ENV'] = os.path.dirname(os.path.dirname(activate_this))

        self.prev_sys_path = list(sys.path)
        self.prev_os_path = os.environ.get('PATH', None)
        self.prev_py_path = os.environ.get('PYTHONPATH', None)

        with open(activate_this) as fhandle:
            exec(compile(fhandle.read(), activate_this, 'exec'),
                 dict(__file__=activate_this))

        sys_path_diff = set(sys.path) - set(self.prev_sys_path)

        if sys_path_diff and update_pythonpath:
            os.environ['PYTHONPATH'] = os.pathsep.join(sys_path_diff)

            if self.prev_py_path:
                os.environ['PYTHONPATH'] += os.pathsep + self.prev_py_path

    def extactivate(self, syspath):
        import sys

        self.internal = False

        self.prev_sys_path = list(sys.path)

        new_sys_path = eval(syspath)

        if '_vim_path_' not in new_sys_path:
            new_sys_path.append('_vim_path_')

        sys.path[:] = new_sys_path

    def deactivate(self):
        import sys

        sys.path[:] = self.prev_sys_path

        if self.internal:
            import os

            if self.prev_os_path is not None:
                os.environ['PATH'] = self.prev_os_path
            else:
                os.environ.pop('PATH', None)

            if self.prev_py_path is not None:
                os.environ['PYTHONPATH'] = self.prev_py_path
            else:
                os.environ.pop('PYTHONPATH', None)

            os.environ.pop('VIRTUAL_ENV', None)

        self.internal = None


VirtualEnvPlugin = VirtualEnvPlugin()
