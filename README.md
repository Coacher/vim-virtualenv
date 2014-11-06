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

For more detailed help, see

    :help virtualenv

Changes in this fork
====================

* Add Python3 support. Environments for `:python` and `:python3` commands
    are updated separately depending on virtualenv's Python major version.

* Remove $PROJECT\_HOME handling from `virtualenv#activate()`.
    Reason: unclear virtualenv state when $PROJECT\_HOME is set.
    If it is set and virtualenv is activated, then there is nothing to do.
    If it is set and virtualenv is not activated, then simply adjust
    `g:virtualenv_directory`.

* Do not re-activate virtualenv when $VIRTUAL\_ENV is set.
    Reason: virtualenv is already activated when $VIRTUAL\_ENV is set,
    therefore we cannot re-activate it properly, i.e. save _original_
    `sys.path` and `$PATH`. If you know what you are doing,
    use `virtualenv#force_activate($VIRTUAL_ENV)`.

* Add options to automatically `cd` into virtualenv directory on activation
    and return back on deactivation.
