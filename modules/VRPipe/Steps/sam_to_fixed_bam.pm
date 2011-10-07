use VRPipe::Base;

class VRPipe::Steps::sam_to_fixed_bam with VRPipe::StepRole {
    method options_definition {
        return { reference_fasta => VRPipe::StepOption->get(description => 'absolute path to genome reference file used to do the mapping'),
                 uncompressed_fixed_bam_output => VRPipe::StepOption->get(description => 'A boolean to choose if the output bams from this step should be uncompressed',
                                                                          optional => 1,
                                                                          default_value => 1),
                 fixed_bam_seq_from_reference => VRPipe::StepOption->get(description => 'A boolean to choose whether sequence info is read from the reference -- set for mappers, such as smalt, which don\'t include this in output sam files',
                                                                            optional => 1),
                 samtools_exe => VRPipe::StepOption->get(description => 'path to your samtools executable',
                                                         optional => 1,
                                                         default_value => 'samtools') };
    }
    method inputs_definition {
        return { sam_files => VRPipe::StepIODefinition->get(type => 'txt',
                                                            max_files => -1,
                                                            description => 'raw sam files from a mapper',
                                                            metadata => {reads => 'total number of reads (sequences)',
                                                                         paired => '0=unpaired reads were mapped; 1=paired reads were mapped'}) };
    }
    method body_sub {
        return sub {
            my $self = shift;
            my $options = $self->options;
            my $ref = Path::Class::File->new($options->{reference_fasta});
            $self->throw("reference_fasta must be an absolute path") unless $ref->is_absolute;
            
            my $samtools = $options->{samtools_exe};
            
            my $u = $options->{uncompressed_fixed_bam_output} ? ' -u' : ' -b';
            my $t = $options->{fixed_bam_seq_from_reference} ? ' -T $reference_fasta' : '';
            $self->set_cmd_summary(VRPipe::StepCmdSummary->get(exe => 'samtools',
                                                               version => VRPipe::StepCmdSummary->determine_version($samtools, '^Version: (.+)$'),
                                                               summary => "samtools view -bSu \$sam_file$t | samtools sort -n -o - samtools_nsort_tmp | samtools fixmate /dev/stdin /dev/stdout | samtools sort -o - samtools_csort_tmp | samtools fillmd$u - \$reference_fasta > \$fixed_bam_file"));
            
            my $req = $self->new_requirements(memory => 2900, time => 1);
            foreach my $sam (@{$self->inputs->{sam_files}}) {
                my $bam_basename = $sam->basename;
                $bam_basename =~ s/\.sam$//;
                my $prefix_base = '.'.$bam_basename;
                $bam_basename .= '.bam';
                
                my $sam_meta = $sam->metadata;
                my $bam_meta = {};
                foreach my $key (qw(lane library sample center_name platform study insert_size bases reads paired mapped_fastqs chunk)) {
                    if (defined $sam_meta->{$key}) {
                        $bam_meta->{$key} = $sam_meta->{$key};
                    }
                }
                
                my $bam_file = $self->output_file(output_key => 'fixed_bam_files',
                                                  basename => $bam_basename,
                                                  type => 'bam',
                                                  metadata => $bam_meta);
                
                my $bam_dir = $bam_file->dir;
                my $sam_path = $sam->path;
                my $bam_path = $bam_file->path;
                my $nprefix = Path::Class::File->new($bam_dir, $prefix_base.'.samtools_nsort_tmp');
                my $cprefix = Path::Class::File->new($bam_dir, $prefix_base.'.samtools_csort_tmp');
                
                my $tr = $options->{fixed_bam_seq_from_reference} ? " -T $ref" : '';
                my $this_cmd = "$samtools view -bSu $sam_path$tr | $samtools sort -n -o - $nprefix | $samtools fixmate /dev/stdin /dev/stdout | $samtools sort -o - $cprefix | $samtools fillmd$u - $ref > $bam_path";
                
                $self->dispatch_wrapped_cmd('VRPipe::Steps::sam_to_fixed_bam', 'fix_and_check', [$this_cmd, $req, {output_files => [$bam_file]}]);
            }
        };
    }
    method outputs_definition {
        return { fixed_bam_files => VRPipe::StepIODefinition->get(type => 'bam',
                                                                  max_files => -1,
                                                                  description => 'uncompressed coordinate-sorted bam file(s)',
                                                                  metadata => {reads => 'total number of reads (sequences)',
                                                                               paired => '0=unpaired reads were mapped; 1=paired reads were mapped'}) };
    }
    method post_process_sub {
        return sub { return 1; };
    }
    method description {
        return "Turns a sam file into an uncompressed coordinate-sorted bam file with fixed mates and correct NM tag values";
    }
    method max_simultaneous {
        return 0;
    }
    
    method fix_and_check (ClassName|Object $self: Str $cmd_line) {
        my ($samtools, $sam_path, $bam_path) = $cmd_line =~ /^(\S+) view -bSu (\S+) .+ (\S+)$/;
        $bam_path || $self->throw("cmd_line [$cmd_line] was not constructed as expected");
        
        my $sam_file = VRPipe::File->get(path => $sam_path);
        my $bam_file = VRPipe::File->get(path => $bam_path);
        
        $bam_file->disconnect;
        system($cmd_line) && $self->throw("failed to run [$cmd_line]");
        
        my $expected_reads = $sam_file->metadata->{reads};
        $bam_file->update_stats_from_disc(retries => 3);
        my $actual_reads = $bam_file->num_records;
        
        if ($actual_reads == $expected_reads) {
            return 1;
        }
        else {
            $bam_file->unlink;
            $self->throw("cmd [$cmd_line] failed because $actual_reads lines were generated in the bam file, yet there were $expected_reads reads in the sam file");
        }
    }
}

1;
