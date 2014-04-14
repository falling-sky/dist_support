#! /usr/bin/perl

use Getopt::Long;
use Google::Code::Upload;
use YAML::Syck;
use IO::Prompter;
use FindBin qw($Bin);

use strict;

$| = 1;

my $git_version = `$Bin/git-revision.sh`;
chomp $git_version;

#my $diff = ` git diff --shortstat`;
#if ( $diff =~ /file/ ) {
#    print $diff;
#    print "REFUSING TO BUILD UNTIL FILES ARE COMMITTED\n";
#    exit 1;
#}

my ( %argv, %input, $usage );

%input = (
           "b|basename=s" => "base name of package",
           "staged=s"     => "staged directory with content to package (default: 'work')",
           "version=s"    => "version number to use (default: $git_version, based on git tags and commits)",
           "google!"      => "Upload to google (default: no)",
           "gigo!"        => "copy to rsync.test-ipv6.com (default: yes)",
           "branch=s"     => "branch name (test, current, release)",
           "n|nomodify", "don't actually delete anything - just print steps taken",
           "v|verbose",  "spew extra data to the screen",
           "h|help",     "show option help"
         );

my $result = GetOptions( \%argv, keys %input );
get_config();
$argv{"v"}       ||= $argv{"n"};
$argv{"version"} ||= "$git_version";
$argv{"staged"}  ||= "work";
$argv{"gigo"}   ||= 1;
$argv{"branch"} ||= "test";

if ( ( !$result ) || ( !$argv{"b"} ) || ( $argv{h} ) ) {
    &showOptionsHelp;
    exit 0;
}

if ( $argv{"google"} ) {
    $argv{"password"} ||= get_password();
}

if ( !-d $argv{"staged"} ) {
    die "--staged $argv{staged} : not a directory";
}

my $basename_v = "fsky-" . $argv{"b"} . "-" . $argv{"version"};
my $basename_l = "fsky-" . $argv{"b"} . "-" . $argv{"branch"};


my $dir = "/var/www/files.test-ipv6.com/$argv{b}/$argv{branch}";
if (-f "$dir/$basename_v.tgz") {
  print STDERR "***\n";
  print STDERR "*** $dir/$basename_v.tgz already exists\n";
  print STDERR "*** treating as success\n";
  print STDERR "***\n";
  exit 0;
}
    


# First clean up
    my_system( "rm",    "-fr", $basename_l,       $basename_v );
    my_system( "mkdir", "-p",  $basename_v,       $basename_l );
    
    # Get the staged files
    my_system( "rsync", "-a",  "$argv{staged}/.", "$basename_v/." );
    my_system( "rsync", "-a",  "$argv{staged}/.", "$basename_l/." );
    
    # Tarballs!
    my_system( "tar",   "cfz", "$basename_v.tgz", $basename_v );
    my_system( "tar",   "cfz", "$basename_l.tgz", $basename_l );


    # copy to Loose files
    $dir = "/home/fsky/$argv{branch}/$argv{b}";
    my_system( "mkdir", "-p", $dir );
    my_system( "rsync", "$basename_v/.", "$dir/.", "-a", "--delete" );

    # copy to Tarball
    $dir = "/var/www/files.test-ipv6.com/$argv{b}/$argv{branch}";
    my_system( "mkdir", "-p", $dir );
    my_system( "rsync", "$basename_v.tgz", "$dir/", "-a" );

    # Update the "latest" tarball
    $dir = "/var/www/files.test-ipv6.com/latest";
    my_system( "mkdir", "-p", $dir );
    my_system( "rsync", "$basename_l.tgz", "$dir/", "-a" );

my_system( "rm", "-fr", $basename_l, $basename_v );




sub my_system {
    my (@args) = @_;
    print "% @args\n";
    system(@args) == 0 or die "system @args failed: $?";
}

sub get_password {
    my $passwd = prompt 'Enter your code.google.com code: ', -echo => '*';
    return $passwd;
}

sub get_config {
    my $cf = "$ENV{HOME}/.make-dist";
    if ( -f $cf ) {
        my $ref = LoadFile($cf);
        foreach my $key ( keys %$ref ) {
            $argv{$key} ||= $ref->{$key};
        }
    }
}

sub showOptionsHelp {
    my ( $left, $right, $a, $b, $key );
    my (@array);
    print "Usage: $0 [options] $usage\n";
    print "where options can be:\n";
    foreach $key ( sort keys(%input) ) {
        ( $left, $right ) = split( /[=:]/, $key );
        ( $a,    $b )     = split( /\|/,   $left );
        if ($b) {
            $left = "-$a --$b";
        } else {
            $left = "   --$a";
        }
        $left = substr( "$left" . ( ' ' x 20 ), 0, 20 );
        push( @array, "$left $input{$key}\n" );
    }
    print sort @array;
}
