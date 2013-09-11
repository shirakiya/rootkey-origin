package Rootkey::DB::Schema;
use strict;
use warnings;
use utf8;

use Teng::Schema::Declare;

base_row_class 'Rootkey::DB::Row';

table {
    name 'member';
    pk 'id';
    columns qw(id name);
};

1;
