#! /usr/bin/perl -w
# Build.PL: Installation configuration for Module::Build
use strict;
use warnings;
use Config qw(%Config);
use Module::Build;

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

my $build = Module::Build->new(
    dist_name		=> "reslog",
    dist_version_from	=> "reslog",
    dist_abstract	=> "Reverse-resolve IP in Apache log files",
    dist_author		=> "imacat <imacat\@mail.imacat.idv.tw>",
    license		=> "apache_2_0",
    sign		=> 1,
    
    script_files	=> [ "reslog" ],
    requires		=> {
        "perl"			=> "5.8.0",
    },
    recommends		=> {
        "File::MMagic"			=> 0,
        "IO::Compress::Gzip"	=> 0,
        "IO::Compress::Bzip2"	=> 0,
        "IO::Compress::Xz"		=> 0,
        "Term::ReadKey"			=> 0,
    },
    build_requires		=> {
        "Module::Signature"	=> 0,
        "Test::Pod"		=> 0,
    },
    add_to_cleanup	=> [ "t/logs*" ],
);

$build->create_build_script;

__END__
