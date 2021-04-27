use Modern::Perl;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'SSAuthenticator',
    dist_author => 'Joonas Kylmälä <joonas.kylmala@jns.fi>',
    dist_abstract => 'Controls access to library',

    build_requires => {

    },
    requires => {
        'Bot::BasicBot'      => undef,
        'Carp::Always'       => undef,
        'Config::Simple'     => undef,
        'Crypt::Eksblowfish::Bcrypt' => undef,
        'Data::Alias'        => undef,
        'Data::Printer'      => undef,
        'DateTime'           => undef,
        'DateTime::Format::HTTP' => undef,
        'DBM::Deep'          => undef,
        'Digest::SHA'        => undef,
        'HTTP::Request::Common' => undef,
        'JSON::XS'           => undef,
        'Locale::TextDomain' => 1.30, # Later versions don't work
        'Log::Log4perl'      => undef,
        'LWP::UserAgent'     => undef,
        'Modern::Perl'       => undef,
        'POSIX'              => undef,
        'Sys::SigAction'     => undef,
        'Test::More'         => undef,
        'Test::MockModule'   => undef,
        'Try::Tiny'          => undef,
    },
);

$build->create_build_script;
