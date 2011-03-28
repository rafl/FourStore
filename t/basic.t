use strict;
use warnings;
use Test::More;

use FourStore;

my $link = FourStore::Link->new('moo', 'bar');
isa_ok $link, 'FourStore::Link';

ok $link->features;

diag $link->segments;

done_testing;
