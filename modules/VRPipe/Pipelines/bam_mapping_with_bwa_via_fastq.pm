
=head1 NAME

VRPipe::Pipelines::bam_mapping_with_bwa_via_fastq - a pipeline

=head1 DESCRIPTION

NB: this pipeline has been superseded by
bam_mapping_with_bwa_via_fastq_no_namesort now that the bam_to_fastq step no
longer needs name sorted bams as input.

Maps reads in a bam file datasource to a reference genome using bwa fastq
alignment. For this the bams are first converted to fastq format, then
converted back after the alignment.

=head1 AUTHOR

Chris Joyce <cj5@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 Genome Research Limited.

This file is part of VRPipe.

VRPipe is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use VRPipe::Base;

class VRPipe::Pipelines::bam_mapping_with_bwa_via_fastq with VRPipe::PipelineRole {
    method name {
        return 'bam_mapping_with_bwa_via_fastq';
    }
    
    method description {
        return 'DEPRECATED: use bam_mapping_with_bwa_via_fastq_no_namesort instead. (Map reads in bam files to a reference genome with bwa fastq alignment)';
    }
    
    method step_names {
        (
            'sequence_dictionary',   #1
            'bwa_index',             #2
            'bam_metadata',          #3
            'bam_name_sort',         #4
            'bam_to_fastq',          #5
            'fastq_split',           #6
            'bwa_aln_fastq',         #7
            'bwa_sam',               #8
            'sam_to_fixed_bam',      #9
            'bam_merge_lane_splits', #10
            'bam_index',             #11
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0,  to_step => 3,  to_key   => 'bam_files' },
            { from_step => 0,  to_step => 4,  to_key   => 'bam_files' },
            { from_step => 4,  to_step => 5,  from_key => 'name_sorted_bam_files', to_key => 'bam_files' },
            { from_step => 5,  to_step => 6,  from_key => 'fastq_files', to_key => 'fastq_files' },
            { from_step => 6,  to_step => 7,  from_key => 'split_fastq_files', to_key => 'fastq_files' },
            { from_step => 7,  to_step => 8,  from_key => 'bwa_sai_files', to_key => 'sai_files' },
            { from_step => 6,  to_step => 8,  from_key => 'split_fastq_files', to_key => 'fastq_files' },
            { from_step => 8,  to_step => 9,  from_key => 'bwa_sam_files', to_key => 'sam_files' },
            { from_step => 9,  to_step => 10, from_key => 'fixed_bam_files', to_key => 'bam_files' },
            { from_step => 1,  to_step => 10, from_key => 'reference_dict', to_key => 'dict_file' },
            { from_step => 10, to_step => 11, from_key => 'merged_lane_bams', to_key => 'bam_files' }
        );
    }
    
    method behaviour_definitions {
        (
            { after_step => 8, behaviour => 'delete_outputs', act_on_steps => [4, 5, 6, 7], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 11, behaviour => 'delete_outputs', act_on_steps => [8, 9], regulated_by => 'cleanup', default_regulation => 1 }
        );
    }
}

1;
