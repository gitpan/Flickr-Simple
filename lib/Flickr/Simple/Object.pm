#!/usr/bin/perl
package Flickr::Simple::Object;

use strict;
use warnings qw( all );

use Log::Agent;
use Log::Agent::Priorities qw(:LEVELS);

our $AUTOLOAD;

my %attrs = (
	apisecret	=> undef,
	apikey		=> undef,
	fetched		=> undef,
	error		=> '',
);

sub new {
        my $p = shift;
        my $class = ref($p) || $p;
        my $args = shift;
	my %a = %attrs;
	my $self = {
		_permitted	=> \%a,
	};
        foreach my $arg (keys(%attrs)) {
                $self->{$arg} = undef unless exists($self->{$arg});
                $self->{$arg} = $args->{$arg} if $args->{$arg};
        }
        bless($self,$class);
        logdbg(DEBUG,"constructed $self");
        $self->_initapi();
        return $self if $self->error();
        $self->_init();
        return $self;
}

sub _init {
}

sub _initapi {
	my $self = shift;
	return $self->_rerror("No API key")
		unless $self->{'apikey'};
	return $self->_rerror("No API secret")
		unless $self->{'apisecret'};
	my $flickr = new Flickr::API(
		{
			key 		=> $self->{'apikey'},
			secret		=> $self->{'apisecret'},
		}
	);
	return $self->_rerror("Unable to create API object")
		unless $flickr;
	$self->{'api'} = $flickr;
	# once is sufficient:
	$self->_test() if ref($self) eq 'Flickr::Simple::Auth';
}

sub _test {
	my $self = shift;
	my $method = 'flickr.test.echo';
	my $args = { testkey => 'testval' };
	my $resp = $self->_run($method,$args);
	$self->_rerror("Unable to make API calls: " .
		$resp->{'error_message'})
		unless $resp->{'success'};
}

sub _fetchinfo { } # this gets superceded in subclasses

sub _rerror {
	my $self = shift;
	my $msg = shift;
	$msg = 'Unknown error' unless $msg;
	logwarn("$self has error: '$msg'");
	$self->{'error'} = $msg;
}

sub error {
	my $self = shift;
	return unless $self->{'error'};
	return $self->{'error'};
}

sub _run {
	my $self = shift;
	my $method = shift;
	my $args = shift;

	logdbg(DEBUG,$self . "->_run('" . $method . "')");
	my $req = new Flickr::API::Request(
		{
			method	=> $method,
			args	=> $args,
		}
	);
	my $resp = $self->{'api'}->execute_request($req);
	return $resp;
}

sub list_attrs {
	my $self = shift;
	my $out = $self->_attrhash();
	return keys(%{$out});
}

sub _attrhash {
	my $self = shift;
	my %h = %{$self->{'_permitted'}};
	my @strip = qw( apikey apisecret );
	foreach my $a (@strip) {
		delete($h{$a}) if exists($h{$a});
	}
	return \%h;
}

sub tryset {
	my $self = shift;
	my $attr = shift;
	my $val = shift;
	return unless $val;
	my $allowed = $self->_attrhash();
	unless(exists($allowed->{$attr})) {
		logcarp("trying to set invalid ".
			"attribute $attr on $self");
		return;
	}
	logdbg(DEBUG,"setting " . $self . '->{\'' . $attr . '\'} = \'' .
		$val . '\';');
	$self->{$attr} = $val;
}

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self)
		or logdie("$self is not an object");

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully-qualified portion

	unless (exists $self->{'_permitted'}{$name} ) {
		logdie("Can't access `$name' field in class $type");
	}

	logdbg(DEBUG,"using autoload method to access $name");

	if (@_) {
		my $arg = shift;
		$self->tryset($name,$arg);
	} else {
		$self->_fetchinfo()
			unless(exists($self->{$name}) && $self->{$name});
		return $self->{$name};
	}
}

sub _xmlelement {
	my $self = shift;
	my $tree = shift;
	my $elemname = shift;
	return unless $elemname;
	my $children = $tree->{children};
	return unless $children;
	my @out = ( );
	foreach my $elem (@$children) {
		next unless exists($elem->{name});
		next unless $elem->{name};
		next unless $elem->{name} eq $elemname;
		push(@out,$elem);
	}
	return \@out;
}

1;

__END__
