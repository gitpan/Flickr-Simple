#!/usr/bin/perl
package Flickr::Simple::Tag;
use Flickr::Simple;
use vars qw( @ISA );
@ISA = qw( Flickr::Simple::Object );
our $AUTOLOAD;

use strict;
use warnings qw( all );

my %attrs = (
	id		=> undef,
	author		=> undef,
	raw		=> undef,
	body		=> undef,
	machine_tag	=> undef,
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

1;

__END__
