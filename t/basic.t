use strict;
use warnings;
use Test::More;

use FourStore;

my $link = FourStore::Link->new('foo', 'bar');

diag $link->features;

done_testing;
