#!/usr/bin/perl -s
#########################################################################
#
# TTYtter v0.9 (c)2007-2009 cameron kaiser (and contributors).
# all rights reserved.
# http://www.floodgap.com/software/ttytter/
#
# distributed under the floodgap free software license
# http://www.floodgap.com/software/ffsl/
#
# After all, we're flesh and blood. -- Oingo Boingo
# If someone writes an app and no one uses it, does his code run? -- me
#
#########################################################################

require 5.005;

BEGIN {
#	@INC = (); # wreck intentionally for testing
	$TTYtter_VERSION = "0.9";
	$TTYtter_PATCH_VERSION = 5;
	$0 = "TTYtter";
	$space_pad = " " x 1024;

	(warn ("${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}\n"), exit)
		if ($version);

	$ENV{'PERL_SIGNALS'} = 'unsafe';

	%opts_boolean = map { $_ => 1 } qw(
		ansi noansi verbose superverbose ttytteristas noprompt
		seven silent hold daemon script anonymous readline ssl
		newline vcheck verify noratelimit notrack
	); %opts_sync = map { $_ => 1 } qw(
		ansi pause dmpause ttytteristas verbose superverbose
		url rlurl dmurl newline wrap autosplit notimeline
		queryurl trendurl track colourprompt colourme notrack
		colourdm colourreply colourwarn coloursearch idurl
	); %opts_urls = map {$_ => 1} qw(
		url dmurl uurl rurl wurl frurl rlurl update shorturl
		apibase queryurl trendurl idurl delurl
	); %opts_secret = map { $_ => 1} qw(
		superverbose ttytteristas
	); %opts_can_set = map { $_ => 1 } qw(
		url pause dmurl dmpause superverbose ansi verbose
		update uurl rurl wurl avatar ttytteristas frurl track
		rlurl noprompt shorturl newline wrap verify autosplit
		notimeline queryurl trendurl colourprompt colourme
		colourdm colourreply colourwarn coloursearch idurl
		urlopen delurl noratelimit notrack
	); %opts_others = map { $_ => 1 } qw(
		lynx curl seven silent maxhist noansi lib hold status
		daemon timestamp twarg user anonymous script readline
		leader ssl rc norc filter vcheck apibase 
	); %valid = (%opts_can_set, %opts_others);
	$rc = (defined($rc) && length($rc)) ? $rc : "";
	$supreturnto = $verbose + 0;
	unless ($norc) {
		if (open(W, ($n = "$ENV{'HOME'}/.ttytterrc${rc}"))) {
			while(<W>) {
				chomp;
				next if (/^\s*$/ || /^#/);
				s/^-//;
				($key, $value) = split(/\=/, $_, 2);
				if ($key eq 'rc') {
			warn "** that's stupid, setting rc in an rc file\n";
				} elsif ($key eq 'norc') {
			warn "** that's dumb, using norc in an rc file\n";
				} elsif ($valid{$key} && !length($$key)) {
					$$key = $value;
				} elsif (!$valid{$key}) {
			warn "** setting $key not supported in this version\n";
				}
			}
			close(W);
		} elsif (length($rc)) {
			die("couldn't access rc file $n: $!\n".
	"to use defaults, use -norc or don't specify the -rc option.\n\n");
		}
	}
	$seven ||= 0;
	$lib ||= "";
	$parent = $$;

	# defaults that our lib can override
	$last_id = 0;
	$last_dm = 0;
	$print_max = 100; # shiver

	# try to init Term::ReadLine if it was requested
	# (shakes fist at @br3nda, it's all her fault)
	%readline_completion = ();
	if ($readline) {
		die(
		"you can't use -silent and -readline together. pick one.\n")
			if ($silent || $script);
		eval
'use Term::ReadLine; $termrl = new Term::ReadLine ("TTYtter", \*STDIN, \*STDOUT)'
		|| die(
	"$@\nthis perl doesn't have ReadLine. don't use -readline.\n");
		$stdout = $termrl->OUT || \*STDOUT;
		$stdin = $termrl->IN || \*STDIN;
		$readline = '' if ($readline eq '1');
		$readline =~ s/^"//; # for optimizer
		$readline =~ s/"$//;
		#$termrl->Attribs()->{'autohistory'} = undef; # not yet
		(%readline_completion) = map {$_ => 1} split(/\s+/, $readline);
		%original_readline = %readline_completion;
	} else {
		$stdout = \*STDOUT;
		$stdin = \*STDIN;
	}

	print $stdout "$leader\n" if (length($leader));
	if (length($lib)) {
		warn "** attempting to load library: $lib\n" unless ($silent);
		require $lib;
	}
	unless ($seven) {
		eval
'use utf8;binmode($stdin,":utf8");binmode($stdout,":utf8");return 1' ||
	die("$@\nthis perl doesn't fully support UTF-8. use -seven.\n");
	# this is for the prinput utf8 validator.
	# adapted from http://mail.nl.linux.org/linux-utf8/2003-03/msg00087.html
		$badutf8='[\x00-\x7f][\x80-\xbf]+|^[\x80-\xbf]+|'.
			 '[\xc0-\xdf][\x00-\x7f\xc0-\xff]|'.
	 		 '[\xc0-\xdf][\x80-\xbf]{2}|'.
	 		 '[\xe0-\xef][\x80-\xbf]{0,1}[\x00-\x7f\xc0-\xff]|'.
	 		 '[\xe0-\xef][\x80-\xbf]{3}|'.
	 		 '[\xf0-\xf7][\x80-\xbf]{0,2}[\x00-\x7f\xc0-\xff]|'.
	 		 '[\xf0-\xf7][\x80-\xbf]{4}|'.
	 		 '[\xf8-\xfb][\x80-\xbf]{0,3}[\x00-\x7f\xc0-\xff]|'.
	 		 '[\xf8-\xfb][\x80-\xbf]{5}|'.
	 	'[\xfc-\xfd][\x80-\xbf]{0,4}[\x00-\x7f\xc0-\xff]|'.
			'\xed[\xa0-\xbf][\x80-\xbf]|'.
			'\xef\xbf[\xbe-\xbf]|'.
 			'[\xf0-\xf7][\x8f,\x9f,\xaf,\xbf]\xbf[\xbe-\xbf]|'.
			'\xfe|\xff|'.
	 		 '[\xc0-\xc1][\x80-\xbf]|'.
	 		 '\xe0[\x80-\x9f][\x80-\xbf]|'.
	 		 '\xf0[\x80-\x8f][\x80-\xbf]{2}|'.
	 		 '\xf8[\x80-\x87][\x80-\xbf]{3}|'.
	 		 '\xfc[\x80-\x83][\x80-\xbf]{4}'; # gah!

	}
	if ($timestamp) {
		if (length($timestamp) > 1) { # pattern specified
			eval 'use Date::Parse;return 1' ||
		die("$@\nno Date::Parse -- no custom timestamps.\nspecify -timestamp by itself to use Twitter's without module.\n");
			eval 'use Date::Format;return 1' ||
		die("$@\nno Date::Format -- no custom timestamps.\nspecify -timestamp by itself to use Twitter's without module.\n");
			$mtimestamp = 1;
			$timestamp = "%Y-%m-%d %k:%M:%S"
				if ($timestamp eq "default" ||
				    $timestamp eq "def");
		}
	}

	# do we have POSIX::Termios? (usually we do)
	eval 'use POSIX; $termios = new POSIX::Termios;';
	print $stdout "-- termios test: $termios\n" if ($verbose);

	# wrap warning
	die(
"** dude, what the hell kind of terminal can't handle a 5 character line?\n")
		if ($wrap > 1 && $wrap < 5);
	print $stdout "** warning: prompts not wrapped for wrap < 70\n"
		if ($wrap > 1 && $wrap < 70);

	# precompile filter line for speed
	if ($filter) {
		# note attributes
		${"filter_$1"}++ while ($filter =~ s/^([a-z]+),//);
		my $b = <<"EOF";
		\$filter = sub {
			local \$_ = shift;
			return ($filter);
		};
EOF
		undef $filter;
		eval $b;
		die("syntax error in your filter: $@\n") if (!length($filter));
	}
	$is_background = 0;
	%store_hash = ();
	$back_split = 200; # i.e., 200 tweets reserved for background menuroll
	$mini_split = 250; # i.e., 10 tweets for the mini-menu (/th)
	# leaving 50 tweets for the foreground temporary menus
	$tweet_counter = 0;
	$alphabet = "abcdefghijkLmnopqrstuvwxyz";
	$in_reply_to = 0;
	$expected_tweet_ref = undef;
}

# track tag management subroutines

# run when a string is passed
sub tracktags_makearray {
	@tracktags = ();
	$track =~ s/^'//; $track =~ s/'$//;
	if (!length($track)) {
		@trackstrings = ();
		return;
	}
	my $k;
	my $l = '';
	my $q = 0;
	my %w;
	my (@ptags) = split(/\s+/, $track);

	# filter duplicates and merge quoted strings
	foreach $k (@ptags) {
		if ($q && $k =~ /"$/) { # this has to be first
			$l .= " $k";
			$q = 0;
		} elsif ($k =~ /^"/ || $q) {
			$l .= (length($l)) ? " $k" : $k;
			$q = 1;
			next;
		} else {
			$l = $k;
		}
			
		if ($w{$l}) {
			print $stdout
			"-- warning: dropping duplicate track term \"$l\"\n";
		} elsif (uc($l) eq 'OR' || uc($l) eq 'AND') {
			print $stdout
			"-- warning: dropping unnecessary logical op \"$l\"\n";
		} else {
			$w{$l} = 1;
			push(@tracktags, $l);
		}
		$l = '';
	}
	print $stdout "-- warning: syntax error, missing quote?\n" if ($q);
	$track = join(' ', @tracktags);
	&compile_tracktags;
}
	
# run when array is altered (based on @kellyterryjones' code)
sub compile_tracktags {
	@trackstrings = ();
	return if (!scalar(@tracktags));

	my $k;
	my $l = '';
	my @jtags = map { # don't alter @tracktags, and support UTF-8
		$j=$_; $j=~s/([^0-9a-zA-Z_])/&uhex($1)/eg; $j;
	} @tracktags;
	# need to make 140 character pieces
	TAGBAG: foreach $k (@jtags) {
		if (length($k) > 130) { # I mean, really
			print $stdout
				"-- warning: track tag \"$k\" is TOO LONG\n";
			next TAGBAG;
		}
		if (length($l)+length($k) > 130) { # reasonable safety
			push(@trackstrings, $l);
			$l = '';
		}
		$l = (length($l)) ? "${l}+OR+${k}" : "q=${k}";
	}
	push(@trackstrings, $l) if (length($l));
}

# set up track tags
&tracktags_makearray;

sub end_me { exit; } # which falls through to ...
END {
	&killkid;
}
sub generate_otabcomp {
	if (scalar(@j = keys(%readline_completion))) {
		# print optimized readline. include all that we
		# manually specified, plus/including top @s, total 10.
		@keys = sort { $readline_completion{$b} <=>
			$readline_completion{$a} } @j;
		$factor = $readline_completion{$keys[0]};
		foreach(keys %original_readline) {
			$readline_completion{$_} += $factor;
		}
		print $stdout "*** optimized readline:\n";
		@keys = sort { $readline_completion{$b} <=>
			$readline_completion{$a} } keys
				%readline_completion;
		@keys = @keys[0..14] if (scalar(@keys) > 15);
		print $stdout "-readline=\"@keys\"\n";
	}
}
sub killkid {
	if ($child) {
		print $stdout "\n\ncleaning up.\n";
		if (length($track)) {
			print $stdout "*** you were tracking:\n";
			print $stdout "*** -track='$track'\n";
		}
		&generate_otabcomp;
		kill 9, $child;
	}
	#print $stdout "done.\n";
	exit;
}

# interpret script at this level
if ($script) {
	$silent = $noansi = $noprompt = 1;
	$pause = $vcheck = 0;
}

die("you can't use automatic ratelimits with -noratelimit.\nuse -pause=#sec\n")
	if ($noratelimit && $pause eq 'auto');

# dup $stdout for benefit of various other scripts
if ($termrl) {
	# this is mostly for 5.005 which doesn't have three-item open()
	eval 'open(DUPSTDOUT,">&", $stdout); return 1;' || do {
		warn("** warning: could not dup STDOUT: $!\n");
	};
	warn(<<"EOF") if ($] < 5.006);
*************************************************
** -readline is not supported on Perls < 5.6.0 **
** your terminal may not display correctly!!!! **
*************************************************
EOF
} else {
	open(DUPSTDOUT, ">&STDOUT") ||
		warn("** warning: could not dup $stdout: $!\n");
}
if ($silent) {
	close($stdout);
	open($stdout, ">>/dev/null"); # KLUUUUUUUDGE
}
binmode(DUPSTDOUT, ":utf8") unless ($seven);

# initialize our route back out so background can talk to foreground
pipe(W, P) || die("pipe() error [or your Perl doesn't support it]: $!\n");
select(P); $|++;
binmode(P, ":utf8") unless ($seven);
binmode(W, ":utf8") unless ($seven);

# defaults
$anonymous ||= 0;
undef $user if ($anonymous);
if ($ssl) {
	print $stdout "-- using SSL for default URLs.\n";
}
$http_proto = ($ssl) ? 'https' : 'http';

$apibase ||= "${http_proto}://twitter.com";
$url ||= ($anonymous)
	? "${apibase}/statuses/public_timeline.json"
	: "${apibase}/statuses/friends_timeline.json";
$rurl ||= "${apibase}/statuses/replies.json";
$uurl ||= "${apibase}/statuses/user_timeline";
$wurl ||= "${apibase}/users/show";
$update ||= "${apibase}/statuses/update.json";
$dmurl ||= "${apibase}/direct_messages.json";
$frurl ||= "${apibase}/friendships/exists.json";
$rlurl ||= "${apibase}/account/rate_limit_status.json";
$idurl ||= "${apibase}/statuses/show";
$delurl ||= "${apibase}/statuses/destroy";

#$shorturl ||= "http://bit.ly/api?url=";
$shorturl ||= "http://is.gd/api.php?longurl=";
# figure out the domain to stop shortener loops
sub generate_shortdomain {
	($shorturl =~ m#^(http://[^/]+/)#) && ($shorturldomain = $1);
	print $stdout "-- warning: couldn't parse shortener service\n"
		if (!length($shorturldomain));
}
&generate_shortdomain;

$queryurl ||= "http://search.twitter.com/search.json";
$trendurl ||= "http://search.twitter.com/trends/current.json";

$pause = (($anonymous) ? 120 : "auto") if (!defined $pause);
	# NOT ||= ... zero is a VALID value!
$superverbose ||= 0;
$avatar ||= "";
$urlopen ||= 'echo %U';
$hold ||= 0;
$daemon ||= 0;
$maxhist ||= 19;
$timestamp ||= 0;
$noprompt ||= 0;
$twarg ||= undef;

$colourprompt ||= "CYAN";
$colourme ||= "YELLOW";
$colourdm ||= "GREEN";
$colourreply ||= "RED";
$colourwarn ||= "MAGENTA";
$coloursearch ||= "CYAN";

$verbose ||= $superverbose;
$dmpause = 4 if (!defined $dmpause); # NOT ||= ... zero is a VALID value!
$dmpause = 0 if ($anonymous);
$dmpause = 0 if ($pause eq '0');
$ansi = ($noansi) ? 0 :
	(($ansi || $ENV{'TERM'} eq 'ansi' || $ENV{'TERM'} eq 'xterm-color')
		? 1 : 0);
$whoami = (split(/\:/, $user, 2))[0] unless ($anonymous);

$dmcount = $dmpause;
$lastshort = undef;

# to force unambiguous bareword interpretation
$true = 'true';
sub true { return 'true'; }
$false = 'false';
sub false { return 'false'; }
$null = undef;
sub null { return undef; }

# ANSI sequences
$ESC = pack("C", 27);
$BEL = pack("C", 7);
sub generate_ansi {
	my $k;

	$BLUE = ($ansi) ? "${ESC}[34;1m" : '';
	$RED = ($ansi) ? "${ESC}[31;1m" : '';
	$GREEN = ($ansi) ? "${ESC}[32;1m" : '';
	$YELLOW = ($ansi) ? "${ESC}[33m" : '';
	$MAGENTA = ($ansi) ? "${ESC}[35m" : '';
	$CYAN = ($ansi) ? "${ESC}[36m" : '';

	$EM = ($ansi) ? "${ESC}[1;3m" : '';
	$UNDER = ($ansi) ? "${ESC}[4m" : '';
	$OFF = ($ansi) ? "${ESC}[0m" : '';

	foreach $k (qw(prompt me dm reply warn search)) {
		${"colour$k"} = uc(${"colour$k"});
		if (!defined($${"colour$k"})) {
			print $stdout
		"-- warning: bogus colour '".${"colour$k"}."'\n";
		} else {
			eval("\$CC$k = \$".${"colour$k"});
		}
	}
}
&generate_ansi;

# default exposed methods
# don't change these here. instead, use -lib=yourlibrary.pl and set them there.
# note that these are all anonymous subroutine references.
# anything you don't define is overwritten by the defaults.
# it's better'n'superclasses.

sub defaultexception {
	shift;
	print $stdout "${MAGENTA}@_${OFF}";
	$laststatus = 1;
}
$exception ||= \&defaultexception;
sub defaulthandle {
	my $tweet_ref = shift;
	my $class = shift;
	my $menu_select = $tweet_ref->{'menu_select'};

	$menu_select = (length($menu_select) && !$script)
		? "${menu_select}> " : '';
	$class = ($verbose) ? "{$class,$tweet_ref->{'id'}} " :  '';
	if ($silent) {
		print DUPSTDOUT $menu_select . $class .
			&standardtweet($tweet_ref);
	} else {
		print $stdout $menu_select . $class .
			&standardtweet($tweet_ref);
	}
	return 1;
}

sub wraptime {
	my $time = shift;
	my $ts = $time;
	if ($mtimestamp) {
		# avoid precompiling these in case .pm not present
		eval '$time = str2time($time);' ||
			die("str2time failed: $time $@ $!\n");
		eval '$ts = time2str($timestamp, $time);' ||
			die("time2str failed: $timestamp $time $@\n");
	}
	return ($time, $ts);
}

sub standardtweet {
	my $ref = shift;
	my $sn = &descape($ref->{'user'}->{'screen_name'});
	my $tweet = &descape($ref->{'text'});
	my $colour;
	my $g;
	my $h;

	# wordwrap really ruins our day here, thanks a lot, @augmentedfourth
	# have to insinuate the ansi sequences after the string is wordwrapped

	$g = $colour = &$choosecolour($ref, $sn, $tweet);
	$colour = $OFF . $colour;

	$sn = "\@$sn" if ($ref->{'in_reply_to_status_id'} > 0);
	$sn = "*$sn" if ($ref->{'source'} =~ /TTYtter/ && $ttytteristas);
	$tweet = "<$sn> $tweet";
	# br3nda's modified timestamp patch
	if ($timestamp) {
		my ($time, $ts) = &wraptime($ref->{'created_at'});
		$tweet = "[$ts] $tweet";
	}
	
	# pull it all together
	$tweet = &wwrap($tweet, ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0)
		if ($wrap); # remember to account for prompt length on #1
	$tweet =~ s/^([^<]*)<([^>]+)>/${g}\1<${EM}\2${colour}>/;
	$tweet =~ s/\n*$//;
	$tweet .= "$OFF\n";

	# highlight anything that we have in track
	if(scalar(@tracktags)) { # I'm paranoid
		foreach $h (@tracktags) {
			$h =~ s/^"//; $h =~ s/"$//; # just in case
$tweet =~ s/(^|[^a-zA-Z0-9])($h)([^a-zA-Z0-9]|$)/\1${EM}\2${colour}\3/ig;
		}
	}

	# smb's underline/bold patch goes on last
	$tweet =~ s/(^|[^a-zA-Z0-9_])\@(\w+)/\1\@${UNDER}\2${colour}/g;

	return $tweet;
}
$handle ||= \&defaulthandle;

sub defaultchoosecolour {
	my $ref = shift;
	my $sn = shift;
	my $tweet = shift;

	# br3nda's and smb's modified colour patch
	unless ($anonymous) {
		if ($sn eq $whoami) {
			# if it's me speaking, colour the line yellow
			return $CCme;
		} elsif ($tweet =~ /\@$whoami/i) {
			# if I'm in the tweet, colour red
			return $CCreply;
		} elsif ($ref->{'class'} eq 'search') {
			# if this is a search result, colour cyan
			return $CCsearch;
		}
	}
	return '';
}
$choosecolour ||= \&defaultchoosecolour;

sub defaultconclude {
	if ($filtered && $filter_count) {
		print $stdout "-- (filtered $filtered tweets)\n";
		$filtered = 0;
	}
}
$conclude ||= \&defaultconclude;

sub defaultdmhandle {
	if ($silent) {
		print DUPSTDOUT &standarddm(shift);
	} else {
		print $stdout &standarddm(shift);
	}
	return 1;
}
sub standarddm {
	my $ref = shift;
	my ($time, $ts) = &wraptime($ref->{'created_at'});
	my $text = &descape($ref->{'text'});
	my $g = &wwrap("[DM ".
		&descape($ref->{'sender'}->{'screen_name'}) .
		"/$ts] $text", ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0);
	$g =~ s/^\[DM ([^\/]+)\//${CCdm}[DM ${EM}\1${OFF}${CCdm}\//;
	$g =~ s/\n*$//;
	$g .= "$OFF\n";
	$g =~ s/(^|[^a-zA-Z0-9_])\@(\w+)/\1\@${UNDER}\2${OFF}${CCdm}/g;
	return $g;
}
$dmhandle ||= \&defaultdmhandle;

sub defaultdmconclude { ; }
$dmconclude ||= \&defaultdmconclude;

sub defaultheartbeat { ; }
$heartbeat ||= \&defaultheartbeat;

sub defaultprecommand { return ("@_"); }
$precommand ||= \&defaultprecommand;

sub defaultprepost { return ("@_"); }
$prepost ||= \&defaultprepost;

sub defaultpostpost {
	my $line = shift;
	return if (!$termrl);

	# populate %readline_completion if readline is on
	while($line =~ s/^\@(\w+)\s+//) {
		$readline_completion{'@'.$1}++;
	}
	if ($line =~ /^[dD]\s+(\w+)\s+/) {
		$readline_completion{'@'.$1}++;
	}
}
$postpost ||= \&defaultpostpost;

sub defaultautocompletion {
	my ($text, $line, $start) = (@_);
	my @proband;
	my @rlkeys;

	# handle / completion
	if ($start == 0 && $text =~ m#^/#) {
		return grep(/^$text/i, '/history',
			'/print', '/quit', '/bye', '/again',
			'/wagain', '/whois', '/thump', '/dm',
			'/refresh', '/dmagain', '/set', '/help',
			'/replies', '/ruler', '/exit', '/me',
			'/verbose', '/short');
	}
	@rlkeys = keys(%readline_completion);

	# handle @ completion. this works slightly weird because
	# readline hands us the string WITHOUT the @, so we have to
	# test somewhat blindly. this works even if a future readline
	# DOES give us the word with @. also handles D, /wa, /wagain,
	# /a, /again, etc.
	if (($line =~ m#^(D|/wa|/wagain|/a|/again) #i) ||
		($start == 1 && substr($line, 0, 1) eq '@') ||
		# this code is needed to prevent inline @ from flipping out
		($start >= 1 && substr($line, ($start-2), 2) eq ' @')) {
		@proband = grep(/^\@$text/i, @rlkeys);
		if (scalar(@proband)) {
			@proband = map { s/^\@//;$_ } @proband;
			return @proband;
		}
	}
	# definites that are left over, including @ if it were included
	if(scalar(@proband = grep(/^$text/i, @rlkeys))) {
		return @proband;
	}

	# heuristics
	# URL completion (this doesn't always work of course)
	if ($text =~ m#http://#) {
		return (&urlshorten($text) || $text);
	}

	# "I got nothing."
	return ();
}
if ($termrl) {
	$termrl->Attribs()->{'completion_function'} =
		($autocompletion) ? $autocompletion : \&defaultautocompletion;
}

select($stdout); $|++;

if ($lynx) {
	if (length($lynx) > 1 && -x "/$lynx") {
		$wend = $lynx;
		print $stdout "Lynx forced to $wend\n";
	} else {
		$wend = &wherecheck("trying to find Lynx", "lynx",
"specify -curl to use curl instead, or just let TTYtter autodetect stuff.\n");
	}
} else {
	if (length($curl) > 1 && -x "/$curl") {
		$wend = $curl;
		print $stdout "cURL forced to $wend\n";
	} else {
		$wend = (($curl) ? &wherecheck("trying to find cURL", "curl",
"specify -lynx to use Lynx instead, or just let TTYtter autodetect stuff.\n")
			: &wherecheck("trying to find cURL", "curl"));
		if (!$curl && !length($wend)) {
			$wend = &wherecheck("failed. trying to find Lynx",
				"lynx",
	"you must have either Lynx or cURL installed to use TTYtter.\n")
					if (!length($wend));
			$lynx = 1;
		} else {
			$curl = 1;
		}
	}
}
$baseagent = $wend;

# this is where OAuth will live when that support is completed.
sub defaultauthenticate {
	my @foo;
	my $pass;

	return undef if ($anonymous);
	@foo = split(/:/, $user, 2);
	$whoami = $foo[0];
	die("choose -user=username[:password], or -anonymous.\n")
		if (!length($whoami) || $whoami eq '1');
	$pass = $foo[1];
	if (!length($pass)) {
		# original idea by @jcscoobyrs, heavily modified
		my $k;
		my $l;

		$l = "no termios; password WILL";
		if ($termios) {
			$termios->getattr(fileno($stdin));
			$k = $termios->getlflag;
			$termios->setlflag($k ^ &POSIX::ECHO);
			$termios->setattr(fileno($stdin));
			$l = "password WILL NOT";
		}
		print $stdout "enter password for $whoami ($l be echoed): ";
		chomp($pass = <$stdin>);
		if ($termios) {
			print $stdout "\n";
			$termios->setlflag($k);
			$termios->setattr(fileno($stdin));
		}
	}
	die("a password must be specified.\n") if (!length($pass));
	return ($lynx) ? "-auth=$whoami:$pass" :
		($curl) ? "-u $whoami:$pass" : # no --basic now (ktj)
		die("authenticating for an unknown browser: wtf\n");
}
$authenticate ||= \&defaultauthenticate;

# authenticate sets $whoami, sphincter says $what
sub update_authenticationheaders {
#TODO
# needs to stop asking for password all the damn time when not given
	$auth = ($anonymous) ? "" : &$authenticate;
	if ($lynx) {
		$wend = "$baseagent -nostatus";
		$weld = "$wend -source";
		$wend = "$wend $auth";
		$wand = "$wend -source";
		$wind = "$wand";
		$wend = "$wend -post_data";
	} else {
		$wend = "$baseagent -s -m 13 -f";
		$weld = $wend;
		$wend = "$wend $auth";
		$wand = "$wend -f";
		$wind = "$wend";
		$wend = "$wend --data \@-";
	}
}
&update_authenticationheaders;

# update check
sub updatecheck {
	my $vcheck_url =
		"http://www.floodgap.com/software/ttytter/00current.txt";
	my $vs;
	my $tverify;
	my $inversion;
	my $vittles;
	my $maj;
	my $min;

	print $stdout "-- checking version at $vcheck_url\n";
	chomp($vs = `$weld $vcheck_url`);
	($tverify, $inversion, $vittles) = split(/;/, $vs, 3);
	if ($tverify ne 'ttytter') {
		$vs = "-- warning: unable to verify version\n";
	} else {
		($inversion =~/^(\d+\.\d+)\.(\d+)$/) && ($maj = 0+$1,
			$min = 0+$2);
		if (0+$TTYtter_VERSION < $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION < $min)) {
			$vs =
	"** NEWER TTYtter VERSION NOW AVAILABLE: $inversion **\n";
		} elsif (0+$TTYtter_VERSION > $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION > $min)) {
			$vs = 
	"** REMINDER: you are using a beta or unofficial release\n";
		} else {
			$vs =
	"-- your version of TTYtter is up to date ($inversion)\n";
		}
	}
	$vs .= "** TTYtter NOTICE: $vittles\n" if (length($vittles));
	return $vs;
}
if ($vcheck && !length($status)) {
	$vs = &updatecheck;
} else {
	$vs =
	"-- no version check performed (use -vcheck to check on startup)\n"
	unless ($script || $status);
}
print $stdout $vs; # and then again when client starts up

# initial login tests and command line controls

$phase = 0;
for(;;) {
	$rv = 0;
	die(
	"sorry, you can't tweet anonymously. use an authenticated username.\n")
		if ($anonymous && length($status));
	die(
"sorry, status too long: reduce by @{[ &ulength($status)-140 ]} bytes, ".
"or use -autosplit={word,char,cut}.\n")
		if (&ulength($status) > 140 && !$autosplit);
	($status, $next) = &usplit($status, ($autosplit eq 'char' ||
			$autosplit eq 'cut') ? 1 : 0)
		if (!length($next));
	if ($autosplit eq 'cut' && length($next)) {
		print "-- warning: input autotrimmed to 140 bytes\n";
		$next = "";
	}
	if (length($status) && $phase) {
		print "post attempt "; $rv = &updatest($status, 0);
	} else {
		$cline = "$wind $url 2>/dev/null";
		print "test-login "; 
		print "\n$cline\n" if ($superverbose);
		$data = `$cline`;
		$rv = $?;
	}
	if ($rv) {
		$x = $rv >> 8;
		print "FAILED. ($x) bad password, login or URL? server down?\n";
		print "access failure on: ";
		print (($phase) ? $update : $url);
		print "\n";
		print "--- data received ---\n$data\n--- data received ---\n"
			if ($superverbose);
		if ($hold) {
			print
			"trying again in 2 minutes, or kill process now.\n\n";
			sleep 120;
			next;
		}
		print "to automatically wait for a connect, use -hold.\n";
		exit 1;
	}
	if ($status && !$phase) {
		print "SUCCEEDED!\n";
		$phase++;
		next;
	}
	if (length($next)) {
		print "SUCCEEDED!\n(autosplit) ";
		$status = $next;
		$next = "";
		next;
	}
	last;
}
print "SUCCEEDED!\n";
exit 0 if (length($status));

# daemon mode

$last_rate_limit = undef;
$rate_limit_left = undef;
$rate_limit_rate = undef;
$rate_limit_next = 0;
$effpause = 0; # for both daemon and background
if ($daemon) {
	if (!$pause) {
		print $stdout "*** kind of stupid to run daemon with pause=0\n";
		exit 1;
	}
	if ($child = fork()) {
		print $stdout "*** detached daemon released. pid = $child\n";
		kill 15, $$;
		exit 0;
	} elsif (!defined($child)) {
		print $stdout "*** fork() failed: $!\n";
		exit 1;
	} else {
		# using our regular MONITOR select() loop won't work, because
		# STDIN is almost always "ready." so we use a blunter,
		# simpler one.
		$parent = 0;
		$dmcount = 1 if ($dmpause); # force fetch
		for(;;) {
			&$heartbeat;
			&update_effpause;
			&refresh(0);
			if ($dmpause) {
				if (!--$dmcount) {
					&dmrefresh(0);
					$dmcount = $dmpause;
				}
			}
			sleep ($effpause || $pause || 60);
		 }
	}
	die("uncaught fork() exception\n");
}

# interactive mode

print <<"EOF";

######################################################        +oo=========oo+ 
         ${EM}TTYtter ${TTYtter_VERSION}.${TTYtter_PATCH_VERSION} (c)2009 cameron kaiser${OFF}                 @             @
EOF
$e = <<'EOF';
                 ${EM}all rights reserved.${OFF}                         +oo=   =====oo+
       ${EM}http://www.floodgap.com/software/ttytter/${OFF}            ${GREEN}a==:${OFF}  ooo
                                                            ${GREEN}.++o++.${OFF} ${GREEN}..o**O${OFF}
  freeware under the floodgap free software license.        ${GREEN}+++${OFF}   :O${GREEN}:::::${OFF}
        http://www.floodgap.com/software/ffsl/              ${GREEN}+**O++${OFF} #   ${GREEN}:ooa${OFF}
                                                                   #+$$AB=.
         ${EM}tweet me: http://twitter.com/ttytter${OFF}                   #;;${YELLOW}ooo${OFF};;
            ${EM}tell me: ckaiser@floodgap.com${OFF}                          #+a;+++;O
######################################################           ,$B.${RED}*o***${OFF} O$,
#                                                                a=o${RED}$*O*O*$${OFF}o=a
# when ready, hit RETURN/ENTER for a prompt.                        @${RED}$$$$$${OFF}@
# type /help for commands or /quit to quit.                         @${RED}o${OFF}@o@${RED}o${OFF}@
# starting background monitoring process.                           @=@ @=@
#
EOF
$e =~ s/\$\{([A-Z]+)\}/${$1}/eg; print $stdout $e;
if ($superverbose) {
	print $stdout "-- OMGSUPERVERBOSITYSPAM enabled.\n\n";
} else {
	print $stdout "-- verbosity enabled.\n\n" if ($verbose);
}
sleep 3 unless ($silent);

sub defaultprompt {
	my $rv = ($noprompt) ? "" : "TTYtter> ";
	my $rvl = ($noprompt) ? 0 : 9;
	return ($rv, $rvl) if (shift);
	$wrapseq = 0;
	print $stdout "${CCprompt}$rv${OFF}" unless ($termrl);
}
$prompt ||= \&defaultprompt;

sub defaultaddaction { return 0; }
$addaction ||= \&defaultaddaction;

sub defaultconsole {
	@history = ();
	if ($termrl) {
		while(defined ($_ = $termrl->readline((&$prompt(1))[0]))) {
			$rv = &prinput($_);
			last if ($rv);
		}
	} else {
		&$prompt;
		while(<>) { #not stdin so we can read from script files
			$rv = &prinput($_);
			last if ($rv);
			&$prompt;
		}
	}
}

$console ||= \&defaultconsole;

# this has to be last or the background process can't see the full API
if ($child = open(C, "|-")) {
	close(P);
	binmode(C, ":utf8") unless ($seven);
} else {
	close(W);
	goto MONITOR;
}
$SIG{'BREAK'} = $SIG{'INT'} = \&end_me;
select(C); $|++; select($stdout);

&$console;
exit;

# for future expansion: this is the declared API callable method
sub ucommand { &prinput(@_); }

sub prinput {
	my $i;
	local($_) = shift; # bleh

	# validate this string if we are in UTF-8 mode
	unless ($seven) {
		$probe = $_;
		eval 'utf8::encode($probe);';
		die("utf8 doesn't work right in this perl. run with -seven.\n")
			if (&ulength($probe) < length($_));
			# should be at least as big
		if ($probe =~ /($badutf8)/) {
print $stdout "*** invalid UTF-8: partial delete of a wide character?\n";
			print $stdout "*** ignoring this string\n";
			return 0;
		}
	}

	$in_reply_to = 0;
	chomp;
	$_ = &$precommand($_);
	s/^\s+//;
	s/\s+$//;
	my $cfc = 0;
	$cfc++ while (s/\033\[[0-9]?[ABCD]// || s/.[\177]// || s/.[\010]//
		|| s/[\000-\037\177]//);
	if ($cfc) {
		$history[0] = $_;
		print $stdout "*** filtered control characters; now \"$_\"\n";
	print $stdout "*** use %% for truncated version, or append to %%.\n";
		return 0;
	}

	if (/^$/) {
		return 0;
	}

	if (/^\%(\%|-\d+):p$/) {
		my $x = $1;
		if ($x eq '%') {
			print $stdout "=> \"$history[0]\"\n";
		} else {
			$x += 0;
			if (!$x || $x < -(scalar(@history))) {
				print $stdout "*** illegal index\n";
			} else {
				print $stdout "=> \"$history[-($x + 1)]\"\n";
			}
		}
		return 0;
	}

	# handle history substitution (including /%%, %%--, etc.)
	$i = 0;
	if (/^(\/?)\%(\%|-\d+)(--|-\d+)?/) {
		$i = 1;
		my $y = $1;
		my $r = $2;
		my $s = $3;
		my $x;
		my $q;
		$_ = substr($_, 1) if ($y eq '/');
		if ($r eq '%') {
			$x = -1;
		} else {
			$x = $r + 0;
		}
		if (!$x || $x < -(scalar(@history))) {
			print $stdout "*** illegal index\n";
			return 0;
		}
		my $proband = $history[-($x + 1)];
		if ($s eq '--') {
			$q = 1;
		} else {
			$q = -(0+$s);
		} 
		if ($q) {
			my $j;
			for($j=0; $j<$q; $j++) {
				$proband =~ s/\s+[^\s]+$//;
			}
		}
		s/^\%$r$s/$proband/;
		$_ = "$y$_";
	}
	$i = 1 if (s/^\%URL\%/$urlshort/ || s/\%URL\%$/$urlshort/);
	$i = 1 if (s/^\%RT\%/$retweet/ || s/\%RT\%$/$retweet/);

	# and escaped history
	s/^\\\%/%/;

	if ($i) {
		print $stdout "(expanded to \"$_\")\n" ;
		$in_reply_to = $expected_tweet_ref->{'id'} || 0
			if (defined $expected_tweet_ref &&
				ref($expected_tweet_ref) eq 'HASH');
	} else {
		$expected_tweet_ref = undef;
	}

	# handle history display
	if ($_ eq '/history' || $_ eq '/h') {
		@history = (($_, @history)[0..&min(scalar(@history),
			$maxhist)]) if ($termrl); # this is fricking gross.
		for ($i = scalar(@history); $i >= 1; $i--) {
			print $stdout "\t$i\t$history[($i-1)]\n";
		}
		return 0;
	}	
	@history = (($_, @history)[0..&min(scalar(@history), $maxhist)]);
	$termrl->addhistory($_) if ($termrl);

	my $slash_first = ($_ =~ m#^/#);

	return -1 if ($_ eq '/quit' || $_ eq '/q' || $_ eq '/bye' ||
			$_ eq '/exit');

	return 0 if (&$addaction($_));

	# add commands here
	if (m#^/zipet (..)#) {
		$k = &get_tweet($1);
		warn "$k->{'user'}->{'screen_name'} said $k->{'text'}\n";
		return 0;
	}

	# evaluator
	if (m#^/ev(al)? (.+)$#) {
		$k = eval $2;
		print $stdout "==> $k $@\n";
		return 0;
	}

	# version check
	if (m#^/v(ersion)?check$# || m#^/u(pdate)?check$#) {
		print $stdout &updatecheck;
		return 0;
	}

	# url shortener routine
	if (m#^/sh(ort)? (http://[^ ]+)#) {
		print $stdout
"*** shortened to: @{[ (&urlshorten($2) || 'FAILED -- %% to retry') ]}\n";
		return 0;
	}

	# getter for internal value settings
	if (/^\/r(ate)?l(imit)?$/) {
		$_ = '/print rate_limit_rate';
		# and fall through to ...
	}
	if (/^\/p(rint)? ?([^ ]*)/) {
		$key = $2;
		if (!length($key)) {
			foreach $key (sort keys %opts_can_set) {
				print $stdout "*** $key => $$key\n"
					if (!$opts_secret{$key});
			}
		} elsif ($valid{$key}) {
			print $stdout "*** ";
			print $stdout "(read-only value) "
				if (!$opts_can_set{$key});
			print $stdout "$key => $$key\n";
		} elsif ($key eq 'effpause' ||
				$key eq 'rate_limit_rate' ||
				$key eq 'rate_limit_left') {
			print $stdout "*** (requesting read-only value)\n";
			print C (substr("?$key                    ", 0, 19)
					. "\n");
			sleep 1;
		} elsif ($key eq 'tabcomp') {
			if ($termrl) {
				&generate_otabcomp;
			} else {
				print $stdout "*** readline isn't on\n";
			}
		} elsif ($key eq 'ntabcomp') { # sigh
			if ($termrl) {
				print $stdout "*** new TAB-comp entries: ";
				$did_print = 0;
				foreach(keys %readline_completion) {
					next if ($original_readline{$_});
					$did_print = 1;
					print $stdout "$_ ";
				}
				print $stdout "(none)" if (!$did_print);
				print $stdout "\n";
			} else {
				print $stdout "*** readline isn't on\n";
			}

		} else {
			print "*** not a valid option or setting: $key\n";
		}
		return 0;
	}
	if ($_ eq '/verbose' || $_ eq '/ve') {
		$verbose ^= 1;
		$_ = "/set verbose $verbose";
		print $stdout "-- verbosity.\n" if ($verbose);
		# and fall through to set
	}

	# search api integration (originally based on @kellyterryjones',
	# @vielmetti's and @br3nda's patches)
	if (/^\/se(arch)? (.+)\s*$/) {
		my $kw = $2;
		$kw =~ s/([^ a-z0-9A-Z_])/&uhex($1)/eg;
		$kw =~ s/\s+/+/g;
		$kw = "q=$kw" if ($kw !~ /^q=/);
		$kw .= "&rpp=20";

		my $r = &grabjson("$queryurl?$kw", 0, 1);
		if (defined($r) && ref($r) eq 'ARRAY' && scalar(@{ $r })) {
			my ($crap, $art) = &tdisplay($r, 'search');
			unless ($timestamp) {
				my ($time, $ts1) = &wraptime(
		$r->[(&min($print_max,scalar(@{ $r }))-1)]->{'created_at'});
				my ($time, $ts2) =
					&wraptime($art->{'created_at'});
			print $stdout "-- results cover $ts1 thru $ts2\n";
			}
		} else {
			print $stdout "-- sorry, no results were found.\n";
		}
		return 0;
	}
	if ($_ eq '/notrack') { # special case
		print $stdout "*** all tracking keywords cancelled\n";
		$track = '';
		&tracktags_makearray;
		&synckey('track', '');
		return 0;
	}
	if (s/^\/troff\s+// && s/\s*// && length) {
	# remove it from array, regenerate $track, call compile_tracktags
	# (don't need to do &tracktags_makearray) and then sync
		my $k;
		my $l = '';
		my $q = 0;
		my %w;
		my (@ptags) = split(/\s+/, $_);

		# filter duplicates and merge quoted strings (again)
		# but this time we're building up a hash for fast searches
		foreach $k (@ptags) {
			if ($q && $k =~ /"$/) { # this has to be first
				$l .= " $k";
				$q = 0;
			} elsif ($k =~ /^"/ || $q) {
				$l .= (length($l)) ? " $k" : $k;
				$q = 1;
				next;
			} else {
				$l = $k;
			}
			next if ($w{$l}); # ignore silently here
			$w{$l} = 1;
			$l = '';
		}
		print $stdout "-- warning: syntax error, missing quote?\n"
			if ($q);

		# now filter out of @tracktags
		@ptags = ();
		foreach $k (@tracktags) {
			push (@ptags, $k) unless ($w{$k});
		}
		unless (scalar(@ptags) < scalar(@tracktags)) {
			print $stdout "-- sorry, no track terms matched.\n";
			print $stdout (length($track) ?
				"-- you are tracking: $track\n" :
			"-- (maybe because you're not tracking anything?)\n");
			return 0;
		}
		print $stdout "*** ok, filtered @{[ keys(%w) ]}\n";
		@tracktags = @ptags;
		$track = join(' ', @tracktags);
		&compile_tracktags;
		&synckey('track', $track);
		return 0;
	}
	if ($_ eq '/tre' || $_ eq '/trends') {
		my $t;
		my $r = &grabjson("$trendurl", 0, 1);

#{"as_of":1237580149,"trends":{"2009-03-20 20:15:49":[{"query":"#sxsw OR SXSW",
		if (defined($r) && ref($r) eq 'HASH' && ($t = $r->{'trends'})){
			my $i;
			my $j;

			print $stdout "${EM}<<< TRENDING TOPICS >>>${OFF}\n";
			# this is moderate paranoia
			foreach $i (keys %{ $t }) {
				foreach $j (@{ $t->{$i} }) {		
					my $k = &descape($j->{'query'});
					print $stdout "/search $k\n";
					$k =~ s/\sOR\s/ /g;
					print $stdout "/tron $k\n";
				}
			}
			print $stdout "${EM}<<< TRENDING TOPICS >>>${OFF}\n";
		} else {
			print $stdout "-- sorry, trends not available.\n";
		}
		return 0;
	}
		
	1 if (s/^\/#([^\s]+)/\/tron #\1/);
	# /# command falls through to tron
	if (s/^\/tron\s+// && s/\s*$// && length) {
		$track .= " " if (length($track));
		$_ = "/set track ${track}$_";
		# fall through to set
	}
	if (/^\/track ([^ ]+)/) {
		s#^/#/set #;
		# and fall through to set
	}

	# setter for internal value settings
	if (/^\/s(et)? ([^ ]+) (.+)\s*$/) {
		$key = $2;
		$value = $3;
		if ($key eq 'tquery' && $value eq '0') { # undo tqueries
			$key = 'track';
			$value = join(' ', @tracktags);
		}
		if ($opts_can_set{$key}) {
			if (length($value) > 1023) {
				# can't transmit this in a packet
				print $stdout "*** value too long\n";
			} elsif ($opts_boolean{$key} && $value ne '0' &&
					$value ne '1') {
				print $stdout "*** 0|1 only (boolean): $key\n";
			} elsif ($opts_urls{$key} &&
		$value !~ m#^(http|https|gopher)://#) {
				print $stdout "*** must be valid URL: $key\n";
			} else {
				KEYAGAIN: $$key = $value;
				print $stdout "*** changed: $key => $$key\n";

				# handle special values
				&generate_ansi if ($key eq 'ansi' ||
					$key =~ /^colour/);
				&generate_shortdomain if ($key eq 'shorturl');
				&tracktags_makearray if ($key eq 'track');

				# transmit to background process sync-ed values
				if ($opts_sync{$key}) {
					&synckey($key, $value);
				}
				if ($key eq 'superverbose') {
					if ($value eq '0') {
						$key = 'verbose';
						$value = $supreturnto;
						goto KEYAGAIN;
					}
					$supreturnto = $verbose;
				}
			}
		# virtual keys
		} elsif ($key eq 'tquery') {
			$value =~ s/([^ a-z0-9A-Z_])/"%".unpack("H2",$1)/eg;
			$value =~ s/\s/+/g;
			$value = "q=$value" if ($value !~ /^q=/);
			if (length($value) > 139) {
				print $stdout
			"*** custom query is too long (encoded: $value)\n";
			} else {
				&synckey($key, $value);
			}
		} elsif ($valid{$key}) {
			print $stdout
			"*** read-only, must change on command line: $key\n";
		} else {
			print $stdout
			"*** not a valid option or setting: $key\n";
		}
		return 0;
	}

	# shell escape
	if (s/^\/\!// && s/\s*$// && length) {
		system("$_");
		$x = $? >> 8;
		print $stdout "*** exited with $x\n" if ($x);
		return 0;
	}

	if ($_ eq '/help' || $_ eq '/?') {
		print <<'EOF';

      *** BASIC COMMANDS:  :a$AAOOOOOOOOOOOOOOOOOAA$a,     ==================
                         +@A:.                     .:B@+    ANYTHING WITHOUT
   /refresh              =@B     HELP!!!  HELP!!!    B@=     A LEADING / IS
     grabs the newest    :a$Ao                     oA$a,    SENT AS A TWEET!
     tweets right            ;AAA$a; :a$AAAAAAAAAAA;       ==================
     away (or tells  :AOaaao:,   .:oA*:.                   JUST TYPE TO TALK!
     you if there    .;=$$$OBO***+        .+aaaa$:
     is nothing new)             :*; :***O@Aaaa*o,            ============
     by thumping     .+++++:       o#o                         REMEMBER!!
     the background  :OOOOOOA*:::, =@o       ,:::::.          ============
     process.          .+++++++++: =@*.....=a$OOOB#;       MANY COMMANDS, AND
                                   =@OoO@BAAA#@$o,           ALL TWEETS ARE
   /again                          =@o  .+aaaaa:            --ASYNCHRONOUS--
      displays most recent         =@Aaaaaaaaaa*o*a;,     and might not always
      tweets, both old and         =@$++=++++++:,;+aA:          respond
      new.                       ,+$@*.=O+  ...oO; oAo+.      immediately!
                               ,+o$OO=.+aA#####Oa;.*OO$o+.
   /dm and /dmagain for DMs.   +Ba::;oaa*$Aa=aA$*aa=;::$B:
                                 ,===O@BOOOOOOOOO#@$===,
   /replies                          o@BOOOOOOOOO#@+
      shows replies and mentions.    o@BOB@B$B@BO#@+    
                                     o@*.a@o a@o.$@+     
   /quit resumes your boring life.   o@B$B@o a@A$#@+  
EOF
		if ($termrl) {
			$termrl->readline("PRESS RETURN/ENTER> ");
		} else {
			print "PRESS RETURN/ENTER> ";
			$j = <$stdin>;
		}
		print <<"EOF";

+- MORE COMMANDS -+  -=-=- USER STUFF -=-=-
|                 |  /whois username            displays info about username
| See the TTYtter |  /again username            views their most recent tweets
|  home page for  |  /wagain username           combines them all
|  complete list  |  
|                 |  you can also FOLLOW or LEAVE a username (no slash) 
+-----------------+  or send them a DM via D username message (no slash)

+--- TWEET SELECTION --------------------------------------------------------+
| all tweets have a menu code (letter + number). example:                    |
|      a5> <ttytter> Send me Dr Pepper http://www.floodgap.com/TTYtter       |
|                                                                            |
| /reply a5 message                 replies to tweet a5                      |
|      example: /reply a5 I also like Dr Pepper                              |
|      becomes  \@ttytter I also like Dr Pepper     (and is threaded)         |
| /thread a5                        if a5 is part of a thread (the username  |
|                                    has a \@) then show all posts up to that |
| /url a5                           opens all URLs in tweet a5               |
|      Mac OS X users, do first: /set urlopen open %U                        |
|      Dummy terminal users, try /set urlopen lynx -dump %U | more           |
| /delete a5                        deletes tweet a5, if it's your tweet     |
+-- Abbreviations: /re, /th, /url, /del --- menu codes wrap around at end ---+

EOF
		if ($termrl) {
			$termrl->readline("PRESS RETURN/ENTER> ");
		} else {
			print "PRESS RETURN/ENTER> ";
			$j = <$stdin>;
		}

		print <<"EOF";




Use /set to turn on options or set them at runtime. There is a BIG LIST!

>> EXAMPLE: WANT ANSI? /set ansi 1
                       or use the -ansi command line option.
For readline support, UTF-8, SSL, proxies, etc., see the documentation.

** READ THE COMPLETE DOCUMENTATION: http://www.floodgap.com/software/ttytter/

 TTYtter $TTYtter_VERSION is (c)2009 cameron kaiser + contributors.
 all rights reserved. this software is offered AS IS, with no guarantees. it
 is not endorsed by Obvious or the executives and developers of Twitter.

           *** subscribe to updates at http://twitter.com/ttytter
                                    or http://twitter.com/floodgap
               send your suggestions to me at ckaiser\@floodgap.com
                                           or http://twitter.com/doctorlinguist




EOF
		return 0;
	}
	if ($_ eq '/ruler' || $_ eq '/ru') {
		my ($prompt, $prolen) = &$prompt(1);
		$prolen = $prolen x " ";
		print $stdout <<"EOF";
${prolen}         1         2         3         4         5         6         7         8         9         0         1         2         3        XX
${prompt}1...5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5...XX
EOF
		return 0;
	}
	if ($_ eq '/refresh' || $_ eq '/thump' || $_ eq '/r') {
		&thump;
		return 0;
	}
	if ($_ =~ m#^/(w)?a(gain)?\s+([^\s]+)#) { # the synchronous form
		my $mode = $1;
		my $uname = $3;
		
		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout "-- synchronous /again command for $uname\n"
			if ($verbose);
		my $my_json_ref = &grabjson("$uurl/${uname}.json", 0);

		if (defined($my_json_ref)
				&& ref($my_json_ref) eq 'ARRAY'
				&& scalar(@{ $my_json_ref })) {
			my ($crap, $art) =
				&tdisplay($my_json_ref, "again");
			unless ($timestamp) {
				my ($time, $ts1) = &wraptime(
$my_json_ref->[(&min($print_max,scalar(@{ $my_json_ref }))-1)]->{'created_at'});
				my ($time, $ts2) =
					&wraptime($art->{'created_at'});
			print $stdout "-- update covers $ts1 thru $ts2\n";
			}
		}
		&$conclude;
		unless ($mode eq 'w' || $mode eq 'wf') {
			return 0;
		} # else fallthrough
	}
	if ($_ =~ m#^/w(hois|a|again)?\s+([^\s]+)#) {
		my $uname = $2;

		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout "-- synchronous /whois command for $uname\n"
			if ($verbose);
		my $my_json_ref = &grabjson("$wurl/${uname}.json", 0);

		if (defined($my_json_ref) && ref($my_json_ref) eq 'HASH' &&
				length($my_json_ref->{'screen_name'})) {
			my $purl =
				&descape($my_json_ref->{'profile_image_url'});
			if ($avatar && length($purl) && $purl ne
"http://static.twitter.com/images/default_profile_normal.png") {
				my $exec = $avatar;
				my $fext;
				($purl =~ /\.([a-z0-9A-Z]+)$/) &&
					($fext = $1);
				$exec =~ s/\%U/'$purl'/g;
				$exec =~ s/\%N/$uname/g;
				$exec =~ s/\%E/$fext/g;
				print $stdout "\n($exec)\n";
				system($exec);
			}
			print $stdout <<"EOF"; 

${CCprompt}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} ($uname) (f:$my_json_ref->{'friends_count'}/$my_json_ref->{'followers_count'}) (u:$my_json_ref->{'statuses_count'})
EOF
			print $stdout
"\"@{[ &descape($my_json_ref->{'description'}) ]}\"\n"
				if (length($my_json_ref->{'description'}));
			print $stdout
"${EM}Location:${OFF}\t@{[ &descape($my_json_ref->{'location'}) ]}\n"
				if (length($my_json_ref->{'location'}));
			print $stdout
"${EM}URL:${OFF}\t\t@{[ &descape($my_json_ref->{'url'}) ]}\n"
				if (length($my_json_ref->{'url'}));
			print $stdout <<"EOF";
${EM}Picture:${OFF}\t@{[ &descape($my_json_ref->{'profile_image_url'}) ]}

EOF
			unless ($anonymous || $whoami eq $uname) {
				my $g =
		&grabjson("$frurl?user_a=$whoami&user_b=$uname", 0);
				print $stdout 
	"${EM}Do you follow${OFF} this user? ... ${EM}$g->{'literal'}${OFF}\n"
					if (ref($g) eq 'HASH');
				my $g =
		&grabjson("$frurl?user_a=$uname&user_b=$whoami", 0);
				print $stdout
"${EM}Does this user follow${OFF} you? ... ${EM}$g->{'literal'}${OFF}\n"
					if (ref($g) eq 'HASH');
				print $stdout "\n";
			}
		}
		return 0;
	}
		
	if ($_ eq '/again' || $_ eq '/a') { # the asynchronous form
		print C "reset--------------\n";
		return 0;
	}

	if (m#^/th(read)? ([a-zA-Z][0-9])$#) {
		my $code = lc($2);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $limit = 9;
		my $id = $tweet->{'in_reply_to_status_id'};
		my $thread_ref = [ $tweet ];
		while ($id && $limit) {
			print $stdout "-- thread: fetching $id\n"
				if ($verbose);
			my $next = &grabjson("${idurl}/${id}.json", 0);
			$id = 0;
			$limit--;
			if (defined($next) && ref($next) eq 'HASH') {
				push(@{ $thread_ref }, $next);
				$id = $next->{'in_reply_to_status_id'} || 0;
			}
		}
		&tdisplay($thread_ref, "", 0, 1); # use the mini-menu
		return 0;
	}

	if (m#^/url ([a-zA-Z][0-9])$#) {
		my $code = lc($1);
		my $tweet = &get_tweet($code);
		$urlshort = undef;
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $text = &descape($tweet->{'text'});
		# findallurls
		while ($text
	=~ s#(http|https|ftp|gopher)://([a-zA-Z0-9_~/:%\-\+\.\=\&\?\#]+)##) {
			my $url = $1 . "://$2";
			$url =~ s/[\.\?]$//;
			my $comm = $urlopen;
			$urlshort = $url;
			$comm =~ s/\%U/'$url'/g;
			print $stdout "($comm)\n";
			system("$comm");
		}
		print $stdout "-- sorry, couldn't find any URL.\n"
			if (!defined($urlshort));
		return 0;
	}
	if (s#^/(e?)r(etweet|t) ([a-zA-Z][0-9])\s*##) {
		my $mode = $1;
		my $code = lc($3);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		$retweet = "RT @" .
			&descape($tweet->{'user'}->{'screen_name'}) .
			": " . &descape($tweet->{'text'});
		if ($mode eq 'e') {
			print $stdout &wwrap(
				"-- ok, %RT% is now \"$retweet\"\n");
			return 0;
		}
		$_ = (length) ? "$retweet $_" : $retweet;
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
	}

	if (m#^/del(ete)? ([a-zA-Z][0-9])$#) {
		my $code = lc($2);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		if (lc(&descape($tweet->{'user'}->{'screen_name'}))
				ne lc($whoami)) {
			print $stdout
			"-- not allowed to delete somebody's else's tweets\n";
			return 0;
		}
		print $stdout &wwrap(
"-- verify you want to delete: \"@{[ &descape($tweet->{'text'}) ]}\"");
		print $stdout
"\n-- sure you want to delete? (only y or Y is affirmative): ";
		chomp($answer = lc(<$stdin>));
		if ($answer ne 'y') {
			warn "-- ok, tweet is NOT deleted.\n";
			return 0;
		}
		&deletest($tweet->{'id'}, 1);
		return 0;
	}

	if (s#^/re(ply)? ([a-zA-Z][0-9]) ## && length) {
		my $code = lc($2);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		$in_reply_to = $tweet->{'id'};
		$expected_tweet_ref = $tweet;
		$_ = '@' . &descape($tweet->{'user'}->{'screen_name'}) . " $_";
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
	}

	if ($_ eq '/replies' || $_ eq '/re') {
		if ($anonymous) {
			print $stdout
		"-- sorry, how can anyone reply to you if you're anonymous?\n";
		} else {
			# we are intentionally not keeping track of "last_re"
			# in this version because it is not automatically
			# updated and may not act as we expect.
			print $stdout "-- synchronous /replies command\n"
				if ($verbose);
			my $my_json_ref = &grabjson($rurl, 0);
			if (defined($my_json_ref)
				&& ref($my_json_ref) eq 'ARRAY'
					&& scalar(@{ $my_json_ref })) {
				&tdisplay($my_json_ref, "replies");
			}
			&$conclude;
		}
		return 0;
	}

	if ($_ eq '/dm' || $_ eq '/dmrefresh' || $_ eq '/dmr') {
		print C "dmthump------------\n";
		return 0;
	}

	if ($_ eq '/dmagain' || $_ eq '/dma') {
		print C "dmreset------------\n";
		return 0;
	}

	if ($_ eq '/end' || $_ eq '/e') {
		if ($child) {
			print "waiting for child ...\n";
			print C "sync---------------\n";
			waitpid $child, 0;
			$child = 0;
			print "exiting.\n";
			exit ($? >> 8);
		}
		exit;
	}

	if (m#^/me\s#) {
		$slash_first = 0; # kludge!
	}

	if ($slash_first) {
		if (!m#^//#) {
			print $stdout "*** command not recognized\n";
			print $stdout "*** to pass as a tweet, type /%%\n";
			return 0;
		}
		s#^/##; # leave the second slash on
	}

TWEETPRINT: # fugly! FUGLY!

	(@tweetstack) = &usplit($_, ($autosplit eq 'char' ||
		$autosplit eq 'cut') ? 1 : 0);
	$_ = shift(@tweetstack);
	if (scalar(@tweetstack)) {
		$history[0] = $_;
		if (!$autosplit) {
			print $stdout &wwrap(
"*** sorry, tweet too long; ".
"truncated to \"$_\" (@{[ &ulength($_) ]} bytes)\n");
	print $stdout "*** use %% for truncated version, or append to %%.\n";
			return 0;
		}
		print $stdout &wwrap(
			"*** overlong tweet; autosplitting to \"$_\"\n");
	}
	&updatest($_, 1, $in_reply_to);
	if (scalar(@tweetstack)) {
		$_ = shift(@tweetstack);
		@history = (($_, @history)[0..&min(scalar(@history),
			$maxhist)]);
		$termrl->addhistory($_) if ($termrl);
		print $stdout &wwrap("*** next tweet part is ready: \"$_\"\n");
		print $stdout "*** (this will also be automatically split)\n"
			if (&ulength($_) > 140);
		print $stdout
		"*** to send this next portion of your tweet, use %%.\n";
	}
	return 0;
}

sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $in_reply_to = shift;
	my $urle = '';
	my $i;
	my $subpid;
	my $istring;

	$in_reply_to = ($in_reply_to > 0) ?
		"&in_reply_to_status_id=$in_reply_to" : '';

	if ($anonymous) {
		print $stdout "-- sorry, you can't tweet if you're anonymous.\n"
			if ($interactive);
		return 99;
	}
	$string = &$prepost($string);

	if ($verify) {
		my $answer;

		warn &wwrap("-- verify you want to post: \"$string\"\n");
		print $stdout
"-- do you want to post this tweet? (only y or Y is affirmative): ";
		chomp($answer = lc(<$stdin>));
		if ($answer ne 'y') {
			warn "-- ok, tweet is NOT posted.\n";
			return 0;
		}
	}

	# to avoid unpleasantness with UTF-8 interactions, this will simply
	# turn the whole thing into a hex string and insert %, thus URL
	# escaping the whole thing whether it needs it or not. ugly? well ...
	$istring = $string;
	eval 'utf8::encode($istring)' unless ($seven);
	$istring = unpack("H280", $istring);
	for($i = 0; $i < length($istring); $i+=2) {
		$urle .= '%' . substr($istring, $i, 2);
	}
	my $credirect = ($superverbose) ? "" : " 2>/dev/null >/dev/null";
	#&update_authenticationheaders;
	my $cline = "$wend ${update}${credirect}";
	print $stdout "$cline\n" if ($superverbose);
	my $subpid = open(N,
		# I know the below is redundant. this is to remind me to see
		# if there is something cleverer to do with it later.
"|$cline") || do{
		print $stdout "post failure: $!\n" if ($interactive);
		return 99;
	};
	
	my $i = "source=TTYtter&status=${urle}${in_reply_to}\n";
	print $stdout $i if ($superverbose);
	print N $i;
	close(N);
	if ($? > 0) {
		$x = $? >> 8;
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: connect timeout or no confirmation received ($x)
*** to attempt a resend, type %%${OFF}
EOF
		return $?;
	}
	$lasttwit = $string;
	&$postpost($string);

	return 0;
}

# this is a modified, abridged version of &updatest.
sub deletest {
	my $id = shift;
	my $interactive = shift;

	my $update = "${delurl}/${id}.json";
	my $credirect = ($superverbose) ? "" : " 2>/dev/null >/dev/null";
	#&update_authenticationheaders;
	my $cline = "$wend ${update}${credirect}";
	print $stdout "$cline\n" if ($superverbose);

	my $subpid = open(N,
		# I know the below is redundant. this is to remind me to see
		# if there is something cleverer to do with it later.
"|$cline") || do{
		print $stdout "delete failure: $!\n" if ($interactive);
		return 99;
	};
	close(N);
	if ($? > 0) {
		$x = $? >> 8;
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: connect timeout or no confirmation received ($x)
*** to attempt again, type %%${OFF}
EOF
		return $?;
	}
	print $stdout "-- tweet id #${id} has been removed\n"
		if ($interactive);
	return 0;
}

# this is the central routine that takes a rolling tweet code, figures
# out where that tweet is, and returns something approximating a tweet
# structure (or the actual tweet structure itself if it can).
sub get_tweet {
	my $code = lc(shift);
	return undef if (length($code) != 2);
	my $source = ($code =~ /^[u-z]/) ? 1 : 0;
	my $k = '';
	my $l = '';
	my $w = {'user' => {}};

	if ($is_background) {
		if ($source == 1) { # foreground only
			return undef;
		}
		return $store_hash{$code};
	}
	return $store_hash{$code} if ($source); # foreground, foreground twt

	print C "pipet $code ----------\n";
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	return undef if ($k !~ /[^\s]/);
	$k =~ s/\s+$//; # remove trailing spaces
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	($w->{'menu_select'}, $w->{'id'}, $w->{'in_reply_to_status_id'},
		$w->{'user'}->{'screen_name'}, $w->{'created_at'},
			$w->{'text'}) = split(/\s/, $k, 6);
	$w->{'created_at'} =~ s/_/ /g;
	return $w;
}
		

sub thump { print C "update-------------\n"; }

sub synckey {
	my $key = shift;
	my $value = shift;
	print $stdout "*** (transmitting to background)\n";
	print C (substr("=$key                           ", 0, 19) . "\n");
#TODO
# got a WIDE CHARACTER IN PRINT error here
	print C (substr(($value . $space_pad), 0, 1024));
	sleep 1;
}

sub urlshorten {
	my $url = shift;
	my $rc;

	return $url if ($url =~ /^$shorturldomain/i); # stop loops
	chomp($rc = `$weld "${shorturl}$url"`);
	return ($urlshort = (($rc =~ m#^http://#) ? $rc : undef));
}

sub update_effpause {
	if ($pause ne 'auto' && $noratelimit) {
		$effpause = 0+$pause;
		return;
	}
	$effpause = 0+$pause if ($anonymous || (!$pause && $pause ne 'auto'));
	if (!$rate_limit_next && !$anonymous && ($pause > 0 ||
		$pause eq 'auto')) {

# {'reset_time_in_seconds':1218948315,'remaining_hits':98,'reset_time':'Sun Aug 17 04:45:15 +0000 2008','hourly_limit':100}

		$rate_limit_next = 5;
		$rate_limit_ref = &grabjson($rlurl, 0);

		if (defined $rate_limit_ref &&
				ref($rate_limit_ref) eq 'HASH') {
			$rate_limit_left =
				$rate_limit_ref->{'remaining_hits'};
			$rate_limit_rate =
				$rate_limit_ref->{'hourly_limit'};
			if ($rate_limit_left < 10) {
				$estring = 
"*** warning: $rate_limit_left API requests remain";
				if ($pause eq 'auto') {
					$estring .=
				"; temporarily halting autofetch";
					$effpause = 0;
				}
				&$exception(5, "$estring\n");
			} else {
				if ($pause eq 'auto') {
					if ($rate_limit_rate > 3000) {
# whitelisted accounts: can't go lower than once a minnit
						$effpause = 60;
					} else {
# other accounts
# this is computed to give you approximately 40% over the limit for client
# requests
# first, how many requests do we want to make an hour? $dmpause in a sec
						$effpause =
				$rate_limit_rate - ($rate_limit_rate * 0.4);
# second, take requests away for $dmpause (e.g., 4:1 means reduce by 25%)
						$effpause -=
				((1/$dmpause) * $effpause) if ($dmpause);
# finally determine how many seconds should elapse
						print $stdout
		"-- that's funny: effpause is zero, using fallback 180sec\n"
						if (!$effpause && $verbose);
						$effpause =
				($effpause) ? int(3600/$effpause) : 180;
					}
				} else {
					$effpause = 0+$pause;
				}
			}
			print $stdout
"-- rate limit check: $rate_limit_left/$rate_limit_rate (rate is $effpause sec)\n"
				if ($verbose);
			$adverb = (!$last_rate_limit) ? ' currently' :
		($last_rate_limit < $rate_limit_rate) ? ' INCREASED to':
		($last_rate_limit > $rate_limit_rate) ? ' REDUCED to':
					'';
			$notify_rate = 
"-- notification: API rate limit is${adverb} ${rate_limit_rate} req/hr\n"
				if ($last_rate_limit != $rate_limit_rate);
			$last_rate_limit = $rate_limit_rate;
		} else {
			$rate_limit_next = 0;
			$effpause = ($pause eq 'auto') ? 120 : 0+$pause;
			print $stdout
"-- failed to fetch rate limit (rate is $effpause sec)\n"
				if ($verbose);
		}
	} else {
		$rate_limit_next-- unless ($anonymous);
	}
}

MONITOR:
# asynchronous monitoring process -- uses select() to receive from console

%store_hash = ();
$is_background = 1;
$rin = '';
vec($rin,fileno(STDIN),1) = 1;
# paranoia
binmode($stdout, ":crlf") if ($termrl);
unless ($seven) {
	binmode(STDIN, ":utf8");
	binmode($stdout, ":utf8");
}
$interactive = $timeleft = $previous_last_id = 0;
$dm_first_time = ($dmpause) ? 1 : 0;

for(;;) {
	&$heartbeat;
	&update_effpause;
	$wrapseq = 0; # remember, we don't know when commands are sent.
	&refresh($interactive, $previous_last_id) unless ($timeleft
		|| (!$effpause && !$interactive));
	$previous_last_id = $last_id;
	if ($dmpause && $effpause) {
		if ($dm_first_time) {
			&dmrefresh(0);
			$dmcount = $dmpause;
		} elsif (!$interactive) {
			if (!--$dmcount) {
				&dmrefresh($interactive); # using dm_first_time
				$dmcount = $dmpause;
			}
		}
	}
	$interactive = 0;
	print $stdout $notify_rate;
	$notify_rate = "";
	print $stdout $vs;
	$vs = "";
	$timeleft = ($effpause) ? $effpause : 60;
	if($timeleft=select($rout=$rin, undef, undef, ($timeleft||$effpause))) {
		sysread(STDIN, $rout, 20);
		next if (!length($rout));
		# background communications central command code
		if ($rout =~ /^pipet (..)/) {
			my $key = &get_tweet($1);
			my $ms = $key->{'menu_select'} || 'XX';
			my $ds = $key->{'created_at'} || 'argh, no created_at';
			$ds =~ s/\s/_/g;
			$key = substr(( "$ms ".(0+$key->{'id'})." ".
		(0+$key->{'in_reply_to_status_id'})." ".
		$key->{'user'}->{'screen_name'}." $ds ".$key->{'text'}.
			$space_pad), 0, 1024);
			print P $key;
		} elsif ($rout =~ /^sync/) {
			print $stdout "-- synced; exiting at ", scalar localtime
				if ($verbose);
			exit $laststatus;
		} elsif ($rout =~ /([\=\?])([^ ]+)/) {
			$comm = $1;
			$key =$2;
			if ($comm eq '?') {
				print $stdout "*** $key => $$key\n";
			} else {
				sysread(STDIN, $value, 1024);
				$value =~ s/\s+$//;
				if ($key eq 'tquery') {
					print $stdout
					"*** custom query installed\n";
					print $stdout
					"$value" if ($verbose);
					@trackstrings = ();
					# already URL encoded
					push(@trackstrings, $value);
				} else {
					$$key = $value;
					print $stdout
					"*** changed: $key => $$key\n";

					&generate_ansi if ($key eq 'ansi' ||
						$key =~ /^colour/);
					$rate_limit_next = 0
						if ($key eq 'pause' &&
							$value eq 'auto');
					&tracktags_makearray
						if ($key eq 'track');
				}
			}
		} else {
			$interactive = 1;
			$last_id = 0 if ($rout =~ /^reset/);
			$last_dm = 0 if ($rout =~ /^dmreset/);
			print $stdout "-- command received ", scalar
				localtime, " $rout" if ($verbose);
			if ($rout =~ /^dm/) {
				&dmrefresh($interactive);
				$dmcount = $dmpause;
			} else {
				$timeleft = 0;
			}
		}
	} else {
		print $stdout "-- routine refresh ($dmcount to next dm) ",
			scalar localtime, "\n" if ($verbose);
	}
}

# the refresh engine depends on later tweets having higher id numbers.
# Obvious, don't change this if you know what's good for you, ya twerps,
# or I will poison all of yer kitties. *pats my Burmese, who purrs*

sub grabjson {
	my $data;
	my $url = shift;
	my $last_id = shift;
	my $agent = (shift) ? $weld : $wand;
	my $count = shift;
	my $tdata;
	my $seed;
	my $xurl;
	my $my_json_ref = undef; # durrr hat go on foot
	my $kludge_search_api_adjust = 0;
	my $i;

	#undef $/; $data = <STDIN>;

	# count needs to be removed for the default case due to show, etc.
	$xurl = ($last_id) ? 
		((($url =~ /\?/) ? '&' : '?')."since_id=$last_id")
			: "";
	$xurl .= ((length($xurl)) ? "&count=$count" :
		((($url =~ /\?/) ? '&' : '?')."count=$count"))
			if ($count);

	#&update_authenticationheaders;
	print $stdout "$agent \"$url$xurl\"\n" if ($superverbose);
	chomp($data = `$agent "$url$xurl" 2>/dev/null`);

	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;
	#print unpack("H90", $data);

	if (!length($data)) {
		&$exception(1, "*** warning: timeout or no data\n");
		return undef;
	}

	# old non-JSON based error reporting code still supported
	if ($data =~ /^<!DOCTYPE\s+html/i || $data =~ /^(Status:\s*)?50[0-9]\s/ || $data =~ /^<html>/i) {
		print $stdout $data if ($superverbose);
		&$exception(2, "*** warning: Twitter error message received\n" .
			(($data =~ /<title>Twitter:\s*([^<]+)</) ?
				"*** \"$1\"\n" : ''));
		return undef;
	}
	if ($data =~ /^rate\s*limit/i) {
		print $stdout $data if ($superverbose);
		&$exception(3,
"*** warning: exceeded API rate limit for this interval.\n" .
"*** no updates available until interval ends.\n");
		return undef;
	}

	# handle things like 304, or other things that look like HTTP
	# error codes
	if ($data =~ m#^HTTP/\d\.\d\s+(\d+)\s+#) {
		$code = 0+$1;
		print $stdout $data if ($superverbose);

		# 304 is actually a cop-out code and is not usually
		# returned, so we should consider it a non-fatal error
		if ($code == 304 || $code == 200 || $code == 204) {
			&$exception(1, "*** warning: timeout or no data\n");
			return undef;
		}
		&$exception(4,
"*** warning: unexpected HTTP return code $code from Twitter server\n");
		return undef;
	}

# process the JSON data ... simplemindedly, because I just write utter crap,
# am not a professional programmer, and don't give a flying fig whether
# kludges suck or no.

	# test for error/warning conditions with trivial case
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1/s
		|| $data =~ /(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1\}/s) {
		print $stdout $data if ($superverbose);
		&$exception(2, "*** warning: Twitter $2 message received\n" .
			"*** \"$3\"\n");
		return undef;
	}

	# test for single logicals
	return {
		'ok' => 1,
		'result' => (($1 eq 'true') ? 1 : 0),
		'literal' => $1,
			} if ($data =~ /^['"]?(true|false)['"]?$/);

	# THIS IS A TEMPORARY KLUDGE for API issue #26
	# http://code.google.com/p/twitter-api/issues/detail?id=26
	if ($data =~ s/Couldn't find Status with ID=[0-9]+,//) {
		print $stdout ">>> cfswi sucky kludge tripped <<<\n"
			if ($superverbose);
	}

	# if wrapped in results object, unwrap it (@kellyterryjones)
	# (and tag it to do more later)
        if ($data =~ s/^\{['"]results['"]:(\[.*\]).*$/$1/isg) {
		$kludge_search_api_adjust = 1;
	}

	# first isolate escaped backslashes with a unique sequence.
	$bbqqmask = "BBQQ";
	$seed = 0;
	$seed++ while ($data =~ /$bbqqmask$seed/);
	$bbqqmask .= $seed;
	$data =~ s/\\\\/$bbqqmask/g;

	# next isolate escaped quotes with another unique sequence.
	$ddqqmask = "DDQQ";
	$seed = 0;
	$seed++ while ($data =~ /$ddqqmask$seed/);
	$ddqqmask .= $seed;
	$data =~ s/\\\"/$ddqqmask/g;

	# then turn literal ' into another unique sequence. you'll see
	# why momentarily.
	$ssqqmask = "SSQQ";
	$seed = 0;
	$seed++ while ($data =~ /$ssqqmask$seed/);
	$ssqqmask .= $seed;
	$data =~ s/\'/$ssqqmask/g;

	# here's why: we're going to turn doublequoted strings into single
	# quoted strings to avoid nastiness like variable interpolation.
	$data =~ s/\"/\'/g;

	# and then we're going to turn the inline ones all back except
	# ssqq, which we'll do last so that our syntax checker still works.
	$data =~ s/$bbqqmask/\\\\/g;
	$data =~ s/$ddqqmask/"/g;

	print $stdout "$data\n" if ($superverbose);

	# trust, but verify. I'm sure twitter wouldn't send us malicious
	# or bogus JSON, but one day this might talk to something that would.
	# in particular, need to make sure nothing in this will eval badly or
	# run arbitrary code. that would really suck!
	$tdata = $data;
	1 while $tdata =~ s/'[^']+'//;
	$tdata =~ s/-?[0-9]+//g;
	$tdata =~ s/(true|false|null)//g;
	$tdata =~ s/\s//g;

	print $stdout "$tdata\n" if ($superverbose);

	# verify the syntax tree.
	# the remaining stuff should just be enclosed in [ ], and only {}:,
	# for example, imagine if a bare semicolon were in this ...
	if ($tdata !~ s/^\[// || $tdata !~ s/\]$// || $tdata =~ /[^{}:,]/) {
		$tdata =~ s/'[^']*$//; # cut trailing strings
		if (($tdata =~ /^\[/ && $tdata !~ /\]$/)
				|| ($tdata =~ /^\{/ && $tdata !~ /\}$/)) {
			# incomplete transmission
			&$exception(10, "*** JSON warning: connection cut\n");
			return undef;
		}
		if ($tdata =~ /\[\]/) { # oddity
			&$exception(11, "*** JSON warning: null list\n");
			return undef;
		}
		# total failure should fail hard, because this indicates an
		# absolutely serious error at this stage (all traps failed)
		&screech
		("$data\n$tdata\nJSON IS UNSAFE TO EXECUTE! BAILING OUT!\n")
			if ($tdata =~ /[^\[\]\{\}:,]/);
	}

	# syntax tree passed, so let's turn it into a Perl reference.
	# have to turn colons into ,s or Perl will gripe. but INTELLIGENTLY!
	1 while
	($data =~ s/([^'])':(true|false|null|\'|\{|\[|-?[0-9])/\1\',\2/);

	# finally, single quotes, just before interpretation.
	$data =~ s/$ssqqmask/\\'/g;

	# now somewhat validated, so safe (?) to eval() into a Perl struct
	eval "\$my_json_ref = $data;";
	print $stdout "$data => $my_json_ref $@\n"  if ($superverbose);

	# do a sanity check
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!defined($my_json_ref));

	if ($kludge_search_api_adjust && defined($my_json_ref) &&
			ref($my_json_ref) eq 'ARRAY') {
		# this translates search API fields into standard ones,
		# and marks them.
		foreach $i (@{ $my_json_ref }) {
			$i->{'class'} = "search";

			# hopefully this hack can die with API v2.
			$i->{'user'}->{'screen_name'} = $i->{'from_user'};
			# translate time stamps
			# Fri Mar 20 13:18:18 +0000 2009 (twitter) vs
			# Fri, 20 Mar 2009 16:35:56 +0000 (search)
			$i->{'created_at'} =~
	s/(...), (..) (...) (....) (..:..:..) (.....)/\1 \3 \2 \5 \6 \4/;
		}
	}

	$laststatus = 0;
	return $my_json_ref;
}

sub refresh {
	my $interactive = shift;
	my $relative_last_id = shift;
	my $k;
	my $my_json_ref = undef;
	my $i;
	my @streams = ();

	# this mixes all the tweet streams (timeline, hashtags, replies
	# [someday]) into a single unified data river.

	# first, get my own timeline
	unless ($notimeline) {
		$my_json_ref = &grabjson($url, $last_id, 0, 30);
		# if I can't get my own timeline, ABORT! highest priority!
		return if (!defined($my_json_ref) ||
			ref($my_json_ref) ne 'ARRAY');
	}

	# next handle hashtags and tracktags
	# failure here does not abort, because search may be down independently
	# of the main timeline.
	if (!$notrack && scalar(@trackstrings)) {
		foreach $k (@trackstrings) {
			my $r = &grabjson("$queryurl?${k}&rpp=20",
				$last_id, 1);
			push(@streams, $r)
				if (defined($r) &&
					ref($r) eq 'ARRAY' &&
					scalar(@{ $r }));
		}
	}

	# replies ... maybe later

	# now, streamix all the streams into my_json_ref, discarding duplicates
	# a simple hash lookup is no good; it has to be iterative. because of
	# that, we might as well just splice it in here and save a sort later.
	# remember, the most recent tweets are FIRST.
	if (scalar(@streams)) {
		my $j;
		my $k;
		my $l = scalar(@{ $my_json_ref });
		my $m;

		foreach $i (@streams) {
			SMIX0: foreach $j (@{ $i }) {
				if (!$l) { # degenerate case
					push (@{ $my_json_ref }, $j);
					$l++;
					next SMIX0;
				}
				my $id = $j->{'id'}; # anticipating many comps

				# find the same ID, or one just before,
				# and splice in
				$m = -1;
				SMIX1: for($i=0; $i<$l; $i++) {
					next SMIX0 # it's a duplicate
					if($my_json_ref->[$i]->{'id'} == $id);
					if($my_json_ref->[$i]->{'id'} < $id) {
						$m = $i;
						last SMIX1; # got it
					}
				}
				if ($m == -1) { # didn't find
					push (@{ $my_json_ref }, $j);
				} elsif ($m == 0) { # degenerate case
					unshift (@{ $my_json_ref }, $j);
				} else { # did find, so splice
					splice(@{ $my_json_ref }, $m, 0,
						$j);
				} 
				$l++;
			}
		}
	}

	($last_id, $crap) =
		&tdisplay($my_json_ref, undef, $relative_last_id);
	print
	$stdout "-- id bookmark is $last_id, rollback is $relative_last_id.\n"
		if ($verbose);
	&$conclude;
} 

sub tdisplay { # used by both synchronous /again and asynchronous refreshes
	my $my_json_ref = shift;
	my $class = shift;
	my $relative_last_id = shift;
	my $mini_id = shift;
	my $printed = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $j;

	if ($disp_max) { # null list may be valid if we get code 304
		unless ($is_background) { # reset store hash each console
			if ($mini_id) {
#TODO
# generalize this at some point instead of hardcoded menu codes
				$tweet_counter = $mini_split;
				for(0..9) {
					undef $store_hash{"z$_"};
				}
			} else {
				$tweet_counter = $back_split;
				%store_hash = ();
			}
		}
		for($i = $disp_max; $i > 0; $i--) {
			my $g = ($i-1);
			$j = $my_json_ref->[$g];
			my $id = $j->{'id'};

			next if ($id <= $last_id);
			next if (!length($j->{'user'}->{'screen_name'}));
			if ($filter && &$filter(&descape($j->{'text'}))) {
				$filtered++;
				next;
			}

			$wrapseq++;
			$key = substr($alphabet, $tweet_counter/10, 1) .
				$tweet_counter % 10;
			$tweet_counter = 
				($tweet_counter == 259) ? $mini_split :
				($tweet_counter == ($mini_split - 1))
					? $back_split :
				($tweet_counter == ($back_split - 1)) ? 0 :
				($tweet_counter+1);
			$j->{'menu_select'} = $key;
			$store_hash{lc($key)} = $j;
			$printed += &$handle($j,
			($class || (($id <= $relative_last_id) ? 'again' :
				undef)));
		}
	}
	print $stdout "-- sorry, nothing to display.\n"
		if (($interactive || $verbose) && !$printed);
	return (&max(0+$my_json_ref->[0]->{'id'}, $last_id), $j);
}

sub dmrefresh {
	my $interactive = shift;
	if ($anonymous) {
		print $stdout
			"-- sorry, you can't read DMs if you're anonymous.\n"
			if ($interactive);
		return;
	}

	# no point in doing this if we can't even get to our own timeline
	# (unless user specifically requested it, or our timeline is off)
	return if (!$interactive && !$last_id && !$notimeline); # NOT last_dm

	my $my_json_ref = &grabjson($dmurl, $last_dm);
	return if (!defined($my_json_ref)
		|| ref($my_json_ref) ne 'ARRAY');

	my $printed = 0;
	my $max = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $g;

	if ($disp_max) { # an empty list can be valid
		if ($dm_first_time) {
			print $stdout
			"-- checking for most recent direct messages:\n";
			$disp_max = 2;
			$interactive = 1;
		}
		for($i = $disp_max; $i > 0; $i--) {
			$g = ($i-1);
			next if ($my_json_ref->[$g]->{'id'} <= $last_dm);
			next if
		(!length($my_json_ref->[$g]->{'sender'}->{'screen_name'}));

			$wrapseq++;
			$printed += &$dmhandle($my_json_ref->[$g]);
		}
		$max = 0+$my_json_ref->[0]->{'id'};
	}
	print $stdout "-- sorry, no new direct messages.\n"
		if (($interactive || $verbose) && !$printed);
	$last_dm = &max($last_dm, $max);
	$dm_first_time = 0 if ($last_dm || !scalar(@{ $my_json_ref }));
	print $stdout "-- dm bookmark is $last_dm.\n" if ($verbose);
	&$dmconclude;
}	

sub wherecheck {
	my ($prompt, $filename, $fatal) = (@_);
	my (@paths) = split(/\:/, $ENV{'PATH'});
	my $setv = '';

	unshift(@paths, '/usr/bin'); # the usual place
	@paths = ('') if ($filename =~ m#^/#); # for absolute paths

	print $stdout "$prompt ... ";
	foreach(@paths) {
		if (-r "$_/$filename") {
			$setv = "$_/$filename";
			1 while $setv =~ s#//#/#;
			print "$setv\n";
			last;
		}
	}
	if (!length($setv)) {
		print "not found.\n";
		(print($fatal),exit) if ($fatal);
	}
	return $setv;
}

sub screech {
	print $stdout "\n\n${BEL}${BEL}@_";
	kill 9, $parent;
	kill 9, $$;
	die("death not achieved conventionally");
}

sub descape {
	my $x = shift;
	my $mode = shift;

	$x =~ s#\\/#/#g;

	# try to do something sensible with unicode
	if ($mode) { # this probably needs to be revised
		$x =~ s/\\u([0-9a-fA-F]{4})/"&#" . hex($1) . ";"/eg;
	} else {
		if ($seven) {
			$x =~ s/\\u([0-9a-fA-F]{4})/./g;
			$x =~ s/[\x80-\xff]/./g;
		} else {
			# try to promote to UTF-8
			eval 'utf8::decode($x)';
			$x =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/eg;
		}
		$x =~ s/\&quot;/"/g;
		$x =~ s/\&apos;/'/g;
		$x =~ s/\&lt;/\</g;
		$x =~ s/\&gt;/\>/g;
		$x =~ s/\&amp;/\&/g;
	}
	if ($newline) {
		$x =~ s/\\n/\n/sg;
		$x =~ s/\\r//sg;
	}
	return $x;
}

sub max { return ($_[0] > $_[1]) ? $_[0] : $_[1]; }
sub min { return ($_[0] < $_[1]) ? $_[0] : $_[1]; }
# this is mostly a utility function for /eval
sub a   { return (scalar(@_) ? ("('" . join("', '", @_) . "')") : "NULL"); }

sub wwrap {
	return shift if (!$wrap);

	my $k;
	my $klop = ($wrap > 1) ? $wrap : ($ENV{'COLUMNS'} || 79);
	$klop--; # don't ask me why
	my $lop;
	my $buf = '';
	my $string = shift;
	my $indent = shift; # for very first time with the prompt
	my $needspad = 0;
	my $stringpad = " " x 3;

	$indent += 4; # for the menu select string

	$lop = $klop - $indent;
	$lop -= $indent;
	W: while($k = length($string)) {
		$lop += $indent if ($lop < $klop);
		($buf .= $string, last W) if ($k <= $lop && $string !~ /\n/);
		($string =~ s/^\s*\n//) && ($buf .= "\n",
			$needspad = 1,
			next W);
		if ($needspad) {
			$string = "   $string";
			$needspad = 0;
		}
		# I don't know if people will want this, so it's commented out.
		#($string =~ s#^(http://[^\s]+)# #) && ($buf .= "$1\n",
		#	next W);
		($string =~ s/^(.{4,$lop})\s/   /) && ($buf .= "$1\n",
			next W); # i.e., at least one char, plus 3 space indent
		($string =~ s/^(.{$lop})/   /) && ($buf .= "$1\n",
			next W);
		warn
		"-- pathologic string somehow failed wordwrap! \"$string\"\n";
		return $buf;
	}               
	1 while ($buf =~ s/\n\n\n/\n\n/s); # mostly paranoia
	return $buf;
}

# these subs look weird, but they're encoding-independent and run anywhere
sub ulength { my @k; return (scalar(@k = unpack("C*", shift))); }
sub uhex {
	# URL-encode an arbitrary string, even UTF-8
	# more versatile than the miniature one in &updatest
	my $k = '';
	my $s = shift;
	eval 'utf8::encode($s)' unless ($seven);

	foreach(split(//, $s)) {
		my $j = unpack("H256", $_);
		while(length($j)) {
			$k .= '%' . substr($j, 0, 2);
			$j = substr($j, 2);
		}
	}
	return $k;
}
sub usplit {
	# take a string and return up to 140 bytes plus the rest.
	# this is tricky because we don't want to split up UTF-8 sequences, so
        # we let Perl do the work since it internally knows where they end.
	my $k = shift;
	my $z;
	my $mode = shift;
	my @m;
	my $q;
	my $r;

	$mode += 0;

	# optimize whitespace
	$k =~ s/^\s+//;
	$k =~ s/\s+$//;
	$k =~ s/\s+/ /g;
	$z = &ulength($k);
	return ($k) if ($z <= 140); # also handles the trivial case

	# this needs to be reply-aware, so we put @'s at the beginning of
	# the second half too (and also Ds for DMs)
	$r .= $1 if ($k =~ s/^(\@[^\s]+\s)\s*// ||
			$k =~ s/^(D\s+[^\s]+\s)\s*//);  # not while -- just one
	$k = "$r$k";

	my $i = 140;
	$i-- while(($z = &ulength($q = substr($k, 0, $i))) > 140);
	$m = substr($k, $i);

	# if we just wanted split-on-byte, return now (mode = 1)
	if ($mode) {
		# optimize again in case we split on whitespace
		$q =~ s/\s+$//;
		$m =~ s/^\s+//;
		return ($q, "$r$m");
	}

	# else try to do word boundary and cut even more
	if (!$autosplit) { # use old mechanism first: drop trailing non-alfanum
		($q =~ s/([^a-zA-Z0-9]+)$//) && ($m = "$1$m");
		# optimize again in case we split on whitespace
		$q =~ s/\s+$//;
		if (&ulength($q) < 140) {
			$m =~ s/^\s+//;
			return($q, "$r$m")
		}
	}
	($q =~ s/\s+([^\s]+)$//) && ($m = "$1$m");
	return ($q, "$r$m");
}

