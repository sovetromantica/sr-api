package mysql_db;

use strict;
use warnings;
use DBI;

our $DB_links_cnt = 2;
our $DB_links_hash = {};
our $DB_links_nextnum = 0;


sub DB_Init {
    my $class = shift;
    my $self = { @_ };

    $self->{DB_HOST} = $ENV{'DB_HOST'} if (!defined $self->{DB_HOST});
    $self->{DB_PORT} = $ENV{'DB_PORT'} if (!defined $self->{DB_PORT});

    $self->{DB_NAME} = $ENV{'DB_NAME'} if (!defined $self->{DB_NAME});
    $self->{DB_USER} = $ENV{'DB_USER'} if (!defined $self->{DB_USER});
    $self->{DB_PASS} = $ENV{'DB_PASS'} if (!defined $self->{DB_PASS});

    bless($self, $class);

    for (my $i = 0; $i < $DB_links_cnt; $i++) {
        $DB_links_hash->{$i} = $self->DB_Connect();
    }	

    return $self;
}

### MySQL Connectors ###
sub DB_Connect {
    my $self = shift;

    my $dsn = sprintf('DBI:mysql:database=%s;host=%s;port=%u', $self->{DB_NAME}, $self->{DB_HOST}, $self->{DB_PORT});

    my $dbh;
    my $i = 0;
    while (1) {
        return undef if ($i >= 3);
        if ($dbh) {
            return $dbh;
        }
        $dbh = DBI->connect($dsn, $self->{DB_USER}, $self->{DB_PASS},
        {
            mysql_enable_utf8 => 1,
        });
        $i++;
    }
}

sub DB_GetLink {
    my $self = shift;
    #return DB_Connect();

    my $dbh;
    $dbh = $DB_links_hash->{$DB_links_nextnum} if (defined($DB_links_hash->{$DB_links_nextnum}));
    if (!defined($dbh) || !$dbh->ping()) {
#        log_lib::LogPush(sprintf("MySqlLink Link %u dead. Reconnect", $MySqlLink_NextNum));
        $dbh = $self->DB_Connect();
    }
    $DB_links_hash->{$DB_links_nextnum} = $dbh;

    if ($DB_links_nextnum >= $DB_links_cnt - 1) {
        $DB_links_nextnum = 0;
    } else {
        $DB_links_nextnum++;
    }
    return $dbh;
}

sub DB_Disconnect {
    my $self = shift;

#    my $dbh;
    for (my $i = 0; $i < $DB_links_cnt; $i++) {
        $DB_links_hash->{$i}->disconnect();
    }    
}
###############

1;
