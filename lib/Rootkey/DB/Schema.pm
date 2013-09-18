package Rootkey::DB::Schema;
use strict;
use warnings;
use utf8;

use Teng::Schema::Declare;

base_row_class 'Rootkey::DB::Row';

table {
    name 'account';
    pk 'id';
    columns qw(
        id
        account_id
        account_password
    );
};

table {
    name 'search';
    pk 'search_id';
    columns qw(
        search_id
        search_department_word
        search_destination_word
        search_keyword
        search_mode
        search_radius
        search_name
        search_created_at
        search_updated_at
        search_account_id
    );
};

table {
    name 'waypoint';
    pk 'adhesive_id';
    columns qw(
        waypoint_id
        waypoint_search_id
        waypoint_account_id
        waypoint_word_id
        waypoint_lat
        waypoint_lng
    );
};

table {
    name 'result';
    pk 'result_id';
    columns qw(
        result_id
        result_search_id
        result_institution_id
        result_institution_lat
        result_institution_lng
        result_institution_name
        result_reference
        result_created_at
    );
};

1;
