#!/usr/bin/perl
# plugin.pm - The mootykins3 plugin base class.
#
# (c) 2007 Lorenz Diener, lorenzd@gmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License or any later
# version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict;
use Text::Iconv;

package BookSpider::Plugin;

#use Exporter 'import';
#
#our @EXPORT_OK = qw(init isMatchingUrl hasValidBookId getName parseIndex parseDocument convert_encoding print_chapter getIndexUrl);

# A simple constructor.
sub new {
	my $type = shift;
	my $self = { };
	return bless $self, $type;
}

sub init {
	
}
sub isMatchingUrl {
	die "BookSpider::Plugin default isMatchingUrl called!";
}
sub hasValidBookId {
	die "BookSpider::Plugin default hasValidBookId called!";
}
sub getName {
	my $self = shift;
	
	return $self->{PLUGIN_NAME};
}

sub getIndexUrl {
	my $self = shift;
	
	return $self->{INDEX_URL};
}
sub parseIndex {
	die "BookSpider::Plugin default parseIndex called!";
}
sub parseDocument {
	die "BookSpider::Plugin default parseDocument called!";
}
sub convert_encoding {
	my ($self, $text) = @_;
	
	if ($self->{FROM_CODE} ne $self->{TO_CODE}) {
		my $converter = Text::Iconv->new($self->{FROM_CODE}, $self->{TO_CODE});
		$text = $converter->convert($text);
	}
		
	return $text;
}
sub print_chapter {
	die "BookSpider::Plugin default print_chapter called!";
}

sub help {
	return ( "No help available." );
}
1;
