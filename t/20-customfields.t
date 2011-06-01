use lib qw( t/lib lib extlib plugins/AtomPub/lib plugins/AtomPub/t/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::Server';
}

use MT;
use Test::More;
plan skip_all => "The Commercial Pack is required to test Custom Fields"
    if !MT->component('Commercial');

require MT::Test;
MT::Test->import(qw( :app :db :data ));
plan tests => 1;

use AtomPub::Test qw( basic_auth run_app );
use XML::LibXML;


{
    ok(1, "Yay there are custom fields");
}


1;
