=head1 NAME

RDF::Trine::Store::FourStore - RDF Store for 4store

=head1 VERSION

This document describes RDF::Trine::Store::FourStore version 0.135

=head1 SYNOPSIS

 use RDF::Trine::Store::FourStore;

=head1 DESCRIPTION

RDF::Trine::Store::FourStore provides a RDF::Trine::Store API to interact with a
4store database.

=cut

package RDF::Trine::Store::FourStore;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Data::Dumper;
use Scalar::Util qw(refaddr reftype blessed);
use FourStore;

use RDF::Trine::Error qw(:try);

######################################################################

our $VERSION;
BEGIN {
	$VERSION	= "0.135";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $kb_name ) >>

Returns a new storage object that will connect to the named 4store KB.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<FourStore> for this backend.

The following key must also be used:

=over

=item C<kb>

The KB name.

=back

=cut

sub new {
	my $class	= shift;
	my $kb		= shift;
	my $link	= FourStore::Link->new($kb, '');
	
	my $self	= bless({
		kb		=> $kb,
		'link'	=> $link,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
}

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'FourStore';
	return $proto->SUPER::new_with_config( $config );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config->{kb} );
}

sub _config_meta {
	return {
		required_keys	=> [qw(kb)],
		fields			=> {
			url	=> { description => '4store KB name', type => 'string' },
		}
	}
}


=item C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	my $g			; RDF::Trine::Node::Nil->new();
	if (scalar(@_) >= 4) {
		$g	= $nodes[3];
		if (blessed($g) and not($g->is_variable) and not($g->is_nil)) {
			$use_quad	= 1;
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	my %same;
	my $has_same	= 0;
	my @pos	= qw(subject predicate object graph);
	foreach my $i (0 .. $#nodes) {
		my $n	= $nodes[ $i ];
		if (blessed($n) and $n->is_variable) {
			if ($same{ $n->name }{ count }++) {
				$has_same++;
			}
			push(@{ $same{ $n->name }{ 'pos' } }, $i);
		}
	}
	
	my $same_flag	= FS_BIND_SAME_XXXX;
	if ($has_same) {
		my @vars	= keys %same;
		if (scalar(@vars) == 1) {
			my $v		= shift(@vars);
			my @pos		= @{ $same{ $v }{ 'pos' } };
			my $count	= scalar(@pos);
			my %pos_cmp	= map { $_ => 1 } (0,1,2,3);
			if ($count == 2) {
				my $same_pos	= join('', @pos);
				my %two_bound_flag	= (
					'12'	=> FS_BIND_SAME_XXAA,
					'02'	=> FS_BIND_SAME_XAXA,
					'01'	=> FS_BIND_SAME_XAAX,
					'23'	=> FS_BIND_SAME_AXXA,
					'13'	=> FS_BIND_SAME_AXAX,
					'03'	=> FS_BIND_SAME_AAXX,
				);
				$same_flag	= $two_bound_flag{ $same_pos };
			} elsif ($count == 3) {
				delete $pos_cmp{ $_ } for (@pos);
				my ($missing_pos)	= keys %pos_cmp;
				my @three_bound_flag	= (
					FS_BIND_SAME_AXAA,
					FS_BIND_SAME_AAXA,
					FS_BIND_SAME_AAAX,
					FS_BIND_SAME_XAAA,
				);
				$same_flag	= $three_bound_flag[ $missing_pos ];
			} else {
				$same_flag	= FS_BIND_SAME_AAAA;
			}
		} else {
			my %vmap;
			@vmap{ @vars }	= qw(A B);
			my @same_ab;
			foreach my $v (@vars) {
				foreach my $i (@{ $same{ $v }{ 'pos' } }) {
					$same_ab[$i]	= $vmap{$v};
				}
			}
			unshift(@same_ab, pop(@same_ab));
			my $same_ab	= join('', @same_ab);
			if ($same_ab eq 'AABB' or $same_ab eq 'BBAA') {
				$same_flag	= FS_BIND_SAME_AABB;
			} elsif ($same_ab eq 'ABAB' or $same_ab eq 'BABA') {
				$same_flag	= FS_BIND_SAME_ABAB;
			} else {
				$same_flag	= FS_BIND_SAME_ABBA;
			}
		}
	}
	
	my $st_class	= ($use_quad) ? 'RDF::Trine::Statement::Quad' : 'RDF::Trine::Statement';
	my @vectors	= map { FourStore::RidVector->new() } (1 .. 4);
	my $bind_flags	= 0;
	my @bind_flags	= (FS_BIND_BY_SUBJECT, 0, FS_BIND_BY_OBJECT, 0);
	foreach my $i (0 .. $#nodes) {
		my $vec	= $vectors[ ($i+1) % 4 ];
		if (blessed($nodes[$i]) and not($nodes[$i]->is_variable)) {
			my $node	= $nodes[ $i ];
			unless ($bind_flags) {
				$bind_flags	|= $bind_flags[ $i ];
			}
			if ($node->isa( 'RDF::Trine::Node::Resource')) {
				my $rid	= FourStore::Hash::hash_uri( $node->uri_value );
				$vec->append($rid);
			} elsif ($node->isa( 'RDF::Trine::Node::Literal' )) {
				if ($node->has_language) {
					my $langrid	= FourStore::Hash::hash_literal($node->literal_value_language, 0);
					my $rid		= FourStore::Hash::hash_literal($node->literal_value, $langrid);
					$vec->append($rid);
				} elsif ($node->has_datatype) {
					my $dtrid	= FourStore::Hash::hash_uri($node->literal_datatype, 0);
					my $rid		= FourStore::Hash::hash_literal($node->literal_value, $dtrid);
					$vec->append($rid);
				} else {
					my $rid	= FourStore::Hash::hash_literal($node->literal_value, 0);
					$vec->append($rid);
				}
			}
		}
	}
	
	$bind_flags		||= FS_BIND_BY_SUBJECT;
	my $flags		= FS_BIND_SUBJECT | FS_BIND_PREDICATE | FS_BIND_OBJECT | $bind_flags | $same_flag;
	if ($use_quad) {
		$flags	|= FS_BIND_MODEL;
	}
	
	my @result_vectors = $self->{'link'}->bind_limit_all(
		$flags,
		@vectors,
		-1,
		-1,
	);
	
	if ($use_quad) {
		push(@result_vectors, shift(@result_vectors));	# move the graph vector to the end of the list
	}
	
	my @arrays	= map { $_->data } @result_vectors;
	my $sub		= sub {
		return unless (scalar(@{ $arrays[0] }));
		my @rids	= map { shift(@$_) } @arrays;
		my @triple	= map { $self->{'link'}->get_node( $_ ) } @rids;
		my $st	= $st_class->new( @triple );
		return $st;
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my @vectors	= map { FourStore::RidVector->new() } (1 .. 4);
	my $flags	= FS_BIND_DISTINCT | FS_BIND_MODEL | FS_BIND_BY_SUBJECT;
	my ($vector) = $self->{'link'}->bind_limit_all(
		$flags,
		@vectors,
		-1,
		-1,
	);
	
	my $data	= $vector->data;
	my %seen;
	my $sub		= sub {
		while (1) {
			return unless (scalar(@$data));
			my $rid	= shift(@$data);
			next if ($seen{ $rid }++);
			my $g	= $self->{'link'}->get_node( $rid );
			return $g;
		}
	};
	return RDF::Trine::Iterator->new( $sub );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	throw RDF::Trine::Error::UnimplementedError;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	throw RDF::Trine::Error::UnimplementedError;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	throw RDF::Trine::Error::UnimplementedError;
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	my $self	= shift;
	return;
}

sub _bulk_ops {
	my $self	= shift;
	return $self->{BulkOps};
}

sub _begin_bulk_ops {
	my $self			= shift;
	$self->{BulkOps}	= 1;
}

sub _end_bulk_ops {
	my $self			= shift;
	$self->{BulkOps}	= 0;
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to the Perl+RDF mailing list at C<< <dev@perlrdf.org> >>.

=head1 AUTHOR

Florian Ragwitz C<< <rafl@debian.org> >>
Mischa Tuffield
Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2011
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
