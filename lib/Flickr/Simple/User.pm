#!/usr/bin/perl
package Flickr::Simple::User;
use Flickr::Simple;
use vars qw( @ISA );
@ISA = qw( Flickr::Simple::Object );
our $AUTOLOAD;

use strict;
use warnings qw( all );

use Log::Agent;
use Log::Agent::Priorities qw(:LEVELS);

my %attrs = (
	username	=> undef,
	nsid		=> undef,
	fullname	=> undef,
	isadmin		=> undef,
	ispro		=> undef,
	iconserver	=> undef,
	iconfarm 	=> undef,
	location	=> undef,
	firstdate	=> undef,
	firstdatetaken	=> undef,
	count		=> undef,
	views		=> undef,
	photosurl	=> undef,
	profileurl	=> undef,
	mobileurl	=> undef,
	mbox_sha1sum	=> undef,
	id		=> undef,
);

sub new {
	my $class = shift;
	my $args = shift;
	my $self = $class->SUPER::new($args);
	foreach my $key (keys(%attrs)) {
		$self->{_permitted}->{$key} = $attrs{$key};
		$self->{$key} = $args->{$key}
			if(exists($args->{$key}) && $args->{$key});
	}
	return $self;
}

sub iconurl {
	my $self = shift;
	my $iconserver = $self->iconserver();
	my $out;
	if($iconserver) {
		$out = 'http://static.flickr.com/' . $iconserver .
			"/buddyicons/" . $self->nsid() . ".jpg";
	} else {
		$out = 'http://www.flickr.com/images/buddyicon.jpg';
	}
	return $out;
}

sub urlusername {
	my $self = shift;
	return $self->username if $self->username;
	return $self->nsid;
}

sub _fetchinfo {
	my $self = shift;
	return if(defined($self->{'fetched'}) && $self->{'fetched'});
	my $method = 'flickr.people.getInfo';
	return $self->_rerror("need id") unless $self->{'nsid'};
	my $args = {
		user_id	=> $self->{'nsid'},
	};
	my $resp = $self->_run($method,$args);
	return $self->_rerror("unable to fetch userinfo for $self : " . $resp->{'error_message'})
		unless $resp->{'success'};
	my $hr = $self->_parse_userinfo_tree($resp->{'tree'});

	# only add allowed attributes:
	foreach my $key (keys(%{$hr})) {
		$self->tryset($key,$hr->{$key});
	}
	$self->{'fetched'} = 1;
}

sub _parse_userinfo_tree {
	my $self = shift;
	my $tree = shift;
	my $out = {};
	return unless $tree->{'name'} eq 'rsp';
	foreach my $elem (@{$tree->{'children'}}) {
		next unless exists($elem->{'name'});
		next unless $elem->{'name'} eq 'person';
		$out = $self->_parseperson($elem);
	}
	return $out;
}

sub _parseperson {
	my $self = shift;
	my $elem = shift;
	my $out = {};
	my $looking;
	foreach my $a (keys(%{$self->{'_permitted'}})) {
		$looking->{$a} = 1;
	}
	delete($looking->{'apikey'})
		if exists $looking->{'apikey'};
	delete($looking->{'apisecret'})
		if exists $looking->{'apisecret'};

	foreach my $b (keys(%{$elem->{'attributes'}})) {
		$out->{$b} = $elem->{'attributes'}{$b};
		delete($looking->{$b})
			if exists $looking->{$b};
	}
	foreach my $c (@{$elem->{'children'}}) {
		next unless exists ($c->{'name'}) && $c->{'name'};
		next unless exists($looking->{$c->{'name'}});
		$out->{$c->{'name'}} = $c->{'children'}[0]{'content'};
	}
	foreach my $d (@{$elem->{'children'}}) {
		next unless exists ($d->{'name'}) && $d->{'name'};
		next unless $d->{'name'} eq 'photos';
		foreach my $pc (@{$d->{'children'}}) {
			next unless exists($pc->{'name'}) && $pc->{'name'};
			next unless exists($looking->{$pc->{'name'}});
			$out->{$pc->{'name'}} =
				$pc->{'children'}[0]{'content'}
				if exists($pc->{'children'}[0]{'content'});
		}
	}
	return $out;
}

sub photosets {
	my $self = shift;
	my $method = 'flickr.photosets.getList';
	my $args = {
		user_id => $self->nsid(),
	};
	my $resp = $self->_run($method,$args);
	return $self->_rerror("Unable to fetch photosets: " .
		$resp->{'error_message'})
		unless $resp->{'success'};
	my $tree = $resp->{'tree'};
	my $hr = Flickr::Simple::Misc::_xmltree_to_hr($tree);
	return unless exists($hr->{'photosets'}{'children'});
	my $ar = $hr->{'photosets'}{'children'};
	my @out;
	foreach my $elem (@{$ar}) {
		next unless exists($elem->{'name'});
		next unless $elem->{'name'} eq 'photoset';
		my $set = Flickr::Simple::Photoset->new(
			{
				apikey		=> $self->{'apikey'},
				apisecret	=> $self->{'apisecret'},
				%{$elem->{'attributes'}},
			}
		);
		$set->tryset('owner',$self);
		push(@out,$set);
	}
	return @out;
}

sub tags {
	my $self = shift;
	my $method = 'flickr.tags.getListUserRaw';
	logdie("unimplemented");
}

sub all_photos {
	my $self = shift;
	logdbg("fetching photo page 1");
	my $rsp = $self->_fetch_photo_page(1);
	return $self->_rerror("unable to fetch photos")
		unless $rsp;
	my $totalpages = $rsp->{attributes}{pages};
	my @photos;
	push(@photos,$self->_objectify_photo_page($rsp));
	return @photos if $totalpages == 1;
	foreach my $pagenum (2 .. $totalpages) {
		logdbg("fetching photo page $pagenum of $totalpages");
		my $pagersp = $self->_fetch_photo_page($pagenum);
		return $self->_rerror("unable to fetch photos")
			unless $pagersp;
		push(@photos,$self->_objectify_photo_page($pagersp));
	}
	return @photos;
}

sub _howmanypages {
	my $self = shift;
	my $xml = shift;
	return $xml->{attributes}{pages};
}

sub _objectify_photo_page {
	my $self = shift;
	my $page = shift;
	my @photogroups = $self->_xmlelement($page,'photo');
	my $photoblocks = pop(@photogroups);
	my @out;
	my @attrs = qw(
			isfriend ispublic title server secret id farm isfamily
		      );
	foreach my $block (@{$photoblocks}) {
		my $new = {
			apikey          => $self->{'apikey'},
			apisecret       => $self->{'apisecret'},
		};
		foreach my $attr (@attrs) {
			$new->{$attr} = $block->{attributes}{$attr};
		}
		my $photoo = Flickr::Simple::Photo->new($new);
		# FIXME do owner
		push(@out,$photoo);
	}
	return @out;
}

sub _fetch_photo_page {
	my $self = shift;
	my $page = shift;

	my $method = 'flickr.photos.search';
	my $args = {
		user_id => $self->nsid,
		per_page => 500,
		page => $page,
	};
        my $resp = $self->_run($method,$args);
	return unless $resp->{success};
	my $tree = $resp->{'tree'};
	return unless $tree->{name} eq 'rsp';
	my $rsp = $self->_xmlelement($tree,'photos');
	return unless $rsp;
	return $rsp->[0];
}

1;

__END__
