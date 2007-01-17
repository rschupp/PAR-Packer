gpp - a gui for pp
------------------
Version 2.2

Gpp provides (yet another) gui frontend to the PAR compiler - pp. The help
display is taken from the pod in pp (or pp.bat on win32) at runtime, and
options to pp are "use"ed from Packer.pm, so new options in later PAR versions
should appear automatically in gpp. Gpp looks for pp (or pp.bat) first in the
current directory, then in the environment variable PATH.

Options are displayed in a scrolling window, with a checkbox next to each to
enable it. Options that take an integer value have an up/down counter next to
them. Options that take a string or non-integer number have an entrybox with a
pulldown history window. Each option checkbox has a popup hint with the pp
short description.

Only the following options are expected to be supported by pp and are treated
specially by gpp:
        -h
The "Help" button displays the pp pod and -h doesn't appear in the list.
        -o <output file>
The output file has an entry box of it's own and -o doesn't appear in the list,
        -L <logfile>
The "View Log" button displays the contents of the file shown next to "L" in
the option list. It does not need to be checked to view. While viewing the log
file, "Clear Log File" will set that file to zero length. When pp runs, it
appends to the log file.

The [...] buttons will browse for source or output files. On win32, files
returned from the file browser that contain spaces are auto-quoted in the
entrybox.

For options with a pulldown history, the <Enter> key enters the current value
into the history list. Browsed files are auto-entered. Duplicates are not be
saved. Auto-completion from the history is enabled and case sensitive. The
histories are saved on "Exit" in .gpp.history in the $ENV{HOME} dir or
$ENV{HOMEPATH} dir or the path of gpp, and restored on startup.

Options which can have multiple values, have a * (zero or more required) or a +
(one or more required) next to the entrybox. When pp is run, the displayed
value is broken apart and repeated with the option flag as many times as
needed. Strings which contain spaces must be quoted. Quoted strings or
strings-without-spaces can be separated by spaces, commas or semicolons, i.e.
if the M option value is:
        "one two" three, four; five six
the pp command would contain:
        -M "one two" -M three -M four -M five -M six

The current values of the source file, output file, all option checkboxes and
values can be saved to a file with "Save Opts". The default file extension is
".gpp". Saved options are (re)loaded with "Open Opts". All values are saved,
but a .gpp file could be hand editted to remove some values, so the resulting
file could be loaded as a partial "default", without changing those values.
The format is ordinary Perl. Gpp accepts an option file as an optional
parameter on the command line.

The pp command that is assembled by "Pack" is echoed in the console window,
before executing pp.

I am a Win32 ActivePerl user, so here is how I set it up.
------------------
Place gpp in the directory C:\ActivePerl\bin and then do:
        pl2bat gpp
        ftype gppfile="C:\ActivePerl\bin\gpp.bat" "%1"
        assoc .gpp=gppfile
or use some user friendly tool (like freeware WAssociate) instead of
ftype/assoc.

Edit the gpp.bat file to add this line near the top, right after "@echo off":
        title gpp - Pack output
so the console windows will have a meaningful title.

Run gpp, select all the default options you normally use and "Save Opts"
to C:\ActivePerl\bin\default.gpp. Create a desktop icon for:
        "C:\ActivePerl\bin\gpp.bat" "C:\ActivePerl\bin\default.gpp"
and change the icon to the one in C:\ActivePerl\bin\parl.exe (a camel).

Now the desktop camel is the default startup, and a .gpp file can be d-clicked
like a project file.
------------------

Gpp fonts, colors, browser file types and window sizes are located near the top
of the gpp script for your tweaking convenience :)

Gpp is free and carries no license or guarantee. It is placed in the public
domain. Do whatever you want to do with it.

Alan Stewart
astewart1@cox.net