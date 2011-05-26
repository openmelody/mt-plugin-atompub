use lib qw( t/lib lib extlib plugins/AtomPub/lib );

use strict;
use warnings;

BEGIN {
    $ENV{MT_APP} = 'AtomPub::AtomServer';
}

use MT::Test qw( :app :db :data );
use Test::More tests => 7;


out_like(
    'AtomPub::AtomServer',
    {},
    qr{ Status:\s200 \b .* \b 1 \z }xms,
    "Just a 1 on the root URL",
);

out_like(
    'AtomPub::AtomServer',
    {
        __test_path_info => q{1.0},
    },
    qr{ Status:\s401 }xms,
    "Unauthorized on the weblogs URL",
);
like(get_last_output(), qr{ X-WSSE }xms, "Unauthorized error message on the weblogs URL");

{
    local $ENV{HTTP_AUTHORIZATION} = q{Derp herp="derp"};
    out_like(
        'AtomPub::AtomServer',
        {
            __test_path_info => q{1.0},
        },
        qr{ Status:\s401 }xms,
        "Unauthorized on the weblogs URL with bad auth",
    );
    like(get_last_output(), qr{ X-WSSE }xms, "Unauthorized error message on the weblogs URL with bad auth");
}

use LWP::Authen::Wsse;
use MIME::Base64 qw( encode_base64 );
use Digest::SHA1 qw( sha1 );

sub wsse_auth {
    my $username = "Chuck D";
    my $password = "seecret";
    my $nonce_raw = LWP::Authen::Wsse->make_nonce();
    my $created = LWP::Authen::Wsse->now_w3cdtf();

    my $digest = encode_base64(sha1($nonce_raw . $created . $password), q{});
    my $nonce = encode_base64($nonce_raw, q{});

    return (q{WSSE profile="UsernameToken"}, qq{UsernameToken Username="$username", PasswordDigest="$digest", Nonce="$nonce", Created="$created"});
}

{
    local %ENV = %ENV;
    ($ENV{HTTP_AUTHORIZATION}, $ENV{HTTP_X_WSSE}) = wsse_auth();
    out_like(
        'AtomPub::AtomServer',
        {
            __test_path_info => q{1.0},
        },
        qr{ Status:\s200 }xms,
        "Authorized on the weblogs URL with good auth",
    );
    like(get_last_output(), qr{ <\?xml }xms, "Authorized response is XML");
}


1;
