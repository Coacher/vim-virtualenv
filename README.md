vim-virtualenv
==============

By default, `:python` and `:!python` (as well as `:python3` and `:!python3`)
commands have access only to the system-wide Python environment.

vim-virtualenv plugin changes Python `sys.path` and environment `$PATH`
variables so that they refer to the chosen virtualenv.

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

You can also use `<Tab>` completion with `VirtualEnvActivate`
and `VirtualEnvList` commands.

Change the current directory to the current virtualenv directory:

    :VirtualEnvCdvirtualenv

Deactivate the current virtualenv:

    :VirtualEnvDeactivate

You can show the current virtualenv name in the statusline
via `virtualenv#statusline()` function.

For more detailed help see:

    :help virtualenv

Changes from jmcantrell/vim-virtualenv
======================================

* Add Python3 support. Environments for `:python` and `:python3` commands
    are updated separately depending on the Python major version
    inside the target virtualenv.

* Remove $PROJECT\_HOME handling from `virtualenv#activate()` function.
    Reason: unclear virtualenv state when $PROJECT\_HOME variable is set.
    If it is set and virtualenv is activated, then there is nothing to do.
    If it is set and virtualenv is not activated, then simply adjust
    the `g:virtualenv_directory` variable.

* Do not re-activate virtualenv when $VIRTUAL\_ENV variable is set.
    Reason: in this case virtualenv has already been activated,
    therefore we cannot re-activate it properly, i.e. save the _original_
    values of `sys.path` and `$PATH` variables. If you know what you are doing,
    you can use `virtualenv#force_activate($VIRTUAL_ENV)`.

* Add support for activation by path to `VirtualEnvActivate` command.
    Path can be absolute or relative, in the latter case it is first expanded
    against `g:virtualenv_directory` and then against the current directory.

* Add optional argument to specify directory to `VirtualEnvList` command.

* Add proper `<Tab>` completion support to `VirtualEnvActivate`
    and `VirtualEnvList` commands.

* Add `VirtualEnvCdvirtualenv` command to change the current directory
    to the current virtualenv directory.

* Add options to automatically `cd` into the virtualenv directory on activation
    and return back on deactivation.

* Rename `virtualenv#names` function to `virtualenv#find`.
