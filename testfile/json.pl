#! /usr/bin/perl
use strict;
use warnings;
use JSON qw( decode_json );
use Encode qw( encode_utf8 );
use Data::Dumper;
use utf8;

#JSONからPerlへの変換
my $json_text = '{"user":"shirakiya","message":"\u304a\u306f\u3088\u3046"}';
my $ref = decode_json($json_text);
print Dumper $ref;
print encode_utf8("$ref->{user} : $ref->{message}\n");

#PerlからJSONへの変換
my $json = JSON->new;
$json->ascii(1);
$json_text = $json->encode({ user => 'shirakiya', message => 'おはよう' });
print Dumper $json_text;
print "$json_text\n";
