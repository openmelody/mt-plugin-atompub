# Movable Type (r) Open Source (C) 2001-2011 Six Apart, Ltd.
# This program is distributed under the terms of the
# GNU General Public License, version 2.
#
# $Id$

package AtomPub::Authen::Basic;
use strict;

use base qw( AtomPub::Authen );

use MIME::Base64 qw( decode_base64 );
use MT::Author;


sub authenticate {
    my $class = shift;
    my ($app) = shift;

    my $header = $app->get_header('Authorization')
        or return $class->auth_failure($app, 401, 'Basic authentication required');
    $header =~ s{ \A Basic \s }{}xms;

    my ($username, $password) = split q{:}, decode_base64($header), 2;

    my $user = MT::Author->load({ name => $username, type => 1 })
        or return $class->auth_failure($app, 403, 'Invalid login');
    return $class->auth_failure($app, 403, 'Invalid login')
        unless $user->is_active;
    my $expected_password = $user->api_password
        or return $class->auth_failure($app, 403, 'Invalid login');
    
    return $class->auth_failure($app, 403, 'Invalid login')
        if $expected_password ne $password;

    $app->{user} = $user;
    return 1;
}

sub auth_failure {
    my $class = shift;
    my $app = shift;
    $app->set_header('WWW-Authenticate', 'Basic realm="AtomPub"');
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
