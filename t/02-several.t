#! /usr/bin/perl -w
# Test processing several log files at once

# Copyright (c) 2007-2022 imacat.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file replaces 04-hybrix.t.

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 5 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir);
use FindBin;
use lib $FindBin::Bin;
use _helper;
our ($WORKDIR, $tno, $reslog);

$WORKDIR = catdir($FindBin::Bin, "logs");
$tno = 0;
$reslog = catfile($FindBin::Bin, updir, "blib", "script", "reslog");

# 1: Source log files listed as the arguments
$_ = eval {
    my ($title, $cmd, $ret_no, $out, $err, %logfiles);
    my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
    my ($num, @fs, @fo, @cs, @csr, @co, @st, $suf, $trim_suf);
    rmtree $WORKDIR;
    mkpath $WORKDIR;
    $title = join ", ", "several log files", "all listed as arguments";
    $suf = "." . random_word;
    do { $trim_suf = "." . random_word; } until $trim_suf ne $suf;
    # (2-4 times available compression) log files
    $_ = 2 + (has_no_gzip? 0: 2) + (has_no_bzip2? 0: 2)
        + (has_no_xz? 0: 2);
    $num = $_ + int rand $_;
    my %types = qw();
    # At least 2 files for each available compression
    foreach my $st (@SOURCE_TYPES) {
        next if ($$st{"type"} eq TYPE_GZIP && has_no_gzip)
                || ($$st{"type"} eq TYPE_BZIP2 && has_no_bzip2)
                || ($$st{"type"} eq TYPE_XZ && has_no_xz);
        @_ = grep !exists $types{$_}, (0...$num-1);
        $types{$_[int rand @_]} = $st;
        @_ = grep !exists $types{$_}, (0...$num-1);
        $types{$_[int rand @_]} = $st;
    }
    # Set random compression on the rest files
    foreach (grep !exists $types{$_}, (0...$num-1)) {
        do {
            $types{$_} = $SOURCE_TYPES[int rand @SOURCE_TYPES];
        } until !(${$types{$_}}{"type"} eq TYPE_GZIP && has_no_gzip)
                && !(${$types{$_}}{"type"} eq TYPE_BZIP2 && has_no_bzip2)
                && !(${$types{$_}}{"type"} eq TYPE_XZ && has_no_xz);
    }
    @st = map $types{$_}, (0...$num-1);
    @fs = qw();
    @fo = qw();
    @cs = qw();
    @csr = qw();
    @co = qw();
    @fle = qw();
    %logfiles = qw();
    for (my $k = 0; $k < $num; $k++) {
        my ($logfile, $cs, $csr, $co);
        do { $logfile = random_word } until !exists $logfiles{$logfile};
        $logfiles{$logfile} = 1;
        push @fs, catfile($WORKDIR, "$logfile$trim_suf" . ${$st[$k]}{"suf"});
        push @fo, catfile($WORKDIR, "$logfile$suf" . ${$st[$k]}{"suf"});
        ($cs, $csr) = make_log_file $fs[$k];
        push @cs, $cs;
        push @csr, $csr;
        push @fle, basename($fo[$k]);
        # 1: create existing file, 0: no existing file
        if (int rand 1) {
            $co = (make_log_file $fo[$k])[0];
            push @co, $co;
        } else {
            push @co, "";
        }
    }
    preserve_source $WORKDIR;
    @_ = ($reslog, qw(-d -d -d -o a), "-s", $suf, "-t", $trim_suf, @fs);
    $cmd = join(" ", @_);
    ($ret_no, $out, $err) = run_cmd "", @_;
    ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
    %cef = qw();    # Expected content by file
    %tef = qw();    # Expected file type by file
    %crf = qw();    # Resulted content by file
    %trf = qw();    # Resulted file type by file
    for (my $k = 0; $k < $num; $k++) {
        $fr = $fo[$k];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($co[$k] . $csr[$k], ${$st[$k]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
    }
    die "$title\n$cmd\n$out$err" unless $ret_no == 0;
    die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
        unless $flr eq $fle;
    foreach $fr (@fle) {
        die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
            unless has_no_file || $trf{$fr} eq $tef{$fr};
        die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
            unless $crf{$fr} eq $cef{$fr};
    }
    1;
};
ok($_, 1, $@);
clean_up $_, $WORKDIR, ++$tno;

# 2-5: One of the source log files is read from STDIN
# The file type at STDIN
foreach my $st_stdin (@SOURCE_TYPES) {
    my $skip;
    $skip = 0;
    $_ = eval {
        if (    ($$st_stdin{"type"} eq TYPE_GZIP && has_no_gzip)
                || ($$st_stdin{"type"} eq TYPE_BZIP2 && has_no_bzip2)
                || ($$st_stdin{"type"} eq TYPE_XZ && has_no_xz)) {
            $skip = 1;
            return;
        }
        my ($title, $cmd, $ret_no, $out, $err, %logfiles);
        my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
        my ($num, @fs, @fo, @cs, @csr, @co, @st, $suf, $trim_suf, $stdin);
        rmtree $WORKDIR;
        mkpath $WORKDIR;
        $title = join ", ", "several log files", "one read from STDIN",
            "STDIN " . $$st_stdin{"title"};
        $suf = "." . random_word;
        do { $trim_suf = "." . random_word; } until $trim_suf ne $suf;
        # (2-4 times available compression) log files
        $_ = 2 + (has_no_gzip? 0: 2) + (has_no_bzip2? 0: 2)
            + (has_no_xz? 0: 2);
        $num = $_ + int rand $_;
        my %types = qw();
        # At least 2 files for each available compression
        foreach my $st (@SOURCE_TYPES) {
            next if ($$st{"type"} eq TYPE_GZIP && has_no_gzip)
                    || ($$st{"type"} eq TYPE_BZIP2 && has_no_bzip2)
                    || ($$st{"type"} eq TYPE_XZ && has_no_xz);
            @_ = grep !exists $types{$_}, (0...$num-1);
            $types{$_[int rand @_]} = $st;
            @_ = grep !exists $types{$_}, (0...$num-1);
            $types{$_[int rand @_]} = $st;
        }
        # Set random compression on the rest files
        foreach (grep !exists $types{$_}, (0...$num-1)) {
            do {
                $types{$_} = $SOURCE_TYPES[int rand @SOURCE_TYPES];
            } until !(${$types{$_}}{"type"} eq TYPE_GZIP && has_no_gzip)
                    && !(${$types{$_}}{"type"} eq TYPE_BZIP2 && has_no_bzip2)
                    && !(${$types{$_}}{"type"} eq TYPE_XZ && has_no_xz);
        }
        # Choose the STDIN from the matching compression
        @_ = grep ${$types{$_}}{"type"} eq $$st_stdin{"type"}, (0...$num-1);
        $stdin = $_[int rand @_];
        @st = map $types{$_}, (0...$num-1);
        @fs = qw();
        @fo = qw();
        @cs = qw();
        @csr = qw();
        @co = qw();
        @fle = qw();
        %logfiles = qw();
        for (my $k = 0; $k < $num; $k++) {
            my ($logfile, $cs, $csr, $co);
            do { $logfile = random_word } until !exists $logfiles{$logfile};
            $logfiles{$logfile} = 1;
            push @fs, catfile($WORKDIR, "$logfile$trim_suf" . ${$st[$k]}{"suf"});
            if ($k == $stdin) {
                do { $_ = random_word } until !exists $logfiles{$_};
                $logfiles{$_} = 1;
                push @fo, catfile($WORKDIR, "$_" . ${$st[$k]}{"suf"});
            } else {
                push @fo, catfile($WORKDIR, "$logfile$suf" . ${$st[$k]}{"suf"});
            }
            ($cs, $csr) = make_log_file $fs[$k];
            push @cs, $cs;
            push @csr, $csr;
            push @fle, basename($fs[$k]) if $k == $stdin;
            push @fle, basename($fo[$k]);
            # 1: create existing file, 0: no existing file
            if ($k != $stdin && int rand 1) {
                $co = (make_log_file $fo[$k])[0];
                push @co, $co;
            } else {
                push @co, "";
            }
        }
        preserve_source $WORKDIR;
        @_ = @fs;
        $_[$stdin] = "-";
        @_ = ($reslog, qw(-d -d -d -o a), "-s", $suf, "-t", $trim_suf, @_);
        $cmd = join(" ", @_) . " < " . $fs[$stdin];
        ($ret_no, $out, $err) = run_cmd read_raw_file $fs[$stdin], @_;
        write_raw_file($fo[$stdin], $out);
        ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
        %cef = qw();    # Expected content by file
        %tef = qw();    # Expected file type by file
        %crf = qw();    # Resulted content by file
        %trf = qw();    # Resulted file type by file
        $fr = $fs[$stdin];
        $frb = basename($fr);
        ($cef{$frb}, $tef{$frb}) = ($cs[$stdin], ${$st[$stdin]}{"type"});
        ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
        for (my $k = 0; $k < $num; $k++) {
            $fr = $fo[$k];
            $frb = basename($fr);
            ($cef{$frb}, $tef{$frb}) = ($co[$k] . $csr[$k], ${$st[$k]}{"type"});
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
        }
        die "$title\n$cmd\n$out$err" unless $ret_no == 0;
        die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
            unless $flr eq $fle;
        foreach $fr (@fle) {
            die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                unless has_no_file || $trf{$fr} eq $tef{$fr};
            die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                unless $crf{$fr} eq $cef{$fr};
        }
        1;
    };
    skip($skip, $_, 1, $@);
    clean_up $_ || $skip, $WORKDIR, ++$tno;
    die if !$_ && !$skip;
}
