use strict;
use warnings FATAL => 'all';
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    recursive_test_files => 1,
    dynamic_config       => 0,
    build_requires       => {
        'Test::More'      => '0.98',
        'Test::Exception' => '0.31',
    },
    configure_requires => { 'Module::Build' => '0.4003' },
    requires           => {
        'perl'         => '5.008001',
        'B'            => '0',
        'Carp'         => '0',
        'Class::Accessor::Lite' => '0.05',
        'Data::Clone'  => '0.003',
        'Exporter'     => '0',
        'JSON'         => '2.53',
        'URI::Escape'  => '3.31',
    },
    no_index    => { 'directory' => [ 'inc', 't', 'xt' ] },
    name        => 'JSON-Pointer',
    module_name => 'JSON::Pointer',
    test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',
    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
