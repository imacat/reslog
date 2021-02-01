# _helper.pm - A simple test suite helper

# Copyright (c) 2005-2007 imacat
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package _helper;
use 5.005;
use strict;
use warnings;
use base qw(Exporter);
use vars qw($VERSION @EXPORT);
$VERSION = "0.05";
@EXPORT = qw();
push @EXPORT, qw(fread frread fwrite frwrite);
push @EXPORT, qw(runcmd whereis ftype flist prsrvsrc cleanup);
push @EXPORT, qw(nofile nogzip nobzip2);
push @EXPORT, qw(mkrndlog_normal mkrndlog_noip mkrndlog_empty);
push @EXPORT, qw(randword);
push @EXPORT, qw(TYPE_PLAIN TYPE_GZIP TYPE_BZIP2);
push @EXPORT, qw(@CNTTYPES @SRCTYPES @KEEPTYPES @OVERTYPES @SUFTYPES @TSUFTYPES);
# Prototype declaration
sub thisfile();
sub fread($);
sub frread($);
sub fwrite($$);
sub frwrite($$);
sub runcmd($@);
sub whereis($);
sub ftype($);
sub flist($);
sub prsrvsrc($);
sub cleanup($$$);
sub nofile();
sub nogzip();
sub nobzip2();
sub mkrndlog_normal($);
sub mkrndlog_noip($);
sub mkrndlog_empty($);
sub randword();
sub randip();

use ExtUtils::MakeMaker qw();
use Fcntl qw(:seek);
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(splitdir catdir catfile path);
use File::Temp qw(tempfile);
use Socket;

use vars qw(%WHEREIS $NOFILE $NOGZIP $NOBZIP2 $RANDIP);
%WHEREIS = qw();
undef $NOFILE;
undef $NOGZIP;
undef $NOBZIP2;
undef $RANDIP;

use constant TYPE_PLAIN => "text/plain";
use constant TYPE_GZIP => "application/x-gzip";
use constant TYPE_BZIP2 => "application/x-bzip2";

use vars qw(@CNTTYPES @SRCTYPES @KEEPTYPES @OVERTYPES @SUFTYPES @TSUFTYPES);
# All the countent type information
@CNTTYPES = (   {   "title" => "normal log file",
                    "sub"   => \&mkrndlog_normal, },
                {   "title" => "log file without IP",
                    "sub"   => \&mkrndlog_noip, },
                {   "title" => "empty log file",
                    "sub"   => \&mkrndlog_empty, }, );
# All the source type information
@SRCTYPES = (   {   "title" => "plain text source",
                    "type"  => TYPE_PLAIN,
                    "suf"   => "",
                    "skip"  => 0, },
                {   "title" => "gzip source",
                    "type"  => TYPE_GZIP,
                    "suf"   => ".gz",
                    "skip"  => nogzip, },
                {   "title" => "bzip2 source",
                    "type"  => TYPE_BZIP2,
                    "suf"   => ".bz2",
                    "skip"  => nobzip2, }, );
# All the keep type information
@KEEPTYPES = (  {   "title" => "keep default",
                    "opts"  => [],
                    "del"   => 1,
                    "keep"  => 0,
                    "cdel"  => 0,
                    "ckeep" => 1, },
                {   "title" => "keep all",
                    "opts"  => [qw(-k a)],
                    "del"   => 0,
                    "keep"  => 1,
                    "cdel"  => 0,
                    "ckeep" => 1, },
                {   "title" => "keep delete",
                    "opts"  => [qw(-k d)],
                    "del"   => 1,
                    "keep"  => 0,
                    "cdel"  => 1,
                    "ckeep" => 0, },
                {   "title" => "keep restart",
                    "opts"  => [qw(-k r)],
                    "del"   => 0,
                    "keep"  => 0,
                    "cdel"  => 0,
                    "ckeep" => 0, }, );
# All the override type information
@OVERTYPES = (  {   "title" => "override no existing",
                    "opts"  => [],
                    "mkex"  => 0,
                    "ok"    => 1,
                    "ce"    => sub { $_[1]; }, },
                {   "title" => "override default",
                    "opts"  => [],
                    "mkex"  => 1,
                    "ok"    => 0,
                    "ce"    => sub { $_[0]; }, },
                {   "title" => "override overwrite",
                    "opts"  => [qw(-o o)],
                    "mkex"  => 1,
                    "ok"    => 1,
                    "ce"    => sub { $_[1]; }, },
                {   "title" => "override append",
                    "opts"  => [qw(-o a)],
                    "mkex"  => 1,
                    "ok"    => 1,
                    "ce"    => sub { $_[0] . $_[1]; }, },
                {   "title" => "override fail",
                    "opts"  => [qw(-o f)],
                    "mkex"  => 1,
                    "ok"    => 0,
                    "ce"    => sub { $_[0]; }, }, );
# All the suffix information
@SUFTYPES = (  {    "title" => "default suffix",
                    "suf"   => ".resolved",
                    "opts"  => sub { }, },
                {   "title" => "custom suffix",
                    "suf"   => undef,
                    "opts"  => sub { ("-s", $_[0]); }, }, );
# All the trim-suffix information
@TSUFTYPES = (  {   "title" => "default trim-suffix",
                    "suf"   => "",
                    "opts"  => sub { }, },
                {   "title" => "custom trim-suffix",
                    "suf"   => undef,
                    "opts"  => sub { ("-t", $_[0]); }, }, );

# thisfile: Return the name of this file
sub thisfile() { basename($0); }

# fread: A simple reader to read a log file in any supported format
sub fread($) {
    local ($_, %_);
    my ($file, $content);
    $file = $_[0];
    
    # non-existing file
    return undef if !-e $file;
    
    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # Compress::Zlib
        if (eval {  require Compress::Zlib;
                    import Compress::Zlib qw(gzopen);
                    1; }) {
            my ($FH, $gz);
            $content = "";
            open $FH, $file             or die thisfile . ": $file: $!";
            $gz = gzopen($FH, "rb")     or die thisfile . ": $file: $!";
            while (1) {
                ($gz->gzread($_, 10240) != -1)
                                        or die thisfile . ": $file: " . $gz->gzerror;
                $content .= $_;
                last if length $_ < 10240;
            }
            $gz->gzclose                and die thisfile . ": $file: " . $gz->gzerror;
            return $content;
        
        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "gzip";
            $CMD = "\"$CMD\" -cd \"$file\"";
            open $PH, "$CMD |"          or die thisfile . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die thisfile . ": $CMD: $!";
            return $content;
        }
    
    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # Compress::Bzip2
        if (eval {  require Compress::Bzip2;
                    import Compress::Bzip2 2.00;
                    import Compress::Bzip2 qw(bzopen);
                    1; }) {
            my ($FH, $bz);
            $content = "";
            open $FH, $file             or die thisfile . ": $file: $!";
            $bz = bzopen($FH, "rb")     or die thisfile . ": $file: $!";
            while (1) {
                ($bz->bzread($_, 10240) != -1)
                                        or die thisfile . ": $file: " . $bz->bzerror;
                $content .= $_;
                last if length $_ < 10240;
            }
            $bz->bzclose                and die thisfile . ": $file: " . $bz->bzerror;
            return $content;
        
        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "bzip2";
            $CMD = "bzip2 -cd \"$file\"";
            open $PH, "$CMD |"          or die thisfile . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die thisfile . ": $CMD: $!";
            return $content;
        }
    
    # a plain text file
    } else {
        my $FH;
        open $FH, $file                 or die thisfile . ": $file: $!";
        $content = join "", <$FH>;
        close $FH                       or die thisfile . ": $file: $!";
        return $content;
    }
}

# frread: A raw file reader
sub frread($) {
    local ($_, %_);
    my ($file, $content, $FH, $size);
    $file = $_[0];
    
    # non-existing file
    return undef if !-e $file;
    
    $size = (stat $file)[7];
    open $FH, $file                     or die thisfile . ": $file: $!";
    binmode $FH                         or die thisfile . ": $file: $!";
    (read($FH, $content, $size) == $size)
                                        or die thisfile . ": $file: $!";
    close $FH                           or die thisfile . ": $file: $!";
    return $content;
}

# fwrite: A simple writer to write a log file in any supported format
sub fwrite($$) {
    local ($_, %_);
    my ($file, $content);
    ($file, $content) = @_;
    
    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # Compress::Zlib
        if (eval {  require Compress::Zlib;
                    import Compress::Zlib qw(gzopen);
                    1; }) {
            my ($FH, $gz);
            open $FH, ">$file"          or die thisfile . ": $file: $!";
            $gz = gzopen($FH, "wb9")    or die thisfile . ": $file: $!";
            ($gz->gzwrite($content) == length $content)
                                        or die thisfile . ": $file: " . $gz->gzerror;
            $gz->gzclose                and die thisfile . ": $file: " . $gz->gzerror;
            return;
        
        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "gzip";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"          or die thisfile . ": $CMD: $!";
            print $PH $content          or die thisfile . ": $CMD: $!";
            close $PH                   or die thisfile . ": $CMD: $!";
            return;
        }
    
    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # Compress::Bzip2
        if (eval {  require Compress::Bzip2;
                    import Compress::Bzip2 2.00;
                    import Compress::Bzip2 qw(bzopen);
                    1; }) {
            my ($FH, $bz);
            open $FH, ">$file"          or die thisfile . ": $file: $!";
            $bz = bzopen($FH, "wb9")    or die thisfile . ": $file: $!";
            if ($content ne "") {
                ($bz->bzwrite($content, length $content) == length $content)
                                        or die thisfile . ": $file: " . $bz->bzerror;
            }
            $bz->bzclose                and die thisfile . ": $file: " . $bz->bzerror;
            return;
        
        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = whereis "bzip2";
            $CMD = "\"$CMD\" -9f > \"$file\"";
            open $PH, "| $CMD"        or die thisfile . ": $CMD: $!";
            print $PH $content        or die thisfile . ": $CMD: $!";
            close $PH                 or die thisfile . ": $CMD: $!";
            return;
        }
    
    # a plain text file
    } else {
        my $FH;
        open $FH, ">$file"              or die thisfile . ": $file: $!";
        print $FH $content              or die thisfile . ": $file: $!";
        close $FH                       or die thisfile . ": $file: $!";
        return;
    }
}

# frwrite: A raw file writer
sub frwrite($$) {
    local ($_, %_);
    my ($file, $content, $FH);
    ($file, $content) = @_;
    
    open $FH, ">$file"                  or die thisfile . ": $file: $!";
    binmode $FH                         or die thisfile . ": $file: $!";
    print $FH $content                  or die thisfile . ": $file: $!";
    close $FH                           or die thisfile . ": $file: $!";
    return;
}

# runcmd: Run a command and return the result
sub runcmd($@) {
    local ($_, %_);
    my ($retno, $out, $err, $in, @cmd, $cmd, $OUT, $ERR, $STDOUT, $STDERR, $PH);
    ($in, @cmd) = @_;
    
    $err = "Running " . join(" ", map "\"$_\"", @cmd) . "\n";
    $out = "";
    
    open $STDOUT, ">&", \*STDOUT        or die thisfile . ": STDOUT: $!";
    open $STDERR, ">&", \*STDERR        or die thisfile . ": STDERR: $!";
    $OUT = tempfile                     or die thisfile . ": tempfile: $!";
    binmode $OUT                        or die thisfile . ": tempfile: $!";
    $ERR = tempfile                     or die thisfile . ": tempfile: $!";
    binmode $ERR                        or die thisfile . ": tempfile: $!";
    open STDOUT, ">&", $OUT             or die thisfile . ": tempfile: $!";
    binmode STDOUT                      or die thisfile . ": tempfile: $!";
    open STDERR, ">&", $ERR             or die thisfile . ": tempfile: $!";
    binmode STDERR                      or die thisfile . ": tempfile: $!";
    
    $cmd = join " ", map "\"$_\"", @cmd;
    if ($^O eq "MSWin32") {
        open $PH, "| $cmd"              or die thisfile . ": $cmd: $!";
    } else {
        open $PH, "|-", @cmd            or die thisfile . ": $cmd: $!";
    }
    binmode $PH                         or die thisfile . ": $cmd: $!";
    print $PH $in                       or die thisfile . ": $cmd: $!";
    close $PH;
    $retno = $?;
    
    open STDOUT, ">&", $STDOUT          or die thisfile . ": tempfile: $!";
    open STDERR, ">&", $STDERR          or die thisfile . ": tempfile: $!";
    
    seek $OUT, 0, SEEK_SET              or die thisfile . ": tempfile: $!";
    $out = join "", <$OUT>;
    close $OUT                          or die thisfile . ": tempfile: $!";
    seek $ERR, 0, SEEK_SET              or die thisfile . ": tempfile: $!";
    $err = join "", <$ERR>;
    close $ERR                          or die thisfile . ": tempfile: $!";
    
    return ($retno, $out, $err);
}

# whereis: Find an executable
#   Code inspired from CPAN::FirstTime
sub whereis($) {
    local ($_, %_);
    my ($file, $path);
    $file = $_[0];
    return $WHEREIS{$file} if exists $WHEREIS{$file};
    foreach my $dir (path) {
        return ($WHEREIS{$file} = $path)
            if defined($path = MM->maybe_command(catfile($dir, $file)));
    }
    return ($WHEREIS{$file} = undef);
}

# ftype: Find the file type
sub ftype($) {
    local ($_, %_);
    my $file;
    $file = $_[0];
    return undef unless -e $file;
    # Use File::MMagic
    if (eval { require File::MMagic; 1; }) {
        $_ = new File::MMagic->checktype_filename($file);
        return TYPE_GZIP if /gzip/;
        return TYPE_BZIP2 if /bzip2/;
        # All else are text/plain
        return TYPE_PLAIN;
    }
    # Use file executable
    if (defined($_ = whereis "file")) {
        $_ = join "", `"$_" "$file"`;
        return TYPE_GZIP if /gzip/;
        return TYPE_BZIP2 if /bzip2/;
        # All else are text/plain
        return TYPE_PLAIN;
    }
    # No type checker available
    return undef;
}

# flist: Obtain the files list in a directory
sub flist($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die thisfile . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die thisfile . ": $dir: $!";
    return join " ", sort @_;
}

# prsrvsrc: Preserve the source test files
sub prsrvsrc($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die thisfile . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die thisfile . ": $dir: $!";
    rmtree "$dir/source";
    mkpath "$dir/source";
    frwrite "$dir/source/$_", frread "$dir/$_"
        foreach @_;
    return;
}

# cleanup: Clean up the test files
sub cleanup($$$) {
    local ($_, %_);
    my ($r, $dir, $testno, $testname, $c);
    ($r, $dir, $testno) = @_;
    # Nothing to clean up
    return unless -e $dir;
    # Success
    if ($r) {
        rmtree $dir;
        return;
    }
    # Fail - keep the test files for debugging
    $testname = basename((caller)[1]);
    $testname =~ s/\.t$//;
    $c = 1;
    $c++ while -e ($_ = "$dir.$testname.$testno.$c");
    rename $dir, $_                     or die thisfile . ": $dir, $_: $!";
    return;
}

# nofile: If we have the file type checker somewhere
sub nofile() {
    $NOFILE = eval { require File::MMagic; 1; }
                || defined whereis "file"?
            0: "File::MMagic or file executable not available"
        if !defined $NOFILE;
    return $NOFILE;
}

# nogzip: If we have gzip support somewhere
sub nogzip() {
    $NOGZIP = eval { require Compress::Zlib; 1; }
                || defined whereis "gzip"?
            0: "Compress::Zlib or gzip executable not available"
        if !defined $NOGZIP;
    return $NOGZIP;
}

# nobzip2: If we have bzip2 support somewhere
sub nobzip2() {
    $NOBZIP2 = eval { require Compress::Bzip2; import Compress::Bzip2 2.00; 1; }
                || defined whereis "bzip2"?
            0: "Compress::Bzip2 v2 or bzip2 executable not available"
        if !defined $NOBZIP2;
    return $NOBZIP2;
}

# mkrndlog_normal: Create a normal random log file
sub mkrndlog_normal($) {
    local ($_, %_);
    my ($file, $hosts, @host_is_ip, @logs, $t, $content, $malformed, $tz);
    my (%rlogs, $rcontent);
    $file = $_[0];
    
    @logs = qw();
    %rlogs = qw();
    
    # Start from sometime in the past year
    $t = time - int rand(86400*365);
    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    
    # 3-5 hosts
    $hosts = 3 + int rand 3;
    # Host type: 1: IP, 0: domain name
    @host_is_ip = qw();
    push @host_is_ip, 0 while @host_is_ip < $hosts;
    # We need exactly 2 IP
    $host_is_ip[int rand $hosts] = 1
        while grep($_ == 1, @host_is_ip) < 2;
    foreach my $is_ip (@host_is_ip) {
        my ($host, $rhost, $user, $htver, @hlogs, $hlogs);
        if ($is_ip) {
            # Generate a random IP
            ($host, $rhost) = randip;
        
        } else {
            # Generate a random domain name
            # 3-5 levels, end with net or com
            $_ = 2 + int rand 3;
            @_ = qw();
            push @_, randword while @_ < $_;
            push @_, (qw(net com))[int rand 2];
            $host = join ".", @_;
            $rhost = $host;
        }
        $user = (0, 0, 1)[int rand 3]? "-": randword;
        $htver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
        # 3-5 log entries foreach host
        $hlogs = 3 + int rand 3;
        @hlogs = qw();
        while (@hlogs < $hlogs) {
            my ($ttxt, $method, $url, $dirs, @dirs, $type, $status, $size);
            my $record;
            # 0-2 seconds later
            $t += int rand 3;
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $ttxt = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                @_[3,4,5,2,1,0],
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;
            
            $method = (qw(GET GET GET HEAD POST))[int rand 5];
            
            # Generate a random URL
            # 0-3 levels of directories
            $dirs = int rand 4;
            @dirs = qw();
            push @dirs, "/" . randword while @dirs < $dirs;
            $type = ("", qw(html html txt css png jpg))[int rand 7];
            if ($type eq "") {
                $url = join("", @dirs) . "/";
            } else {
                $url = join("", @dirs) . "/" . randword . ".$type";
            }
            
            $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
            if ($status == 304) {
                $size = 0;
            } else {
                $size = 200 + int rand 35000;
            }
            $record = sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $host, $user, $ttxt, $method, $url, $htver, $status, $size;
            $rlogs{$record} = sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $rhost, $user, $ttxt, $method, $url, $htver, $status, $size;
            push @hlogs, $record;
        }
        push @logs, @hlogs;
        # 0-5 seconds later
        $t += int rand 6;
    }
    
    # Insert 1-2 malformed lines
    $malformed = 1 + int rand 2;
    while ($malformed > 0) {
        my ($line, $pos);
        # Generate the random malformed line
        $_ = 3 + int rand 5;
        @_ = qw();
        push @_, randword while @_ < $_;
        $line = join(" ", @_) . ".\n";
        $line =~ s/^(.)/uc $1/e;
        # The position to insert the line
        $_ = int rand @logs;
        @logs = (@logs[0...$_], $line, @logs[$_+1...$#logs]);
        $malformed--;
    }
    
    # Compose the content
    $content = join "", @logs;
    $rcontent = join "", map exists $rlogs{$_}? $rlogs{$_}: $_, @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return ($content, $rcontent);
}

# mkrndlog_noip: Create a random log file without IP.
sub mkrndlog_noip($) {
    local ($_, %_);
    my ($file, $hosts, @logs, $t, $content, $malformed, $tz);
    $file = $_[0];
    
    @logs = qw();
    
    # Start from sometime in the past year
    $t = time - int rand(86400*365);
    # Time zone
    $tz = (-12 + (int rand 53) / 2) * 3600;
    
    # 3-5 hosts
    $hosts = 3 + int rand 3;
    for (my $i = 0; $i < $hosts; $i++) {
        my ($host, $user, $htver, @hlogs, $hlogs);
        # Generate a random domain name
        # 3-5 levels, end with net or com
        $_ = 2 + int rand 3;
        @_ = qw();
        push @_, randword while @_ < $_;
        push @_, (qw(net com))[int rand 2];
        $host = join ".", @_;
        $user = (0, 0, 1)[int rand 3]? "-": randword;
        $htver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
        # 3-5 log entries foreach host
        $hlogs = 3 + int rand 3;
        @hlogs = qw();
        while (@hlogs < $hlogs) {
            my ($ttxt, $method, $url, $dirs, @dirs, $type, $status, $size);
            # 0-2 seconds later
            $t += int rand 3;
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $ttxt = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                @_[3,4,5,2,1,0],
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;
            
            $method = (qw(GET GET GET HEAD POST))[int rand 5];
            
            # Generate a random URL
            # 0-3 levels of directories
            $dirs = int rand 4;
            @dirs = qw();
            push @dirs, "/" . randword while @dirs < $dirs;
            $type = ("", qw(html html txt css png jpg))[int rand 7];
            if ($type eq "") {
                $url = join("", @dirs) . "/";
            } else {
                $url = join("", @dirs) . "/" . randword . ".$type";
            }
            
            $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
            if ($status == 304) {
                $size = 0;
            } else {
                $size = 200 + int rand 35000;
            }
            push @hlogs, sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $host, $user, $ttxt, $method, $url, $htver, $status, $size;
        }
        push @logs, @hlogs;
        # 0-5 seconds later
        $t += int rand 6;
    }
    
    # Insert 1-2 malformed lines
    $malformed = 1 + int rand 2;
    while ($malformed > 0) {
        my ($line, $pos);
        # Generate the random malformed line
        $_ = 3 + int rand 5;
        @_ = qw();
        push @_, randword while @_ < $_;
        $line = join(" ", @_) . ".\n";
        $line =~ s/^(.)/uc $1/e;
        # The position to insert the line
        $_ = int rand @logs;
        @logs = (@logs[0...$_], $line, @logs[$_+1...$#logs]);
        $malformed--;
    }
    
    # Compose the content
    $content = join "", @logs;
    # Output the file
    fwrite($file, $content);
    # Return the content
    return ($content, $content);
}

# mkrndlog_empty: Create an empty log file.
sub mkrndlog_empty($) {
    local ($_, %_);
    $_ = $_[0];
    fwrite($_, "");
    return ("", "");
}

# randword: Supply a random English word
sub randword() {
    local ($_, %_);
    @_ = qw(
culminates spector thule tamil sages fasten bothers intricately librarian
mist criminate impressive scissor trance standardizing enabler athenians
planers decisions salvation wetness fibers cowardly winning call stockton
bifocal rapacious steak reinserts overhaul glaringly playwrights wagoner
garland hampered effie messy despaired orthodoxy bacterial bernardine driving
danization vapors uproar sects litmus sutton lacrosse);
    return $_[int rand @_];
}

# randip: Supply a random IP
#   Big public web companies have more reliable reverse DNS
sub randip() {
    local ($_, %_);
    # Initialize our resolvable IP pool
    if (!defined $RANDIP) {
        my (@ip, @hosts);
        $RANDIP = {};
        @ip = qw();
        # Famous websites - they are resolved to several IPs, and their
        # reverse domain is guarenteed by the akadns.net service.
        foreach my $host (qw(www.google.com
                www.yahoo.com www.microsoft.com)) {
            # Find the addresses
            push @ip, map join(".", unpack "C4", $_), @_[4...$#_]
                if (@_ = gethostbyname $host) > 0;
        }
        # 127.0.0.1 may be resolved to localhost
        push @ip, "127.0.0.1";
        foreach my $ip (@ip) {
            my $host;
            # Find its reverse lookup domain name
            next if !defined($host = gethostbyaddr inet_aton($ip), AF_INET);
            # Find the address again
            next unless (@_ = gethostbyname $host) > 0;
            next if (@_ = @_[4...$#_]) > 1;
            $_ = join ".", unpack "C4", $_[0];
            # Not match
            next if $_ ne $ip;
            # OK.  Record it.
            $$RANDIP{$ip} = $host;
        }
        # Hosts reliably resolve to themselves
        @hosts = qw();
        # My own hosts
        push @hosts, qw(rinse.wov.idv.tw cotton.wov.idv.tw);
        # Yahoo! mail servers
        for (my $i = 101; $i <= 109; $i++) {
            push @hosts, "smtp$i.mail.mud.yahoo.com";
        }
        # HiNet mail servers
        for (my $i = 1; $i <= 89; $i++) {
            push @hosts, "ms$i.hinet.net"
                if $i % 10 != 0;
        }
        foreach my $host (@hosts) {
            my $ip;
            # Find the address
            next unless (@_ = gethostbyname $host) > 0;
            next if (@_ = @_[4...$#_]) > 1;
            $ip = join ".", unpack "C4", $_[0];
            # Find its reverse lookup domain name again
            next if !defined($_ = gethostbyaddr inet_aton($ip), AF_INET);
            # Not match
            next if $_ ne $host;
            # OK.  Record it.
            $$RANDIP{$ip} = $host;
        }
    }
    # 1: Resolvables
    if (keys %$RANDIP > 0 && int rand 2) {
        @_ = sort keys %$RANDIP;
        $_ = $_[int rand @_];
        return ($_, $$RANDIP{$_});
    }
    # 0: Unresolvables
    # Use loopback (127.0.0.0/8) and link local (169.254.0.0/16)
    do {
        if (int rand 2) {
            $_ = join ".", 127, int rand 255, int rand 255, 1 + int rand 254;
        } else {
            $_ = join ".", 169, 254, int rand 255, 1 + int rand 254;
        }
    } until !defined gethostbyaddr inet_aton($_), AF_INET;
    return ($_, $_);
}

1;

__END__
