#!/usr/bin/perl
package Flickr::Simple;

use 5.008008;
use strict;
use warnings qw( all );
our $VERSION = '0.01';

=head1 NAME

Flickr::Simple - Perl object library for manipulating Flickr data via
the Flickr API

=head1 RELEASE EARLY AND OFTEN                                                         
                                                                         
This module is quite incomplete.  Please submit patches or improvements         
to sneak@datavibe.net or join the mailing list by sending mail to               
flickr-simple-subscribe@googlegroups.com.   

=head1 SYNOPSIS

  use Flickr::Simple;

  my $apikey = '...';
  my $apisecret = '...';

  my $auth = Flickr::Simple::Auth->new(
  	{
  		apikey          => $apikey,
  		apisecret       => $apisecret,
  	}
  );

  my $user = $auth->authuser();
  print "authed as user: " . $user->username() . "\n";
  print "icon: " . $user->iconurl() . "\n";
  print "photo count: " . $user->count() . "\n";
  my @photos = $user->all_photos;
  foreach my $photo (@photos) {
  	print $photo->photopage . "\n";
  }

  my @photosets = $user->photosets;
  my $firstset = pop(@photosets);
  my @photoset_photos = $firstset->photos_in_set;
  my @tags = $photo->tags;

=head1 DESCRIPTION

Object interface to Flickr API calls, organized by logical Flickr
elements (Photo, Photoset, User, etc.)

=head2 EXPORT

None by default.

=head1 SEE ALSO

The following object modules:
  Flickr::Simple::Photo
  Flickr::Simple::Photoset
  Flickr::Simple::User
  Flickr::Simple::Tag
  Flickr::Simple::Auth

Send mail to flickr-simple-subscribe@googlegroups.com to join the mailing list.

This module would not be possible without Cal Henderson's wonderful Flickr::API
module.

Included with the module are some sample implementations that use Storable to
allow the application authorization cookie to persist.

=head1 AUTHOR

Rev. Jeffrey Paul, E<lt>sneak@datavibe.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Rev. Jeffrey Paul.

=cut

use Log::Agent;
use Log::Agent::Priorities qw(:LEVELS);
use Flickr::API;
use Flickr::API::Request;

use Flickr::Simple::Object;
use Flickr::Simple::Auth;
use Flickr::Simple::Photo;
use Flickr::Simple::User;
use Flickr::Simple::Photoset;
use Flickr::Simple::Tag;
use Flickr::Simple::Misc;

1;

__END__
