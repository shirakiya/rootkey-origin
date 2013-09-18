use strict;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;

use Rootkey::Web;
use Rootkey;
#use Cache::Memcached::Fast;
use YAML;
use Plack::Session::Store::File;
use Plack::Session::State::Cookie;
use URI::Escape;
use File::Path ();

my $session_dir = File::Spec->catdir(File::Spec->tmpdir, uri_escape("Rootkey") . "-$<" );
File::Path::mkpath($session_dir);
builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon\.ico)$},
        root => File::Spec->catdir(dirname(__FILE__), 'static');
    enable 'Plack::Middleware::ReverseProxy';

    #enable 'Plack::Middleware::Session',
    #    store => Plack::Session::Store::Cache->new(
    #        cache => Cache::Memcached::Fast->new( +{
    #            servers   => ["localhost:11211"],
    #            namespace => 'Rootkey',
    #        }),
    #    ),
    #    state => Plack::Session::State::Cookie->new(
    #        session_key => 'Rootkey_session',
    #        httponly    => 1,
    #        expires     => 604800,
    #    );

    # If you want to run the app on multiple servers,
    # you need to use Plack::Sesion::Store::DBI or ::Store::Cache.
    enable 'Plack::Middleware::Session',
        store => Plack::Session::Store::File->new(
            dir => $session_dir,
            serializer   => sub { YAML::DumpFile( reverse @_ ) },
            deserializer => sub { YAML::LoadFile( @_ ) },
        ),
        state => Plack::Session::State::Cookie->new(
            httponly => 1,
            expires  => 3600,
        );
    Rootkey::Web->to_app();
};
