#!/usr/bin/perl
package Flickr::Simple::Photoset;
use Flickr::Simple;
use vars qw( @ISA );
@ISA = qw( Flickr::Simple::Object );
our $AUTOLOAD;

use strict;
use warnings qw( all );
use Log::Agent::Priorities qw(:LEVELS);

my %attrs = (
	id		=> undef,
	primary		=> undef,
	secret		=> undef,
	server		=> undef,
	photos		=> undef,
	farm		=> undef,
	title		=> undef,
	description	=> undef,
	owner		=> undef,
);

sub new {
	my $class = shift;
	my $args = shift;
	my $self = $class->SUPER::new($args);
	foreach my $key (keys(%attrs)) {
		$self->{'_permitted'}->{$key} = $attrs{$key};
		$self->{$key} = $args->{$key}
			if(exists($args->{$key}) && $args->{$key});
	}
	return $self;
}

sub owner {
	my $self = shift;
	if(@_) {
		logdie("accessor only");
	} else {
		$self->_fetchinfo()
			unless defined($self->{'owner'}) && $self->{'owner'};

		# this may be already done:
		return $self->{'owner'}
			if ref($self->{'owner'}) eq 'Flickr::Simple::User';

		my $u = Flickr::Simple::User->new(
			{
				apikey		=> $self->{'apikey'},
				apisecret	=> $self->{'apisecret'},
				nsid		=> $self->{'owner'},
			}
		);
		return $u;
	}
}

sub _fetchinfo {
	my $self = shift;
	return if defined($self->{'fetched'}) && $self->{'fetched'};
	my $method = 'flickr.photosets.getInfo';
	my $args = {
		photoset_id	=> $self->{'id'},
	};
	my $resp = $self->_run($method,$args);
	return $self->_rerror("unable to fetch owner for photoset " . 
		$self->id())
		unless $resp->{'success'};
	my $tree = $resp->{'tree'};
	foreach my $elem (@{$tree->{'children'}}) {
		next unless defined($elem->{'name'});
		next unless $elem->{'name'} eq 'photoset';
		my $att = $elem->{'attributes'};
		foreach my $a (keys(%{$att})) {
			$self->{$a} = $att->{$a}
				if(exists($self->{'_permitted'}{$a}));
		}
	}
	
	$self->{'fetched'} = 1;
}

sub photos_in_set {
	my $self = shift;
	if(@_) {
		# TODO handle write somehow!
		logdie("write not supported on " . $self . "->photos() yet");
	} else {
		if(ref($self->{'photos-in-set'}) eq 'ARRAY') {
			return $self->{'photos-in-set'};
		} else {
			$self->{'photos-in-set'} = [];
			$self->_fetchphotos();
			return if $self->error();
			return @{$self->{'photos-in-set'}};
		}	
	}
}

sub _fetchphotos {
	my $self = shift;
	# FIXME
	# implement paging to fetch big sets

	my $tree = $self->_fetch_photo_page(1);
	unless($self->{'owner'}) {
		my $owner = Flickr::Simple::User->new(
			{
				nsid      => $tree->{'attributes'}{'owner'},
				apikey    => $self->apikey(),
				apisecret => $self->apisecret(),
			}
		);
		$self->{'owner'} = $owner;
	}

	foreach my $photo (@{$tree->{'children'}}) {
		next unless defined($photo->{'name'});
		next unless $photo->{'name'} eq 'photo';
		my $p = $self->_make_photo_object($photo);
		push(@{$self->{'photos-in-set'}},$p);
	}
}

sub _fetch_photo_page {
	my $self = shift;
	my $page = shift;
	logdie() unless $page;

	my $method = 'flickr.photosets.getPhotos';
	my $args = {
		photoset_id	=> $self->id(),
		page		=> $page,
	};

	my $resp = $self->_run($method,$args);
	return($self->_rerror("unable to fetch photos for set " . $self->id()))
		unless $resp->{'success'};
	
	my $c = $resp->{'tree'}{'children'};
	foreach my $child (@{$c}) {
		next unless defined($child->{'name'});
		next unless $child->{'name'} eq 'photoset';
		next unless defined($child->{'attributes'}{'id'});
		next unless $child->{'attributes'}{'id'} eq $self->id();
		return $child;
	}
}

sub _make_photo_object {
	my $self = shift;
	my $tree = shift;
	my @a = qw( title server secret id farm );

	my $attr = $tree->{'attributes'};
	return unless exists($attr->{'id'}) && $attr->{'id'};

	my $args = {
		apikey => $self->{'apikey'},
		apisecret => $self->{'apisecret'},
	};
	my $pobj = Flickr::Simple::Photo->new($args);

	foreach my $check (@a) {
		next unless defined($attr->{$check});
		$pobj->tryset($check,$attr->{$check});
	}
	return $pobj;
}

sub url {
	my $self = shift;
	my $base = 'http://www.flickr.com/photos/';
	my $who = $self->owner();
	my $upart;
	if($who->username()) {
		$upart = $who->username();
	} else {
		$upart = $who->nsid();
	}
	return unless $upart;
	my $url = $base . $upart . "/sets/" . $self->id() . "/";
	return $url;
}

sub add_photo {
	my $self = shift;
	die("unimplemented");
}

1;

__END__
