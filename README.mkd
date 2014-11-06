virtualenv.vim
==============

By default, `:python` and `:!python` (as well as `:python3` and `:!python3`)
commands have access only to system-wide Python environment.

virtualenv.vim plugin changes Python's `sys.path` and `$PATH` environment
variable so that they refer to the chosen virtualenv.

However, `:python` and `:python3` commands will be still tied to, respectively,
Python 2 and Python 3 versions that Vim was compiled against.

Usage examples
==============

List all available virtualenvs

    :VirtualEnvList

Deactivate the current virtualenv

    :VirtualEnvDeactivate

Activate the 'spam' virtualenv

    :VirtualEnvActivate spam

You can always use `<Tab>` completion

    :VirtualEnvActivate <Tab>

You can also show the current virtualenv name in the statusline via included function.

For more detailed help see

    :help virtualenv

Changes in this fork
====================

* Add Python3 support. Environments for `:python` and `:python3` commands
    are updated separately depending on virtualenv's Python major version.

* Remove $PROJECT\_HOME processing.
    Reason: is virtualenv already active when $PROJECT\_HOME is set?
    If it is set and virtualenv is active, then there is nothing to do.
    If it is set and virtualenv is not active, then simply adjust g:virtualenv_directory.

* Do not re-activate/deactivate virtualenv if $VIRTUAL\_ENV is present.
    Reason: virtualenv is already active when $VIRTUAL\_ENV is set,
    therefore we cannot neither deactivate, nor re-activate it properly.

* Add option to automatically `cd` into virtualenv on activation and
    return back on deactivation.
