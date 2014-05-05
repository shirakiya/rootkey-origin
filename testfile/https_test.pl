#! /usr/bin/perl
use strict;
use warnings;
use utf8;
use URI;
use LWP::UserAgent;
use HTTP::Request;

my $places_uri = URI->new('https://maps.googleapis.com/maps/api/place/search/json');
$places_uri->query_form(
    key => 'AIzaSyC6MyJJ0JoQDbBqTunjCiTrXeClAn7uqJM',
    location => '34.8263774,135.4702585',
    radius => '5000',
    sensor => 'false',
    keyword => '銭湯',
    language => 'ja',
    #rankby => 'distance'
);
print "$places_uri\n";
my $ua = LWP::UserAgent->new();
my $res = $ua->get($places_uri);
    die $res->status_line if $res->is_error;
my $res_json = $res->content;
print "$res_json\n";
