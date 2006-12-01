Tk::Stdio is based on Tk::Stderr.

This module provides an "on demand" console window, appearing only when
standard IO is needed. As such, it is not just a PAR module, but is useful for
any Perl executable generated without a normal DOS console. That could be a
PAR package made with "pp -g" or a Perl script that intentionally closes the
associated console to avoid having a DOS window hanging around.

See the pod in the module for usage.

Alan Stewart
