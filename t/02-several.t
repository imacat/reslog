#! /usr/bin/perl -w
# Test processing several log files at once

# Copyright (c) 2007 imacat
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

# This file replaces 04-hybrix.t.

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 4 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir);
use FindBin;
use lib $FindBin::Bin;
use _helper;
use vars qw($WORKDIR $tno $reslog);

$WORKDIR = catdir($FindBin::Bin, "logs");
$tno = 0;
$reslog = catfile($FindBin::Bin, updir, "blib", "script", "reslog");

# 1: Source log files listed as the arguments
$_ = eval {
    my ($title, $cmd, $retno, $out, $err, %logfiles);
    my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
    my ($num, @fs, @fo, @cs, @csr, @co, @st, $suf, $tsuf);
    rmtree $WORKDIR;
    mkpath $WORKDIR;
    $title = join ", ", "several log files", "all listed as arguments";
    $suf = "." . randword;
    do { $tsuf = "." . randword; } until $tsuf ne $suf;
    # (2-4 times available compression) log files
    $_ = 2 + (nogzip? 0: 2) + (nobzip2? 0: 2);
    $num = $_ + int rand $_;
    %_ = qw();
    # At least 2 files for each available compression
    foreach my $st (@SRCTYPES) {
        next if ($$st{"type"} eq TYPE_GZIP && nogzip)
                || ($$st{"type"} eq TYPE_BZIP2 && nobzip2);
        @_ = grep !exists $_{$_}, (0...$num-1);
        $_{$_[int rand @_]} = $st;
        @_ = grep !exists $_{$_}, (0...$num-1);
        $_{$_[int rand @_]} = $st;
    }
    # Set random compression on the rest files
    foreach (grep !exists $_{$_}, (0...$num-1)) {
        do {
            $_{$_} = $SRCTYPES[int rand @SRCTYPES];
        } until !(${$_{$_}}{"type"} eq TYPE_GZIP && nogzip)
                && !(${$_{$_}}{"type"} eq TYPE_BZIP2 && nobzip2);
    }
    @st = map $_{$_}, (0...$num-1);
    @fs = qw();
    @fo = qw();
    @cs = qw();
    @csr = qw();
    @co = qw();
    @fle = qw();
    %logfiles = qw();
    for (my $k = 0; $k < $num; $k++) {
        my ($logfile, $cs, $csr, $co);
        do { $logfile = randword } until !exists $logfiles{$logfile};
        $logfiles{$logfile} = 1;
        push @fs, catfile($WORKDIR, "$logfile$tsuf" . ${$st[$k]}{"suf"});
        push @fo, catfile($WORKDIR, "$logfile$suf" . ${$st[$k]}{"suf"});
        ($cs, $csr) = mkrndlog_normal $fs[$k];
        push @cs, $cs;
        push @csr, $csr;
        push @fle, basename($fo[$k]);
        # 1: create existing file, 0: no existing file
        if (int rand 1) {
            $co = (mkrndlog_normal $fo[$k])[0];
            push @co, $co;
        } else {
            push @co, "";
        }
    }
    prsrvsrc $WORKDIR;
    @_ = ($reslog, qw(-d -d -d -o a), "-s", $suf, "-t", $tsuf, @fs);
    $cmd = join(" ", @_);
    ($retno, $out, $err) = runcmd "", @_;
    ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
    %cef = qw();    # Expected content by file
    %tef = qw();    # Expected file type by file
    %crf = qw();    # Resulted content by file
    %trf = qw();    # Resulted file type by file
    for (my $k = 0; $k < $num; $k++) {
        $fr = $fo[$k];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($co[$k] . $csr[$k], ${$st[$k]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
    }
    die "$title\n$cmd\n$out$err" unless $retno == 0;
    die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
        unless $flr eq $fle;
    foreach $fr (@fle) {
        die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
            unless nofile || $trf{$fr} eq $tef{$fr};
        die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
            unless $crf{$fr} eq $cef{$fr};
    }
    1;
};
ok($_, 1, $@);
cleanup $_, $WORKDIR, ++$tno;

# 2-4: One of the source log files is read from STDIN
# The file type at STDIN
foreach my $ststdin (@SRCTYPES) {
    my $skip;
    $skip = 0;
    $_ = eval {
        if (    ($$ststdin{"type"} eq TYPE_GZIP && nogzip)
                || ($$ststdin{"type"} eq TYPE_BZIP2 && nobzip2)) {
            $skip = 1;
            return;
        }
        my ($title, $cmd, $retno, $out, $err, %logfiles);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($num, @fs, @fo, @cs, @csr, @co, @st, $suf, $tsuf, $stdin);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $title = join ", ", "several log files", "one read from STDIN",
            "STDIN " . $$ststdin{"title"};
        $suf = "." . randword;
        do { $tsuf = "." . randword; } until $tsuf ne $suf;
        # (2-4 times available compression) log files
        $_ = 2 + (nogzip? 0: 2) + (nobzip2? 0: 2);
        $num = $_ + int rand $_;
        %_ = qw();
        # At least 2 files for each available compression
        foreach my $st (@SRCTYPES) {
            next if ($$st{"type"} eq TYPE_GZIP && nogzip)
                    || ($$st{"type"} eq TYPE_BZIP2 && nobzip2);
            @_ = grep !exists $_{$_}, (0...$num-1);
            $_{$_[int rand @_]} = $st;
            @_ = grep !exists $_{$_}, (0...$num-1);
            $_{$_[int rand @_]} = $st;
        }
        # Set random compression on the rest files
        foreach (grep !exists $_{$_}, (0...$num-1)) {
            do {
                $_{$_} = $SRCTYPES[int rand @SRCTYPES];
            } until !(${$_{$_}}{"type"} eq TYPE_GZIP && nogzip)
                    && !(${$_{$_}}{"type"} eq TYPE_BZIP2 && nobzip2);
        }
        # Choose the STDIN from the matching compression
        @_ = grep ${$_{$_}}{"type"} eq $$ststdin{"type"}, (0...$num-1);
        $stdin = $_[int rand @_];
        @st = map $_{$_}, (0...$num-1);
        @fs = qw();
        @fo = qw();
        @cs = qw();
        @csr = qw();
        @co = qw();
        @fle = qw();
        %logfiles = qw();
        for (my $k = 0; $k < $num; $k++) {
            my ($logfile, $cs, $csr, $co);
            do { $logfile = randword } until !exists $logfiles{$logfile};
            $logfiles{$logfile} = 1;
            push @fs, catfile($WORKDIR, "$logfile$tsuf" . ${$st[$k]}{"suf"});
            if ($k == $stdin) {
                do { $_ = randword } until !exists $logfiles{$_};
                $logfiles{$_} = 1;
                push @fo, catfile($WORKDIR, "$_" . ${$st[$k]}{"suf"});
            } else {
                push @fo, catfile($WORKDIR, "$logfile$suf" . ${$st[$k]}{"suf"});
            }
            ($cs, $csr) = mkrndlog_normal $fs[$k];
            push @cs, $cs;
            push @csr, $csr;
            push @fle, basename($fs[$k]) if $k == $stdin;
            push @fle, basename($fo[$k]);
            # 1: create existing file, 0: no existing file
            if ($k != $stdin && int rand 1) {
                $co = (mkrndlog_normal $fo[$k])[0];
                push @co, $co;
            } else {
                push @co, "";
            }
        }
        prsrvsrc $WORKDIR;
        @_ = @fs;
        $_[$stdin] = "-";
        @_ = ($reslog, qw(-d -d -d -o a), "-s", $suf, "-t", $tsuf, @_);
        $cmd = join(" ", @_) . " < " . $fs[$stdin];
        ($retno, $out, $err) = runcmd frread $fs[$stdin], @_;
        frwrite($fo[$stdin], $out);
        ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        $fr = $fs[$stdin];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs[$stdin], ${$st[$stdin]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        for (my $k = 0; $k < $num; $k++) {
            $fr = $fo[$k];
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($co[$k] . $csr[$k], ${$st[$k]}{"type"});
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        }
        die "$title\n$cmd\n$out$err" unless $retno == 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless nofile || $trf{$fr} eq $tef{$fr};
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    skip($skip, $_, 1, $@);
    cleanup $_ || $skip, $WORKDIR, ++$tno;
    die if !$_ && !$skip;
}
