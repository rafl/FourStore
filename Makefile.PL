use ExtUtils::MakeMaker;
use ExtUtils::Depends;

my $deps = ExtUtils::Depends->new('FourStore', 'XS::Object::Magic');
$deps->set_inc('-I../4store/src/common');

WriteMakefile(
    NAME => 'FourStore',
    VERSION_FROM => 'lib/FourStore.pm',
    $deps->get_makefile_vars,
);
