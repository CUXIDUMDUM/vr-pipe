=head1 NAME

VRPipe::Parser::fasta - parse fasta files

=head1 SYNOPSIS

use VRPipe::Parser;

# create object, supplying fasta file
my $pars = VRPipe::Parser->create('fasta', {file => $fa_file});

# get the array reference that will hold the most recently requested record
my $parsed_record = $pars->parsed_record();

# loop through the file, getting records
while ($pars->next_record()) {
    my $id = $parsed_record->[0];
    my $seq = $parsed_record->[1];
}

=head1 DESCRIPTION

A straightforward parser for fasta files.

=head1 AUTHOR

Sendu Bala: bix@sendu.me.uk

=cut

use VRPipe::Base;

class VRPipe::Parser::fasta with VRPipe::ParserRole {
    has '_saw_last_line' => (is => 'rw',
                             isa => 'Bool',
                             default => 0);
    
=head2 parsed_record

 Title   : parsed_record
 Usage   : my $parsed_record= $obj->parsed_record()
 Function: Get the data structure that will hold the last parsed record
           requested by next_record()
 Returns : array ref, where the elements are:
           [0]  sequence id
           [1]  sequence string
 Args    : n/a

=cut
    
=head2 next_record

 Title   : next_record
 Usage   : while ($obj->next_record()) { # look in parsed_record }
 Function: Parse the next line from the fasta file
 Returns : boolean (false at end of output; check the parsed_record for the
           actual information)
 Args    : n/a

=cut
    method next_record {
        # just return if no file set
        my $fh = $self->fh() || return;
        
        # get the next line
        local $/ = "\n>";
        my $line = <$fh> || return;
        
        if ($. == 1) {
            $self->throw("file not in fasta format?: $line") unless $line =~ /^>/;
            $line =~ s/^>//;
        }
        
        $line =~ s/>$//;
        
        my ($head, $seq) = split(/\n/, $line, 2);
        my ($seq_name) = split(" ", $head);
        $seq =~ tr/ \t\n\r//d;
        
        my $pr = $self->parsed_record;
        $pr->[0] = $seq_name;
        $pr->[1] = $seq;
        
        return 1;
    }
}

1;