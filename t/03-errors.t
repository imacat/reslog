#! /usr/bin/perl -w
# Test the errors that should be captured.

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

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 7 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir);
use FindBin;
use lib $FindBin::Bin;
use _helper;
use vars qw($WORKDIR $reslog $tno);

$WORKDIR = catdir($FindBin::Bin, "logs");
$reslog = catfile($FindBin::Bin, updir, "blib", "script", "reslog");
$tno = 0;

# 1-6: Trim suffix is the same as suffix
foreach my $st (@SRCTYPES) {
    # 1: Trim suffix is the same as suffix
    $_ = eval {
        return if $$st{"skip"};
        my ($title, $cmd, $retno, $out, $err, $logfile);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($fs, $fo, $cs, $csr, $co, $suf);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $title = join ", ", "Trim suffix is the same as suffix",
            $$st{"title"};
        $logfile = randword;
        $suf = "." . randword;
        $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
        ($cs, $csr) = mkrndlog_normal $fs;
        @fle = qw();
        push @fle, basename($fs);
        prsrvsrc $WORKDIR;
        @_ = ($reslog, qw(-d -d -d -n 1), "-s", $suf, "-t", $suf, $fs);
        $cmd = join " ", @_;
        ($retno, $out, $err) = runcmd "", @_;
        ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        $fr = $fs;
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs, $$st{"type"});
        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        die "$title\n$cmd\n$out$err" unless $retno != 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless nofile || $trf{$fr} eq $tef{$fr}
                    || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    skip($$st{"skip"}, $_, 1, $@);
    cleanup $_ || $$st{"skip"}, $WORKDIR, ++$tno;
    
    # 2: Default suffix and trim suffix is set to .resolved
    $_ = eval {
        return if $$st{"skip"};
        my ($title, $cmd, $retno, $out, $err, $logfile);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($fs, $fo, $cs, $csr, $co, $suf);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $title = join ", ", "Default suffix and trim suffix is set to .resolved",
            $$st{"title"};
        $logfile = randword;
        $suf = ".resolved";
        $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
        ($cs, $csr) = mkrndlog_normal $fs;
        @fle = qw();
        push @fle, basename($fs);
        prsrvsrc $WORKDIR;
        @_ = ($reslog, qw(-d -d -d -n 1), "-t", $suf, $fs);
        $cmd = join " ", @_;
        ($retno, $out, $err) = runcmd "", @_;
        ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        $fr = $fs;
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs, $$st{"type"});
        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        die "$title\n$cmd\n$out$err" unless $retno != 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless nofile || $trf{$fr} eq $tef{$fr}
                    || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    skip($$st{"skip"}, $_, 1, $@);
    cleanup $_ || $$st{"skip"}, $WORKDIR, ++$tno;
}

# 7: A same log file is specified more than once
$_ = eval {
    my ($title, $cmd, $retno, $out, $err, %logfiles);
    my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
    my ($num, @fs, @fo, @cs, @csr, @co, @st, $suf, $tsuf, $dup);
    rmtree $WORKDIR;
    mkpath $WORKDIR;
    $title = "A same log file is specified more than once";
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
        push @fle, basename($fs[$k]);
        # 1: create existing file, 0: no existing file
        if (int rand 1) {
            $co = (mkrndlog_normal $fo[$k])[0];
            push @co, $co;
            push @fle, basename($fo[$k]);
        } else {
            push @co, "";
        }
    }
    prsrvsrc $WORKDIR;
    $dup = $fs[int rand @fs];
    $_ = int rand(@fs + 1);
    @_ = (@fs[0...$_-1], $dup, @fs[$_...$#fs]);
    @_ = ($reslog, qw(-d -d -d -o a), "-s", $suf, "-t", $tsuf, @_);
    $cmd = join(" ", @_);
    ($retno, $out, $err) = runcmd "", @_;
    ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
    %cef = qw();    # Expected content by file
    %tef = qw();    # Expected file type by file
    %crf = qw();    # Resulted content by file
    %trf = qw();    # Resulted file type by file
    for (my $k = 0; $k < $num; $k++) {
        $fr = $fs[$k];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs[$k], ${$st[$k]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        if ($co[$k] ne "") {
            $fr = $fo[$k];
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($co[$k], ${$st[$k]}{"type"});
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
        }
    }
    die "$title\n$cmd\n$out$err" unless $retno != 0;
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
