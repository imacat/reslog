#! /usr/bin/perl -w
# Test all the possible combination of options

# Copyright (c) 2005-2022 imacat.
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

# This file is combined from 01-plain.t, 02-gzip.t and 03-bzip2.t.

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 1788 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir devnull);
use FindBin;
use lib $FindBin::Bin;
use _helper;
our ($WORKDIR, $tno, $reslog);

$WORKDIR = catdir($FindBin::Bin, "logs");
$tno = 0;
$reslog = catfile($FindBin::Bin, updir, "blib", "script", "reslog");

# Test each source log file type
foreach my $st (@SOURCE_TYPES) {
    # Test each source file content type
    foreach my $sct (@CONTENT_TYPES) {
        # Test each keep mode
        foreach my $keep (@KEEP_MODES) {
            # Test each override mode
            foreach my $override (@OVERRIDE_MODES) {
                # Test each existing file content type
                my @ecnttypes;
                if (!$$override{"exists"}) {
                    # Existing file content type is meaningless
                    # if there is no existing file.
                    @ecnttypes = (1);
                } else {
                    # make_resolved_log_file() does not make a difference than
                    # make_log_file() as an existing file.
                    @ecnttypes = grep $$_{"title"} ne "resolved log file",
                        @CONTENT_TYPES;
                }
                foreach my $ect (@ecnttypes) {
                    # Test each suffix type
                    foreach my $suffix (@SUFFICES) {
                        # Test each trim-suffix type
                        foreach my $trim_suffix (@TRIM_SUFFIX) {
                            $_ = eval {
                                return if $$st{"skip"};
                                my ($title, $cmd, $ret_no, $out, $err, $logfile);
                                my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                                my ($fs, $fo, $cs, $csr, $co, $suf, $trim_suf);
                                rmtree $WORKDIR;
                                mkpath $WORKDIR;
                                $title = join ", ", $$st{"title"}, $$sct{"title"},
                                    $$keep{"title"}, $$override{"title"},
                                    $$suffix{"title"}, $$trim_suffix{"title"};
                                $logfile = random_word;
                                $suf = defined $$suffix{"suf"}? $$suffix{"suf"}: "." . random_word;
                                if (defined $$trim_suffix{"suf"}) {
                                    $trim_suf = $$trim_suffix{"suf"};
                                } else {
                                    do { $trim_suf = "." . random_word; } until $trim_suf ne $suf;
                                }
                                $fs = catfile($WORKDIR, "$logfile$trim_suf" . $$st{"suf"});
                                ($cs, $csr) = &{$$sct{"sub"}}($fs);
                                if ($$override{"exists"}) {
                                    $fo = catfile($WORKDIR, "$logfile$suf" . $$st{"suf"});
                                    $co = (&{$$ect{"sub"}}($fo))[0];
                                }
                                @fle = qw();
                                push @fle, basename($fs) if !($$override{"ok"} && $$keep{"del"});
                                if ($$override{"ok"}) {
                                    push @fle, "$logfile$suf"  . $$st{"suf"};
                                } else {
                                    push @fle, basename($fo) if !$$keep{"del"} || $$override{"exists"};
                                }
                                preserve_source $WORKDIR;
                                @_ = ($reslog, qw(-d -d -d -n 1), @{$$keep{"opts"}},
                                    @{$$override{"opts"}}, &{$$suffix{"opts"}}($suf),
                                    &{$$trim_suffix{"opts"}}($trim_suf), $fs);
                                $cmd = join " ", @_;
                                ($ret_no, $out, $err) = run_cmd "", @_;
                                ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
                                %cef = qw();    # Expected content by file
                                %tef = qw();    # Expected file type by file
                                %crf = qw();    # Resulted content by file
                                %trf = qw();    # Resulted file type by file
                                if (!($$override{"ok"} && $$keep{"del"})) {
                                    $fr = $fs;
                                    $frb = basename($fr);
                                    $cef{$frb} = $$keep{"keep"} || !$$override{"ok"}? $cs: "";
                                    $tef{$frb} = $$st{"type"};
                                    ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                                }
                                if ($$override{"ok"} || $$override{"exists"}) {
                                    $frb = "$logfile$suf" . $$st{"suf"};
                                    $fr = catfile($WORKDIR, $frb);
                                    $cef{$frb} = &{$$override{"ce"}}($co, $csr);
                                    $tef{$frb} = $$st{"type"};
                                    ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                                }
                                die "$title\n$cmd\n$out$err"
                                    unless $$override{"ok"}? $ret_no == 0: $ret_no != 0;
                                die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
                                    unless $flr eq $fle;
                                foreach $fr (@fle) {
                                    die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                                        unless has_no_file || $trf{$fr} eq $tef{$fr}
                                            || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
                                    die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                                        unless $crf{$fr} eq $cef{$fr};
                                }
                                1;
                            };
                            skip($$st{"skip"}, $_, 1, $@);
                            clean_up $_ || $$st{"skip"}, $WORKDIR, ++$tno;
                            die unless $_ || $$st{"skip"};
                        }
                    }
                }
            }

            # 37: From file to STDOUT
            $_ = eval {
                return if $$st{"skip"};
                my ($title, $cmd, $ret_no, $out, $err, $logfile, $result);
                my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                my ($fs, $cs, $csr);
                rmtree $WORKDIR;
                mkpath $WORKDIR;
                $title = join ", ", "From file to STDOUT", $$sct{"title"},
                    $$st{"title"}, $$keep{"title"};
                $logfile = random_word;
                do { $result = random_word; } until $result ne $logfile;
                $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
                ($cs, $csr) = &{$$sct{"sub"}}($fs);
                @fle = qw();
                push @fle, basename($fs) if !$$keep{"cdel"};
                push @fle, $result . $$st{"suf"};
                preserve_source $WORKDIR;
                @_ = ($reslog, qw(-d -d -d -n 1 -c), @{$$keep{"opts"}}, $fs);
                $cmd = join " ", @_;
                ($ret_no, $out, $err) = run_cmd "", @_;
                write_raw_file(catfile($WORKDIR, $result . $$st{"suf"}), $out);
                ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
                %cef = qw();    # Expected content by file
                %tef = qw();    # Expected file type by file
                %crf = qw();    # Resulted content by file
                %trf = qw();    # Resulted file type by file
                if (!$$keep{"cdel"}) {
                    $fr = $fs;
                    $frb = basename($fr);
                    $cef{$frb} = $$keep{"ckeep"}? $cs: "";
                    $tef{$frb} = $$st{"type"};
                    ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                }
                $frb = $result . $$st{"suf"};
                $fr = catfile($WORKDIR, $frb);
                ($cef{$frb}, $tef{$frb}) = ($csr, $$st{"type"});
                ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
                die "$title\n$cmd\n$out$err" unless $ret_no == 0;
                die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
                    unless $flr eq $fle;
                foreach $fr (@fle) {
                    die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                        unless has_no_file || $trf{$fr} eq $tef{$fr}
                            || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
                    die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                        unless $crf{$fr} eq $cef{$fr};
                }
                1;
            };
            skip($$st{"skip"}, $_, 1, $@);
            clean_up $_ || $$st{"skip"}, $WORKDIR, ++$tno;
            die unless $_ || $$st{"skip"};
        }

        # 149: From STDIN to STDOUT
        $_ = eval {
            return if $$st{"skip"};
            my ($title, $cmd, $ret_no, $out, $err, $logfile, $result);
            my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
            my ($fs, $cs, $csr);
            rmtree $WORKDIR;
            mkpath $WORKDIR;
            $title = join ", ", "From STDIN to STDOUT", $$sct{"title"},
                $$st{"title"};
            $logfile = random_word;
            do { $result = random_word; } until $result ne $logfile;
            $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
            ($cs, $csr) = &{$$sct{"sub"}}($fs);
            @fle = qw();
            push @fle, basename($fs);
            push @fle, $result . $$st{"suf"};
            preserve_source $WORKDIR;
            @_ = ($reslog, qw(-d -d -d -n 1));
            $cmd = join(" ", @_) . " < $fs";
            ($ret_no, $out, $err) = run_cmd read_raw_file $fs, @_;
            write_raw_file(catfile($WORKDIR, $result . $$st{"suf"}), $out);
            ($fle, $flr) = (join(" ", sort @fle), list_files $WORKDIR);
            %cef = qw();    # Expected content by file
            %tef = qw();    # Expected file type by file
            %crf = qw();    # Resulted content by file
            %trf = qw();    # Resulted file type by file
            $fr = $fs;
            $frb = basename($fr);
            $cef{$frb} = $cs;
            $tef{$frb} = $$st{"type"};
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
            $frb = $result . $$st{"suf"};
            $fr = catfile($WORKDIR, $frb);
            ($cef{$frb}, $tef{$frb}) = ($csr, $$st{"type"});
            ($crf{$frb}, $trf{$frb}) = (read_file $fr, file_type $fr);
            die "$title\n$cmd\n$out$err" unless $ret_no == 0;
            die "$title\n$cmd\nresult files incorrect.\nGot: $flr\nExpected: $fle\nOutput:\n$out$err"
                unless $flr eq $fle;
            foreach $fr (@fle) {
                die "$title\n$cmd\n$fr: result type incorrect.\nGot: $trf{$fr}\nExpected: $tef{$fr}\nOutput:\n$out$err"
                    unless has_no_file || $trf{$fr} eq $tef{$fr}
                        || ($tef{$fr} eq TYPE_BZIP2 && -z catfile($WORKDIR, $fr));
                die "$title\n$cmd\n$fr: result incorrect.\nGot:\n$crf{$fr}\nExpected:\n$cef{$fr}\nOutput:\n$out$err"
                    unless $crf{$fr} eq $cef{$fr};
            }
            1;
        };
        skip($$st{"skip"}, $_, 1, $@);
        clean_up $_ || $$st{"skip"}, $WORKDIR, ++$tno;
        die unless $_ || $$st{"skip"};
    }
}
