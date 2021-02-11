`reslog` - Reverse-resolve IP in Apache log files
===============================================


Description
-----------

`reslog` reverse-resolves IP in the [Apache] log files.  These log
files can then be analyzed by another program, like [Analog].  You can
think of it as a replacement of Apache `HostNameLookups` directive, in
the sense that it batch resolves the client IP once a day.

[Apache]: https://httpd.apache.org
[Analog]: https://www.c-amie.co.uk/software/analog


Caution
-------

* *Resolving takes long time*.  This is mainly caused by the look up:
  Network packets may be filtered by firewalls; DNS servers may not be
  correctly configured; may not be up working; may sit in slow network
  sections; may be old slow machines; may have traffic jam… etc.  All
  these problems are beyond our control.

* If it stops in the middle of its execution, as when the user hits a
  `Ctrl-Break`, it may leave a temporary working file.  The next time
  it runs, it stops when it sees that temporary working file at the
  first sight.  Please process that file first.  You can resolve it
  again, just like an ordinary log file.

* `reslog` needs temporary working space.  Disk space is cheaper and
  is more available than memory.  However, this means that it needs
  free temporary disk space about 2 times of the size of the
  uncompressed source log file (10 times if using memory).  Please
  make sure you have that much free space.

* `reslog` does not support IPv6 yet.

* I suggest that you install [File::MMagic] instead of counting on the
  `file` executable.  The internal magic file of File::MMagic works
  better than the `file` executable.  `reslog` treats everything not
  gzip nor bzip2 compressed as plain text.  When a compressed log file
  is wrongly recognized as an image, `reslog` treats it as plain text,
  reads directly from it, and fails.  This does not hurt the source
  log files, but is still annoying.

[File::MMagic]: https://metacpan.org/release/File-MMagic


System Requirement
------------------

1. Perl, version 5.8.0 or above.  `reslog` uses 3-argument open() to
   duplicate file handles, which is only supported since 5.8.0.  I
   have not successfully port this onto earlier versions yet.  Please
   tell me if you made it.

   You can run `perl -v` to check your current Perl version.  If you
   do not have Perl, or if you have an older version of Perl, you can
   download and install/upgrade it from the [Perl website].  For
   MS-Windows, you can download and install [Strawberry Perl] or
   [ActivePerl].

2. Required Perl modules: None.

3. Optional Perl modules:

   * [File::MMagic]

     This is used to check the file type.  If this is not available,
     `reslog` tries the `file` executable instead.  If that is not
     available, too, `reslog` judges the file type by its name suffix
     (extension).  In that case `reslog` fails when reading from
     `STDIN`.  You can download and install File::MMagic from the CPAN
     archive, or install it with the CPAN shell:

         cpan File::MMagic

     or with the CPANPLUS shell:

         cpanp i File::MMagic

     For Debian/Ubuntu:

         sudo apt install libfile-mmagic-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-File-MMagic

     For FreeBSD:

         ports install p5-File-MMagic

     The alternative `file.exe` for MS-Windows can be obtained from
     the [GnuWin32] home page.  Be sure to save it as `file.exe`
     somewhere in your `PATH`.

   * [Compress::Zlib]

     This is used to support reading/writing the gzip compressed
     files.  It is only needed when gzip compressed files are
     encountered.  If it is not available, `arclog` tries the `gzip`
     executable instead.  If that is not available, too, `arclog`
     fails.  Compress::Zlib comes with Perl since version 5.9.3.  If
     not, you can download and install it from the CPAN archive, or
     install it with the CPAN shell:

         cpan Compress::Zlib

     or with the CPANPLUS shell:

         cpanp i Compress::Zlib

     For Debian/Ubuntu:

         sudo apt install libio-compress-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-IO-Compress

     For FreeBSD:

         ports install p5-IO-Compress

     For ActivePerl:

         ppm install IO-Compress

     The alternative `gzip.exe` for MS-Windows can be obtained from
     [the gzip website].  Be sure to save it as `gzip.exe` somewhere
     in your `PATH`.

   * [Compress::Bzip2] version 2 or above.

     This is used to support reading/writing the bzip2 compressed
     files.  It is only needed when bzip2 compressed files are
     encountered.  If it is not available, `reslog` tries the `bzip2`
     executable instead.  If that is not available, too, `reslog`
     fails.  Notice that older versions before 2 does not work, since
     the file I/O compression was not implemented yet.  You can
     download and install Compress::Bzip2 from the CPAN archive, or
     install it with the CPAN shell:

         cpan Compress::Bzip2

     or with the CPANPLUS shell:

         cpanp i Compress::Bzip2

     For Debian/Ubuntu:

         sudo apt install libcompress-bzip2-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-Compress-Bzip2

     For FreeBSD:

         ports install p5-Compress-Bzip2

     For ActivePerl:

         ppm install Compress-Bzip2

     The alternative `bzip2.exe` for MS-Windows can be obtained from
     [the bzip2 website].  Be sure to save it as `bzip2.exe` somewhere
     in your `PATH`.

   * [Term::ReadKey]

     This is used to display the progress bar.  The progress bar is a
     good visual feedback of what `reslog` is currently doing, but
     `reslog` is safe without it.  You can download and install
     Term::ReadKey from the CPAN archive, or install it with the
     CPAN shell:

         cpan Term::ReadKey

     or with the CPANPLUS shell:

         cpanp i Term::ReadKey

     For Debian/Ubuntu:

         sudo apt install libterm-readkey-perl

     For Red Hat/Fedora/CentOS:

         sudo yum install perl-TermReadKey

     For FreeBSD:

         ports install p5-Term-ReadKey

     For ActivePerl:

         ppm install TermReadKey

[Perl website]: https://www.perl.org
[Strawberry Perl]: https://strawberryperl.com
[ActivePerl]: https://www.activestate.com/products/perl/
[File::MMagic]: https://metacpan.org/release/File-MMagic
[GnuWin32]: http://gnuwin32.sourceforge.net
[Compress::Zlib]: https://metacpan.org/pod/Compress::Zlib
[the gzip website]: https://www.gzip.org
[Compress::Bzip2]: https://metacpan.org/release/Compress-Bzip2
[the bzip2 website]: http://www.bzip.org
[Term::ReadKey]: https://metacpan.org/release/TermReadKey


Download
--------

`reslog` is hosted is on…

* [reslog project on GitHub]

* [reslog project on SourceForge]

You can always download the newest version of `reslog` from…

* [reslog download on SourceForge]

* [Tavern IMACAT’s FTP directory]

imacat’s PGP public key is at…

* [imacat’s PGP key at Tavern IMACAT’s]

[reslog project on GitHub]: https://github.com/imacat/reslog
[reslog project on SourceForge]: https://sf.net/p/reslog
[reslog download on SourceForge]: https://sourceforge.net/projects/reslog/files
[Tavern IMACAT’s FTP directory]: https://ftp.imacat.idv.tw/pub/reslog/
[imacat’s PGP key at Tavern IMACAT’s]: https://www.imacat.idv.tw/me/pgpkey.asc


Install
-------

If you are upgrading from `reslog` 3.10 or earlier, or if you are
upgrading from `reslog.pl` 3.02 or earlier, please read the upgrade
instruction later in this document.

### Install with [ExtUtils::MakeMaker]

    % perl Makefile.PL
    % make
    % make test
    % make install

When running `make install`, make sure you have the privilege to
write to the installation locations.  This usually requires the `root`
privilege.

For MS-Windows, since `make` is not universally available,
Module::Build is preferred to ExtUtils::MakeMaker.  See the
instructions below.


### Install with [Module::Build]

    % perl Build.PL
    % ./Build
    % ./Build test
    % ./Build install

When running `./Build install`, make sure you have the privilege to
write to the installation locations.  This usually requires the `root`
privilege.

If you want to install into another location, you can set the
`--prefix`.  For example, to install into your home when you are not
`root`:

    % perl Build.PL --prefix=/home/jessica

Refer to the documentation of Module::Build for more installation
options (by running `perldoc Module::Build`).

[ExtUtils::MakeMaker]: https://metacpan.org/release/ExtUtils-MakeMaker
[Module::Build]: https://metacpan.org/release/Module-Build


Upgrade Instruction
-------------------

Here are a few hints for people upgrading from 3.10 or earlier:

### The Default Installation Location Is at `/usr/bin`

Also, the man page is at `/usr/share/man/man1/reslog.1`.  This is to
follow Perl’s standard convention, and to avoid breaking
ExtUtils::MakeMaker with future versions.

When you run `perl Makefile.PL` or `perl Build.PL`, it hints a
list of existing old files to be removed.  Please delete them
manually.

If you saved them in other places, you have to delete them yourself.

Also, if you have any scripts or cron jobs that are running `reslog`,
remember to modify your script for the new `reslog` location.  Of
course, you can copy `reslog` to the original location.  It still
works.


Here are a few hints for people upgrading from 3.02 or earlier:

### The Script Name is Changed from `reslog.pl` to `reslog`

This is obvious.  If you have any scripts or cron jobs that are
running `reslog`, remember to modify your script for the new name.
Of course, you can rename `reslog` to `reslog.pl`.  It still works.

The reason I changed the script and project name is that:  A dot `.`
in the project name is not valid everywhere.  At least SourceForge
don’t accept it.  Besides, `reslog` is enough for a script name under
UNIX.  The `.pl` file name suffix/extension may be convenient on
MS-Windows, but MS-Windows users won’t run it with explorer file name
association anyway, and there is a `pl2bat` to convert `reslog` to
`reslog.bat`, which would make more sense.  The only disadvantage is
that I was using `UltraEdit`, which depends on the file name extension
for the syntax highlighting rules.  I can manually set it anyway.  I’m
using `gedit` on Linux now.  This is not a problem anymore.


### You Need Perl 5.8.0 or Above

`reslog` now has threading to speed up resolving, which requires
Perl’s `ithreads` threading module support that’s only available since
5.8.0.  You can still disable threading if it causes troubles to you,
but the code itself need it.  If you are using a Perl before 5.8.0,
please upgrade it.  You can run `perl -v` to see your current Perl
version.


### The Default Keep Mode is Now `delete`

The documentation said the default keep mode is `delete`, but `reslog`
actually did a `restart`. :p  This is fixed.  If you are running with
the default keep mode, remember to fix it.


### The Argument of `--keep` and `--override` Options Are Required Now

Support for omitting the `--keep` or `--override` arguments are
removed.  This helps to avoid confusion for the log file name and the
option arguments.


### Specifying One `STDIN` No Longer Trigger Everything to `STDOUT`

When resolving multiple files, `STDIN` can output to `STDOUT` now,
with other files output to where they should be.  Specifying one
`STDIN` no longer writes everything to `STDOUT`.  If you want to write
everything to `STDOUT`, be sure to add the `--stdout` option.


Options
-------

    ./reslog [options] [logfile…]
    ./reslog [-h|-v]

* `logfile`

  The log file to be resolved.  You can specify multiple log files.
  If not specified, it reads from `STDIN` and outputs to `STDOUT`.
  You can also specify `-` to read from `STDIN`.  Result of `STDIN`
  goes to `STDOUT`.  `gzip` or `bzip2` compressed files are supported.

* `-k`, `--keep mode`

  What to keep in the source file.  The following modes are supported:

  * `a`, `all`

    Keep the source file after records are archived.

  * `r`, `restart`

    Restart the source file after records are resolved.

  * `d`, `delete`

    Delete the source file after records are resolved.  This is the
    default.

* `-o`, `--override mode`

  What to do with the existing resolved files.  The following modes
  are supported:

  * `o`, `overwrite`

    Overwrite existing target files.

  * `a`, `append`

    Append the records to existing target files.

  * `f`, `fail`

    Stop processing whenever a target file exists, to prevent
    destroying existing files by accident.  This is the default.

* `-s`, `--suffix suf`

  The suffix to be appended to the output file.  If not specified,
  the default is `.resolved`.

* `-t`, `--trim-suffix suf`

  The suffix to be trimmed from the input file name before appending
  the above suffix.  Default is none.  If you are running several log
  file filters, this can help you trim the suffix of the previous one.

* `-n`, `--num-threads num`

  Number of threads to run simultaneously.  The default is 10.  Use 0
  to disable threading.  Your system must support threading itself.
  This option has no effect for systems that do not support threading.

* `-c`, `--stdout`

  Output the result to `STDOUT`.

* `-d`, `--debug`

  Show the detailed debugging messages.  More `-d` to be more
  detailed.

* `-q`, `--quiet`

  Hush!  Only yell on error.

* `-h`, `--help`

  Display the help message and exit.

* `-v`, `--version`

  Output version information and exit.


Documentation
-------------

Type `perldoc reslog` to read the `reslog` manual.


News, Changes and Updates
-------------------------

Refer to the `Changes` for changes, bug fixes, updates, new functions,
etc.


Support
-------

The `reslog` project is hosted on GitHub.  Address your issues on the
GitHub issue tracker https://github.com/imacat/reslog/issues.


Thanks
------

* Thanks to [SourceForge] for hosting the project.

[SourceForge]: https://sf.net


License
-------

    Copyright (C) 2000-2021 imacat.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


imacat ^_*'  
2007/12/4  
<imacat@mail.imacat.idv.tw>  
https://www.imacat.idv.tw  
