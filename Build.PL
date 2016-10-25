use Modern::Perl;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'SSAuthenticator',
    dist_author => 'Joonas Kylmälä <joonas.kylmala@jns.fi>',
    dist_abstract => 'Controls access to library',

    build_requires => {

    },
    requires => {
        'POSIX' => '1',
        'Locale::TextDomain' => '1.26',
        'Log::Log4perl' => '1.47',
        'Test::More' => '1',
        'Test::MockModule' => '0.05',
        'Modern::Perl' => '1',
        'Config::Simple' => '4',
        'DBM::Deep' => '2',
        'LWP::UserAgent' => '6',
        'HTTP::Request::Common' => '6',
        'JSON' => '2',
        'Sys::SigAction' => '0.20',
        'DateTime' => '1',
        'DateTime::Format::HTTP' => '0.4',
        'Digest::SHA' => '5',
    },
);

$build->create_build_script;
