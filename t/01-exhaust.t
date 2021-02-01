#! /usr/bin/perl -w
# Test all the possible combination of options

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

# This file is combined from 01-plain.t, 02-gzip.t and 03-bzip2.t.

use 5.005;
use strict;
use warnings;
use diagnostics;
use Test;

BEGIN { plan tests => 1341 }

use File::Basename qw(basename);
use File::Path qw(mkpath rmtree);
use File::Spec::Functions qw(catdir catfile updir devnull);
use FindBin;
use lib $FindBin::Bin;
use _helper;
use vars qw($WORKDIR $tno $reslog);

$WORKDIR = catdir($FindBin::Bin, "logs");
$tno = 0;
$reslog = catfile($FindBin::Bin, updir, "blib", "script", "reslog");

# Test each source log file type
foreach my $st (@SRCTYPES) {
    # Test each source file content type
    foreach my $sct (@CNTTYPES) {
        # Test each keep type
        foreach my $kt (@KEEPTYPES) {
            # Test each override type
            foreach my $ot (@OVERTYPES) {
                # Test each existing file content type
                my @ecnttypes;
                if (!$$ot{"mkex"}) {
                    # Existing file content type is meaningless
                    # if there is no existing file.
                    @ecnttypes = (1);
                } else {
                    # mkrndlog_noip() does not make a difference than
                    # mkrndlog_normal() as an existing file.
                    @ecnttypes = grep $$_{"title"} ne "log file without IP",
                        @CNTTYPES;
                }
                foreach my $ect (@ecnttypes) {
                    # Test each suffix type
                    foreach my $suft (@SUFTYPES) {
                        # Test each trim-suffix type
                        foreach my $tsuft (@TSUFTYPES) {
                            $_ = eval {
                                return if $$st{"skip"};
                                my ($title, $cmd, $retno, $out, $err, $logfile);
                                my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                                my ($fs, $fo, $cs, $csr, $co, $suf, $tsuf);
                                rmtree $WORKDIR;
                                mkpath $WORKDIR;
                                $title = join ", ", $$st{"title"}, $$sct{"title"},
                                    $$kt{"title"}, $$ot{"title"},
                                    $$suft{"title"}, $$tsuft{"title"};
                                $logfile = randword;
                                $suf = defined $$suft{"suf"}? $$suft{"suf"}: "." . randword;
                                if (defined $$tsuft{"suf"}) {
                                    $tsuf = $$tsuft{"suf"};
                                } else {
                                    do { $tsuf = "." . randword; } until $tsuf ne $suf;
                                }
                                $fs = catfile($WORKDIR, "$logfile$tsuf" . $$st{"suf"});
                                ($cs, $csr) = &{$$sct{"sub"}}($fs);
                                if ($$ot{"mkex"}) {
                                    $fo = catfile($WORKDIR, "$logfile$suf" . $$st{"suf"});
                                    $co = (&{$$ect{"sub"}}($fo))[0];
                                }
                                @fle = qw();
                                push @fle, basename($fs) if !($$ot{"ok"} && $$kt{"del"});
                                if ($$ot{"ok"}) {
                                    push @fle, "$logfile$suf"  . $$st{"suf"};
                                } else {
                                    push @fle, basename($fo) if !$$kt{"del"} || $$ot{"mkex"};
                                }
                                prsrvsrc $WORKDIR;
                                @_ = ($reslog, qw(-d -d -d -n 1), @{$$kt{"opts"}},
                                    @{$$ot{"opts"}}, &{$$suft{"opts"}}($suf),
                                    &{$$tsuft{"opts"}}($tsuf), $fs);
                                $cmd = join " ", @_;
                                ($retno, $out, $err) = runcmd "", @_;
                                ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
                                %cef = qw();    # Expected content by file
                                %tef = qw();    # Expected file type by file
                                %crf = qw();    # Resulted content by file
                                %trf = qw();    # Resulted file type by file
                                if (!($$ot{"ok"} && $$kt{"del"})) {
                                    $fr = $fs;
                                    $frb = basename($fr);
                                    $cef{$frb} = $$kt{"keep"} || !$$ot{"ok"}? $cs: "";
                                    $tef{$frb} = $$st{"type"};
                                    ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                                }
                                if ($$ot{"ok"} || $$ot{"mkex"}) {
                                    $frb = "$logfile$suf" . $$st{"suf"};
                                    $fr = catfile($WORKDIR, $frb);
                                    $cef{$frb} = &{$$ot{"ce"}}($co, $csr);
                                    $tef{$frb} = $$st{"type"};
                                    ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                                }
                                die "$title\n$cmd\n$out$err"
                                    unless $$ot{"ok"}? $retno == 0: $retno != 0;
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
                            die unless $_ || $$st{"skip"};
                        }
                    }
                }
            }
            
            # 37: From file to STDOUT
            $_ = eval {
                return if $$st{"skip"};
                my ($title, $cmd, $retno, $out, $err, $logfile, $result);
                my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
                my ($fs, $fo, $cs, $csr, $co);
                rmtree $WORKDIR;
                mkpath $WORKDIR;
                $title = join ", ", "From file to STDOUT", $$sct{"title"},
                    $$st{"title"}, $$kt{"title"};
                $logfile = randword;
                do { $result = randword; } until $result ne $logfile;
                $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
                ($cs, $csr) = &{$$sct{"sub"}}($fs);
                @fle = qw();
                push @fle, basename($fs) if !$$kt{"cdel"};
                push @fle, $result . $$st{"suf"};
                prsrvsrc $WORKDIR;
                @_ = ($reslog, qw(-d -d -d -n 1 -c), @{$$kt{"opts"}}, $fs);
                $cmd = join " ", @_;
                ($retno, $out, $err) = runcmd "", @_;
                frwrite(catfile($WORKDIR, $result . $$st{"suf"}), $out);
                ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
                %cef = qw();    # Expected content by file
                %tef = qw();    # Expected file type by file
                %crf = qw();    # Resulted content by file
                %trf = qw();    # Resulted file type by file
                if (!$$kt{"cdel"}) {
                    $fr = $fs;
                    $frb = basename($fr);
                    $cef{$frb} = $$kt{"ckeep"}? $cs: "";
                    $tef{$frb} = $$st{"type"};
                    ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                }
                $frb = $result . $$st{"suf"};
                $fr = catfile($WORKDIR, $frb);
                ($cef{$frb}, $tef{$frb}) = ($csr, $$st{"type"});
                ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
                die "$title\n$cmd\n$out$err" unless $retno == 0;
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
            die unless $_ || $$st{"skip"};
        }
        
        # 85: From STDIN to STDOUT
        $_ = eval {
            return if $$st{"skip"};
            my ($title, $cmd, $retno, $out, $err, $logfile, $result);
            my ($fr, $frb, @fle, $fle, $flr, %cef, %crf, %tef, %trf);
            my ($fs, $fo, $cs, $csr, $co);
            rmtree $WORKDIR;
            mkpath $WORKDIR;
            $title = join ", ", "From STDIN to STDOUT", $$sct{"title"},
                $$st{"title"};
            $logfile = randword;
            do { $result = randword; } until $result ne $logfile;
            $fs = catfile($WORKDIR, "$logfile" . $$st{"suf"});
            ($cs, $csr) = &{$$sct{"sub"}}($fs);
            @fle = qw();
            push @fle, basename($fs);
            push @fle, $result . $$st{"suf"};
            prsrvsrc $WORKDIR;
            @_ = ($reslog, qw(-d -d -d -n 1));
            $cmd = join(" ", @_) . " < $fs";
            ($retno, $out, $err) = runcmd frread $fs, @_;
            frwrite(catfile($WORKDIR, $result . $$st{"suf"}), $out);
            ($fle, $flr) = (join(" ", sort @fle), flist $WORKDIR);
            %cef = qw();    # Expected content by file
            %tef = qw();    # Expected file type by file
            %crf = qw();    # Resulted content by file
            %trf = qw();    # Resulted file type by file
            $fr = $fs;
            $frb = basename($fr);
            $cef{$frb} = $cs;
            $tef{$frb} = $$st{"type"};
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
            $frb = $result . $$st{"suf"};
            $fr = catfile($WORKDIR, $frb);
            ($cef{$frb}, $tef{$frb}) = ($csr, $$st{"type"});
            ($crf{$frb}, $trf{$frb}) = (fread $fr, ftype $fr);
            die "$title\n$cmd\n$out$err" unless $retno == 0;
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
        die unless $_ || $$st{"skip"};
    }
}
