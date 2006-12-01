pare - A utility to pare down the size of PAR files
---------------------------------------------------
Version 1.0

Usage: pare [-l <logfile>] -u <usedfile> <reducedfiles> . . .
---------------------------------------------------

Pare reduces the size of PAR file by scanning another PAR file and removing
any matching zipped files found in the other file. Matching is on full paths.
The matching file is removed from the MANIFEST and a:

    use PAR qw( some.par );

statement is added to the main.pl file, where "some.par" is the
other PAR file.

As an example, if you have a number of Tk applications, all PAR packaged, each
PAR application has a copy of all the required Tk files. If all of these
applications are going to live in the same directory, there is a lot of
redundancy and you can save disk space by do this:

    pp -e "use Tk;" -p -o Tk.par
    pare -l log.txt -u Tk.par appl1.exe appl2.exe appl3.exe

After that, Tk.par contains all of the basic Tk stuff, while appl1.exe,
appl2.exe, and appl3.exe don't. All three applications will have the line:

    use PAR qw( Tk.par);

at the beginning of their main.pl that launches your script. Just put Tk.par
in the same directory with the applications.

---------------------------------------------------

If application #3 also used LWP, you could continue reducing it with:

    pp -e "use LWP;" -p -o LWP.par
    pare -l log.txt -u LWP.par appl3.exe

and application #3 would have:

    use PAR qw( LWP.par Tk.par);

at the beginning of its main.pl.

---------------------------------------------------

If you build applications that have a growing list of things in common, you
could have a file common.pl that contained only the common "use" statements:

    use Tk;
    use LWP;
    use This;
    use The::Other;

and pull them out of the application with:

    pp -p -o common.par common.pl
    pare -u common.par application.exe

---------------------------------------------------

Reduced and "use"d files can be any of the three PAR type outputs: a
standalone executable, a standalone perl script, or a PAR (zip) file.

For instance, if you have one application already shipped that is quite large,
and you want to reduce the size of a second application that uses much of the
same libraries, you can do:

    pare -u first_app.exe second_app.exe

as long as first_app.exe and second_app.exe are going to be stored at the same
location. second_app.exe will use first_app.exe as a PAR.

---------------------------------------------------

Pare modifies MANIFEST and main.pl, but not the application code. Nothing in
the script/ directory will be removed even if it matches in the other PAR file.
Log output appends to the log file.

In the case of simple zip files, pare automates the process of comparing
and removing files that could be done with any zip tool. In the case of an
executable or standalone script, it is also preserving the loader frontend and
re-calculating the PAR trailer.

Pare is free and carries no license or guarantee. It is placed in the public
domain. Do whatever you want to do with it.

Alan Stewart
astewart1@cox.net