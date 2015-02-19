vim-virtualenv
==============

By default, `:python` and `:!python` (as well as `:python3` and `:!python3`)
commands have access only to the system-wide Python environment.

vim-virtualenv plugin changes Python `sys.path` and environment `$PATH`
and `$PYTHONPATH` variables so that they refer to the chosen virtualenv.

However, `:python` and `:python3` commands will be still tied to, respectively,
Python 2 and Python 3 versions that Vim was compiled against.

Usage examples
==============

List virtualenvs located inside `g:virtualenv_directory`:

    :VirtualEnvList

List virtualenvs located inside the '/foo/bar' directory:

    :VirtualEnvList /foo/bar

Activate the 'foo' virtualenv located inside `g:virtualenv_directory`:

    :VirtualEnvActivate foo

Activate virtualenv located at '/foo/bar/baz':

    :VirtualEnvActivate /foo/bar/baz

Both `VirtualEnvActivate` and `VirtualEnvList` commands support
`<Tab>` completion.

Change the current directory to the current virtualenv directory:

    :VirtualEnvCdvirtualenv

Deactivate the current virtualenv:

    :VirtualEnvDeactivate

Current virtualenv name can be shown in the statusline
via `virtualenv#statusline()` function.

For a more detailed help see:

    :help virtualenv

Key features
============

* Activate, deactivate and list virtualenvs from a Vim session.
    By default, vim-virtualenv works with virtualenvs located inside
    `g:virtualenv_directory` to avoid unnecessary typing.

* Activate virtualenvs by path using `VirtualEnvActivate` command.
    Paths can be absolute or relative, in the latter case they are first
    expanded against `g:virtualenv_directory` and then against the current
    directory.

* Both `VirtualEnvActivate` and `VirtualEnvList` commands support
    `<Tab>` completion.

* Change the current directory to the current virtualenv directory
    using `VirtualEnvCdvirtualenv` command. By default, vim-virtualenv
    automatically does this on virtualenv activation and returns back on
    deactivation.

* Python3 support.
    `sys.path` for `:python` and `:python3` commands is updated separately
    depending on the Python major version inside the target virtualenv.
