# PLUGIN STUFF GOES HERE---------------------------------------------------------

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
	$self->{PLUGIN_NAME} = "readnovelforum";
	# The name of the site that this plugin is for
	$self->{PLUGIN_DESC} = "bbs.readnovel.com forum plugin";
	# The url to use for the index page (The one that contains all links, or the starting page). %s is replaced with the bookId.
	$self->{INDEX_URL} = "http://bbs.readnovel.com/read.php?tid=".$self->{BOOK_ID}."&page=1";
	# The url pattern to match for each chapter. Use groups to parse out additional data from the url.
	$self->{RX_CHAPTER_URL} = "/read\\.php\\?tid=".$self->{BOOK_ID}."\&page=(\\d+)";
	#$self->{RX_CHAPTER_TITLE} = "\\p{Close_Punctuation}(.*)\$";
	$self->{RX_CHAPTER_TITLE} = "\\p{Close_Punctuation}(.*?)\\s-\\p{Open_Punctuation}";
	$self->{RX_BOOK_TITLE} = "\\p{Close_Punctuation}(.*?)\\s-\\p{Open_Punctuation}";
	$self->{RX_BOOK_ID} = "(\\d+)";

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
	
	if (($self->{USE_INDEX_TITLE_AS_BOOK_TITLE})) {
		my $title = $mech->title();
		my $rxBookTitle = $self->{RX_BOOK_TITLE};
		if ($title =~ m|$rxBookTitle|) {
			if ($1) {
				$title = $1;
			} 
			print STDERR "Found book title: $title\n" if ($self->{VERBOSE});
			$self->{BOOK_TITLE} = $title;
		}
	}
	
	$self->parseDocument($mech, $origUrl);
}

sub parseDocument {
	my ($self, $mech, $origUrl) = @_;
	
	my $chapterNum;
	my $chapterName;
	
	my $content = $mech->content();
	# readnovel redirects to static content, so uri from mech is not parseable. Use origUrl instead.
	my $title = $mech->title();
	my $url = $origUrl;
	
	my $tree = HTML::TreeBuilder::XPath->new();
	$tree->parse_content($content);
	
	my $rxChapterUrl = $self->{RX_CHAPTER_URL};
	if ($url =~ m|$rxChapterUrl|) {
		print STDERR "Found chapter number: $1\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'number'} = $1;
	} else {
		print STDERR "Error: Could not parse chapter number from $url using $rxChapterUrl" if ($self->{VERBOSE});
	}
	
	my $rxChapterTitle = $self->{RX_CHAPTER_TITLE};
	if (($self->{BOOK_DATA}{$url}{'linkText'}) && ($self->{BOOK_DATA}{$url}{'linkText'} =~ m|$rxChapterTitle|)) {
		print STDERR "Found chapter number in linkText: $1\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'number'} = $1;
	}
	
	my $text;
	
	my $f = HTML::FormatText::WithLinks->new();
	foreach my $node ($tree->findnodes_as_string("//span[\@class='tpc_content'")) {
		$text = $text.$f->parse($node);
		#$text = $text.$node;
	}
	
	#TODO Using this method, the entire site must use the same encoding. Any way for different pages to have different encodings? Can get current page's encoding from HTTP header?
	$text = $self->convert_encoding($text);
	
	$self->{BOOK_DATA}{$url}{'content'} = $text;
	
	if ($title =~ m|$rxChapterTitle|) {
		if ($1) {
			$title = $1;
		}
		print STDERR "Found chapter title: $title\n" if ($self->{VERBOSE});
		$self->{BOOK_DATA}{$url}{'title'} = $title;
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
	
	return $bookData->{'title'} . " (" . $bookData->{'number'} . ")\n" . $bookData->{'content'} . "\n";
}

# PLUGIN STUFF ENDS HERE---------------------------------------------------------