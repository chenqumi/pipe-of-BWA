use warnings;
use strict;
use FindBin qw($Bin);
use File::Basename;
use Cwd qw(abs_path getcwd);
BEGIN {
    push (@INC,"$Bin");
}
use Qsub;
=head1 Usage
 
 perl bam_stat.pl <ref.fa> <bam.lst> <project_name>

=head1 bam.lst format:
 
 PE450_1.bam
 PE450_2.bam
 PE500.bam

=cut
my ($ref,$bam_lst,$pro_name) = @ARGV;
die `pod2text $0` if (@ARGV != 3);

# Software
#=============================================
#
my $SAMTOOLS = "/lustre/project/og04/shichunwei/biosoft/samtools-1.3/samtools";
my $ITOOLS ="/p299/user/og06/pipe/pub/baozhigui/biosoft/iTools_Code/iTools";

# working dir
#=============================================
#
my $cwd = getcwd();
my $dir_shell = "$cwd/Shell_stat";
mkdir "$dir_shell";

#qsub parameters
#=============================================
#
my $outdir = "Shell";
my $memory = "5G";
my $thread = 1;
my $queue = "dna.q,rna.q,reseq.q,all.q";
my $project = "og";
my $max_job = 20;

# sort bam
#=============================================
#
my $shell_sort = "$dir_shell/sort.sh";
my $sort_lst = "$cwd/sort.lst";
open FI, "$bam_lst" or die $!;
open FO, ">$shell_sort" or die $!;
open SOR, ">$sort_lst" or die $!;
# for index bam
my $shell_index = "$dir_shell/index_bam.sh";
open IN,">$shell_index" or die $!;

while (<FI>) {
	chomp;
	$_ = abs_path($_);
	my $bam = basename($_);
	my $sort_bam = "sorted\_$bam";
	my $shell = "$sort_bam\.sh";
	print FO "$shell\t$SAMTOOLS sort $_ > $cwd/$sort_bam\n";
	print SOR "$cwd/$sort_bam\n";
	# for index bam
	my $index = "$sort_bam\_index.sh";
	print IN "$index\t$SAMTOOLS index $cwd/$sort_bam\n";
}
close FI;
close FO;
close SOR;
close IN;

qsub($shell_sort, $dir_shell, $memory, $thread,
         $queue, $project, $pro_name, $max_job);

qsub($shell_index, $dir_shell, $memory, $thread,
         $queue, $project, $pro_name, $max_job);

# Stat alignment rate
#=============================================
#
my $shell_map = "$dir_shell/map.sh";
my $shell_cov = "$dir_shell/coverage.sh";

open LST, "$sort_lst" or die $!;
open MAP, ">$shell_map" or die $!;


while (<LST>) {
	chomp;
	$_ = abs_path($_);
	my $bam = basename($_);
	my $map = "$bam\.map";
	my $shell = "$bam\_map.sh";
	print MAP "$shell\t$SAMTOOLS flagstat $_ > $cwd/$map\n";
}
close LST;
close MAP;

qsub($shell_map, $dir_shell, $memory, $thread,
        $queue, $project, $pro_name, $max_job);

# Stat coverage
#=============================================
#
$ref = abs_path($ref);

my $cmd_cov = "$ITOOLS Xamtools stat ";
$cmd_cov .= "-Bam -InList $sort_lst ";
$cmd_cov .= "-OutStat $cwd/result.coverage ";
$cmd_cov .= "-SiteD 1 ";
$cmd_cov .= "-Ref $ref; ";
$cmd_cov .= "echo done";

open COV, ">$shell_cov" or die $!;
print COV "cov.sh\t$cmd_cov\n";
close COV;

qsub($shell_cov, $dir_shell, $memory, $thread,
        $queue, $project, $pro_name, $max_job);

# Be convient to check statistic
`head -n 1 result.coverage > stat`;
`tail -n 1 result.coverage >> stat`;