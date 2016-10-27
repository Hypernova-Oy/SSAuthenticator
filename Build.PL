use Modern::Perl;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'SSAuthenticator',
    dist_author => 'Joonas Kylmälä <joonas.kylmala@jns.fi>',
    dist_abstract => 'Controls access to library',

    build_requires => {

    },
    requires => {
        'POSIX' => undef,
        'Locale::TextDomain' => undef,
        'Log::Log4perl' => undef,
        'Test::More' => undef,
        'Test::MockModule' => undef,
        'Modern::Perl' => undef,
        'Config::Simple' => undef,
        'DBM::Deep' => undef,
        'LWP::UserAgent' => undef,
        'HTTP::Request::Common' => undef,
        'JSON' => undef,
        'Sys::SigAction' => undef,
        'DateTime' => undef,
        'DateTime::Format::HTTP' => undef,
        'Digest::SHA' => undef,
    },
);

$build->create_build_script;
