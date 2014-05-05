use strict;
use warnings;
use URI;
use LWP::UserAgent;
use utf8;
use Data::Dumper;

my $uri = URI->new('http://gihyo.jp/');
my $ua = LWP::UserAgent->new();

print Dumper \$ua;

my $res = $ua->get( $uri );
die $res->status_line if $res->is_error;

#print Dumper \$res;

my ($title) = ($res->content =~ m!<title>(.+?)</title>!i);
print "$title\n";
