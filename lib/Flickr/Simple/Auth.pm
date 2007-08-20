#!/usr/bin/perl
package Flickr::Simple::Auth;
use Flickr::Simple;
use vars qw( @ISA );
@ISA = qw( Flickr::Simple::Object );

use strict;
use warnings qw( all );

use Log::Agent;
use Log::Agent::Priorities qw(:LEVELS);

sub new {
	my $p = shift;
	my $class = ref($p) || $p; 
	my $args = shift;
	my @parts = qw( apikey apisecret perms );
	my $self = {
		perms => 'read',
	};
	foreach my $arg (@parts) {
		$self->{$arg} = undef unless exists($self->{$arg});
		$self->{$arg} = $args->{$arg} if $args->{$arg};
	}
	bless($self,$class);
	logdbg(DEBUG,"constructed $self");
	$self->_initapi();
	return $self;
}

sub _get_new_frob {
        my $self = shift;
        my $method = 'flickr.auth.getFrob';
        my $args = {};
        my $resp = $self->_run($method,$args);
        unless($resp->{'success'}) {
		$self->_rerror("Unable to get authentication frob: " .
			$resp->{'error_message'});
		return;
	}
        my $frob = _getfrob_from_xmltree($resp->{'tree'});
        unless($frob) {
		$self->_rerror("Unable to get authentication ".
			"frob - xml error?");
		return;
	} else {
		$self->{'frob'} = $frob;
		$self->{'frobtime'} = time();
		return $frob;
	}
}

sub valid {
	my $self = shift;
	
	$self->{'valid'} = 0;

	if(exists($self->{'authtoken'})) {
		# this call deletes the authtoken on
		# the object if it's invalid:
		$self->_check_authtoken_valid();
	} elsif(exists($self->{'frob'})) {
		$self->reauthorize() if($self->_frob_expired());
		$self->_get_authtoken_from_frob();
	} else {
		$self->_get_new_frob();
	}
	return $self->{'valid'};	
}

sub _frob_expired {
	my $self = shift;
	# frobs are only good for an hour:
	my $expiry = 60*60;
	
	# default to expired
	my $frobage = $expiry + 1;
	
	if(exists($self->{'frobtime'})) {
		$frobage = time() - $self->{'frobtime'};
		logdbg(DEBUG,"our frob is $frobage seconds old");
	}

	if($frobage > $expiry) {
		return 1;
	} else {
		return 0;
	}
}

sub _check_authtoken_valid {
	my $self = shift;
	$self->{'valid'} = 0; # assume until proven otherwise
	return unless exists($self->{'authtoken'}) && $self->{'authtoken'};
	my $method = 'flickr.auth.checkToken';
	my $args = {
		auth_token => $self->{'authtoken'}
	};
	my $resp = $self->_run($method,$args);
	if(exists($resp->{'success'}) && $resp->{'success'}) {
		$self->{'valid'} = 1;
		my $stuff = _parse_authcheck_tree($resp->{'tree'});
		my $user = Flickr::Simple::User->new(
			{
				apikey		=> $self->{'apikey'},
				apisecret	=> $self->{'apisecret'},
			}
		);
		my @oas = qw( fullname nsid username );
		foreach my $attr (@oas) {
			next unless $stuff->{'user'}{$attr};
			next unless exists($user->{'_permitted'}{$attr});
			$user->{$attr} = $stuff->{'user'}{$attr};
		}
		$self->{'authuser'} = $user;
	} else {
		delete($self->{'authtoken'});
		delete($self->{'frob'});  # this should be unnecessary
	}
	return;
}

sub _parse_authcheck_tree {
        # NOT A METHOD
        my $tree = shift;
	return unless $tree->{'name'} eq 'rsp';
	my $hr = Flickr::Simple::Misc::_xmltree_to_hr($tree);
	return unless $hr->{'auth'}{'children'};
	my $ahr = Flickr::Simple::Misc::_xmltree_to_hr($hr->{'auth'});
	return unless $ahr->{'user'};
	my $out = {
		token => $ahr->{'token'}{'children'}[0]{'content'},
		perms => $ahr->{'perms'}{'children'}[0]{'content'},
		user => {
			fullname => $ahr->{'user'}{'attributes'}{'fullname'},
			nsid => $ahr->{'user'}{'attributes'}{'nsid'},
			username => $ahr->{'user'}{'attributes'}{'username'},
		},
	};
	#return unless $ahr->{'token'}{'children'}[0]{'content'};
	#return $ahr->{'token'}{'children'}[0]{'content'};
}

sub authuser {
	my $self = shift;
	return unless ref($self->{'authuser'}) eq 'Flickr::Simple::User';
	return $self->{'authuser'};
}

sub url {
	my $self = shift;
	
	return if ($self->{'authtoken'} && $self->{'valid'});

	return unless $self->{'frob'};
	return unless $self->{'perms'};
	my $url = $self->{'api'}->request_auth_url(
		$self->{'perms'},
		$self->{'frob'}
	);
	return $url;
}

sub reauthorize {
	my $self = shift;
	my @attrs = qw( authtoken frob );
	logdbg(DEBUG,"reauthorizing $self");
	foreach my $attr (@attrs) {
		delete($self->{$attr}) if exists($self->{$attr});
	}
	$self->valid();
}

sub _get_authtoken_from_frob {
        my $self = shift;
        die unless $self->{'frob'};
        my $method = 'flickr.auth.getToken';
        my $args = {
		frob	=> $self->{'frob'},
	};
        my $resp = $self->_run($method,$args);
        return unless $resp->{'success'};
        my $token = _getauthtoken_from_xmltree($resp->{'tree'});
	return $self->_rerror("unable to get authtoken from frob")
		unless $token;
	delete($self->{'frob'});
	$self->{'authtoken'} = $token;
	$self->_check_authtoken_valid();
}

sub _getauthtoken_from_xmltree {
        # NOT A METHOD
        my $tree = shift;
	return unless $tree->{'name'} eq 'rsp';
	my $hr = Flickr::Simple::Misc::_xmltree_to_hr($tree);
	return unless $hr->{'auth'}{'children'};
	my $ahr = Flickr::Simple::Misc::_xmltree_to_hr($hr->{'auth'});
	return unless $ahr->{'token'}{'children'}[0]{'content'};
	return $ahr->{'token'}{'children'}[0]{'content'};
}

sub _getfrob_from_xmltree {
        # NOT A METHOD
        my $tree = shift;
        return unless $tree->{'name'} eq 'rsp';
        my $ar = $tree->{'children'};
        foreach my $part (@{$ar}) {
                next unless exists($part->{'name'});
                next unless $part->{'name'} eq 'frob';
                my $frob = $part->{'children'}[0]{'content'};
                return unless $frob;
                return $frob;
        }
        return;
}

sub DESTROY {}

1;

__END__
