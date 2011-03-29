use ExtUtils::MakeMaker;
use ExtUtils::Depends;
use ExtUtils::PkgConfig;

my $deps = ExtUtils::Depends->new('FourStore', 'XS::Object::Magic');
$deps->set_inc('-I../4store/src/common');
$deps->set_libs('-l4store');

WriteMakefile(
    NAME => 'FourStore',
    VERSION_FROM => 'lib/FourStore.pm',
    $deps->get_makefile_vars,
);
