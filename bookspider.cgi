#!/usr/bin/perl -T

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
use MIME::Lite;
use Net::SMTP::SSL;
use File::Basename;
use POSIX qw(dup2);

my $q = CGI->new;
$q->charset('utf-8');

my $command = "/opt/scripts/bookspider/bookspider.pl";
#$command = "/Users/benhaw01/desktop/BookSpider/bookspider.test.sh";	# override for development on macbook
my $outdir = "/tmp";
my $default_email = "username\@kindle.com";	# Comment out if you don't want a default address.
my $assetprefix = "http://bookspider.swimfrog.com";
#$assetprefix = "/bookspider/assets";	# override for development on macbook
my $from = 'gmail_account_username@gmail.com';
my $password = 'gmail_account_password_goes_here';

# Path untainting
$ENV{"PATH"} = "";

# Autoflush (why wouldn't you?)
local $| = 1;

# "mode" cgi parameter + untainting
my $cgi_mode = $q->param('mode');
my $mode = "init";
$mode = $1 if ($cgi_mode =~ /([a-z]+)/);

# "plugin" cgi parameter + untainting
my $cgi_plugin = $q->param('plugin');
my $plugin = "";
$plugin = $1 if ($cgi_plugin =~ /([a-z0-9_]+)/);

# "verbose" cgi parameter + untainting
my $cgi_verbose = $q->param('verbose');
my $verbose = "";
$verbose = "-v" if ($cgi_verbose =~ /([01]+)/);

# "id" cgi parameter + untainting
my $cgi_id = $q->param('id');
my $id = 0;
$id = $1 if ($cgi_id =~ /([0-9A-Za-z]+)/);

# "shortname" cgi parameter + untainting
my $cgi_shortname = $q->param('shortname');
my $shortname = "";
$shortname = $1 if ($cgi_shortname =~ /([0-9A-Za-z_]+)/);

# "email" cgi parameter + untainting
my $cgi_email = $q->param('email');
my $email = "";
$email = $1 if ($cgi_email =~ /([0-9A-Za-z_\-\.\@]+)/);

print <<EOF;
Content-type: text/html;charset=UTF-8\n
<HTML>\n
<HEAD>\n
<link rel="stylesheet" type="text/css" href="$assetprefix/stylesheet.css" id="thecss">
EOF

print '<link rel="stylesheet" type="text/css" href="'.$assetprefix.'/mobile.css" id="mobilecss"\n' if ismobile($ENV{HTTP_USER_AGENT});

print STDERR "client (useragent=".$ENV{HTTP_USER_AGENT}." mobile=".ismobile($ENV{HTTP_USER_AGENT})."\n";

print <<EOF;
<script src="$assetprefix/jquery-1.7.2.min.js"></script>
<script src="$assetprefix/jquery.watermark.js"></script>
</HEAD>\n
<BODY>\n
EOF

# Nice for debugging CGI state.
#print '<div id="debug"><p><font size=1 color="gray">'.Dumper($q).'</font></p></div>';

sub htmlize {
	my $buffer = $_;
	print Dumper($buffer);
	
	$buffer =~ s/\n/<br>\n/g;	# Add literal line breaks
	#TODO Add link detection?
	
	return $buffer;
}

sub in_array {
     my ($arr,$search_for) = @_;
     my %items = map {$_ => 1} @$arr; # create a hash out of the array values
     return (exists($items{$search_for}))?1:0;
}

sub ismobile {
	$useragent=lc(@_);
	$is_mobile = 0;
	if($useragent =~ m/(android|up.browser|up.link|mmp|symbian|smartphone|midp|wap|phone|kindle)/i) {
		$is_mobile=1;
	}
	if((index($ENV{HTTP_ACCEPT},'application/vnd.wap.xhtml+xml')>0) || ($ENV{HTTP_X_WAP_PROFILE} || $ENV{HTTP_PROFILE})) {
		$is_mobile=1;
	}
	$mobile_ua = lc(substr $ENV{HTTP_USER_AGENT},0,4);
	@mobile_agents = ('w3c ','acs-','alav','alca','amoi','andr','audi','avan','benq','bird','blac','blaz','brew','cell','cldc','cmd-','dang','doco','eric','hipt','inno','ipaq','java','jigs','kddi','keji','leno','lg-c','lg-d','lg-g','lge-','maui','maxo','midp','mits','mmef','mobi','mot-','moto','mwbp','nec-','newt','noki','oper','palm','pana','pant','phil','play','port','prox','qwap','sage','sams','sany','sch-','sec-','send','seri','sgh-','shar','sie-','siem','smal','smar','sony','sph-','symb','t-mo','teli','tim-','tosh','tsm-','upg1','upsi','vk-v','voda','wap-','wapa','wapi','wapp','wapr','webc','winw','winw','xda','xda-',);
	if(in_array(\@mobile_agents,$mobile_ua)) {
		$is_mobile=1;
	}
	if ($ENV{ALL_HTTP}) {
		if (index(lc($ENV{ALL_HTTP}),'OperaMini')>0) {
		      $is_mobile=1;
		}
	}
	if (index(lc($ENV{HTTP_USER_AGENT}),'windows')>0) {
		$is_mobile=0;
	}
    return $is_mobile;
}


sub send_file_mail {
	my $to = shift;
	my $subject = shift;
	my $filename = shift;
	
	my $from = 'username';
	my $password = 'password';
	
	open(FILE, "<$filename") || die("Couldn't open file to mail: $!");
	
	my $msg = MIME::Lite->new(
		From    =>$from,
		To      =>$to,
		CC      =>'swimfrog@gmail.com',
		Reply-To	=> 'benh@swimfrog.com',
		Subject =>$subject,
		Type    =>'text/plain',
		Data    =>"Book delivery.",
	);
	$msg->attach(
		Type => "text/plain",
		Path => $filename,
		Filename => basename($filename),
		Disposition => "attachment",
		Encoding => "base64",
	);
	
	print htmlize($msg->as_string) if $verbose;
	
	my $smtp;
	
	if (not $smtp = Net::SMTP::SSL->new('smtp.gmail.com',
	                            Port => 465,
	                            Debug => 0,
	)) {
	   die "Could not connect to server\n";
	}
	
	$smtp->auth($from, $password)
	   || die "Authentication failed!\n";
	
	$smtp->mail($from . "\n");
	my @recepients = split(/,/, $to);
	foreach my $recp (@recepients) {
	    $smtp->to($recp . "\n");
	}
	$smtp->data();
	$smtp->datasend($msg->as_string . "\n");
	$smtp->dataend();
	$smtp->quit;
	
	
	return 1;
}

sub fork_child {
    my ($child_process_code) = @_;
    my $pid = fork;
    die "Can't fork: $!\n" if !defined $pid;
    return $pid if $pid != 0;
    # Now in child process
    $child_process_code->();
    exit;
}

if ($mode eq "init") {
	print '
	<form method="POST">
	<div id="logo">
	<center>
	<img id="logo" src="'.$assetprefix.'/logo.png">
	<p>What can BookSpider grab for you today?</p>
	</center>
	</div>
	
	<div class="section" id="section_one">
		<div id="number_one" class="number">
			<img id="number_one_img" src="'.$assetprefix.'/number_one.png">
			<p class="value">Pick a plugin:</p>
		</div>
		<div id="plugin_name_div">
		<p class="value">
			<select name="plugin" id="plugin">';
			open (COMMAND, "$command --listplugins 2>&1 |") || die("Couldn't list plugins: $!");
			while (<COMMAND>) {
				chomp;
				print "<option name=\"$_\">$_</option>\n";
			}
			close(COMMAND);
			print '
			</select>
		</p>
		</div>
	</div>
	
	<div class="section" id="section_two">
		<div id="number_two" class="number">
			<img id="number_two_img" src="'.$assetprefix.'/number_two.png">
			<p class="value">A few details:</p>
		</div>		
		<div id="id_div">
			<p class="value"><input type="text" id="id" name="id"></p>
		</div>
		
		<div id="shortname_div">
			<p class="value"><input type="text" id="shortname" name="shortname"></p>
		</div>
		
		<div id="email_div">
			<p class="value"><input type="text" value="'.$default_email.'" id="email" name="email"></p>
		</div>
	</div>
	
	<div class="section" id="section_three">
		<div id="number_three" class="number">
			<img id="number_three_img" src="'.$assetprefix.'/number_three.png">
			<p class="value">Go!</p>
		</div>
		
		<div class="submit" id="submit_div">
			<input type="hidden" name="mode" value="run">
			<input type="submit" name="submit" value="submit">
		</div>

		<br>
		<div id="verbose_div">
			<p class="value"><input type="checkbox" name="verbose" value="1">Verbose?</p>
		</div>
	</div>
	
	</form>
	';
} elsif ($mode eq "run") {

	print '
	<div class="header">
		<img id="logo_small" src="'.$assetprefix.'/logo_small.png">
		<p>Now downloading '.$shortname.' using plugin '.$plugin.'...</p>
	</div>
	<div class="scriptoutput">
	';

	unless (($plugin) && ($id) && ($shortname)) {
		print "invalid parameters specified";
		die("invalid parameters specified");
	}
	
	my $runcommand = "$command $verbose -p $plugin -f $outdir/$shortname.txt $id";
	#print "<br>About to run: ".$runcommand."\n";
	
#	open(COMMAND, "$runcommand 2>&1 |") || die ("Could not execute $runcommand: $!\n");
#	
#	while (<COMMAND>) {
#		chomp;
#		next if ($_ =~ m/Wide character in print/);
#		$_ .="<br>\n";
#		print;
#	}
#	
#	close(COMMAND);
	
	my @execcmd = split(" ", $runcommand);
			
	pipe my ($readable, $writable)
		or die "Can't create pipe: $!\n";
	my $pid = fork_child(sub {
		dup2(fileno $writable, 1);
		dup2(1, 2); # Redirect stderr to stdout
		exec @execcmd or die "Can't exec $runcommand: $!\n";
	});
	close $writable;
	while (<$readable>) {
		#chomp;
		next if (m/Wide character in print/);
		#$_ .="<br>\n";
		#print "Gonna htmlize $_\n";
		#htmlize;
		print;
	}
	waitpid $pid, 0;
	
	#print "Here is the preview:<br>\n";
	
	#print '<div id="preview_div"><font size=1>';
	#open (OUTPUT, "<$outdir/$shortname.txt") || die("Couldn't open output file: $!\n");
	#while (<OUTPUT>) {
	#	print;
	#}
	#print '</font></div>';

	print '
	</div>
	';
	
	print '
	<form method="POST">
		<div id="hidden_div">
			<input type="hidden" value="$shortname">
		</div>
		<div id="hidden_div">
			<p>Please review the output. OK to send the output to '.$email.'?</p>
		</div>
		<div id="submit_div">
			<input type="hidden" name="mode" value="send">
			<input type="hidden" name="shortname" value="'.$shortname.'">
			<input type="hidden" name="email" value="'.$email.'">
			<input type="submit" value="confirm">
		</div>
	</form>
	';

} elsif ($mode eq "send") {
	print '
	<form method="POST">
		<div class="header">
			<img id="logo_small" src="'.$assetprefix.'/logo_small.png">
			<p>Now sending '.$shortname.' to '.$email.'...</p>
		</div>
		<div class="scriptoutput">
	';
	
	die "Invalid input parameters\n" if ((!$email) || (!$shortname) );
	my $succ = send_file_mail($email, $shortname, "$outdir/$shortname.txt");
	
	if ($succ) {
		print "Mail to $email sent successfully. ($outdir/$shortname.txt)\n";
	} else {
		print "Error sending mail to $email. ($outdir/$shortname.txt)\n";
	}
	
	print '		
		</div>
		<div id="submit_div">
			<input type="hidden" name="mode" value="init">
			<input type="submit" value="Start Over">
		</div>
	</form>
	';
}

print <<EOF;
<div id="footer">
	<center><p><a href="mailto:benh\@swimfrog.com">benh\@swimfrog.com</a></p></center>
</div>
<script type="text/javascript">
	\$("#id").watermark("The book ID");
	\$("#shortname").watermark("The book title");
	\$("#email").watermark("Your email address");
</script>
</BODY>\n
</HTML>\n

EOF



