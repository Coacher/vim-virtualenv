vim-virtualenv
==============

This Vim plugin provides a simple way to activate and deactivate Python virtual
environments created by the [virtualenv](https://github.com/pypa/virtualenv) or
[venv](https://docs.python.org/3/library/venv.html) or similar tools from a Vim
session as well as synchronizes the Vim internal Python `sys.path` variable
with an already active virtual environment.

By default, `:python3` command has access only to the system-wide Python
environment. vim-virtualenv changes the Vim internal Python `sys.path` and
environment `$PATH` and `$PYTHONPATH` variables so that they refer to the
chosen virtual environment, i.e. activates it.

However, `:python3` command will be still tied to the Python 3 version that Vim
was compiled against.

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
  [virtualenv](https://github.com/pypa/virtualenv) tool nor it aims to be one.

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

For a more detailed help see:

    :help virtualenv

Feature support
===============

This table shows the availability of features relevant to vim-virtualenv in
popular tools:

| **Tool**              | **Central location of environments** | **Project support** | **Manage environments separately from projects** | **Environments nested in projects** |
|-----------------------|--------------------------------------|---------------------|--------------------------------------------------|-------------------------------------|
| **venv**              | NO                                   | NO                  | N/A                                              | N/A                                 |
| **virtualenv**        | NO                                   | NO                  | N/A                                              | N/A                                 |
| **virtualenvwrapper** | YES                                  | YES                 | YES                                              | NO                                  |
| **pipenv**            | OPTIONAL                             | YES                 | NO                                               | OPTIONAL                            |
| **poetry**            | OPTIONAL                             | YES                 | NO                                               | OPTIONAL                            |
| **pyenv-virtualenv**  | YES                                  | YES                 | YES                                              | NO                                  |
| **tox**               | NO                                   | YES                 | NO                                               | YES                                 |
| **uv**                | NO                                   | YES                 | NO                                               | YES                                 |

This table shows the supported features of popular tools in vim-virtualenv:

| **Tool**              | **Environment detection** | **Tool detection** | **Central location of environments** | **Project detection** |
|-----------------------|---------------------------|--------------------|--------------------------------------|-----------------------|
| **venv**              | YES                       | YES                | N/A                                  | N/A                   |
| **virtualenv**        | YES                       | YES                | N/A                                  | N/A                   |
| **virtualenvwrapper** | YES                       | NO                 | YES                                  | YES                   |
| **pipenv**            | YES                       | NO                 | YES                                  | YES                   |
| **poetry**            | YES                       | NO                 | YES                                  | NESTED ONLY           |
| **pyenv-virtualenv**  | YES                       | IN PROJECT ONLY    | YES                                  | IN PROJECT ONLY       |
| **tox**               | YES                       | YES                | N/A                                  | YES                   |
| **uv**                | YES                       | IN PROJECT ONLY    | N/A                                  | YES                   |

Support notes
-------------

- All of the listed tools utilize or mimic venv or virtualenv environments and
  mostly cannot be properly distinguished from venv or virtualenv.

- virtualenvwrapper and pipenv are the only listed tools that provide a clean
  way to establish a connection from a virtualenv to a project. poetry requires
  hashing names and whatnot. Several tools rely solely on nested virtualenvs.

- pyenv-virtualenv itself does not have a project concept, but `pyenv local`
  can be used to bind a directory to a specific virtual environment via a file
  marker. vim-virtualenv treats such directory as a pyenv project.
