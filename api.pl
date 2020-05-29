use strict;
use warnings;

use FindBin '$Bin';
use lib ( $Bin . '/lib' );

use mysql_db;

use Mojolicious::Lite;

use Mojo::Util qw(secure_compare);
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
use Encode;
use utf8;

use EV;
use AnyEvent;
binmode( STDIN, ':utf8' );

BEGIN {
    use cfg_lib;
    cfg_lib::LoadConfig( $Bin . '/etc/db.cfg' );
}

# DB Connection
my $db = mysql_db->DB_Init( %{ $cfg_lib::config->{'db'} } );

# Go to the production!
app->mode('production');

# App instructions
get '/' => sub {
    my $self = shift;
    $self->render( text => "Hello." );
};

# Anything works, a long as it's GET and POST
any [ 'GET', 'POST' ] => '/v1/time' => sub {
    shift->render( json => { now => scalar(localtime) } );
};

get '/v1/animesearch' => sub {
    my $c = shift;

    my $name = $c->param('anime_name');
    unless ($name) {
        my $reject = {
            'code'        => 503,
            'description' => 'incorrect argument'
        };
        $c->render( json => $reject );
        return;
    }
    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare(
"SELECT anime_id, anime_year, anime_name, anime_name_russian, anime_studio, anime_description, anime_keywords, anime_episodes, anime_folder FROM anime  WHERE anime.anime_name LIKE ? or anime.anime_name_russian LIKE ? LIMIT 20"
    );

    $sth->execute( "%" . $name . "%", "%" . $name . "%" );

    my @titles = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        push @titles, $ref;
    }
    unless ( $titles[0] ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime rows are empty'
        };
        $c->render( json => $reject );
        return;
    }
    $c->render( json => \@titles );
};

get '/v1/anime/:anime_id' => sub {
    my $c = shift;

    my $id = $c->param('anime_id');
    unless ( looks_like_number($id) ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render( json => $reject );
        return;
    }

    my $dbh = $db->DB_GetLink();

    # Кто-нибудь, придумайте запрос умнее!
    my $sth = $dbh->prepare( "
        select a.anime_id, a.anime_year, a.anime_name, a.anime_name_russian, a.anime_studio, a.anime_description,
            a.anime_keywords, a.anime_episodes, a.anime_soft_raw_link, a.anime_ongoing, a.anime_folder,
            count(if(e.episode_type = 0, 1, null)) as episode_current_sub,
            count(if(e.episode_type = 1, 1, null)) as episode_current_dub
        from anime a join episodes e on a.anime_id = e.episode_anime
        where anime_id = ? and anime_disabled = 0
        group by a.anime_id
        limit 1"
    );
    $sth->execute( $id );

    my @titles = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        push @titles, $ref;
    }

    unless ( $titles[0] ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime rows are empty'
        };
        $c->render( json => $reject );
        return;
    }
    $c->render( json => \@titles );

};

get '/v1/anime/:anime_id/episodes' => sub {
    my $c = shift;

    my $a_id = $c->param('anime_id');
    unless ( looks_like_number($a_id) ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render( json => $reject );
        return;
    }
    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare(
"SELECT episode_anime,episode_id, episode_count, episode_view, episode_type FROM episodes WHERE episode_posted = 1 AND episodes.episode_anime = ?"
    );
    $sth->execute($a_id);

    my @episodes = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        if ( $ref->{'episode_type'} == 0 ) {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-subtitles';
        }
        else {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-dubbed';
        }
        push @episodes, $ref;
    }
    unless ( $episodes[0] ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime rows are empty'
        };
        $c->render( json => $reject );
        return;
    }
    $c->render( json => \@episodes );

};

get '/v1/episode/:episode_id' => sub {
    my $c = shift;

    my $e_id = $c->param('episode_id');
    unless ( looks_like_number($e_id) ) {
        my $reject = {
            'code'        => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render( json => $reject );
        return;
    }
    my $dbh = $db->DB_GetLink();

    my $sth = $dbh->prepare(
"SELECT episode_id, episode_anime, episode_type, episode_updated_at, episode_count, episode_view FROM episodes WHERE episode_posted = 1 AND episode_id = ?"
    );
    $sth->execute($e_id);

    my @episodes = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        if ( $ref->{'episode_type'} == 0 ) {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-subtitles';
        }
        else {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-dubbed';
        }
        push @episodes, $ref;
    }
    unless ( $episodes[0] ) {
        my $reject = {
            'code'        => 503,
            'description' => 'episodes rows are empty'
        };
        $c->render( json => $reject );
        return;
    }
    $c->render( json => \@episodes );
};

get '/v1/last_episodes' => sub {
    my $c = shift;

    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare(
"SELECT episode_id, episode_anime, episode_type, episode_updated_at, episode_count, episode_view FROM episodes WHERE episode_posted = 1 ORDER BY episode_id desc LIMIT 15"
    );
    $sth->execute();

    my @episodes = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        if ( $ref->{'episode_type'} == 0 ) {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-subtitles';
        }
        else {
            $ref->{'embed'} =
                'https://sovetromantica.com/embed/episode_'
              . $ref->{'episode_anime'} . '_'
              . $ref->{'episode_count'}
              . '-dubbed';
        }
        push @episodes, $ref;
    }
    $c->render( json => \@episodes );

};

get '/v1/list' => sub {
    my $c = shift;

    my $a_offset   = $c->param('offset');
    my $a_limit    = $c->param('limit');
    my $a_sudio_id = $c->param('studio');
    unless ( looks_like_number($a_limit) && $a_limit <= 30 ) {
        $a_limit = 30;
    }
    unless ( looks_like_number($a_offset) ) {
        $a_offset = 0;
    }
    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare(
"SELECT anime_id, anime_year, anime_name, anime_name_russian, anime_studio, anime_description, anime_keywords, anime_episodes, anime_folder FROM anime ORDER BY anime_id LIMIT ? OFFSET ?"
    );
    $sth->execute( $a_limit, $a_offset );

    my @anime = ();
    while ( my $ref = $sth->fetchrow_hashref() ) {
        push @anime, $ref;
    }
    $c->render( json => \@anime );

};

my $clients = {};
websocket '/v1/ws_episodes' => sub {
    my $self = shift;

    my $id = sprintf "%s", $self->tx;
    $clients->{$id} = $self->tx;

    $self->on(
        finish => sub {
            delete $clients->{$id};
        }
    );
    $self->on(
        message => sub {
            my ( $self, $message ) = @_;
            if ( $message eq 'ACK' ) {
                $self->send( { json => { 'answer' => 'im okey' } } );
            }
        }
    );
};

post '/v1/broadcast' => sub {
    my $self   = shift;
    my $secret = $self->param("secret");
    my $msg    = $self->param("query");

    my $token = $cfg_lib::config->{'secret'}->{'token'};

    unless ( $secret eq $token ) {
        $self->rendered(503);
        my $reject = { 'description' => 'incorrect token' };
        $self->render( json => $reject );
        return;
    }
    if ( length($msg) <= 1 ) {
        $self->rendered(503);
        my $reject = { 'description' => 'incorrect query' };
        $self->render( json => $reject );
        return;
    }
    for ( keys %$clients ) {
        $clients->{$_}->send( { text => $msg } );
    }
    $self->render( text => "ok" );
};

# Required
app->start;
