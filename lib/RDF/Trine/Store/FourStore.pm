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

	my $st_class	= ($use_quad) ? 'RDF::Trine::Statement::Quad' : 'RDF::Trine::Statement';
	my @vectors	= map { FourStore::RidVector->new() } (1 .. 4);
	my $bind_flags	= 0;
	my @bind_flags	= (FS_BIND_BY_SUBJECT, 0, FS_BIND_BY_OBJECT, 0);
	foreach my $i (0 .. $#nodes) {
		my $vec	= $vectors[ ($i+1) % 4 ];
		if (blessed($nodes[$i]) and not($nodes[$i]->is_variable)) {
			my $node	= $nodes[ $i ];
			$bind_flags	|= $bind_flags[ $i ];
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
	
	my $flags		= FS_BIND_SUBJECT | FS_BIND_PREDICATE | FS_BIND_OBJECT | $bind_flags;
	my ($sv, $pv, $ov) = $self->{'link'}->bind_limit_all(
		$flags,
		@vectors,
		-1,
		-1,
	);
	
	my $length		= $sv->length;
	warn "$length results";
	
	my ($s, $p, $o)	= map { $_->data } ($sv, $pv, $ov);
	my $sub		= sub {
		return unless (scalar(@$s));
		my @rids	= (
			shift(@$s),
			shift(@$p),
			shift(@$o),
		);
		my @triple	= map { $self->{'link'}->get_node( $_ ) } @rids;
		if ($use_quad) {
			push(@triple, $g);
		}
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
	throw RDF::Trine::Error::UnimplementedError;
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

Please report any bugs or feature requests to C<< <gwilliams@cpan.org> >>.

=head1 AUTHOR

Florian Ragwitz C<< <rafl@debian.org> >>
Mischa Tuffield
Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2011
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
