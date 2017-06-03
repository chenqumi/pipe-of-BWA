use warnings;
use strict;
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin);
use Cwd qw(abs_path getcwd);
BEGIN {
    push (@INC,"$Bin");
}
use Qsub;

=head1 Usage 

 perl BWA_stat.pl <ref.fa> <fq.lst> <project_name>
      
      -nosplit: NOT split reads
 
=head1 fq.lst format:

 lib_name	read
 PE450	read1.fq.gz
 PE450	read2.fq.gz

=cut

die `pod2text $0` if (@ARGV == 0 or @ARGV < 3);
my($ref,$fq_lst,$pro_name,$size)=@ARGV;
my($nosplit);
GetOptions(
	"nosplit" => \$nosplit,
);


# Software
#=============================================
#
my $SPLIT = "perl $Bin/split_read_mk_list.pl";
my $ALIGN = "perl $Bin/Align.pl";
my $MERGE = "perl $Bin/merge.pl";
my $STAT = "perl $Bin/bam_stat.pl";
my $GC = "perl $Bin/bwa_draw.pl";

#qsub parameters
#==============================================
#
my $memory = "5G";
my $thread = 1;
my $queue = "dna.q,rna.q,reseq.q,all.q";
my $project = "og";
my $max_job = 20;

# Working dir
#=============================================
#
my $cwd = getcwd();
my $dir_split = "$cwd/Split";
my $dir_index = "$cwd/Index";
my $dir_align = "$cwd/Align";
my $dir_merge = "$cwd/Merge";
my $dir_stat = "$cwd/Stat";
my $dir_gc = "$cwd/GC_depth";

mkdir "$dir_split";
mkdir "$dir_index";
mkdir "$dir_align";
mkdir "$dir_merge";
mkdir "$dir_stat";
mkdir "$dir_gc";

#========================================
#
$ref = abs_path($ref);

#Solve path of fq.lst
#=========================================
#
open FQ,"$fq_lst" or die $!;
open LI,">filelst" or die $!;
while (my $line_1 = <FQ>) {
	my $line_2 = <FQ>;
	chomp $line_1;
	chomp $line_2;
	my ($lib_1,$rd_1)=split(/\s+/,$line_1);
	my ($lib_2,$rd_2)=split(/\s+/,$line_2);
	die "Not match" if ($lib_1 ne $lib_2);
	$rd_1 = abs_path($rd_1);
	$rd_2 = abs_path($rd_2);
	print LI "$lib_1\t$rd_1\n";
	print LI "$lib_2\t$rd_2\n";

	open OT,">$dir_split/$lib_1\.lst" or die $!;
	print OT "$lib_1\t$rd_1\n";
	print OT "$lib_1\t$rd_2\n";
	close OT;
}
close FQ;
close LI;

# Split read 
#=============================================
#
if (defined $nosplit){
	`$ALIGN $ref $cwd/filelst $pro_name`;
}else{
	chdir "$dir_split";
	`ls *.lst > list`;
	open LST,"list" or die $!;
	open SP,">Split.sh" or die $!;
	while (<LST>) {
		chomp;
		$_ =~ /(\S+).lst/;
		my $lib = $1;
		my $cmd = "$SPLIT $_ 5G";
		#$cmd .= " $size" if (defined $size);
		print SP "split\_$lib\.sh\t$cmd\n";
	}
	close LST;
	close SP;

	qsub("Split.sh", $dir_split, $memory, $thread,
     $queue, $project, $pro_name, $max_job);
}


# Index & Align
#=============================================
#
if (!defined $nosplit){
	chdir "$cwd";
	`$ALIGN $ref $dir_split/split.lst $pro_name`;
}

# Merge bam 
#=============================================
#
if (!defined $nosplit){
	chdir "$dir_merge";

	`ls $dir_align/*.bam > list`;

	my %lib;
	open FI,"list" or die $!;
	open ME,">merge.lst" or die $!;
	while (<FI>) {
		chomp;
		my $file = basename($_);
		$file =~ /(\S+)_split/;
		if (!exists $lib{$1}){
			print ME ">$1\n";
			$lib{$1} = 1;
		}
		print ME "$_\n";
	}
	close FI;
	close ME;

	`$MERGE merge.lst $pro_name`;
}



# Stats,including map rate & depth
#=============================================
#
chdir "$dir_stat";
if (!defined $nosplit){
	`ls $dir_merge/*.bam > $dir_stat/bam.lst`;
}else{
	`ls $dir_align/*.bam > $dir_stat/bam.lst`;
}

`$STAT $ref bam.lst $pro_name`;

# Draw GC_depth
#==============================================
#
chdir "$dir_gc";
`$GC $ref $dir_stat/result.coverage.depth.fa.gz $pro_name`;

# Remove files
#==============================================
#
chdir "$cwd";
`rm $dir_split/*.fq`;
`rm $dir_align/*.bam`;
`rm $dir_merge/*.bam`;