use strict;
use warnings;
use Test::More;

use FourStore;

my $link = FourStore::Link->new('moo', 'bar');
isa_ok $link, 'FourStore::Link';

ok $link->features;

my $vec = FourStore::RidVector->new(42);
isa_ok $vec, 'FourStore::RidVector';
$vec->append(24, 32);
$vec->append_vector( $vec->copy );

ok $vec->length;
is ref $vec->data, ref [];

BEGIN {
    diag FourStore::FS_BIND_SUBJECT();
}

my @result = $link->bind_limit_all(
    FS_BIND_SUBJECT | FS_BIND_PREDICATE | FS_BIND_OBJECT | FS_BIND_BY_SUBJECT,
    (map { FourStore::RidVector->new } 1 .. 4),
    0,
    0,
);

is @result, 3;
isa_ok($_, 'FourStore::RidVector') for @result;

FourStore::Hash::hash_literal(0, 0);

done_testing;
