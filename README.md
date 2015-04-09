vim-virtualenv
==============

By default, `:python` and `:python3` commands have access only to the
system-wide Python environment.

vim-virtualenv plugin allows to change Vim internal python `sys.path` and
environment `$PATH` and `$PYTHONPATH` variables so that they refer to the
chosen virtualenv.

However, `:python` and `:python3` commands will be still tied to, respectively,
Python 2 and Python 3 versions that Vim was compiled against.

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

Change the current directory to the current virtualenv directory:

    :VirtualEnvCD

Deactivate the current virtualenv:

    :VirtualEnvDeactivate

Current virtualenv name can be shown in the statusline via
`virtualenv#statusline()` function.

For a more detailed help see:

    :help virtualenv

Key features
============

* Activate, deactivate and list virtualenvs from a Vim session.
  By default, vim-virtualenv works with virtualenvs located inside
  `g:virtualenv#directory` to avoid unnecessary typing.

* When a Vim session is started inside an active virtualenv, vim-virtualenv
  synchronizes the Vim internal python `sys.path` variable with the current
  virtualenv.

* Activate virtualenvs by path using `VirtualEnvActivate` command.
  Paths can be absolute or relative, in the latter case they are first expanded
  against `g:virtualenv#directory` and then against the current directory.

* Use `<Tab>` completion with `VirtualEnvActivate` and `VirtualEnvList`
  commands to avoid typing even more.

* Change the current directory to the current virtualenv directory using
  `VirtualEnvCD` command. By default, vim-virtualenv automatically does this on
  virtualenv activation and returns back on deactivation.
