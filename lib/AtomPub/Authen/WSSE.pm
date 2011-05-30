# Movable Type (r) Open Source (C) 2001-2011 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

package AtomPub::Authen::WSSE;
use strict;

use base qw( AtomPub::Authen );

use MT::I18N qw( encode_text );
use MIME::Base64 ();
use Digest::SHA1 ();
use MT::Author;


sub get_auth_info {
    my $class = shift;
    my ($app) = shift;

    my %param;
    my $req = $app->get_header('X-WSSE')
        or return $class->auth_failure($app, 401, 'X-WSSE authentication required');
    $req =~ s/^WSSE //;
    my ($profile);
    ($profile, $req) = $req =~ /(\S+),?\s+(.*)/;
    return $app->error(400, "Unsupported WSSE authentication profile") 
        if $profile !~ /\bUsernameToken\b/i;
    for my $i (split /,\s*/, $req) {
        my($k, $v) = split /=/, $i, 2;
        $v =~ s/^"//;
        $v =~ s/"$//;
        $param{$k} = $v;
    }
    \%param;
}

sub authenticate {
    my $class = shift;
    my ($app) = shift;

    my $auth = $class->get_auth_info($app)
        or return;
    for my $f (qw( Username PasswordDigest Nonce Created )) {
        return $class->auth_failure($app, 400, "X-WSSE requires $f")
            unless $auth->{$f};
    }
    require MT::Session;
    my $nonce_record = MT::Session->load($auth->{Nonce});

    if ($nonce_record && $nonce_record->id eq $auth->{Nonce}) {
        return $class->auth_failure($app, 403, "Nonce already used");
    }
    $nonce_record = new MT::Session();
    $nonce_record->set_values({
        id => $auth->{Nonce},
        start => time,
        kind => 'AN'
    });
    $nonce_record->save();
# xxx Expire sessions on shorter timeout?
    my $enc = $app->config('PublishCharset');
    my $username = encode_text($auth->{Username},undef,$enc);
    my $user = MT::Author->load({ name => $username, type => 1 })
        or return $class->auth_failure($app, 403, 'Invalid login');
    return $class->auth_failure($app, 403, 'Invalid login')
        unless $user->api_password;
    return $class->auth_failure($app, 403, 'Invalid login')
        unless $user->is_active;
    my $created_on_epoch = $app->iso2epoch($auth->{Created});
    if (abs(time - $created_on_epoch) > $app->config('WSSETimeout')) {
        return $class->auth_failure($app, 403, 'X-WSSE UsernameToken timed out');
    }
    $auth->{Nonce} = MIME::Base64::decode_base64($auth->{Nonce});
    my $expected = Digest::SHA1::sha1_base64(
         $auth->{Nonce} . $auth->{Created} . $user->api_password);
    # Some base64 implementors do it wrong and don't put the =
    # padding on the end. This should protect us against that without
    # creating any holes.
    $expected =~ s/=*$//;
    $auth->{PasswordDigest} =~ s/=*$//;
    #print STDERR "expected $expected and got " . $auth->{PasswordDigest} . "\n";
    return $class->auth_failure($app, 403, 'X-WSSE PasswordDigest is incorrect')
        unless $expected eq $auth->{PasswordDigest};
    $app->{user} = $user;

    return 1;
}

sub auth_failure {
    my $class = shift;
    my $app = shift;
    $app->set_header('WWW-Authenticate', 'WSSE profile="UsernameToken"');
    return $app->error(@_);
}


1;
__END__

=head1 NAME

AtomPub::Server

=head1 SYNOPSIS

An Atom Publishing API interface for communicating with Movable Type.

=head1 METHODS

=head2 $app->xml_body()

Takes the content posted to the server and parses it into an XML document.
Uses either XML::LibXML or XML::XPath depending on which is available.

=head2 $app->iso2epoch($iso_ts)

Converts C<$iso_ts> in the format of an ISO timestamp into a unix timestamp
(seconds since the epoch).

=head2 $app->init

Initializes the application.

=head2 $app->get_auth_info

Processes the request for WSSE authentication and returns a hash containing:

=over 4

=item * Username

=item * PasswordDigest

=item * Nonce

=item * Created

=back

=head2 $app->handle_request

The implementation of this in I<AtomPub::Server::Weblog> passes the request
to the proper method.

=head2 $app->handle

Wrapper method that determines the proper AtomPub::Server package to pass the
request to.

=head2 $app->iso2ts($iso_ts, $target_zone)

Converts C<$iso_ts> in the format of an ISO timestamp into a MT-compatible
timestamp (YYYYMMDDHHMMSS) for the specified timezone C<$target_zone>.

=head2 $app->atom_body

Processes the request as Atom content and returns an XML::Atom object.

=head2 $app->error($code, $message)

Sends the HTTP headers necessary to relay an error.

=head2 $app->authenticate()

Checks the WSSE authentication with the local MT user database and
confirms the user is authorized to access the resources required by
the request.

=head2 $app->show_error($message)

Returns an XML wrapper for the error response.

=head2 $app->auth_failure($code, $message)

Handles the response in the event of an authentication failure.

=head1 CALLBACKS

=over 4

=item api_pre_save.entry

    callback($eh, $app, $entry, $original_entry)

Called before saving a new or existing entry. If saving a new entry, the
$original_entry will have an unassigned 'id'. This callback is executed
as a filter, so your handler must return 1 to allow the entry to be saved.

=item api_post_save.entry

    callback($eh, $app, $entry, $original_entry)

Called after saving a new or existing entry. If saving a new entry, the
$original_entry will have an unassigned 'id'.

=item get_posts

    callback($eh, $app, $feed, $blog)

Called right before get_posts method returns atom feed response.
I<$feed> is a reference to XML::Atom::Feed object.
I<$blog> is a reference to the requested MT::Blog object.

=item get_post

    callback($eh, $app, $atom_entry, $entry)

Called right before get_post method returns atom entry response.
I<$atom_entry> is a reference to XML::Atom::Entry object.
I<$entry> is a reference to the requested MT::Entry object.

=item get_blog_comments

    callback($eh, $app, $feed, $blog)

Called right before get_blog_comments method returns atom feed response.
I<$feed> is a reference to XML::Atom::Feed object.
I<$blog> is a reference to the requested MT::Blog object.

=item get_comments

    callback($eh, $app, $feed, $entry)

Called right before get_comments method returns atom feed response. 
I<$feed> is a reference to XML::Atom::Feed object.
I<$entry> is a reference to the requested MT::Entry object.

=item get_comment

    callback($eh, $app, $atom_entry, $comment)

Called right before get_comment method returns atom entry response.
I<$atom_entry> is a reference to XML::Atom::Entry object.
I<$comment> is a reference to the requested MT::Comment object.

=back

=cut
