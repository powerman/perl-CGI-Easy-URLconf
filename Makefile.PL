use inc::Module::Install;

name     'CGI-Easy-URLconf';
all_from 'lib/CGI/Easy/URLconf.pm';

requires        'version';
requires        'Perl6::Export::Attrs';
requires        'URI::Escape';

test_requires   'Test::More';
test_requires   'Test::Exception';

recommends      'Test::CheckManifest'   => '0.9';
recommends      'Test::Perl::Critic';
recommends      'Test::Pod::Coverage'   => '1.08';
recommends      'Pod::Coverage'         => '0.18';
recommends      'Test::Pod'             => '1.22';

auto_install;

WriteAll;

