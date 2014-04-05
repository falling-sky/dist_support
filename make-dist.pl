#! /usr/bin/perl

use Getopt::Long;
use Google::Code::Upload;
use YAML::Syck;
use IO::Prompter;


use strict;

$|=1;


my $svn_version = get_svn_version();

my(%argv,%input,$usage);

%input=( "b|basename=s"=>"base name of package",
 "staged=s"=>"staged directory with content to package (default: 'work')",
 "version=s"=>"version number to use (default: 0.$svn_version, based on svn)",
 "google!"=>"Upload to google (default: no)",
 "gigo!"=>"copy to rsync.test-ipv6.com (default: yes)",
 "user=s"=>"username to use (default: 'jfesler\@gmail.com')",
 "password=s" => "password to use for uploading (https://code.google.com/hosting/settings)",
 "branch=s" => "branch name (test, current, release)",
 "n|nomodify","don't actually delete anything - just print steps taken",
 "v|verbose","spew extra data to the screen",
 "h|help","show option help");

my $result = GetOptions(\%argv,keys %input);
get_config();
$argv{"v"} ||= $argv{"n"};
$argv{"version"} ||= "0.$svn_version";
$argv{"staged"} ||= "work";
$argv{"user"} ||= "jfesler\@gmail.com";
#if (! exists $argv{"google"}) {
#  $argv{"google"} ||= 1 if ($argv{"branch"} =~ /stable/);
#  $argv{"google"} ||= 0;
#}
$argv{"gigo"} ||= 1;
$argv{"branch"} ||= "test";

if ((!$result)  || (!$argv{"b"}) || ($argv{h})) {
   &showOptionsHelp; exit 0;
}

if ($argv{"google"}) {
  $argv{"password"} ||= get_password();
}

if (! -d $argv{"staged"}) {
   die "--staged $argv{staged} : not a directory";
}

my $basename_v = "fsky-" . $argv{"b"} . "-" . $argv{"version"};
my $basename_l = "fsky-" . $argv{"b"} . "-" . $argv{"branch"};
if (-d $basename_v) {
   die "$basename_v already exists.\n" unless (-f "$basename_v.tgz");
} else {


my_system("rm","-fr",$basename_l,$basename_v);
my_system("mkdir","-p",$basename_v,$basename_l);
my_system("rsync","-a","$argv{staged}/.","$basename_v/.");
my_system("rsync","-a","$argv{staged}/.","$basename_l/.");
my_system("tar","cfz","$basename_v.tgz",$basename_v);
my_system("tar","cfz","$basename_l.tgz",$basename_l);
}


# TODO have it fetch a README from the distribution
if ($argv{"google"}) {
  my $gc = Google::Code::Upload->new(project  => 'falling-sky',username => $argv{"user"},password => $argv{"password"});
  print "Uploading $basename_v.tgz ...\n";
  my $url = $gc->upload(file=>"$basename_v.tgz",summary=>"$argv{base} for falling-sky",description=>"$argv{b} for falling-sky", labels => [$argv{branch}]);
  print "Uploaded; available as $url\n";
}

if ($argv{"gigo"}) {
  my $dir;
  
  # Loose files
  $dir = "/home/fsky/$argv{branch}/$argv{b}";
  my_system("mkdir","-p",$dir);
  my_system("rsync","$basename_v/.","$dir/.","-a","--delete");
  
  # Tarball
  $dir = "/var/www/files.test-ipv6.com/$argv{b}/$argv{branch}";
  my_system("mkdir","-p",$dir);
  my_system("rsync","$basename_v.tgz","$dir/","-a");
  
  # Update the "latest" tarball
  $dir = "/var/www/files.test-ipv6.com/latest";
  my_system("mkdir","-p",$dir);
  my_system("rsync","$basename_l.tgz","$dir/","-a");
}

my_system("rm","-fr",$basename_l,$basename_v);



my $got_svn_info;
sub get_svn_info {
  if (!$got_svn_info) {
    $got_svn_info=`svn info`;
  }
  if (!$got_svn_info) {
    die "could not get 'svn info'";
  }
  return $got_svn_info;
}

sub get_svn_version {
  my $got = get_svn_info();
  if ($got =~ /^Revision: (\d+)$/m) {
    return $1;
  }  
  die "could not figure out svn version";
}


sub my_system {
  my(@args) = @_;
  print "% @args\n";
  system(@args) == 0 or die "system @args failed: $?"
}

sub get_password {
  my $passwd = prompt 'Enter your code.google.com code: ', -echo=>'*';
  return $passwd;
}

sub get_config {
  my $cf = "$ENV{HOME}/.make-dist";
  if (-f $cf) {
     my $ref = LoadFile($cf);
     foreach my $key (keys %$ref) {
       $argv{$key} ||= $ref->{$key};
     }
  }
}

sub showOptionsHelp {
 my($left,$right,$a,$b,$key);
 my(@array);
 print "Usage: $0 [options] $usage\n";
 print "where options can be:\n";
 foreach $key (sort keys (%input)) {
    ($left,$right) = split(/[=:]/,$key);
    ($a,$b) = split(/\|/,$left);
    if ($b) {  
      $left = "-$a --$b";
    } else {
      $left = "   --$a";
    }
    $left = substr("$left" . (' 'x20),0,20);
    push(@array,"$left $input{$key}\n");
 }
 print sort @array;
}
