# PLUGIN STUFF GOES HERE---------------------------------------------------------

use Data::Dumper;

sub new {
	my $type = shift;
	my $self = { };
	
	# Required variables when object is created
	$self->{BOOK_ID} = shift;
	my $incode = shift;
	my $outcode = shift;
	$self->{VERBOSE} = shift;
	if ($incode) {
		$self->{FROM_CODE} = $incode;
	}else{
		$self->{FROM_CODE} = "utf-8";
	};
	if ($outcode) {
		$self->{TO_CODE} = $outcode
	}else{
		$self->{TO_CODE} = "utf-8";
	};
	
	# Plugin Variables
	$self->{PLUGIN_NAME} = "wuxiapedia";
	# The name of the site that this plugin is for
	$self->{PLUGIN_DESC} = "wuxiapedia.com plugin";
	# The url to use for the index page (The one that contains all links, or the starting page). %s is replaced with the bookId.
	$self->{INDEX_URL} = "http://wuxiapedia.com/Novels/".$self->{BOOK_ID};
	$self->{RX_INTERMEDIATE_URL} = "/Novels/".$self->{BOOK_ID}."/[A-z0-9-]+\$";
	# The url pattern to match for each chapter. Use groups to parse out additional data from the url.
	$self->{RX_CHAPTER_URL} = "/Novels/".$self->{BOOK_ID}."/.*/Chapter-(\\d+)";
	#$self->{RX_CHAPTER_URL_INDEX} = "/novel/".$self->{BOOK_ID}."\.html";
	$self->{RX_CHAPTER_TITLE} = ">Chapter \\d+ : (.*?)<";
	$self->{RX_BOOK_TITLE} = "Wuxiapedia \\/ Novels \\/ (\\S+ \\/ \\S+) \\/";
	$self->{RX_BOOK_ID} = "(\\S+\\/\\S+)";

	$self->{USE_INDEX_TITLE_AS_BOOK_TITLE} = 1;
	
	$self->{BOOK_TITLE} = "";
	$self->{BOOK_DATA} = {};
	
	return bless $self, $type;
}

sub isMatchingUrl {
	my ($self, $url) = @_;
	
	my $rxChapterUrl = $self->{RX_CHAPTER_URL};
	if ($url =~ m|$rxChapterUrl|) {
		return 1;
	}
	
	my $rxIntermediateUrl = $self->{RX_INTERMEDIATE_URL};
	if ($url =~ m|$rxIntermediateUrl|) {
		return 1;
	}
	
	return 0;
}

sub hasValidBookId {
	my $self = shift;
	
	my $rxBookId = $self->{RX_BOOK_ID};
	if ($self->{BOOK_ID} =~ m|$rxBookId|) {
		return 1;
	} else {
		return 0;
	}
	
	return 1;
}

sub parseIndex {
	my ($self, $mech, $origUrl) = @_;
	
#	if (($self->{USE_INDEX_TITLE_AS_BOOK_TITLE})) {
#		my $title = $mech->title();
#		my $rxBookTitle = $self->{RX_BOOK_TITLE};
#		if ($title =~ m|$rxBookTitle|) {
#			if ($1) {
#				$title = $1;
#			} 
#			print STDERR "Found book title: $title\n" if ($self->{VERBOSE});
#			$self->{BOOK_TITLE} = $title;
#		}
#	}
	
	#$self->parseDocument($mech, $origUrl);
	return 1;
}

sub parseCharset {
	my $self = shift;
	my $buffer = shift;
	my $encoding = $self->{FROM_CODE};
	
	if ($buffer =~ m/.*; charset=(.*?)[;\$]/i) {
		$encoding = $1;
	}
	
	return $encoding;
}

sub parseDocument {
	my ($self, $mech, $origUrl) = @_;
	
	my $chapterNum;
	my $chapterName;
	
	my $content = $mech->content();
	#my $title = $mech->title();
	my $url = $mech->uri();
	
	#print Dumper($mech);
	
	my $rxIntermediateUrl = $self->{RX_INTERMEDIATE_URL};
	if ($url =~ m|$rxIntermediateUrl|) {
		print STDERR "Not parsing intermediate url: $url\n" if ($self->{VERBOSE});
		return 1;
	}
	
	my $rxChapterUrl = $self->{RX_CHAPTER_URL};
	my $rxChapterUrlIndex = $self->{RX_CHAPTER_URL_INDEX};
	if ($url =~ m|$rxChapterUrl|) {
		print STDERR "Found chapter number: $1\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'number'} = $1;
#	} elsif ($url =~ m|$rxChapterUrlIndex|) {
#		print STDERR "Found chapter number: 1\n" if ($self->{VERBOSE});
#		$self->{BOOK_DATA}{$url}{'number'} = 1;
	} else {
		print STDERR "Error: Could not parse chapter number from $url using $rxChapterUrl" if ($self->{VERBOSE});
	}
	
	my $rxChapterTitle = $self->{RX_CHAPTER_TITLE};
	if (($self->{BOOK_DATA}{$url}{'linkText'}) && ($self->{BOOK_DATA}{$url}{'linkText'} =~ m|$rxChapterTitle|)) {
		print STDERR "Found chapter number in linkText: $1\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'number'} = $1;
	}
	
	# Tried this when I was having utf-8 conversion issues, got roughly same effect, so switched back.
	
#	use HTML::TokeParser;
#	
#	my $tree = HTML::TokeParser->new(\$content);
#	
#	while (my $tag = $tree->get_tag("div")) {
#        if (($tag->[1]{class}) && ($tag->[1]{class} eq "attribute-long")) {
#        		print "Found attribute-long DIV\n";
#                while (my $contents = $tree->get_text("div") ) {
#                        $text = $text."$contents\n";
#                }
#        }
#	}
	
#	my $f = HTML::FormatText::WithLinks->new();
#	$text = $f->parse($text);

	my $tree = HTML::TreeBuilder::XPath->new();
	$tree->parse_content($content);
	my $text;
	
	my $f = HTML::FormatText::WithLinks->new();
	foreach my $node ($tree->findnodes_as_string("//div[\@class='attribute-long']/p")) {
		#Strip out H2 tags (they contain chapters, which we already have)
		#$text =~ s|<h2>.*?</h2>||g;
		$text = $text.$f->parse($node);
		#$text = $text.$node;
	}
	
	
	
	my $encoding = $self->parseCharset($mech->response()->header('Content-Type'));
	$self->{FROM_CODE} = $encoding;
	$text = $self->convert_encoding($text);
	
	$self->{BOOK_DATA}{$url}{'content'} = $text;
	
	my $chtitle;
	if ($content =~ m|$rxChapterTitle|m) {
		if ($1) {
			$chtitle = $1;
		}
		print STDERR "Found chapter title: $chtitle\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'title'} = $chtitle;
	}
	
#	return {
#		'content' => $content,
#		'chapterName' => $chapterName,
#		'chapterNum' => $chapterNum,
#	}
	return 1;
}

sub print_chapter {
	my ($self, $bookData) = @_;
	
	return $bookData->{'title'} . " (" . $bookData->{'number'} . ")\n\n" . $bookData->{'content'} . "\n";
}

# PLUGIN STUFF ENDS HERE---------------------------------------------------------