#! /usr/bin/perl -w
# Makefile.PL: Installation configuration for ExtUtils::MakeMaker
use 5.008;
use strict;
use warnings;
use Config qw(%Config);
use ExtUtils::MakeMaker;

# Check if there is any old file
our (%old_version);
%old_version = qw();
foreach (qw(/usr/sbin/reslog.pl
            /usr/sbin/reslog
            /usr/share/man/man8/reslog.pl.8
            /usr/share/man/man8/reslog.8
            /usr/local/sbin/reslog.pl
            /usr/local/sbin/reslog
            /usr/local/share/man/man8/reslog.pl.8
            /usr/local/share/man/man8/reslog.8)) {
    $old_version{$_} = 1 if -e $_;
}
foreach my $cnf (qw(installman1dir installsiteman1dir installvendorman1dir
                    man1dir man1direxp siteman1dir siteman1direxp sysman
                    vendorman1dir vendorman1direxp)) {
    next unless defined $Config{$cnf} && -d $Config{$cnf};
    $_ = $Config{$cnf};
    s/\/man1$/\/man8/;
    $old_version{"$_/reslog.8"} = 1 if -e "$_/reslog.8";
    $old_version{"$_/reslog.pl.8"} = 1 if -e "$_/reslog.pl.8";
}
foreach my $cnf (qw(installscript installsitescript installvendorscript
                    scriptdir scriptdirexp sitescript sitescriptexp
                    vendorscript vendorscriptexp
                    bin binexp installbin installsitebin installvendorbin
                    sitebin sitebinexp vendorbin vendorbinexp)) {
    next unless defined $Config{$cnf} && -d $Config{$cnf};
    $_ = $Config{$cnf};
    s/\/bin$/\/sbin/;
    $old_version{"$_/reslog"} = 1 if -e "$_/reslog";
    $old_version{"$_/reslog.pl"} = 1 if -e "$_/reslog.pl";
}
if (keys %old_version > 0) {
    $_ = join " ", sort keys %old_version;
    warn << "EOT";
-- Old Files Found
You may remove the following old files after "make install":
  $_
EOT
}

# Optional prerequisite modules
our (%OPT_PREREQ);
%OPT_PREREQ = (
    "File::MMagic"	=> 0,
    "Compress::Zlib"	=> 0,
    "Compress::Bzip2"	=> 2,
    "IO::Compress::Xz"	=> 0,
    "Term::ReadKey"	=> 0,
);
delete $OPT_PREREQ{$_}
    foreach grep eval "use $_ $OPT_PREREQ{$_} qw(); 1;", sort keys %OPT_PREREQ;
if (keys %OPT_PREREQ > 0) {
    $_ = join " ", sort keys %OPT_PREREQ;
    warn << "EOT";
-- Optional Prerequisites
You may wish to install these modules altogether.
  $_
EOT
}

WriteMakefile(
    NAME		=> "reslog",
    VERSION_FROM	=> "reslog",
    ABSTRACT		=> "Reverse-resolve IP in Apache log files",
    AUTHOR		=> "imacat <imacat\@mail.imacat.idv.tw>",
    LICENSE		=> "apache_2_0",
    PREREQ_PM		=> { },
    SIGN		=> 1,
    
    EXE_FILES		=> [ "reslog" ],
    dist		=> {
        COMPRESS	=> "gzip -9",
        SUFFIX		=> ".gz",
    },
    clean		=> {
        FILES		=> "t/logs*",
    },
);

__END__
