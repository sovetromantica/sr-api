package cfg_lib;

use strict;
use warnings;
use IO::Handle;
use YAML::XS;


our $config;
sub LoadConfig {
    my $ConfigFile = shift;
    $config = YAML::XS::LoadFile($ConfigFile);
}

1;