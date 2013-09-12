#! /usr/bin/perl
use strict;
use warnings;
use utf8;
use Data::Dumper;
use URI;
use LWP::UserAgent;
use JSON qw( decode_json );
use Encode qw( encode_utf8 );
use Math::Trig;

#設定項目
my $origin      = '箕面';
my $destination = '茨木';
my $radius      = 5000;
my $keyword     = '銭湯';
my $mode        = 'driving';
my $api         = 'AIzaSyC6MyJJ0JoQDbBqTunjCiTrXeClAn7uqJM';

#DirectionsResultの取得
my $directions_uri = URI->new('http://maps.googleapis.com/maps/api/directions/json');
$directions_uri->query_form(
    origin      => $origin,
    destination => $destination,
    sensor      => 'false',
    mode        => $mode,       #移動手段の選択
    avoid       => 'tolls',     #有料道路の選択
    units       => 'metric',    #単位系＝メートル
);

#Google Directions APIへのリクエストと最適化ルートの取得
my $ua                  = LWP::UserAgent->new();
my $directions_res      = $ua->get( $directions_uri );
die $directions_res->status_line if $directions_res->is_error;      #TODO ルートが検索できなかった時の画面も考えとく。
my $directions_res_json = $directions_res->content;
my $directions_res_perl = decode_json( $directions_res_json );

#DirectionsResultから必要なデータを抜き取る。
my $legs_0     = $directions_res_perl->{routes}->[0]->{legs}->[0];
my $steps      = $legs_0->{steps};
my $copyrights = encode_utf8($directions_res_perl->{routes}->[0]->{copyrights});
my $dep_des    = {
    dep_lat      => $legs_0->{start_location}->{lat},
    dep_lng      => $legs_0->{start_location}->{lng},
    des_lat      => $legs_0->{end_location}->{lat},
    des_lng      => $legs_0->{end_location}->{lng},
    sum_distance => $legs_0->{distance}->{value},
};

#出発地と目的地の直線距離を求める
#my $dep_des_d = distance( $dep_des->{dep_lat}, $dep_des->{dep_lng}, $dep_des->{des_lat}, $dep_des->{des_lng});

#Placesでの検索を行う座標の取得
my @search_co;
push_search_co( $dep_des->{dep_lat}, $dep_des->{dep_lng} );
#ステップの合計距離が直径よりも大きくなった場合->つまり、ステップ毎にフォーカスしなければならない場合
if ( $dep_des->{sum_distance} > 2 * $radius ) {
    my $accumulated_value = 0;
    my $step_co;

    for my $step ( @$steps ) {
        $step_co = {
            start_lat => $step->{start_location}->{lat},
            start_lng => $step->{start_location}->{lng},
            end_lat   => $step->{end_location}->{lat},
            end_lng   => $step->{end_location}->{lng},
        };
        my $step_d = distance( $step_co->{start_lat}, $step_co->{start_lng}, $step_co->{end_lat}, $step_co->{end_lng} );

        #一つのステップの直線距離が直径よりも大きい場合
        if( $step_d > 2 * $radius ) {
            print "hoge\n";
            #ワンステップ分割法発動
            my $split_step_num = ceil( $step_d / ( 2 * $radius ) );
            my $inc_delta_lat  = ( $step_co->{end_lat} - $step_co->{start_lat} )/$split_step_num;
            my $inc_delta_lng  = ( $step_co->{end_lng} - $step_co->{start_lng} )/$split_step_num;

            #これまでのルートの合計距離が半径以上になっている場合にのみ始点での検索を行う
            if ( $accumulated_value > $radius ) {
                push_search_co( $step_co->{start_lat}, $step_co->{start_lng} );
            }
            #分割点での検索
            my $count = 0;
            while ( $count == $split_step_num ) {
                $step_co->{start_lat} += $inc_delta_lat;
                $step_co->{start_lng} += $inc_delta_lng;
                push_search_co( $step_co->{start_lat}, $step_co->{start_lng} );
                $count++;
            }
            $accumulated_value = 0;
        }
        #累積ステップ距離が直径よりも大きくなった場合
        elsif ( $accumulated_value + $step->{distance}->{value} > 2 * $radius ) {
            print "fugafuga\n";
            push_search_co( $step_co->{start_lat}, $step_co->{start_lng} );
            $accumulated_value  = 0;
        }
        else {
            $accumulated_value += $step->{distance}->{value};
            print "hogehogehoge\n";
        }
    }
}
push_search_co( $dep_des->{des_lat}, $dep_des->{des_lng} );

#Places検索かつ重複処理
my %key_exist_test;
my @marker_info;
my $institution_info;

for my $co ( @search_co ) {
    my $places_results = places( $co->{lat}, $co->{lng} );
    for $institution_info ( @$places_results ) {
        unless ( exists $key_exist_test{$institution_info->{id}} ) {
            $key_exist_test{$institution_info->{id}} = 1;
            my $marker = {
                id   => $institution_info->{id},
                name => encode_utf8( $institution_info->{name} ),
                lat  => $institution_info->{geometry}->{location}->{lat},
                lng  => $institution_info->{geometry}->{location}->{lng},
            };
            push @marker_info, $marker;
        }
    }
}



#----------------サブルーチン-----------------

#座標間距離を求めるサブルーチン
sub distance {
    my ( $start_lat, $start_lng, $end_lat, $end_lng ) = @_;

    my $delta_lat          = $end_lat - $start_lat;
    my $delta_lng          = $end_lng - $start_lng;
    my $lat_by_distance    = 111319.489;
    my $delta_lat_distance = $delta_lat * $lat_by_distance;
    my $delta_lng_distance = $delta_lng * cos( 2 * pi * $end_lat / 360 ) * $lat_by_distance;
    my $d                  = sqrt( $delta_lat_distance**2 + $delta_lng_distance**2 );

    return $d;
}


#Placesで検索を行う座標を格納するサブルーチン
sub push_search_co {
    my ( $search_lat, $search_lng ) = @_;

    push @search_co, { lat => $search_lat, lng => $search_lng };

    return @search_co;
}


#Placesへのリクエストと検索結果オブジェクト取得サブルーチン
sub places{
    my ($lat, $lng ) = @_;

    my $places_uri   = URI->new('https://maps.googleapis.com/maps/api/place/search/json');
    $places_uri->query_form(
        key      => $api,
        location => "$lat,$lng",
        radius   => $radius,
        sensor   => 'false',
        keyword  => $keyword,
        language => 'ja',
    );

    my $ua              = LWP::UserAgent->new();
    my $places_res      = $ua->get( $places_uri );
    die $places_res->status_line if $places_res->is_error;
    my $places_res_json = $places_res->content;
    my $places_res_perl = decode_json( $places_res_json );
    my $places_results  = $places_res_perl->{results};

    return $places_results;
}


#切り上げ処理
sub ceil {
    my $num = shift;

    my $val = 0;
    $val = 1 if( $num > 0 and $num != int( $num ) );

    return int( $num + $val );
}
