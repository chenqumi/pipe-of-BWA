use warnings;
use strict;
use File::Basename;
use FindBin qw($Bin);
use Cwd qw(abs_path getcwd);
BEGIN {
    push (@INC,"$Bin");
}
use Qsub;

my ($ref,$cov,$pro_name) = @ARGV;
die "perl $0 <ref.fa> <result.coverage.depth.fa.gz> <peroject_name>" if @ARGV != 3;

#qsub parameters
#==============================================
#
my $memory = "5G";
my $thread = 1;
my $queue = "dna.q,rna.q,reseq.q,all.q";
my $project = "og";
my $max_job = 20;

# scripts
# ============================================
# 
my $GC = "perl /nfs2/pipe/genomics/DNA_DENOVO/Evaluation/GC_depth/gc_depth_20110530.pl";
my $COLOR ="perl $Bin/gc_draw.pl";

my $cwd =getcwd();
$ref = abs_path($ref);
$cov = abs_path($cov);
my $cov_path = dirname($cov);

# GC_depth
#=============================================
#
`gunzip $cov`;
open FO, ">Draw.sh" or die $!;
print FO "bwa_draw.sh\t$GC $ref $cov_path/result.coverage.depth.fa\n";
close FO;

qsub("Draw.sh", $cwd, $memory, $thread,
      $queue, $project, $pro_name, $max_job);

# GC color
#=============================================
#
`$COLOR gc_depth.wind`;