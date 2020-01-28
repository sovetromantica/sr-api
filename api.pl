use strict;
use warnings;

use FindBin '$Bin';
use lib ($Bin.'/lib');

use mysql_db;

use Mojolicious::Lite;

use Mojo::Util qw(secure_compare);
use Scalar::Util qw(looks_like_number);
use Data::Dumper;
use Encode;
use utf8;
binmode (STDIN,':utf8');
BEGIN {
    use cfg_lib;
    cfg_lib::LoadConfig($Bin.'/etc/db.cfg');
}

# DB Connection
my $db = mysql_db->DB_Init(
    %{$cfg_lib::config->{'db'}}
);

# App instructions
get '/' => qw(index);

# Anything works, a long as it's GET and POST
any ['GET', 'POST'] => '/v1/time' => sub {
    shift->render(json => { now => scalar(localtime) });
};

# Just a GET request
get '/v1/epoch' => sub {
    shift->render(json => { now => time });
};

get '/v1/animesearch' => sub {
    my $c = shift;

    my $name = $c->param('anime_name');
    unless ($name) {
         my $reject = {
            'code' => 503,
            'description' => 'incorrect argument'
        };
        $c->render(json => $reject);
        return;               
    }
    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare("SELECT anime_id, anime_year, anime_name, anime_name_russian, anime_studio, anime_description, anime_keywords, anime_episodes FROM anime  WHERE anime.anime_name LIKE ? or anime.anime_name_russian LIKE ?");
    $sth->execute("%".$name."%","%".$name."%");
    
    my @titles = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push @titles, $ref;
    }
    unless($titles[0]) {
         my $reject = {
            'code' => 503,
            'description' => 'anime rows are empty'
        };
        $c->render(json => $reject);
        return;       
    }
    $c->render(json => \@titles);
};

get '/v1/anime/:anime_id' => sub {
    my $c = shift;

    my $id = $c->param('anime_id');
    unless (looks_like_number($id)) {
        my $reject = {
            'code' => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render(json => $reject);
        return;
    };

    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare("SELECT anime_id, anime_year, anime_name, anime_name_russian, anime_studio, anime_description, anime_keywords, anime_episodes FROM anime WHERE anime_disabled = 0 and anime_id = ?");
    $sth->execute($id);
    
    my @titles = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push @titles, $ref;
    }

    unless($titles[0]) {
         my $reject = {
            'code' => 503,
            'description' => 'anime rows are empty'
        };
        $c->render(json => $reject);
        return;       
    }
    $c->render(json => \@titles);

};

get '/v1/anime/:anime_id/episodes' => sub {
    my $c = shift;

    my $a_id = $c->param('anime_id');
    unless (looks_like_number($a_id)) {
        my $reject = {
            'code' => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render(json => $reject);
        return;
    };
    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare("SELECT episode_anime,episode_id, episode_count, episode_view, episode_type FROM episodes WHERE episode_posted = 1 AND episodes.episode_anime = ?");
    $sth->execute($a_id);  

    my @episodes = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        if ($ref->{'episode_type'} == 0) {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'. $ref->{'episode_anime'} .'_'.$ref->{'episode_count'}.'-subtitles';
        } else {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'. $ref->{'episode_anime'} .'_'.$ref->{'episode_count'}.'-dubbed';
        }
        push @episodes, $ref;
    } 
    unless($episodes[0]) {
         my $reject = {
            'code' => 503,
            'description' => 'anime rows are empty'
        };
        $c->render(json => $reject);
        return;       
    }
    $c->render(json => \@episodes);
   
};

get '/v1/episode/:episode_id' => sub {
    my $c = shift;

    my $e_id = $c->param('episode_id');
    unless (looks_like_number($e_id)) {
        my $reject = {
            'code' => 503,
            'description' => 'anime_id is not a number'
        };
        $c->render(json => $reject);
        return;
    };
    my $dbh = $db->DB_GetLink();

    my $sth = $dbh->prepare("SELECT episode_id, episode_anime, episode_type, episode_updated_at, episode_count, episode_view FROM episodes WHERE episode_posted = 1 AND episode_id = ?");
    $sth->execute($e_id);  

    my @episodes = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        if ($ref->{'episode_type'} == 0) {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'. $ref->{'episode_anime'} .'_'.$ref->{'episode_count'}.'-subtitles';
        } else {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'.$ref->{'episode_anime'}.'_'.$ref->{'episode_count'}.'-dubbed';
        }
        push @episodes, $ref;
    } 
    unless($episodes[0]) {
         my $reject = {
            'code' => 503,
            'description' => 'episodes rows are empty'
        };
        $c->render(json => $reject);
        return;       
    }
    $c->render(json => \@episodes);    
};

get '/v1/last_episodes' => sub {
    my $c = shift;

    my $dbh = $db->DB_GetLink();
    my $sth = $dbh->prepare("SELECT episode_id, episode_anime, episode_type, episode_updated_at, episode_count, episode_view FROM episodes WHERE episode_posted = 1 ORDER BY episode_id desc LIMIT 15");
    $sth->execute();  

    my @episodes = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        if ($ref->{'episode_type'} == 0) {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'. $ref->{'episode_anime'} .'_'.$ref->{'episode_count'}.'-subtitles';
        } else {
            $ref->{'embed'} = 'https://sovetromantica.com/embed/episode_'.$ref->{'episode_anime'}.'_'.$ref->{'episode_count'}.'-dubbed';
        }
        push @episodes, $ref;
    } 
    $c->render(json => \@episodes);
   
};
# Required
app->start;
