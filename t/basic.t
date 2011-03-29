use strict;
use warnings;
use Test::More;

use FourStore;

my $link = FourStore::Link->new('moo', 'bar');
isa_ok $link, 'FourStore::Link';

ok $link->features;

diag $link->segments;

my $vec = FourStore::RidVector->new(42);
isa_ok $vec, 'FourStore::RidVector';
$vec->append(24, 32);
$vec->append_vector( $vec->copy );

diag $vec->length;

use Data::Dump 'pp';
pp $vec->data;

sub FS_BIND_SUBJECT () { 0x02 }
sub FS_BIND_PREDICATE () { 0x04 }
sub FS_BIND_OBJECT () { 0x08 }
sub FS_BIND_BY_SUBJECT () { 0x1000000 }

pp $link->bind_limit_all(
    FS_BIND_SUBJECT | FS_BIND_PREDICATE | FS_BIND_OBJECT | FS_BIND_BY_SUBJECT,
    (map { FourStore::RidVector->new } 1 .. 4),
    0,
    0,
);

done_testing;
