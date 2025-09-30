vim-virtualenv
==============

This Vim plugin provides a simple way to activate and deactivate Python virtual
environments created by the [virtualenv](https://github.com/pypa/virtualenv) or
[venv](https://docs.python.org/3/library/venv.html) tools from a Vim session as
well as synchronizes the Vim internal Python `sys.path` variable with an
already active virtual environment.

By default, `:python3` command has access only to the system-wide Python
environment. vim-virtualenv changes the Vim internal Python `sys.path` and
environment `$PATH` and `$PYTHONPATH` variables so that they refer to the
chosen virtual environment, i.e. activates it.

However, `:python3` command will be still tied to the Python 3 version that Vim
was compiled against.

**Note.**
Since the v2.0.0 release there are no new features planned and there are no
known issues. Nevertheless this plugin is still maintained so feel free to file
a bug report or a feature request.

Key features
============

* Activate, deactivate and list virtualenvs from a Vim session.
  By default, vim-virtualenv works with virtualenvs located inside
  `g:virtualenv#directory` to avoid unnecessary typing.

* When a Vim session is started inside an active virtualenv, vim-virtualenv
  synchronizes the Vim internal Python `sys.path` variable with the currently
  active virtualenv.

* Activate virtualenvs by path using `VirtualEnvActivate` command.
  Paths can be absolute or relative, in the latter case they are first expanded
  against `g:virtualenv#directory` and then against the current directory.

* Use `<Tab>` completion with `VirtualEnvActivate` and `VirtualEnvList`
  commands to avoid typing even more.

* Change the current directory to the directory of the currently active
  virtualenv using `VirtualEnvCD` command. By default, vim-virtualenv
  automatically does this on virtualenv activation and returns back on
  deactivation.

* This plugin is not a replacement for
  [virtualenv](https://github.com/pypa/virtualenv) or
  [virtualenvwrapper](https://bitbucket.org/dhellmann/virtualenvwrapper) tools
  nor it aims to be one.

Usage examples
==============

List virtualenvs located inside `g:virtualenv#directory`:

    :VirtualEnvList

List virtualenvs located inside the '/foo/bar' directory:

    :VirtualEnvList /foo/bar

Activate the 'foo' virtualenv located inside `g:virtualenv#directory`:

    :VirtualEnvActivate foo

Activate the virtualenv located at '/foo/bar/baz':

    :VirtualEnvActivate /foo/bar/baz

Both `VirtualEnvActivate` and `VirtualEnvList` commands support `<Tab>`
completion.

Change the current directory to the currently active virtualenv directory:

    :VirtualEnvCD

Deactivate the currently active virtualenv:

    :VirtualEnvDeactivate

Name of the currently active virtualenv can be shown in the statusline via
`virtualenv#statusline()` function.

For a more detailed help see:

    :help virtualenv
