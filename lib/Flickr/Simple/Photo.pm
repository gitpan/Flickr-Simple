#!/usr/bin/perl
package Flickr::Simple::Photo;
use Flickr::Simple;
use vars qw( @ISA );
@ISA = qw( Flickr::Simple::Object );
our $AUTOLOAD;

use strict;
use warnings qw( all );
use Log::Agent;
use Log::Agent::Priorities qw(:LEVELS);

my %attrs = (
	id		=> undef,
	primary		=> undef,
	secret		=> undef,
	server		=> undef,
	farm		=> undef,
	title		=> undef,
	description	=> undef,
	isfavorite	=> undef,
	license		=> undef,
	rotation	=> undef,
	originalsecret	=> undef,
	originalformat	=> undef,
	owner		=> undef,
	ispublic	=> undef,
	isfriend	=> undef,
	isfamily	=> undef,
	dateuploaded	=> undef,
	datetaken	=> undef,
	takengranularity=> undef,
	lastupdate	=> undef,
	permcomment	=> undef,
	permaddmta	=> undef,
	cancomment	=> undef,
	canaddmeta	=> undef,
	comments	=> undef,
	notes		=> undef,
	tags		=> undef,
	photopage	=> undef,
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

sub url {
	my($self,$size) = @_;

	logdie() unless $self->{'id'};
	my @needed = qw( farm server secret id );
	foreach my $attr (@needed) {
		return unless exists($self->{$attr}) && $self->{$attr};
	}

	my $sizecodes = {
		smallsquare		=> 's',
		square 			=> 's',
		small			=> 'm',
		medium			=> undef,
		large			=> 'b',
		original		=> 'o',
	};

	my $code = undef;
	unless(exists($sizecodes->{$size})) {
		logdie("unsupported image size: '$size'");
	} else {
		$code = $sizecodes->{$size}
	}
	my $url;
	if(defined($code) && ($code eq 'o')) {
		# originals are a special case
		$url = 'http://farm' . $self->farm() . '.static.flickr.com/' .
			$self->server() . '/' . $self->id() . '_' .
			$self->originalsecret() . 
			'_' . $code .
			'.' . $self->originalformat();
	} else {
		$url = 'http://farm' . $self->farm() . '.static.flickr.com/' .
			$self->server() . '/' . $self->id() . '_' .
			$self->secret() . 
			( $code ? ('_' . $code) : '' ) .
			'.jpg';
	}
	return $url;
}

sub photopage {
	my $self = shift;
	my $owner = $self->owner;
	my $url = 'http://flickr.com/photos/' .
		$owner->urlusername . '/' .
		$self->id;
	return $url;
}

sub _fetchinfo {
	my $self = shift;
	return if(defined($self->{'fetched'}) && $self->{'fetched'});
	my $method = 'flickr.photos.getInfo';
	return $self->_rerror("need id") unless $self->{'id'};
	my $args = {
		photo_id => $self->{'id'},
	};
	my $resp = $self->_run($method,$args);
	return $self->_rerror("unable to fetch photoinfo for $self : " . $resp->{'error_message'})
		unless $resp->{'success'};

	my $hr = $self->_parse_photoinfo_tree($resp->{'tree'});
	# only add allowed attributes:
	foreach my $key (keys(%{$hr})) {
		$self->tryset($key,$hr->{$key});
	}
	$self->{'fetched'} = 1;
}

sub _parse_photoinfo_tree {
	my $self = shift;
	my $tree = shift;
        my $out = {};
        return unless $tree->{'name'} eq 'rsp';
        foreach my $elem (@{$tree->{'children'}}) {
                next unless exists($elem->{'name'});
                next unless $elem->{'name'} eq 'photo';
                $out = $self->_parsephoto($elem);
        }
        return $out;
}

sub _parsephoto {
	# this was stolen mostly verbatim from _parseperson() in User.pm
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
	#foreach my $c (@{$elem->{'children'}}) {
	#	next unless exists ($c->{'name'}) && $c->{'name'};
	#	next unless exists($looking->{$c->{'name'}});
	#	$out->{$c->{'name'}} = $c->{'children'}[0]{'content'};
	#}
	#foreach my $d (@{$elem->{'children'}}) {
	#	next unless exists ($d->{'name'}) && $d->{'name'};
	#	next unless $d->{'name'} eq 'photos';
	#	foreach my $pc (@{$d->{'children'}}) {
	#		next unless exists($pc->{'name'}) && $pc->{'name'};
	#		next unless exists($looking->{$pc->{'name'}});
	#		$out->{$pc->{'name'}} =
	#			$pc->{'children'}[0]{'content'}
	#		if exists($pc->{'children'}[0]{'content'});
	#	}
	#}
	return $out;
}

sub tags {
	my $self = shift;
	my $tagxml = $self->_fetchtags();
	my $tags = $self->_objectify_tags($tagxml);
	return $tags; # this is not cached
}

sub _fetchtags {
	my $self = shift;
	my $method = 'flickr.tags.getListPhoto';
	my $args = {
		photo_id => $self->id(),
	};
	my $resp = $self->_run($method,$args);
	return $self->_rerror("unable to fetch owner for photoset " .
			$self->id())
		unless $resp->{success};
	my $tree = $resp->{tree};
	return $self->_rerror("bad response")
		unless $tree->{name} eq 'rsp';
	my $photos = $self->_xmlelement($tree,'photo');
	my $tags = $self->_xmlelement($photos->[0],'tags');
	return $self->_rerror("error parsing tags") unless $tags;
	my $actualtags = $self->_xmlelement($tags->[0],'tag');
	return $actualtags;
}

sub _objectify_tags {
	my $self = shift;
	my $xml = shift;
	my @out;
	foreach my $tag (@$xml) {
		my $new =  {
			apikey          => $self->{'apikey'},
			apisecret       => $self->{'apisecret'},
		};

		foreach my $a (qw( raw id machine_tag)) {
			$new->{$a} = $tag->{attributes}{$a};
		}

		$new->{body} = $tag->{children}[0]{content};
		
		my $owner = Flickr::Simple::User->new({
			nsid => $tag->{attributes}{author},
			apikey          => $self->{'apikey'},
			apisecret       => $self->{'apisecret'},
		});
		$new->{owner} = $owner;
		my $tago = Flickr::Simple::Tag->new($new);
		return $self->_rerror("unable to create tag object")
			unless $tago;
		return $self->_rerror("error creating tag object")
			if $tago->error;
		push(@out,$tago);
	}
	return \@out;
}

# subs we'll want
# comments
# owner
# notes

1;

__END__
