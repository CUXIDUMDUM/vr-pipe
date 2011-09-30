#!/usr/bin/env perl
use strict;
use warnings;
use File::Copy;
use Path::Class;

BEGIN {
    use Test::Most tests => 12;
    
    use_ok('VRPipe::Persistent::Schema');
    use_ok('VRPipe::Steps::bam_stats');
    
    use TestPipelines;
}

my ($output_dir, $pipeline, $step) = create_single_step_pipeline('bam_stats', 'bam_files');
is_deeply [$step->id, $step->description], [1, 'Calculates various statistics about bam files, producing .bas files'], 'bam_stats step created and has correct description';

# test using the class methods directly
my $test_bam = file(qw(t data bas.bam));
is_deeply {VRPipe::Steps::bam_stats->bam_statistics($test_bam)}, {SRR00001 => {total_bases => 115000,
                                                                               mapped_bases => 58583,
                                                                               total_reads => 2000,
                                                                               mapped_reads => 1084,
                                                                               mapped_reads_paired_in_seq => 1084,
                                                                               mapped_reads_properly_paired => 1070,
                                                                               percent_mismatch => '2.05',
                                                                               avg_qual => '23.32',
                                                                               avg_isize => 286,
                                                                               sd_isize => '74.10',
                                                                               median_isize => 275,
                                                                               mad => 48,
                                                                               duplicate_reads => 2}}, 'bam_statistics test';

my $given_bas = file($output_dir, 'test.bas');
ok VRPipe::Steps::bam_stats->bas($test_bam, $given_bas, dcc => 20100208), 'bas() ran ok';
my $expected_bas = file(qw(t data example.bas));
ok open(my $ebfh, $expected_bas), 'opened expected .bas';
@expected = <$ebfh>;
close($ebfh);
ok open(my $tbfh, $given_bas), 'opened result .bas';
my @given = <$tbfh>;
close($tbfh);
is_deeply \@given, \@expected, 'bas output was as expected';

# test making a bas file from a bam with RG in PU instead of ID
$given_bas = file($output_dir, 'test2.bas');
ok VRPipe::Steps::bam_stats->bas(file(qw(t data rg_pu.bam)), $given_bas, dcc => 20110521, undef, 1), 'bas() with rg_from_pu ran ok';
$expected_bas = file(qw(t data example3.bas));
ok open($ebfh, $expected_bas), 'opened expected .bas';
my @expected2 = <$ebfh>;
close($ebfh);
ok open($tbfh, $given_bas), 'opened result .bas';
@given = <$tbfh>;
close($tbfh);
is_deeply \@given, \@expected2, 'bas output was as expected when converting RG PU to ID';


# test as part of a pipeline
#my $ds = VRPipe::DataSource->get(type => 'list', method => 'all', source => 't/data/datasource.fivelist');
#
#my $setup = VRPipe::PipelineSetup->get(name => 'bsp_setup',
#                                       datasource => $ds,
#                                       output_root => $output_dir,
#                                       pipeline => $pipeline,
#                                       options => {});
#
#handle_pipeline();
#
#finish;