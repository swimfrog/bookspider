#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use Carp;
use Safe;

use Getopt::Long;
use Pod::Usage;
use LWP;
use WWW::Mechanize;
use HTML::TreeBuilder::XPath;
use HTML::FormatText::WithLinks;
use Text::Iconv;
use Encode;
use IO::File;

use lib '/opt/scripts/bookspider';
use BookSpider::Plugin;

=head1 NAME

bookspider.pl - Download an eBook from a website that does not support exporting in eBook format.

=head1 SYNOPSIS

bookspider.pl [-h|--help --man] [-v|--verbose] [-p|--plugin PLUGIN] [-d|--pluginpath PATH] [-f|--output OUTPUT] [-l|--limit NUM] [-i|--incode INCODE] [-o|--outcode OUTCODE] [bookId]

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--verbose>

Prints verbose information to STDERR about spidering and processing of book content.

=item B<--plugin PLUGIN>

Use the specified plugin to interact with the site.

=item B<--pluginpath PATH>

Path where plugin files reside.

=item B<--output>

Output book content to a file. If not specified, content will be printed to STDOUT.

=item B<--limit NUM>

Limit chapters to NUM chapters. Useful when developing plugins

=item B<--incode | --outcode>

The input and output encodings to use. By default, incode will plugin-specific and output will be UTF-8.

=back

=head1 DESCRIPTION

B<bookspider.pl> Uses WWW::Mechanize to get all chapters of an eBook from the site by spidering it. Uses plugins to accommodate each site's quirks.

=cut

my $pluginName = "";
my $verbose = 0;
my $pluginPath = "/opt/scripts/bookspider";
my $output="";
my $incode="";
my $outcode="";
my $limit=9999;
my $listplugins=0;

my $opts = Getopt::Long::GetOptions(
	"help|h" => sub { pod2usage(7) },
	"man|m" => sub {pod2usage(-verbose => 2) },
	"plugin|p=s"	=>	\$pluginName,
	"verbose|v+" => \$verbose,
	"pluginpath|d=s" => \$pluginPath,
	"output|f=s" => \$output,
	"incode|i=s" => \$incode,
	"outcode|o=s" => \$outcode,
	"limit|l=i" => \$limit,
	"listplugins+" => sub {print join("\n", getPluginList()); exit(); }
) || pod2usage(2);

my $bookId = shift;

pod2usage(-msg => "You must specify a book ID.", -exitval => 1) if (! $bookId);
if (! $pluginName) {
	print "You must specify a plugin via --plugin.\n\n";
	print "available plugins: ".join(" ", getPluginList())."\n\n";
	pod2usage(1);
}

if ($output) {
	if (open(OUTPUT, "> $output")) {
		print STDERR "Outputting text to $output\n" if ($verbose >= 2);
	} else {
		die "Warning: Could not open $output";
	}
} else {
	if (open(OUTPUT, ">&STDOUT")) {
		binmode STDOUT, ":utf8";
		print STDERR "Outputting text to STDOUT\n" if ($verbose >= 2);
	}
}

# Read in the plugin, overriding previously-defined functions.

sub load_plugin {
	my $plugin = shift;
	
	my $sub;
	my $pluginFile = $pluginPath."/".$plugin.".pm";
	open PLUGIN, "<".$pluginFile or die "Could not open $pluginFile: $!";
	{
		local $/ = undef;
		$sub = <PLUGIN>
	}
	close PLUGIN;
	
	my $eval = (
		"\n" .
		"package BookSpider::$plugin;" .
		'use vars qw(@ISA);' .
		'use strict;' .
		'@ISA = qw(BookSpider::Plugin);' .
		$sub .
		"# End of plugin.\n"
	);
	eval $eval;
	die "ERROR: $plugin - eval $@" if $@;

	my $pclass = "BookSpider::$plugin";
	my $plug_obj = $pclass->new($bookId, $incode, $outcode, $verbose);
	#$plug_obj->{PLUGIN_NAME} = $plugin;
	return ( $plug_obj );
	
}

#my $plugincode;
#while (<PLUGIN>) {
#	$plugincode = $plugincode . $_;
#}

#eval <PLUGIN>;

my $plugin = load_plugin($pluginName);

#push @INC, $pluginPath;
#use autouse $plugin => qw( isMatchingUrl isValidBookId getName parseIndex parseDocument convert_encoding print_chapter getIndexUrl );

#use vars qw($Plugin);
#my $plug = new Safe 'Plugin';
#
#$plug->share(qw( init isMatchingUrl isValidBookId getName parseIndex parseDocument convert_encoding print_chapter getIndexUrl ));
#
#my $result = $plug->reval(<PLUGIN>);
#

#print Dumper($plugin);

$plugin->init($bookId, $incode, $outcode);




# FUNCTIONS GO HERE--------------------------------------------------------------

sub spider {
	my $indexUrl = shift;
	
	my %history = ();
	my %queue = ();
	my $pageCount=0;
	
	
	
	my $mech = WWW::Mechanize->new();
	
	$queue{$indexUrl} = 1;
	
	while ((keys %queue > 0) && ($pageCount <= $limit)) {
		my @queueItems = keys %queue;
		my $url = $queueItems[0];
		
		if ($history{$url}) {
			print STDERR "Skipping already-seen url: $url\n" if ($verbose >= 2);
			delete $queue{$url};
			next;
		}
		
		if ((! $plugin->isMatchingUrl($url)) && ($url ne $indexUrl)) {
			print STDERR "Discarding non-matching url: $url\n" if ($verbose >= 2);
			delete $queue{$url};
			$history{$url} = 1;
			next;
		}
		
		print STDERR "Retrieving $url\n" if $verbose;
		$mech->get( $url );
		
		if (! $mech->success()) {
			print "Error retrieving url: $url, status ".$mech->status()."\n";
			delete $queue{$url};
		}
		
		my @links = $mech->links();
		
		foreach my $link (@links) {
			my $linkUrl = $link->url_abs();
			if ((! $plugin->isMatchingUrl($linkUrl)) && ($linkUrl ne $indexUrl)) {
				next;
			}
			if (! $plugin->{BOOK_DATA}{$linkUrl}{'linkText'}) {
				$plugin->{BOOK_DATA}{$linkUrl}{'linktext'} = $link->text();
			}
			$queue{$linkUrl} = 1;
		}
		
		#TODO We shouldn't do this here. Leave it up to the plugin.
		if ($url eq $indexUrl) {
			$plugin->parseIndex($mech, $url);
		} else {
			$plugin->parseDocument($mech, $url);
		}
		
		#Remember this URL for next time, so we don't re-process it.
		$history{$url} = 1;
		$pageCount++;
	}
	if ($pageCount >= $limit) {
		print STDERR "Reached page limit ($limit). Stopping spider process.\n";
	}
}

sub getPluginList {
	opendir (DIR, $pluginPath) or die "Could not open $pluginPath: $!";
	my @files = grep(/\.pm$/, readdir(DIR));
	closedir(DIR);
	
	my @plugins;
	foreach my $file (@files) {
		$file =~ s/\.p[lm]//g;
		push(@plugins, $file);
	}
	
	return @plugins;
}


# PROGRAM STARTS HERE------------------------------------------------------------

#my $indexUrl = $rxIndexUrl;
#$indexUrl =~ s/%s/$bookId/g;

# Do error checking
if (!$plugin->hasValidBookId()) { die "That bookId is not valid with this plugin" }

spider($plugin->getIndexUrl());

my %sorthash = ();
my $bookData = $plugin->{BOOK_DATA};
foreach my $key (keys %$bookData) {
	if ($bookData->{$key}{'number'}) {
		my $tmpnum = $bookData->{$key}{'number'};
		$sorthash{$tmpnum} = $key;
	} else {
		#TODO: These are getting put into bookdata. Why? Does plugin do it, or bookspider?
		print STDERR "Ignoring content from $key (not a chapter.)\n";
	}
}

my $buffer;
foreach my $key (sort myplugin::plugin_sort (keys(%sorthash))) { # {$a <=> $b} is "numerically ascending".
	#TODO: Does this work with chinese numbers? (一二三四)?
	
	my $url = $sorthash{$key};
	
	$buffer = $buffer . $plugin->print_chapter($bookData->{$url});
}

#print Dumper($bookData);

print OUTPUT $buffer;

close(OUTPUT);
