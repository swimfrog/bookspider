# PLUGIN STUFF GOES HERE---------------------------------------------------------

# The name of the site that this plugin is for
my $pluginName = "Example morphine Plugin";
# The url to use for the index page (The one that contains all links, or the starting page). %s is replaced with the bookId.
my $indexUrl = "http://morphine/share/bensbook/".$bookId."/index.html";
# The url pattern to match for each chapter. Use groups to parse out additional data from the url.
my $rxChapterUrl = "bensbook\\/".$bookId."\\/".$bookId."_ch(\\p{N}+)\\.html"; #\p{N} matches unicode numeric characters.
my $rxChapterTitle = "Chapter (.*)";
my $rxBookTitle = "(.*) Index\$";
my ($fromcode, $tocode) = ($incode | "utf-8", $outcode | "utf-8");

my $useIndexTitleAsBookTitle = 1;

sub plugin_isMatchingUrl {
	my $url = shift;
	
	if ($url =~ m/$rxChapterUrl/) {
		return 1;
	}
	
	return 0;
}

sub plugin_isValidBookId {
	my $bookId = shift;
	
	return 1;
}

sub plugin_getName {
	return $pluginName;
}

sub plugin_parseIndex {
	if (($useIndexTitleAsBookTitle) && ($url eq $indexUrl)) {
		my $title = $mech->title();
		if ($title =~ m/$rxBookTitle/) {
			if ($1) {
				$title = $1;
			} 
			print "Found book title: $title\n" if ($verbose);
			$bookTitle = $title;
		}
	}
}


sub plugin_parseDocument {
	my $mech = shift;
	
	my $chapterNum;
	my $chapterName;
	
	my $content = $mech->content();
	my $title = $mech->title();
	my $url = $mech->uri();
	
	my $tree = HTML::TreeBuilder::XPath->new();
	$tree->parse_content($content);
	
	if ($url =~ m/$rxChapterUrl/) {
		print "Found chapter number: $1\n" if ($verbose);
		$bookData{$url}{'number'} = $1;
	}
	
	my $text;
	
	my $f = HTML::FormatText::WithLinks->new();
	foreach my $node ($tree->findnodes_as_string('//div[@id="Content"]')) {
		$text = $text.$f->parse($node);
		#$text = $text.$node;
	}
	
	#TODO Using this method, the entire site must use the same encoding. Any way for different pages to have different encodings? Can get current page's encoding from HTTP header?
	$text = plugin_convert_encoding($text);
	
	$bookData{$url}{'content'} = $text;
	
	if ($title =~ m/$rxChapterTitle/) {
		if ($1) {
			$title = $1;
		}
		print "Found chapter title: $title\n" if ($verbose);
		$bookData{$url}{'title'} = $title;
	}
	
#	return {
#		'content' => $content,
#		'chapterName' => $chapterName,
#		'chapterNum' => $chapterNum,
#	}
	return 1;
}

sub plugin_convert_encoding {
	my $text = shift;
	
	if ($fromcode ne $tocode) {
		my $converter = Text::Iconv->new($fromcode, $tocode);
		$text = $converter->convert($text);
	}
		
	return $text;
}

sub plugin_print_chapter {
	my $bookData = shift;
	
	print OUTPUT $bookData->{'title'}." (".$bookData->{'number'}.")"."\n";
	print OUTPUT $bookData->{'content'}."\n";
}

# PLUGIN STUFF ENDS HERE---------------------------------------------------------