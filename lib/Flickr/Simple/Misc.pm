#!/usr/bin/perl
package Flickr::Simple::Misc;

use strict;
use warnings qw( all );

sub _xmltree_to_hr {
	my $tree = shift;
	return unless ref($tree->{'children'});
	my $out;
	my @stuff = qw( name children type attributes content );
	foreach my $elem (@{$tree->{'children'}}) {
		next unless exists($elem->{'name'});
		foreach my $thing (@stuff) {
			$out->{$elem->{'name'}}{$thing} = 
				$elem->{$thing}
				if(exists($elem->{$thing}));
		}
	}
	return $out;
}

1;

__END__
