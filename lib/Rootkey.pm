package Rootkey;
use strict;
use warnings;
use utf8;
use parent qw/Amon2/;
our $VERSION='4.01';
use 5.008001;
use Rootkey::DB::Schema;
use Rootkey::DB;

my $schema = Rootkey::DB::Schema->instance;

sub db {
    my $c = shift;
    if (!exists $c->{db}) {
        my $conf = $c->config->{DBI}
            or die "Missing configuration about DBI";
        $c->{db} = Rootkey::DB->new(
            schema       => $schema,
            connect_info => [@$conf],
            # I suggest to enable following lines if you are using mysql.
            # on_connect_do => [
            #     'SET SESSION sql_mode=STRICT_TRANS_TABLES;',
            # ],
        );
    }
    $c->{db};
}

1;
