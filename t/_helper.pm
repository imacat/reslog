# _helper.pm - A simple test suite helper

# Copyright (c) 2005-2022 imacat
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
our ($VERSION, @EXPORT);
$VERSION = "0.05";
@EXPORT = qw(
    read_file read_raw_file write_file write_raw_file
    run_cmd where_is file_type list_files preserve_source clean_up
    has_no_file has_no_gzip has_no_bzip2 has_no_xz
    make_log_file make_resolved_log_file make_empty_log_file
    random_word
    TYPE_TEXT TYPE_GZIP TYPE_BZIP2 TYPE_XZ
    @CONTENT_TYPES @SOURCE_TYPES @KEEP_MODES @OVERRIDE_MODES @SUFFICES @TRIM_SUFFIX);
# Prototype declaration
sub this_file();
sub read_file($);
sub read_raw_file($);
sub write_file($$);
sub write_raw_file($$);
sub run_cmd($@);
sub where_is($);
sub file_type($);
sub list_files($);
sub preserve_source($);
sub clean_up($$$);
sub has_no_file();
sub has_no_gzip();
sub has_no_bzip2();
sub has_no_xz();
sub make_log_file($);
sub make_resolved_log_file($);
sub make_empty_log_file($);
sub random_word();
sub random_ip();

use ExtUtils::MakeMaker qw();
use Fcntl qw(:seek);
use File::Basename qw(basename);
use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(splitdir catdir catfile path);
use File::Temp qw(tempfile);
use Socket;

our (%WHERE_IS, $HAS_NO_FILE, $HAS_NO_GZIP, $HAS_NO_BZIP2, $HAS_NO_XZ, $RANDOM_IP);
%WHERE_IS = qw();
undef $HAS_NO_FILE;
undef $HAS_NO_GZIP;
undef $HAS_NO_BZIP2;
undef $HAS_NO_XZ;
undef $RANDOM_IP;

use constant TYPE_TEXT => "text/plain";
use constant TYPE_GZIP => "application/x-gzip";
use constant TYPE_BZIP2 => "application/x-bzip2";
use constant TYPE_XZ => "application/x-xz";

our (@CONTENT_TYPES, @SOURCE_TYPES, @KEEP_MODES, @OVERRIDE_MODES, @SUFFICES,
    @TRIM_SUFFIX);
# All the content type information
@CONTENT_TYPES = (
    {   "title" => "normal log file",
        "sub"   => \&make_log_file, },
    {   "title" => "resolved log file",
        "sub"   => \&make_resolved_log_file, },
    {   "title" => "empty log file",
        "sub"   => \&make_empty_log_file, }, );
# All the source type information
@SOURCE_TYPES = (
    {   "title" => "plain text source",
        "type"  => TYPE_TEXT,
        "suf"   => "",
        "skip"  => 0, },
    {   "title" => "gzip source",
        "type"  => TYPE_GZIP,
        "suf"   => ".gz",
        "skip"  => has_no_gzip, },
    {   "title" => "bzip2 source",
        "type"  => TYPE_BZIP2,
        "suf"   => ".bz2",
        "skip"  => has_no_bzip2, },
    {   "title" => "xz source",
        "type"  => TYPE_XZ,
        "suf"   => ".xz",
        "skip"  => has_no_xz, }, );
# All the keep mode information
@KEEP_MODES = (
    {   "title" => "keep default",
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
# All the override mode information
@OVERRIDE_MODES = (
    {   "title"     => "override no existing",
        "opts"      => [],
        "exists"    => 0,
        "ok"        => 1,
        "ce"        => sub { $_[1]; }, },
    {   "title"     => "override default",
        "opts"      => [],
        "exists"    => 1,
        "ok"        => 0,
        "ce"        => sub { $_[0]; }, },
    {   "title"     => "override overwrite",
        "opts"      => [qw(-o o)],
        "exists"    => 1,
        "ok"        => 1,
        "ce"        => sub { $_[1]; }, },
    {   "title"     => "override append",
        "opts"      => [qw(-o a)],
        "exists"    => 1,
        "ok"        => 1,
        "ce"        => sub { $_[0] . $_[1]; }, },
    {   "title"     => "override fail",
        "opts"      => [qw(-o f)],
        "exists"    => 1,
        "ok"        => 0,
        "ce"        => sub { $_[0]; }, }, );
# All the suffix information
@SUFFICES = (
    {   "title" => "default suffix",
        "suf"   => ".resolved",
        "opts"  => sub { }, },
    {   "title" => "custom suffix",
        "suf"   => undef,
        "opts"  => sub { ("-s", $_[0]); }, }, );
# All the trim-suffix information
@TRIM_SUFFIX = (
    {   "title" => "default trim-suffix",
        "suf"   => "",
        "opts"  => sub { }, },
    {   "title" => "custom trim-suffix",
        "suf"   => undef,
        "opts"  => sub { ("-t", $_[0]); }, }, );

# Return the name of this file
sub this_file() { basename($0); }

# A simple reader to read a log file in any supported format
sub read_file($) {
    local ($_, %_);
    my ($file, $content);
    $file = $_[0];

    # non-existing file
    return undef if !-e $file;

    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # IO::Uncompress::Gunzip
        if (eval { require IO::Uncompress::Gunzip; 1; }) {
            my $gz;
            $content = "";
            $gz = IO::Uncompress::Gunzip->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::Gunzip::GunzipError";
            $content = join "", <$gz>;
            $gz->close                  or die this_file . ": $file: $IO::Uncompress::Gunzip::GunzipError";
            return $content;

        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "gzip";
            $CMD = "\"$CMD\" -cdf \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # IO::Uncompress::Bunzip2
        if (eval { require IO::Uncompress::Bunzip2; 1; }) {
            my $bz;
            $content = "";
            $bz = IO::Uncompress::Bunzip2->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::Bunzip2::Bunzip2Error";
            $content = join "", <$bz>;
            $bz->close                  or die this_file . ": $file: $IO::Uncompress::Bunzip2::Bunzip2Error";
            return $content;

        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "bzip2";
            $CMD = "\"$CMD\" -cdf \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # an xz compressed file
    } elsif ($file =~ /\.xz$/) {
        # IO::Uncompress::UnXz
        if (eval { require IO::Uncompress::UnXz; 1; }) {
            my $xz;
            $content = "";
            $xz = IO::Uncompress::UnXz->new($file)
                                        or die this_file . ": $file: $IO::Uncompress::UnXz::UnXzError";
            $content = join "", <$xz>;
            $xz->close                  or die this_file . ": $file: $IO::Uncompress::UnXz::UnXzError";
            return $content;

        # xz executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "xz";
            $CMD = "\"$CMD\" -cdf \"$file\"";
            open $PH, "$CMD |"          or die this_file . ": $CMD: $!";
            $content = join "", <$PH>;
            close $PH                   or die this_file . ": $CMD: $!";
            return $content;
        }

    # a plain text file
    } else {
        my $FH;
        open $FH, $file                 or die this_file . ": $file: $!";
        $content = join "", <$FH>;
        close $FH                       or die this_file . ": $file: $!";
        return $content;
    }
}

# A raw file reader
sub read_raw_file($) {
    local ($_, %_);
    my ($file, $content, $FH, $size);
    $file = $_[0];

    # non-existing file
    return undef if !-e $file;

    $size = (stat $file)[7];
    open $FH, $file                     or die this_file . ": $file: $!";
    binmode $FH                         or die this_file . ": $file: $!";
    (read($FH, $content, $size) == $size)
                                        or die this_file . ": $file: $!";
    close $FH                           or die this_file . ": $file: $!";
    return $content;
}

# A simple writer to write a log file in any supported format
sub write_file($$) {
    local ($_, %_);
    my ($file, $content);
    ($file, $content) = @_;

    # a gzip compressed file
    if ($file =~ /\.gz$/) {
        # IO::Compress::Gzip
        if (eval { require IO::Compress::Gzip; 1; }) {
            my $gz;
            $gz = IO::Compress::Gzip->new($file, -Level => 9)
                                        or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            ($gz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            $gz->close                  or die this_file . ": $file: $IO::Compress::Gzip::GzipError";
            return;

        # gzip executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "gzip";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"          or die this_file . ": $CMD: $!";
            print $PH $content          or die this_file . ": $CMD: $!";
            close $PH                   or die this_file . ": $CMD: $!";
            return;
        }

    # a bzip compressed file
    } elsif ($file =~ /\.bz2$/) {
        # IO::Compress::Bzip2
        if (eval { require IO::Compress::Bzip2; 1; }) {
            my $bz;
            $bz = IO::Compress::Bzip2->new($file, BlockSize100K => 9)
                                        or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            ($bz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            $bz->close                  or die this_file . ": $file: $IO::Compress::Bzip2::Bzip2Error";
            return;

        # bzip2 executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "bzip2";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"        or die this_file . ": $CMD: $!";
            print $PH $content        or die this_file . ": $CMD: $!";
            close $PH                 or die this_file . ": $CMD: $!";
            return;
        }

    # an xz compressed file
    } elsif ($file =~ /\.xz$/) {
        # IO::Compress::Xz
        if (eval { require IO::Compress::Xz; 1; }) {
            my $xz;
            $xz = IO::Compress::Xz->new($file, Extreme => 1)
                                        or die this_file . ": $file: $IO::Compress::Xz::XzError";
            ($xz->write($content) == length $content)
                                        or die this_file . ": $file: $IO::Compress::Xz::XzError";
            $xz->close                  or die this_file . ": $file: $IO::Compress::Xz::XzError";
            return;

        # xz executable
        } else {
            my ($PH, $CMD);
            $CMD = where_is "xz";
            $CMD = "\"$CMD\" -c9f > \"$file\"";
            open $PH, "| $CMD"        or die this_file . ": $CMD: $!";
            print $PH $content        or die this_file . ": $CMD: $!";
            close $PH                 or die this_file . ": $CMD: $!";
            return;
        }

    # a plain text file
    } else {
        my $FH;
        open $FH, ">$file"              or die this_file . ": $file: $!";
        print $FH $content              or die this_file . ": $file: $!";
        close $FH                       or die this_file . ": $file: $!";
        return;
    }
}

# A raw file writer
sub write_raw_file($$) {
    local ($_, %_);
    my ($file, $content, $FH);
    ($file, $content) = @_;

    open $FH, ">$file"                  or die this_file . ": $file: $!";
    binmode $FH                         or die this_file . ": $file: $!";
    print $FH $content                  or die this_file . ": $file: $!";
    close $FH                           or die this_file . ": $file: $!";
    return;
}

# Run a command and return the result
sub run_cmd($@) {
    local ($_, %_);
    my ($ret_no, $out, $err, $in, @cmd, $cmd, $OUT, $ERR, $STDOUT, $STDERR, $PH);
    ($in, @cmd) = @_;

    $err = "Running " . join(" ", map "\"$_\"", @cmd) . "\n";
    $out = "";

    open $STDOUT, ">&", \*STDOUT        or die this_file . ": STDOUT: $!";
    open $STDERR, ">&", \*STDERR        or die this_file . ": STDERR: $!";
    $OUT = tempfile                     or die this_file . ": tempfile: $!";
    binmode $OUT                        or die this_file . ": tempfile: $!";
    $ERR = tempfile                     or die this_file . ": tempfile: $!";
    binmode $ERR                        or die this_file . ": tempfile: $!";
    open STDOUT, ">&", $OUT             or die this_file . ": tempfile: $!";
    binmode STDOUT                      or die this_file . ": tempfile: $!";
    open STDERR, ">&", $ERR             or die this_file . ": tempfile: $!";
    binmode STDERR                      or die this_file . ": tempfile: $!";

    $cmd = join " ", map "\"$_\"", @cmd;
    if ($^O eq "MSWin32") {
        open $PH, "| $cmd"              or die this_file . ": $cmd: $!";
    } else {
        open $PH, "|-", @cmd            or die this_file . ": $cmd: $!";
    }
    binmode $PH                         or die this_file . ": $cmd: $!";
    print $PH $in                       or die this_file . ": $cmd: $!";
    close $PH;
    $ret_no = $?;

    open STDOUT, ">&", $STDOUT          or die this_file . ": tempfile: $!";
    open STDERR, ">&", $STDERR          or die this_file . ": tempfile: $!";

    seek $OUT, 0, SEEK_SET              or die this_file . ": tempfile: $!";
    $out = join "", <$OUT>;
    close $OUT                          or die this_file . ": tempfile: $!";
    seek $ERR, 0, SEEK_SET              or die this_file . ": tempfile: $!";
    $err = join "", <$ERR>;
    close $ERR                          or die this_file . ": tempfile: $!";

    return ($ret_no, $out, $err);
}

# Find an executable
#   Code inspired from CPAN::FirstTime
sub where_is($) {
    local ($_, %_);
    my ($file, $path);
    $file = $_[0];
    return $WHERE_IS{$file} if exists $WHERE_IS{$file};
    foreach my $dir (path) {
        return ($WHERE_IS{$file} = $path)
            if defined($path = MM->maybe_command(catfile($dir, $file)));
    }
    return ($WHERE_IS{$file} = undef);
}

# Find the file type
sub file_type($) {
    local ($_, %_);
    my $file;
    $file = $_[0];
    return undef unless -e $file;
    # Use File::MMagic
    if (eval { require File::MMagic; 1; }) {
        $_ = File::MMagic->new->checktype_filename($file);
        return TYPE_GZIP if /gzip/;
        return TYPE_BZIP2 if /bzip2/;
        return TYPE_XZ if /xz/;
        # All else are text/plain
        return TYPE_TEXT;
    }
    # Use file executable
    if (defined($_ = where_is "file")) {
        $_ = join "", `"$_" "$file"`;
        return TYPE_GZIP if /gzip/;
        return TYPE_BZIP2 if /bzip2/;
        return TYPE_XZ if /: XZ/;
        # All else are text/plain
        return TYPE_TEXT;
    }
    # No type checker available
    return undef;
}

# Obtain the files list in a directory
sub list_files($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die this_file . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die this_file . ": $dir: $!";
    return join " ", sort @_;
}

# Preserve the source test files
sub preserve_source($) {
    local ($_, %_);
    my ($dir, $DH);
    $dir = $_[0];
    @_ = qw();
    opendir $DH, $dir                   or die this_file . ": $dir: $!";
    while (defined($_ = readdir $DH)) {
        next if $_ eq "." || $_ eq ".." || !-f "$dir/$_";
        push @_, $_;
    }
    closedir $DH                        or die this_file . ": $dir: $!";
    rmtree "$dir/source";
    mkpath "$dir/source";
    write_raw_file "$dir/source/$_", read_raw_file "$dir/$_"
        foreach @_;
    return;
}

# Clean up the test files
sub clean_up($$$) {
    local ($_, %_);
    my ($r, $dir, $test_no, $test_name, $c);
    ($r, $dir, $test_no) = @_;
    # Nothing to clean up
    return unless -e $dir;
    # Success
    if ($r) {
        rmtree $dir;
        return;
    }
    # Fail - keep the test files for debugging
    $test_name = basename((caller)[1]);
    $test_name =~ s/\.t$//;
    $c = 1;
    $c++ while -e ($_ = "$dir.$test_name.$test_no.$c");
    rename $dir, $_                     or die this_file . ": $dir, $_: $!";
    return;
}

# If we have the file type checker somewhere
sub has_no_file() {
    $HAS_NO_FILE = eval { require File::MMagic; 1; }
                || defined where_is "file"?
            0: "File::MMagic or file executable not available"
        if !defined $HAS_NO_FILE;
    return $HAS_NO_FILE;
}

# If we have gzip support somewhere
sub has_no_gzip() {
    $HAS_NO_GZIP = eval { require IO::Compress::Gzip; require IO::Uncompress::Gunzip; 1; }
                || defined where_is "gzip"?
            0: "IO::Compress::Gzip or gzip executable not available"
        if !defined $HAS_NO_GZIP;
    return $HAS_NO_GZIP;
}

# If we have bzip2 support somewhere
sub has_no_bzip2() {
    $HAS_NO_BZIP2 = eval { require IO::Compress::Bzip2; require IO::Uncompress::Bunzip2; 1; }
                || defined where_is "bzip2"?
            0: "IO::Compress::Bzip2 v2 or bzip2 executable not available"
        if !defined $HAS_NO_BZIP2;
    return $HAS_NO_BZIP2;
}

# If we have xz support somewhere
sub has_no_xz() {
    $HAS_NO_XZ = eval { require IO::Compress::Xz; require IO::Uncompress::UnXz; 1; }
                || defined where_is "xz"?
            0: "IO::Compress::Xz or xz executable not available"
        if !defined $HAS_NO_XZ;
    return $HAS_NO_XZ;
}

# Create a normal random log file
sub make_log_file($) {
    local ($_, %_);
    my ($file, $hosts, @host_is_ip, @logs, $t, $content, $malformed, $tz);
    my (%resolved_logs, $resolved_content);
    $file = $_[0];

    @logs = qw();
    %resolved_logs = qw();

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
        my ($host, $resolved_host, $user, $http_ver, @host_logs, $count);
        if ($is_ip) {
            # Generate a random IP
            ($host, $resolved_host) = random_ip;

        } else {
            # Generate a random domain name
            # 3-5 levels, end with net or com
            $_ = 2 + int rand 3;
            @_ = qw();
            push @_, random_word while @_ < $_;
            push @_, (qw(net com))[int rand 2];
            $host = join ".", @_;
            $resolved_host = $host;
        }
        $user = (0, 0, 1)[int rand 3]? "-": random_word;
        $http_ver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
        # 3-5 log entries foreach host
        $count = 3 + int rand 3;
        @host_logs = qw();
        while (@host_logs < $count) {
            my ($time, $method, $url, $dirs, @dirs, $type, $status, $size);
            my $record;
            # 0-2 seconds later
            $t += int rand 3;
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $time = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                @_[3,4,5,2,1,0],
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;

            $method = (qw(GET GET GET HEAD POST))[int rand 5];

            # Generate a random URL
            # 0-3 levels of directories
            $dirs = int rand 4;
            @dirs = qw();
            push @dirs, "/" . random_word while @dirs < $dirs;
            $type = ("", qw(html html txt css png jpg))[int rand 7];
            if ($type eq "") {
                $url = join("", @dirs) . "/";
            } else {
                $url = join("", @dirs) . "/" . random_word . ".$type";
            }

            $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
            if ($status == 304) {
                $size = 0;
            } else {
                $size = 200 + int rand 35000;
            }
            $record = sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $host, $user, $time, $method, $url, $http_ver, $status, $size;
            $resolved_logs{$record} = sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $resolved_host, $user, $time, $method, $url, $http_ver, $status, $size;
            push @host_logs, $record;
        }
        push @logs, @host_logs;
        # 0-5 seconds later
        $t += int rand 6;
    }

    # Insert 1-2 malformed lines
    $malformed = 1 + int rand 2;
    while ($malformed > 0) {
        my $line;
        # Generate the random malformed line
        $_ = 3 + int rand 5;
        @_ = qw();
        push @_, random_word while @_ < $_;
        $line = join(" ", @_) . ".\n";
        $line =~ s/^(.)/uc $1/e;
        # The position to insert the line
        $_ = int rand @logs;
        @logs = (@logs[0...$_], $line, @logs[$_+1...$#logs]);
        $malformed--;
    }

    # Compose the content
    $content = join "", @logs;
    $resolved_content = join "", map exists $resolved_logs{$_}? $resolved_logs{$_}: $_, @logs;
    # Output the file
    write_file($file, $content);
    # Return the content
    return ($content, $resolved_content);
}

# Create a random log file that are fully resolved.
sub make_resolved_log_file($) {
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
        my ($host, $user, $http_ver, @host_logs, $count);
        # Generate a random domain name
        # 3-5 levels, end with net or com
        $_ = 2 + int rand 3;
        @_ = qw();
        push @_, random_word while @_ < $_;
        push @_, (qw(net com))[int rand 2];
        $host = join ".", @_;
        $user = (0, 0, 1)[int rand 3]? "-": random_word;
        $http_ver = (qw(HTTP/1.1 HTTP/1.1 HTTP/1.1 HTTP/1.0))[int rand 4];
        # 3-5 log entries foreach host
        $count = 3 + int rand 3;
        @host_logs = qw();
        while (@host_logs < $count) {
            my ($time, $method, $url, $dirs, @dirs, $type, $status, $size);
            # 0-2 seconds later
            $t += int rand 3;
            # Time text
            @_ = gmtime($t + $tz);
            $_[5] += 1900;
            $_[4] = (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))[$_[4]];
            $time = sprintf "%02d/%s/%04d:%02d:%02d:%02d %+05d",
                @_[3,4,5,2,1,0],
                int($tz / 3600) * 100 + ($tz - int($tz / 3600) * 3600) / 60;

            $method = (qw(GET GET GET HEAD POST))[int rand 5];

            # Generate a random URL
            # 0-3 levels of directories
            $dirs = int rand 4;
            @dirs = qw();
            push @dirs, "/" . random_word while @dirs < $dirs;
            $type = ("", qw(html html txt css png jpg))[int rand 7];
            if ($type eq "") {
                $url = join("", @dirs) . "/";
            } else {
                $url = join("", @dirs) . "/" . random_word . ".$type";
            }

            $status = (200, 200, 200, 200, 304, 400, 403, 404)[int rand 8];
            if ($status == 304) {
                $size = 0;
            } else {
                $size = 200 + int rand 35000;
            }
            push @host_logs, sprintf "%s - %s [%s] \"%s %s %s\" %d %d\n",
                $host, $user, $time, $method, $url, $http_ver, $status, $size;
        }
        push @logs, @host_logs;
        # 0-5 seconds later
        $t += int rand 6;
    }

    # Insert 1-2 malformed lines
    $malformed = 1 + int rand 2;
    while ($malformed > 0) {
        my $line;
        # Generate the random malformed line
        $_ = 3 + int rand 5;
        @_ = qw();
        push @_, random_word while @_ < $_;
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
    write_file($file, $content);
    # Return the content
    return ($content, $content);
}

# Create an empty log file.
sub make_empty_log_file($) {
    local ($_, %_);
    $_ = $_[0];
    write_file($_, "");
    return ("", "");
}

# Supply a random English word
sub random_word() {
    local ($_, %_);
    @_ = qw(
hard-to-find striped poor scene miniature marble error shelter clear settle
march breath tested symptomatic delicate road punish grain fabulous camp
authority love system placid bake maddening sleep precious crabby lovely jolly
wrist park common volleyball tick judicious degree alluring hydrant oatmeal
aboard light spare delirious unwritten unnatural existence deadpan cagey
disastrous station fear dam adorable grape event silent extra-large shame meaty
husky drag religion extra-small pot valuable deceive obese seed history
wholesale tremble delightful leather cabbage death tub loss twig hate noxious
trashy sleet bleach quizzical familiar nappy teaching private yak turkey foolish
concentrate reject tacit goofy men ajar communicate);
    return $_[int rand @_];
}

# Supply a random IP
#   Big public web companies have more reliable reverse DNS
sub random_ip() {
    local ($_, %_);
    # Initialize our resolvable IP pool
    if (!defined $RANDOM_IP) {
        my (@ip, @hosts);
        $RANDOM_IP = {};
        @ip = qw();
        # Famous websites - they are resolved to several IPs, and their
        # reverse domain is guaranteed by the akadns.net service.
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
            $$RANDOM_IP{$ip} = $host;
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
            $$RANDOM_IP{$ip} = $host;
        }
    }
    # 1: Resolvable
    if (keys %$RANDOM_IP > 0 && int rand 2) {
        @_ = sort keys %$RANDOM_IP;
        $_ = $_[int rand @_];
        return ($_, $$RANDOM_IP{$_});
    }
    # 0: Unresolvable
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
