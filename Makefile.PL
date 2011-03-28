use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my %glib = ExtUtils::PkgConfig->find('glib-2.0');
my %avahi = ExtUtils::PkgConfig->find('avahi-client');

my $deps = ExtUtils::Depends->new('FourStore', 'XS::Object::Magic');
$deps->set_inc('-I../4store/src/common');
$deps->set_libs('-L. -l4store ' . join q[ ] => $glib{libs}, $avahi{libs});

WriteMakefile(
    NAME => 'FourStore',
    VERSION_FROM => 'lib/FourStore.pm',
    $deps->get_makefile_vars,
);
