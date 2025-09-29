"""Python virtual environment manager for Vim."""

# Keep the global module namespace clean.
# pylint: disable=import-outside-toplevel


class VirtualEnvManager:
    """Python virtual environment manager for Vim."""

    __slots__ = (
        "internal",
        "prev_sys_path",
        "prev_sys_prefix",
        "prev_sys_exec_prefix",
        "prev_os_path",
        "prev_py_path",
    )

    def __init__(self) -> None:
        self.internal = None
        self.prev_sys_path = None
        self.prev_sys_prefix = None
        self.prev_sys_exec_prefix = None
        self.prev_os_path = None
        self.prev_py_path = None

    def activate(self, path: str, *, update_pythonpath: bool = True) -> None:
        """Activate the virtual environment located at the given path.

        Activation works as follows:
        - set VIRTUAL_ENV environment variable
          to make external tools aware of the virtual environment;
        - set PATH environment variable
          to make shell aware of the virtual environment;
        - set Vim internal sys.path, sys.prefix, sys.exec_prefix
          to make internal Python interface aware of the virtual environment;
        - optionally set PYTHONPATH environment variable
          to make external Python code aware of the virtual environment.
        """
        import os
        import site
        import sys
        from pathlib import Path

        self.internal = True
        self.prev_sys_path = sys.path.copy()
        self.prev_sys_prefix = sys.prefix
        self.prev_sys_exec_prefix = sys.exec_prefix
        self.prev_os_path = os.environ.get("PATH", "")
        self.prev_py_path = os.environ.get("PYTHONPATH", "")

        os.environ["VIRTUAL_ENV"] = path

        os.environ["PATH"] = os.pathsep.join(
            [str(Path(path) / "bin"), *self.prev_os_path.split(os.pathsep)]
        )

        sitedirs = list(Path(path).glob("lib*/python*/site-packages"))
        sitedirs.sort(reverse=True)  # Enforce lib64/, lib32/, lib/ order.
        for sitedir in sitedirs:
            site.addsitedir(str(sitedir))

        prev_sys_path_len = len(self.prev_sys_path)
        sys.path[:] = (
            sys.path[prev_sys_path_len:] + sys.path[:prev_sys_path_len]
        )

        sys.prefix = path
        sys.exec_prefix = path

        sys_path_diff = set(sys.path) - set(self.prev_sys_path)
        if sys_path_diff and update_pythonpath:
            os.environ["PYTHONPATH"] = os.pathsep.join(
                list(sys_path_diff) + self.prev_py_path.split(os.pathsep)
            )

    def extactivate(
        self, sys_path: str, sys_prefix: str, sys_exec_prefix: str,
    ) -> None:
        """Sync Vim Python interface with the active virtual environment."""
        import sys
        from ast import literal_eval

        # pylint: disable-next=import-error
        from vim import VIM_SPECIAL_PATH  # See `:help python-special-path`

        self.internal = False
        self.prev_sys_path = sys.path.copy()
        self.prev_sys_prefix = sys.prefix
        self.prev_sys_exec_prefix = sys.exec_prefix

        new_sys_path = literal_eval(sys_path)
        if VIM_SPECIAL_PATH not in new_sys_path:
            new_sys_path.append(VIM_SPECIAL_PATH)

        sys.path[:] = new_sys_path

        sys.prefix = sys_prefix
        sys.exec_prefix = sys_exec_prefix

    def deactivate(self) -> None:
        """Deactivate the currently active virtual environment."""
        import sys

        sys.path[:] = self.prev_sys_path
        sys.prefix = self.prev_sys_prefix
        sys.exec_prefix = self.prev_sys_exec_prefix

        if self.internal:
            import os

            if self.prev_os_path:
                os.environ["PATH"] = self.prev_os_path
            else:
                os.environ.pop("PATH", None)

            if self.prev_py_path:
                os.environ["PYTHONPATH"] = self.prev_py_path
            else:
                os.environ.pop("PYTHONPATH", None)

            os.environ.pop("VIRTUAL_ENV", None)

        self.internal = None


VirtualEnvManager = VirtualEnvManager()
