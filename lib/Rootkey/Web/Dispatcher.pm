package Rootkey::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use URI;
use LWP::UserAgent;
use JSON qw( decode_json );
use Encode qw( encode_utf8 );
use Math::Trig;
use Amon2::Web::Dispatcher::Lite;

any '/' => sub {
    my $c = shift;
    #print Dumper $c;
    return $c->render('index.tt');
};

#post '/account/logout' => sub {
#    my ($c) = @_;
#    $c->session->expire();
#    return $c->redirect('/');
#};

any '/help' => sub {
    my $c = shift;
    return $c->render('help.tt');
};

any '/login' => sub {
    my $c = shift;
    return $c->render('login.tt');
};

any '/new' => sub {
    my $c = shift;
    return $c->render('new_account.tt')
};

#----------新規アカウント作成-----------
post '/new/post' => sub {
    my $c = shift;

    my $user_input = {
        account_id => $c->req->param('account_id'),
        password   => $c->req->param('account_password'),
        password_2 => $c->req->param('account_password_2'),
    };
    #入力項目が不足しているとき
    if ( $user_input->{account_id} eq "" || $user_input->{password} eq "" || $user_input->{password_2} eq "" ) {
        return $c->render(
            'new_account.tt' => {
                no_input => 1,
            },
        );
    }
    #パスワードが一致していないとき
    unless ( $user_input->{password} eq $user_input->{password_2} ) {
        return $c->render(
            'new_account.tt' => {
                password_mismatch => 1,
            },
        );
    }
    #既にIDが使用されているとき（これでIDは全て異なることになる）
    my @account_id = $c->db->search_by_sql( q{SELECT account_id FROM account} );       #TODO より良いaccount_idだけ配列で取り出す方法？
    #print Dumper @account_id;
    for ( @account_id ) {
        #print Dumper $_;
        if ( $_ eq $user_input->{account_id} ) {
            print "fugafuga\n";
            return $c->render(
                'new_account.tt' => {
                    account_id_used => 1,
                },
            );
        }
    }
    #アカウント情報をDBへ記録
    $c->db->insert( account => {
            account_id       => $user_input->{account_id},
            account_password => $user_input->{password},
    });
    #そのユーザ固有のセッションを持たせる
    my $account_info   = $c->db->single( 'account', { account_id => $user_input->{account_id} } );
    $c->session->set( 'account_info' => $account_info );

    return $c->redirect( '/mypage' );
    #    'mypage.tt' => {
    #        account_id     => $account_info->{account_id},
    #        search_history => \@search_history,
    #    },
    #);

};

#--------Myページ------------
any '/mypage' => sub {
    my $c = shift;

    my $account_info;
    if ( $account_info = $c->session->get( 'account_info' ) ) {
        my @search_history = $c->db->search( 'search', { search_account_id => $account_info->{id} },{ order_by => { 'search_id' => 'DESC' } } );

        return $c->render(
            'mypage.tt' => {
                account_id => $account_info->{account_id},
                search_history => \@search_history,
            },
        );
    }
    else {
        return $c->redirect( '/login' );
    }

};

#---------ログアウト---------
any '/logout' => sub {
    my $c = shift;

    $c->session->expire();

    return $c->redirect( '/' );
};

#---------走査型検索----------
get '/get' => sub {
    my $c = shift;

    my $user_input = {
        origin      => $c->req->param('origin'),
        destination => $c->req->param('destination'),
        waypoint    => $c->req->param('waypoint'),
        mode        => $c->req->param('mode'),
        radius      => $c->req->param('radius'),
        keyword     => $c->req->param('keyword'),
    };
    if ( $user_input->{origin} eq "" || $user_input->{destination} eq "" || $user_input->{keyword} eq "" ) {
        return $c->render('no_input.tt');
    }

    #TODO ログインしていればこれらの検索条件をDBへ格納する。


    my $directions_uri = URI->new('http://maps.googleapis.com/maps/api/directions/json');
    $directions_uri->query_form (
            origin      => $user_input->{origin},
            destination => $user_input->{destination},
            sensor      => 'false',
            mode        => $user_input->{mode},
            avoid       => 'tolls',
            units       => 'metric',
    );

    my $ua                  = LWP::UserAgent->new();
    my $directions_res      = $ua->get( $directions_uri );
    return $c->render('search_incapable.tt') if $directions_res->is_error;

    my $directions_res_json = $directions_res->content;
    my $directions_res_perl = decode_json( $directions_res_json );
    my $legs_0     = $directions_res_perl->{routes}->[0]->{legs}->[0];
    my $steps      = $legs_0->{steps};
    my $copyrights = encode_utf8( $directions_res_perl->{routes}->[0]->{copyrights} );
    my $dep_des    = {
        dep_lat      => $legs_0->{start_location}->{lat},
        dep_lng      => $legs_0->{start_location}->{lng},
        des_lat      => $legs_0->{end_location}->{lat},
        des_lng      => $legs_0->{end_location}->{lng},
        sum_distance => $legs_0->{distance}->{value},
    };

    my @search_co;
    push @search_co, { lat => $dep_des->{dep_lat}, lng => $dep_des->{dep_lng} };
    #TODO 検索ロジックの再検討
    if ( $dep_des->{sum_distance} > 2 * $user_input->{radius} ) {
        my $accumulated_value = 0;
        my $step_co;

        for my $step ( @$steps ) {
            $step_co = {
                start_lat => $step->{start_location}->{lat},
                start_lng => $step->{start_location}->{lng},
                end_lat   => $step->{end_location}->{lat},
                end_lng   => $step->{end_location}->{lng},
            };
            my $step_d = distance( $step_co->{start_lat}, $step_co->{start_lng}, $step_co->{end_lat}, $step_co->{end_lng}, );

            if ( $step_d > 2 * $user_input->{radius} ) {
                print "hoge\n";
                my $split_step_num = ceil( $step_d / ( 2 * $user_input->{radius} ) );
                print "$split_step_num\n";
                my $inc_delta_lat  = ( $step_co->{end_lat} - $step_co->{start_lat} ) / $split_step_num;
                my $inc_delta_lng  = ( $step_co->{end_lng} - $step_co->{start_lng} ) / $split_step_num;

                if ( $accumulated_value > $user_input->{radius} ) {
                    push @search_co, { lat => $step_co->{start_lat}, lng => $step_co->{start_lng}, };
                }

                my $count = 0;
                while ( $count < $split_step_num ) {
                    $step_co->{start_lat} += $inc_delta_lat;
                    $step_co->{start_lng} += $inc_delta_lng;
                    push @search_co, { lat => $step_co->{start_lat}, lng => $step_co->{start_lng}, };
                    $count++;
                }
                $accumulated_value = 0;
            }
            elsif ( $accumulated_value + $step->{distance}->{value} > 2 * $user_input->{radius} ) {
                print "fugafuga\n";
                push @search_co, { lat => $step_co->{start_lat}, lng => $step_co->{start_lng}, };
                $accumulated_value = 0;
            }
            else {
                $accumulated_value += $step->{distance}->{value};
                print "hogehogehoge\n";
            }
        }
    }
    push @search_co, { lat => $dep_des->{des_lat}, lng => $dep_des->{des_lng}, };

    my %key_exist_test;
    my @marker_info;
    my $institution_info;

    for my $co ( @search_co ) {
        my $places_results = places( $co->{lat}, $co->{lng}, $user_input->{radius}, $user_input->{keyword}, $c, );
        for $institution_info ( @$places_results ) {
            unless ( exists $key_exist_test{$institution_info->{id}} ) {
                $key_exist_test{$institution_info->{id}} = 1;
                my $marker = {
                    id        => $institution_info->{id},
                    name      => encode_utf8( $institution_info->{name} ),
                    lat       => $institution_info->{geometry}->{location}->{lat},
                    lng       => $institution_info->{geometry}->{location}->{lng},
                    reference => $institution_info->{reference},
                };
                push @marker_info, $marker;
                #もしログインしているのならばDBヘデータを格納
                #$c->db->insert( result => +{
                #        #result_search_id       => searchテーブルのidを持ってくる
                #        result_institution_id   => $institution_info->{id},
                #        result_institution_name => encode_utf8( $institution_info->{name} ),
                #        result_institution_lat  => $institution_info->{geometry}->{location}->{lat},
                #        result_institution_lng  => $institution_info->{geometry}->{location}->{lng},
                #        result_reference        => $institution_info->{reference},
                #});
            }
        }
    }

    return $c->render(
        'index.tt' => {
            user_input  => $user_input,
            search_co   => \@search_co,
            marker_info => \@marker_info,
            map_display => 1,
        },
    );


    #----------サブルーチン-----------

    #座標間距離を求める
    sub distance {
        my ( $start_lat, $start_lng, $end_lat, $end_lng ) = @_;

        my $delta_lat          = $end_lat - $start_lat;
        my $delta_lng          = $end_lng -$start_lng;
        my $distance_by_lat    = 111319.489;
        my $delta_lat_distance = $delta_lat * $distance_by_lat;
        my $delta_lng_distance = $delta_lng * cos( 2 * pi * $end_lat / 360 ) * $distance_by_lat;
        my $d                  = sqrt( $delta_lat_distance**2 + $delta_lng_distance**2 );

        return $d;
    }


    #Placesへのリクエストと検索結果オブジェクト取得
    sub places {
        my ( $lat, $lng, $radius, $keyword, $c ) = @_;

        my $api        = 'AIzaSyC6MyJJ0JoQDbBqTunjCiTrXeClAn7uqJM';
        my $places_uri = URI->new('https://maps.googleapis.com/maps/api/place/search/json');
        $places_uri->query_form (
            key      => $api,
            location => "$lat,$lng",
            radius   => $radius,
            sensor   => 'false',
            keyword  => $keyword,
            language => 'ja',
        );

        my $ua              = LWP::UserAgent->new();
        my $places_res      = $ua->get( $places_uri );
        return $c->render('search_incapable.tt') if $places_res->is_error;

        my $places_res_json = $places_res->content;
        my $places_res_perl = decode_json( $places_res_json );
        my $places_results  = $places_res_perl->{results};

        return $places_results;
    }


    #切り上げ処理
    sub ceil {
        my $num = shift;

        my $val = 0;
        $val = 1 if ( $num > 0 and $num != int( $num ) );

        return int( $num + $val );
    }
    #--------------------------------
};


1;
