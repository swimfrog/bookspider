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
	$self->{PLUGIN_NAME} = "eywedu";
	# The name of the site that this plugin is for
	$self->{PLUGIN_DESC} = "www.eywedu.com plugin";
	# The url to use for the index page (The one that contains all links, or the starting page). %s is replaced with the bookId.
	$self->{INDEX_URL} = "http://www.eywedu.com/".$self->{BOOK_ID}."/index.htm";
	# The url pattern to match for each chapter. Use groups to parse out additional data from the url.
	$self->{RX_CHAPTER_URL} = "([a-z0-9]+).htm\$";
	$self->{RX_CHAPTER_URL_INDEX} = "index.htm\$";
	$self->{RX_CHAPTER_TITLE} = "(.*?)";
	$self->{RX_BOOK_TITLE} = $self->{RX_CHAPTER_TITLE};
	$self->{RX_BOOK_ID} = ".*";

	$self->{USE_INDEX_TITLE_AS_BOOK_TITLE} = 1;
	
	$self->{BOOK_TITLE} = "";
	$self->{BOOK_DATA} = {};
	
	return bless $self, $type;
}

sub isMatchingUrl {
	my ($self, $url) = @_;
	
	my $rxChapterUrl = $self->{RX_CHAPTER_URL};
	my $rxChapterUrlIndex = $self->{RX_CHAPTER_URL_INDEX};
	if ($url =~ m|$rxChapterUrl| && $url !~ m|$rxChapterUrlIndex|) {
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
	
	#$self->parseDocument($mech, $origUrl);
}

sub parseDocument {
	my ($self, $mech, $origUrl) = @_;
	
	my $chapterNum;
	my $chapterName;
	
	my $content = $mech->content();
	my $title = $mech->title();
	my $url = $mech->uri();
	
	my $tree = HTML::TreeBuilder::XPath->new();
	$tree->parse_content($content);
	
	my $rxChapterUrl = $self->{RX_CHAPTER_URL};
	my $rxChapterUrlIndex = $self->{RX_CHAPTER_URL_INDEX};
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
	foreach my $node ($tree->findnodes_as_string("//span[\@class='f1']/p")) {
		#print STDERR "DEBUG: $node\n" if ($self->{VERBOSE} > 2);
		#Strip out H2 tags (they contain chapters, which we already have)
		#$text =~ s|<h2>.*?</h2>||g;
		$text = $text.$f->parse($node);
		#$text = $text.$node;
		#print STDERR "DEBUG: $text\n" if ($self->{VERBOSE} > 2);
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
	
	return $bookData->{'title'} . " (" . $bookData->{'number'} . ")\n\n" . $bookData->{'content'} . "\n";
}

package myplugin;
sub plugin_sort ($$) {
#	# Sort first alphabetically, then numerically
#	my ($aa, $ab, $na, $nb);
#	if ($_[0] =~ m/([a-z]+)/) { $aa = $1; }
#	if ($_[1] =~ m/([a-z]+)/) { $ab = $1; }
#	if ($_[0] =~ m/([0-9]+)/) { $na = $1; }
#	if ($_[1] =~ m/([0-9]+)/) { $nb = $1; }
#	#$aa = join('', grep(/[a-z]+/, $_[0]));
#	#$ab = join('', grep(/[a-z]+/, $_[1]));
#	#$na = join('', grep(/[0-9]+/, $_[0]));
#	#$nb = join('', grep(/[0-9]+/, $_[1]));
#	print "DEBUG: $aa $ab $na $nb\n";
#
#	if ( uc($aa) eq uc($ab)) {
#		print "DEBUG: alpha compared ".uc($aa)." with ".uc($ab)."\n";
#		$na <=> $nb;
#	} else {
#		print "DEBUG: num compared ".uc($na)." with ".uc($nb)."\n";
#		uc($aa) cmp uc($ab);
#	}
	   my $x = uc( shift );
       my $y = uc( shift );
		    if( !($x =~ /\d+(\.\d+)?/) ) {
			            return $x cmp $y;
				        }
					   my $xBefore = $`;
					       my $xMatch = $&;
						   my $xAfter = $';
						        if( !($y =~ /\d+(\.\d+)?/) ) {
								        return $x cmp $y;
									    }
									        if( $xBefore eq $` ) {
											        if( $xMatch == $& ) {
													            return naturalSortInner( $xAfter, $' );
														            } else {
																                return $xMatch <=> $&;
																		        }
																			    } else {
																				            return $x cmp $y;
																					        }
																						    print "\n<before: '$xBefore', match: '$xMatch', after: '$xAfter'>\
																						    +n";
}

# PLUGIN STUFF ENDS HERE---------------------------------------------------------
