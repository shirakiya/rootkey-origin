use strict;
use warnings;
use URI;

my $uri = URI->new('http://maps.googleapis.com/maps/api/directions/json?');
$uri->query_form(
    origin => '箕面',
    hoge => '梅田',
);

print "$uri\n";
