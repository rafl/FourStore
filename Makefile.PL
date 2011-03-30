use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my %fourstore = ExtUtils::PkgConfig->find('4store-0');

my $deps = ExtUtils::Depends->new('FourStore', 'XS::Object::Magic');
$deps->set_inc($fourstore{cflags});
$deps->set_libs($fourstore{libs});

WriteMakefile(
    NAME => 'FourStore',
    VERSION_FROM => 'lib/FourStore.pm',
    $deps->get_makefile_vars,
);
