use strict;
use warnings;

package FourStore;

use XSLoader;
use XS::Object::Magic;

our $VERSION = '0.01';

XSLoader::load(__PACKAGE__, $VERSION);

1;
