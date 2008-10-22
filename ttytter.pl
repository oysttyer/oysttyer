#!/usr/bin/perl -s
#########################################################################
#
# TTYtter v0.9 (c)2007, 2008 cameron kaiser. all rights reserved.
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

#&grabjson;exit;

BEGIN {
	$TTYtter_VERSION = 0.9;
	$TTYtter_PATCH_VERSION = 1;

	(warn ("${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}\n"), exit)
		if ($version);

	$ENV{'PERL_SIGNALS'} = 'unsafe';

	%opts_boolean = map { $_ => 1 } qw(
		ansi noansi verbose superverbose ttytteristas noprompt
		seven silent hold daemon script anonymous readline ssl
		newline
	); %opts_sync = map { $_ => 1 } qw(
		ansi pause dmpause ttytteristas verbose superverbose
		url rlurl dmurl newline
	); %opts_urls = map {$_ => 1} qw(
		url dmurl uurl rurl wurl frurl rlurl update shorturl
	); %opts_secret = map { $_ => 1} qw(
		superverbose ttytteristas
	); %opts_can_set = map { $_ => 1 } qw(
		url pause dmurl dmpause superverbose ansi verbose
		update uurl rurl wurl avatar ttytteristas frurl
		rlurl noprompt shorturl newline
	); %opts_others = map { $_ => 1 } qw(
		lynx curl seven silent maxhist noansi lib hold status
		daemon timestamp twarg user anonymous script readline
		leader ssl
	); %valid = (%opts_can_set, %opts_others);
	if (open(W, ($n = "$ENV{'HOME'}/.ttytterrc"))) {
		while(<W>) {
			chomp;
			next if (/^\s*$/ || /^#/);
			s/^-//;
			($key, $value) = split(/\=/, $_, 2);
			if ($valid{$key} && !length($$key)) {
				$$key = $value;
			} elsif (!$valid{$key}) {
		warn "** setting $key not supported in this version\n";
			}
		}
		close(W);
	}
	$seven ||= 0;
	$lib ||= "";
	$parent = $$;

	# defaults that our lib can override
	$last_id = 0;
	$last_dm = 0;
	$print_max = 20;

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
# 0.8.5
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
	 		 '\xfc[\x80-\x83][\x80-\xbf]{4}';

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
}

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
		foreach(split(/\s+/, $readline)) {
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
		&generate_otabcomp;
		kill 9, $child;
	}
	#print $stdout "done.\n";
	exit;
}

# interpret script at this level
if ($script) { $silent = 1; $pause = 0; $noansi = 1; $noprompt = 1; }

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

# defaults
$anonymous ||= 0;
undef $user if ($anonymous);
if ($ssl) {
	print $stdout "-- using SSL for default URLs.\n";
}
$http_proto = ($ssl) ? 'https' : 'http';

$url ||= ($anonymous)
	? "${http_proto}://twitter.com/statuses/public_timeline.json"
	: "${http_proto}://twitter.com/statuses/friends_timeline.json";
$rurl ||= "${http_proto}://twitter.com/statuses/replies.json";
$uurl ||= "${http_proto}://twitter.com/statuses/user_timeline";
$wurl ||= "${http_proto}://twitter.com/users/show";
$update ||= "${http_proto}://twitter.com/statuses/update.json";
$dmurl ||= "${http_proto}://twitter.com/direct_messages.json";
$frurl ||= "${http_proto}://twitter.com/friendships/exists.json";
$rlurl ||= "${http_proto}://twitter.com/account/rate_limit_status.json";

#$shorturl ||= "http://bit.ly/api?url=";
$shorturl ||= "http://is.gd/api.php?longurl=";
# figure out the domain to stop shortener loops
sub generate_shortdomain {
	($shorturl =~ m#^(http://[^/]+/)#) && ($shorturldomain = $1);
	print $stdout "-- warning: couldn't parse shortener service\n"
		if (!length($shorturldomain));
}
&generate_shortdomain;

$pause = (($anonymous) ? 120 : "auto") if (!defined $pause);
	# NOT ||= ... zero is a VALID value!
$superverbose ||= 0;
$hold ||= 0;
$daemon ||= 0;
$maxhist ||= 19;
$timestamp ||= 0;
$noprompt ||= 0;
$twarg ||= undef;

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
	$BLUE = ($ansi) ? "${ESC}[34;1m" : '';
	$RED = ($ansi) ? "${ESC}[31;1m" : '';
	$GREEN = ($ansi) ? "${ESC}[32;1m" : '';
	$YELLOW = ($ansi) ? "${ESC}[33m" : '';
	$MAGENTA = ($ansi) ? "${ESC}[35m" : '';
	$CYAN = ($ansi) ? "${ESC}[36m" : '';
	$EM = ($ansi) ? "${ESC}[1;3m" : '';
	$UNDER = ($ansi) ? "${ESC}[4m" : '';
	$OFF = ($ansi) ? "${ESC}[0m" : '';
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
# [{"text":"\"quote test\" -- let's see what that does to the code.","id":56487562,"user":{"name":"Cameron Kaiser","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","screen_name":"doctorlinguist","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","url":"http:\/\/www.cameronkaiser.com","id":3841961,"protected":false},"created_at":"Wed May 09 03:28:38 +0000 2007"},
sub defaulthandle {
	my ($tweet_ref, $class) = (@_);
	$class = ($verbose) ? "{$class} " : "";
	if ($silent) {
		print DUPSTDOUT $class . &standardtweet($tweet_ref);
	} else {
		print $stdout $class . &standardtweet($tweet_ref);
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

	# br3nda's and smb's modified colour patch
	unless ($anonymous) {
		if ($sn eq $whoami) {
			#if it's me speaking, colour the line yellow
			$g = $colour = $YELLOW;
		} elsif ($tweet =~ /\@$whoami/i) {
			#if I'm in the tweet, colour red
			$g = $colour = $RED;
		}
	}
	$sn = "*$sn" if ($ref->{'source'} =~ /TTYtter/ && $ttytteristas);

	# br3nda's modified timestamp patch
	if ($timestamp) {
		my ($time, $ts) = &wraptime($ref->{'created_at'});
		$g .= "[$ts] ";
	}
	$colour = $OFF . $colour;
	# smb's underline/bold patch
	$tweet =~ s/(^|\s)\@(\w+)/\1\@${UNDER}\2${colour}/g;
	$g .= "<${EM}${sn}${colour}> ${tweet}${OFF}\n" ;

	return $g;
}
$handle ||= \&defaulthandle;

sub defaultconclude { ; }
$conclude ||= \&defaultconclude;

# {"recipient_id":3841961,"sender":{"url":"http:\/\/www.xanga.com\/the_shambleyqueen","name":"Staci Gainor","screen_name":"emo_mom","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/7460892\/normal\/Staci_070818__2_.jpg?1187488390","description":"mildly neurotic; slightly compulsive; keenly observant  Christian mom of four, including identical twins","location":"Pennsylvania","id":7460892,"protected":false},"created_at":"Fri Aug 24 04:03:14 +0000 2007","sender_screen_name":"emo_mom","recipient_screen_name":"doctorlinguist","recipient":{"url":"http:\/\/www.cameronkaiser.com","name":"Cameron Kaiser","screen_name":"doctorlinguist","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","id":3841961,"protected":false},"text":"that is so cool; does she have a bit of an accent? do you? :-) and do you like vegemite sandwiches?","sender_id":7460892,"id":8570802}
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
	$text =~ s/(^|\s)\@(\w+)/\1\@${UNDER}\2${OFF}${GREEN}/g;
	my $g = "${GREEN}[DM ${EM}".
		&descape($ref->{'sender'}->{'screen_name'}) .
		"${OFF}${GREEN}/$ts] $text $OFF\n";
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
		return grep(/^$text/, '/history',
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
	if (($line =~ m#^(D|/wa|/wagain|/a|/again) #) ||
		($start == 1 && substr($line, 0, 1) eq '@') ||
		# this code is needed to prevent inline @ from flipping out
		($start >= 1 && substr($line, ($start-2), 2) eq ' @')) {
		@proband = grep(/^\@$text/, @rlkeys);
		if (scalar(@proband)) {
			@proband = map { s/^\@//;$_ } @proband;
			return @proband;
		}
	}
	# definites that are left over, including @ if it were included
	if(scalar(@proband = grep(/^$text/, @rlkeys))) {
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

die("$0: specify -user=username:password\n")
	if (!$anonymous && 
		(!length($user) || $user !~ /:/ || $user =~ /[\s;><|]/));
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
		}
	}
}
if ($lynx) {
	$wend = "$wend -nostatus";
	$weld = "$wend -source";
	$wend = "$wend -auth=$user" unless ($anonymous);
	$wand = "$wend -source";
	$wind = "$wand";
	$wend = "$wend -post_data";
} else {
	$wend = "$wend -s --basic -m 13 -f";
	$weld = $wend;
	$wend = "$wend -u $user" unless ($anonymous);
	$wand = "$wend -f";
	$wind = "$wend";
	$wend = "$wend --data \@-";
}
$whoami = ($anonymous) ? undef : ((split(/\:/, $user, 2))[0]);

# initial login tests and command line controls

$phase = 0;
for(;;) {
	$rv = 0;
	die(
	"sorry, you can't tweet anonymously. use an authenticated username.\n")
		if ($anonymous && length($status));
	die(
"sorry, status too long: reduce by @{[ length($status)-140 ]} characters.\n")
		if (length($status) > 140);
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
		print "FAILED. ($x) bad login? bad url? resource down?\n";
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
	last;
}
print "SUCCEEDED!\n";
exit 0 if (length($status));

# daemon mode

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
		&dmrefresh(0) if ($dmpause > 1); # no point if it's 1:1
		for(;;) {
			&$heartbeat;
			&refresh(0);
			if ($dmpause) {
				if (!--$dmcount) {
					&dmrefresh(0);
					$dmcount = $dmpause;
				}
			}
			sleep $pause;
		 }
	}
	die("uncaught fork() exception\n");
}

# interactive mode

print <<"EOF";

######################################################        +oo=========oo+ 
         ${EM}TTYtter ${TTYtter_VERSION}.${TTYtter_PATCH_VERSION} (c)2008 cameron kaiser${OFF}                 @             @
EOF
$e = <<'EOF';
                 ${EM}all rights reserved.${OFF}                         +oo=   =====oo+
       ${EM}http://www.floodgap.com/software/ttytter/${OFF}            ${GREEN}a==:${OFF}  ooo
                                                            ${GREEN}.++o++.${OFF} ${GREEN}..o**O${OFF}
  freeware under the floodgap free software license.        ${GREEN}+++${OFF}   :O${GREEN}:::::${OFF}
        http://www.floodgap.com/software/ffsl/              ${GREEN}+**O++${OFF} #   ${GREEN}:ooa${OFF}
                                                                   #+$$AB=.
     ${EM}tweet me: http://twitter.com/doctorlinguist${OFF}                   #;;${YELLOW}ooo${OFF};;
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
sleep 2 unless ($silent);

if ($child = open(C, "|-")) { ; } else { goto MONITOR; }
$SIG{'BREAK'} = $SIG{'INT'} = \&end_me;
select(C); $|++; select($stdout);

sub defaultprompt {
	my $rv = ($noprompt) ? "" : "TTYtter> ";
	my $rvl = ($noprompt) ? 0 : 9;
	return ($rv, $rvl) if (shift);
	print $stdout "${CYAN}$rv${OFF}" unless ($termrl);
}
$prompt ||= \&defaultprompt;

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
&$console;
exit;

sub prinput {
	my $i;
	local($_) = shift; # bleh

	# validate this string if we are in UTF-8 mode
	unless ($seven) {
		$probe = $_;
		eval 'utf8::encode($probe);';
		die("utf8 doesn't work right in this perl. run with -seven.\n")
			if (length($probe) < length($_)); # should be at least
		if ($probe =~ /($badutf8)/) {
print $stdout "*** invalid UTF-8: partial delete of a wide character?\n";
			print $stdout "*** ignoring this string\n";
			return 0;
		}
	}

	chomp;
	$_ = &$precommand($_);
	s/^\s+//;
	s/\s+$//;
	if (s/\033\[[ABCD]//g || s/[\000-\037]//g) {
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

	# and escaped history
	s/^\\\%/%/;

	print $stdout "(expanded to \"$_\")\n" if ($i);
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

	# evaluator
	if (m#^/ev(al)? (.+)$#) {
		$k = eval $2;
		print $stdout "==> $k $@\n";
		return 0;
	}

	# url shortener routine
	if (m#^/sh(ort)? (http://[^ ]+)#) {
		print $stdout
"*** shortened to: @{[ (&urlshorten($2) || 'FAILED -- %% to retry') ]}\n";
		return 0;
	}

	# getter and setter for internal value settings
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
		} else {
			print "*** not a valid option or setting: $key\n";
		}
		return 0;
	}
	if ($_ eq '/verbose' || $_ eq '/ve') {
		$verbose ^= 1;
		$_ = "/set verbose $verbose";
		print $stdout "-- verbosity.\n" if ($verbose);
		# and fall through to ...
	}
	if (/^\/s(et)? ([^ ]+) ([^ ]+)/) {
		$key = $2;
		$value = $3;
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
				$$key = $value;
				print $stdout "*** changed: $key => $$key\n";

				# handle special values
				&generate_ansi if ($key eq 'ansi');
				&generate_shortdomain if ($key eq 'shorturl');

				# transmit to background process sync-ed values
				if ($opts_sync{$key}) {
					print $stdout
					"*** (transmitting to background)\n";
					print C (
				substr("=$key                           ",
						0, 19) . "\n");
					print C (substr(($value . (" " x 1024)),
						0, 1024));
					sleep 1;
				}
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
	if (s/^\/\!// && length) {
		system("$_");
		$x = $? >> 8;
		print $stdout "*** exited with $x\n" if ($x);
		return 0;
	}

	if ($_ eq '/help' || $_ eq '/?') {
		print <<'EOF';
      *** BASIC COMMANDS:  :a$AAOOOOOOOOOOOOOOOOOAA$a,
                         +@A:.                     .:B@+
   /refresh              =@B     HELP!!!  HELP!!!    B@= 
     grabs the newest    :a$Ao                     oA$a,
     tweets right            ;AAA$a; :a$AAAAAAAAAAA;
     away (or tells  :AOaaao:,   .:oA*:.
     you if there    .;=$$$OBO***+        .+aaaa$:
     is nothing new)             :*; :***O@Aaaa*o,         ============
     by thumping     .+++++:       o#o                      REMEMBER!!
     the background  :OOOOOOA*:::, =@o       ,:::::.       ============
     process.          .+++++++++: =@*.....=a$OOOB#;    MANY COMMANDS, AND
                                   =@OoO@BAAA#@$o,        ALL TWEETS ARE
                                   =@o  .+aaaaa:         --ASYNCHRONOUS--
   /again                          =@Aaaaaaaaaa*o*a;,  and might not always
      displays last twenty         =@$++=++++++:,;+aA:       respond
      tweets, both old and       ,+$@*.=O+  ...oO; oAo+.   immediately!
      new.                     ,+o$OO=.+aA#####Oa;.*OO$o+.
                               +Ba::;oaa*$Aa=aA$*aa=;::$B:
                                 ,===O@BOOOOOOOOO#@$===,
   /quit                             o@BOOOOOOOOO#@+
      resumes your boring life.      o@BOB@B$B@BO#@+    SEE DOCUMENTATION
                                     o@*.a@o a@o.$@+     for OTHER COMMANDS.
 ** EVERYTHING ELSE IS TWEETED **    o@B$B@o a@A$#@+  
EOF
		if ($termrl) {
			$termrl->readline("PRESS RETURN/ENTER> ");
		} else {
			print "PRESS RETURN/ENTER> ";
			$j = <$stdin>;
		}
		print <<"EOF";

 TTYtter $TTYtter_VERSION is (c)2008 cameron kaiser. all rights reserved. this software
 is offered AS IS, with no guarantees. it is not endorsed by Obvious or the
 executives and developers of Twitter.

 --- twitter: doctorlinguist --- http://www.floodgap.com/software/ttytter/ ---

           *** subscribe to updates at http://twitter.com/ttytter
                                    or http://twitter.com/floodgap
               send your suggestions to me at ckaiser\@floodgap.com

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
			my ($time, $ts) = &wraptime($art->{'created_at'});
			print $stdout "-- last update: $ts\n"
				unless ($timestamp);
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

# originally
# {"status":{"created_at":"Thu Jan 10 16:03:20 +0000 2008","text":"@ijastram grand theft probably.","id":584052732},"profile_text_color":"000000","profile_link_color":"0000ff","name":"Cameron Kaiser","profile_background_image_url":"http:\/\/s3.amazonaws.com\/twitter_production\/profile_background_images\/564672\/shbak.gif","profile_sidebar_fill_color":"e0ff92","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","followers_count":277,"screen_name":"doctorlinguist","profile_sidebar_border_color":"87bc44","profile_image_url":"http:\/\/s3.amazonaws.com\/twitter_production\/profile_images\/20933022\/me2_normal.jpg","location":"Southern California","profile_background_tile":true,"favourites_count":49,"following":false,"statuses_count":9878,"friends_count":99,"profile_background_color":"9ae4e8","url":"http:\/\/www.cameronkaiser.com","id":3841961,"utc_offset":-28800,"protected":false}
# now
#{'profile_image_url':'http:\/\/s3.amazonaws.com\/twitter_production\/profile_images\/54729098\/me2_normal.jpg','name':'Cameron Kaiser','followers_count':563,'description':'Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?','location':'Southern California','screen_name':'doctorlinguist','id':3841961,'protected':false,'status':{'text':'thatSSQQ0s enough. ISSQQ0m dying here. crashing.','created_at':'Wed Jul 16 05:42:07 +0000 2008','id':859733472},'url':'http:\/\/www.cameronkaiser.com'}

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
#${CYAN}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} ($uname) (f:$my_json_ref->{'friends_count'}/$my_json_ref->{'followers_count'}) (u:$my_json_ref->{'statuses_count'})
			print $stdout <<"EOF"; 

${CYAN}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} ($uname) (is followed by $my_json_ref->{'followers_count'} users)

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
# THIS IS A TEMPORARY KLUDGE
# this has stopped working so it is disabled
			unless (0 || $anonymous || $whoami eq $uname) {
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

	if (length > 140) {
		$g = length($_) - 140;
		$_ = substr($_, 0, 140);
		# s.m.r.t. truncator (like Homer Simpson)
		s/[^a-zA-Z0-9]+$//;
		s/\s+[^\s]+$// if (length == 140);
		$history[0] = $_;
		print $stdout
"*** sorry, tweet too long by $g characters; truncated to \"$_\" (@{[ length ]} chars)\n";
	print $stdout "*** use %% for truncated version, or append to %%.\n";
		return 0;
	}
	&updatest($_, 1);
	return 0;
}

sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $urle = '';
	my $i;
	my $subpid;
	my $istring;

	if ($anonymous) {
		print $stdout "-- sorry, you can't tweet if you're anonymous.\n"
			if ($interactive);
		return 99;
	}
	$string = &$prepost($string);

	# to avoid unpleasantness with UTF-8 interactions, this will simply
	# turn the whole thing into a hex string and insert %, thus URL
	# escaping the whole thing whether it needs it or not. ugly? well ...
	$istring = $string;
	eval 'utf8::encode($istring)' unless ($seven);
	$istring = unpack("H280", $istring);
	for($i = 0; $i < length($istring); $i+=2) {
		$urle .= '%' . substr($istring, $i, 2);
	}
	$subpid = open(N,
		# I know the below is redundant. this is to remind me to see
		# if there is something cleverer to do with it later.
"|$wend $update 2>/dev/null >/dev/null") || do{
		print $stdout "post failure: $!\n" if ($interactive);
		return 99;
	};
	print N "source=TTYtter&status=$urle\n";
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

sub thump { print C "update-------------\n"; }

sub urlshorten {
	my $url = shift;
	my $rc;

	return $url if ($url =~ /^$shorturldomain/i); # stop loops
	chomp($rc = `$weld "${shorturl}$url"`);
	return ($urlshort = (($rc =~ m#^http://#) ? $rc : undef));
}

MONITOR:
# asynchronous monitoring process -- uses select() to receive from console

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
$last_rate_limit = undef;
$rate_limit_left = undef;
$rate_limit_rate = undef;
$rate_limit_next = 0;
$effpause = 0;

for(;;) {
	&$heartbeat;
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
# this is computed to give you approximately 40% over the limit for client
# requests
# first, how many requests do we want to make an hour? $dmpause in a sec
$effpause = $rate_limit_rate - ($rate_limit_rate * 0.4);
# second, take requests away for $dmpause (e.g., 4:1 means reduce by 25%)
$effpause -= ((1/$dmpause) * $effpause) if ($dmpause);
# finally determine how many seconds should elapse
print $stdout "-- that's funny: effpause is zero, using fallback 180sec\n"
	if (!$effpause && $verbose);
$effpause = ($effpause) ? int(3600/$effpause) : 180;
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
	$timeleft = ($effpause) ? $effpause : 60;
	if($timeleft=select($rout=$rin, undef, undef, ($timeleft||$effpause))) {
		sysread(STDIN, $rout, 20);
		next if (!length($rout));
		if ($rout =~ /^sync/) {
			print $stdout "-- synced; exiting at ", scalar localtime
				if ($verbose);
			exit $laststatus;
		}
		if ($rout =~ /([\=\?])([^ ]+)/) {
			$comm = $1;
			$key =$2;
			if ($comm eq '?') {
				print $stdout "*** $key => $$key\n";
			} else {
				sysread(STDIN, $value, 1024);
				$value =~ s/\s+$//;
				$$key = $value;
				print $stdout "*** changed: $key => $$key\n";

				&generate_ansi if ($key eq 'ansi');
				$rate_limit_next = 0 if ($key eq 'pause' &&
					$value eq 'auto');
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
		print $stdout "-- routine refresh ($dmcount to next dm) ", scalar
			localtime, "\n" if ($verbose);
	}
}

# the refresh engine depends on later tweets having higher id numbers.
# Obvious, don't change this if you know what's good for you, ya twerps,
# or I will poison all of yer kitties. *pats my Burmese, who purrs*

sub grabjson {
	my $data;
	my $url = shift;
	my $last_id = shift;
	my $tdata;
	my $seed;
	my $xurl;
	my $my_json_ref = undef; # durrr hat go on foot

	#undef $/; $data = <STDIN>;

	# THIS IS A TEMPORARY KLUDGE for API issue #16
	# http://code.google.com/p/twitter-api/issues/detail?id=16
	$xurl = ($last_id) ? "?since_id=@{[ ($last_id-1) ]}&count=50" :
		"";
	# count needs to be removed for the default case due to show, etc.
	#$xurl = ($last_id) ? "?since_id=$last_id&count=50" : "";

	print $stdout "$wand \"$url$xurl\"\n" if ($superverbose);
	chomp($data = `$wand "$url$xurl" 2>/dev/null`);

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
		&screech
		("$data\n$tdata\nJSON IS UNSAFE TO EXECUTE! BAILING OUT!\n")
			if ($tdata =~ /[^\[\]\{\}:,]/);
	}

	# have to turn colons into ,s or Perl will gripe. but INTELLIGENTLY!
	1 while ($data =~ s/([^'])':(true|false|null|\'|\{|-?[0-9])/\1\',\2/);

	# somewhat validated, so safe (errr ...) to eval() into a Perl struct
	eval "\$my_json_ref = $data;";
	print $stdout "$data => $my_json_ref $@\n"  if ($superverbose);

	# do a sanity check
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!defined($my_json_ref));

	$laststatus = 0;
	return $my_json_ref;
}

sub refresh {
	my $interactive = shift;
	my $relative_last_id = shift;
	my $my_json_ref = &grabjson($url, $last_id);
	return if (!defined($my_json_ref) || ref($my_json_ref) ne 'ARRAY');
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
	my $printed = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $j;

	if ($disp_max) { # null list may be valid if we get code 304
		for($i = $disp_max; $i > 0; $i--) {
			my $g = ($i-1);
			$j = $my_json_ref->[$g];
			my $id = $j->{'id'};

			next if ($id <= $last_id);
			next if (!length($j->{'user'}->{'screen_name'}));

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
	# (unless user specifically requested it)
	return if (!$interactive && !$last_id); # NOT last_dm

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

			$printed += &$dmhandle($my_json_ref->[$g]);
		}
		$max = 0+$my_json_ref->[0]->{'id'};
	}
	print $stdout "-- sorry, no new direct messages.\n"
		if (($interactive || $verbose) && !$printed);
	$last_dm = &max($last_dm, $max);
	# 0.8.5
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

	$x =~ s/$ssqqmask/\'/g;
	$x =~ s/$ddqqmask/\"/g;
	$x =~ s#\\/#/#g;
	$x =~ s/$bbqqmask/\\/g;

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
