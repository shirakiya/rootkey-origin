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

#-----------メインページ-------------
any '/' => sub {
    my $c = shift;

    if ( my $session_account = $c->session->get( 'account_info' ) ) {
        return $c->render(
            'index.tt' => {
                account_id => $session_account->{account_id},
                login      => 1,
            },
        );
    }
    else {
        return $c->render('index.tt');
    }
};


#-----------ヘルプページ--------------
any '/help' => sub {
    my $c = shift;

    if ( my $session_account = $c->session->get( 'account_info' ) ) {
        return $c->render(
            'help.tt' => {
                account_id => $session_account->{account_id},
                login      => 1,
            },
        )
    }
    else {
        return $c->render('help.tt');
    }
};


#--------新規アカウント作成-----------
any '/new' => sub {
    my $c = shift;
    return $c->render('new_account.tt')
};


#---------ログインページ--------------
any '/login' => sub {
    my $c = shift;
    #ログインされていればmypageに飛ぶ
    if ( my $session_account = $c->session->get( 'account_info' ) ) {
        return $c->redirect( '/mypage' );
    }
    else {
        return $c->render('login.tt');
    }
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
    my $account_id_match = $c->db->single( 'account', { account_id => $user_input->{account_id}} );
    if ( $account_id_match ) {
        return $c->render(
            'new_account.tt' => {
                account_id_used => 1,
            },
        );
    }
    #アカウント情報をDBへ記録
    $c->db->insert( account => {
            account_id       => $user_input->{account_id},
            account_password => $user_input->{password},
    });
    #そのユーザ固有のセッションを持たせる
    my $account_info_itr = $c->db->single( 'account', { account_id => $user_input->{account_id} } );
    my $account_info     = $account_info_itr->get_columns;
    $c->session->set( 'account_info' => $account_info );
    return $c->redirect( '/mypage' );
};


#--------ログイン-----------
post '/login/post' => sub {
    my $c = shift;

    my $user_input = {
        account_id => $c->req->param( 'account_id' ),
        password   => $c->req->param( 'account_password' ),
    };
    #入力項目が不足しているとき
    if ( $user_input->{account_id} eq "" || $user_input->{password} eq "" ) {
        return $c->render(
            'login.tt' => {
                no_input_login => 1,
            },
        );
    }
    #DBにaccount_idが登録されているかどうかを調査。
    my $matching_account = $c->db->single( 'account', { account_id => $user_input->{account_id} } );
    if ( $matching_account ) {
        my $account_info = $matching_account->get_columns;
        if ( $account_info->{account_password} eq $user_input->{password} ) {
            $c->session->set( 'account_info' => $account_info );
            if ( $c->req->param( 'came_from_register' ) ) {
                return $c->redirect( '/' );
            }
            else {
                return $c->redirect( '/mypage' );
            }
        } else {
            return $c->render(
                'login.tt' => {
                    password_mismatch => 1,
                },
            );
        }
    }
    else {
        return $c->render(
            'login.tt' => {
                no_register_account => 1,
            },
        );
    }
};


#--------Myページ------------
any '/mypage' => sub {
    my $c = shift;

    if ( my $session_account = $c->session->get( 'account_info' ) ) {
        my @search_history = $c->db->search( 'search', { search_account_id => $session_account->{id} },{ order_by => { 'search_id' => 'DESC' } } );

        return $c->render(
            'mypage.tt' => {
                account_id     => $session_account->{account_id},
                search_history => \@search_history,
                login          => 1,
                #waypointの情報も渡す。
            },
        );
    }
    else {
        return $c->redirect( '/login' );
    }
};


#----------ログアウト---------
any '/logout' => sub {
    my $c = shift;

    $c->session->expire();

    return $c->render( 'logout.tt' );
};


#--------検索結果登録---------
post '/register/post' => sub {
    my $c = shift;

    if ( (my $session_account = $c->session->get( 'account_info' )) && (my $user_input = $c->session->get( 'user_input' )) && (my $marker_info = $c->session->get( 'marker_info' )) ) {
        my $search_name = $c->req->param( 'search_name' );

        my $last_insert_id_search = $c->db->fast_insert( 'search' => {
            search_department_word  => $user_input->{origin},
            search_destination_word => $user_input->{destination},
            search_keyword          => $user_input->{keyword},
            search_radius           => $user_input->{radius},
            search_name             => $search_name,
            search_mode             => $user_input->{mode},
            search_account_id       => $session_account->{id},
        });
        for my $one_marker_info ( @$marker_info ) {
            $c->db->insert( 'result' => {
                result_search_id        => $last_insert_id_search,
                result_institution_id   => $one_marker_info->{id},
                result_institution_name => $one_marker_info->{name},
                result_institution_lat  => $one_marker_info->{lat},
                result_institution_lng  => $one_marker_info->{lng},
                result_reference        => $one_marker_info->{reference},
            });
        }

        $c->session->set( 'user_input'  => '' );
        $c->session->set( 'marker_info' => '' );

        return $c->render(
            'register.tt' => {
                login => 1,
            },
        );
    }
    else {
       return $c->render(
           'login.tt' => {
               came_from_register => 1,
            },
        );
    }
};


#-----走査型検索ロジック------
get '/get' => sub {
    my $c = shift;

    if ( my $search_id = $c->req->param('came_from_history') ){
        my $session_account = $c->session->get( 'account_info' );

        my $user_input_itr = $c->db->single( 'search', { search_id => $search_id } );
        my $user_input_db  = $user_input_itr->get_columns;
        my $user_input     = {
                origin      => $user_input_db->{search_department_word},
                destination => $user_input_db->{search_destination_word},
                mode        => $user_input_db->{search_mode},
                radius      => $user_input_db->{search_radius},
        };

        my @marker_info_db = $c->db->search( 'result', { result_search_id => $search_id},{ order_by => { 'result_id' => 'DESC' }}  );
        my @marker_info;
        for my $one_marker_info_itr ( @marker_info_db ) {
            my $one_marker_info = $one_marker_info_itr->get_columns;
            my $marker          = {
                id        => $one_marker_info->{result_institution_id},
                name      => $one_marker_info->{result_institution_name},
                lat       => $one_marker_info->{result_institution_lat},
                lng       => $one_marker_info->{result_institution_lng},
                reference => $one_marker_info->{result_reference},
            };
            push @marker_info, $marker;
        }

        return $c->render(
            'index.tt' => {
                account_id  => $session_account->{account_id},
                user_input  => $user_input,
                marker_info => \@marker_info,
                map_display => 1,
                login       => 1,
            },
        );
    }
    else {
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
        my $legs_0              = $directions_res_perl->{routes}->[0]->{legs}->[0];
        my $steps               = $legs_0->{steps};
        my $copyrights          = encode_utf8( $directions_res_perl->{routes}->[0]->{copyrights} );
        my $dep_des             = {
            dep_lat      => $legs_0->{start_location}->{lat},
            dep_lng      => $legs_0->{start_location}->{lng},
            des_lat      => $legs_0->{end_location}->{lat},
            des_lng      => $legs_0->{end_location}->{lng},
            sum_distance => $legs_0->{distance}->{value},
        };

        my @search_co;
        push @search_co, { lat => $dep_des->{dep_lat}, lng => $dep_des->{dep_lng} };
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
                    my $split_step_num = ceil( $step_d / ( 2 * $user_input->{radius} ) );
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
                    push @search_co, { lat => $step_co->{start_lat}, lng => $step_co->{start_lng}, };
                    $accumulated_value = 0;
                }
                else {
                    $accumulated_value += $step->{distance}->{value};
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
                }
            }
        }

        $c->session->set( 'user_input'  => $user_input );
        $c->session->set( 'marker_info' => \@marker_info );
        if ( my $session_account = $c->session->get( 'account_info' ) ) {
            return $c->render(
                'index.tt' => {
                    account_id  => $session_account->{account_id},
                    user_input  => $user_input,
                    search_co   => \@search_co,
                    marker_info => \@marker_info,
                    map_display => 1,
                    login       => 1,
                },
            );
        }
        else {
            return $c->render(
                'index.tt' => {
                    user_input  => $user_input,
                    search_co   => \@search_co,
                    marker_info => \@marker_info,
                    map_display => 1,
                },
            );
        }
    }

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
