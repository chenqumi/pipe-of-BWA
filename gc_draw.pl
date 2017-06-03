use warnings;
use strict;
use FindBin qw($Bin);
use File::Basename;
use Cwd qw(abs_path getcwd);

my ($file)= @ARGV;
my $name = basename($0);
die "perl $name <gc_depth.wind>" if(@ARGV != 1);

open FI,"$file" or die $!;
open FO, ">stat.txt" or die $!;
print FO "GCpercent\tavgDepth\n";

while(<FI>){
	chomp;
	next if($_ eq "");
	my $gc = (split(/\s+/,$_))[3];
	$gc *= 100;
	my $dep = (split(/\s+/,$_))[5];
	print FO "$gc\t$dep\n";
}
close FI;
close FO;

# Using R
system("R <$Bin/gc_depth.R --vanilla");