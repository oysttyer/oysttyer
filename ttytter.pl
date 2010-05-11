#!/usr/bin/perl -s
#########################################################################
#
# TTYtter v1.0 (c)2007-2010 cameron kaiser (and contributors).
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
	# ONLY STUFF THAT MUST RUN BEFORE INITIALIZATION GOES HERE!
	# THIS FUNCTION HAS GOTTEN TOO DAMN CLUTTERED!

#	@INC = (); # wreck intentionally for testing
	$ENV{'PERL_SIGNALS'} = 'unsafe';
	$0 = "TTYtter";
	$TTYtter_VERSION = "1.0";
	$TTYtter_PATCH_VERSION = 3;
	$TTYtter_RC_NUMBER = 0; # non-zero for release candidate
	$my_version_string = "${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}";
	(warn ("$my_version_string\n"), exit) if ($version);

	$space_pad = " " x 1024;

	# for multi-module extension handling
	$multi_module_mode = 0;
	$multi_module_context = 0;
	undef %master_store;

	$padded_patch_version = substr($TTYtter_PATCH_VERSION . " ", 0, 2);

	%opts_boolean = map { $_ => 1 } qw(
		ansi noansi verbose superverbose ttytteristas noprompt
		seven silent hold daemon script anonymous readline ssl
		newline vcheck verify noratelimit notrack nonewrts
		synch exception_is_maskable
	); %opts_sync = map { $_ => 1 } qw(
		ansi pause dmpause ttytteristas verbose superverbose
		url rlurl dmurl newline wrap notimeline
		queryurl trendurl track colourprompt colourme notrack
		colourdm colourreply colourwarn coloursearch idurl
		notifies filter colourdefault
	); %opts_urls = map {$_ => 1} qw(
		url dmurl uurl rurl wurl frurl rlurl update shorturl
		apibase queryurl trendurl idurl delurl dmdelurl favsurl
		myfavsurl favurl favdelurl rtsofmeurl followurl leaveurl
		dmupdate
		#createliurl updateliurl delliurl getliurl getlisurl
		#statusliurl followliurl leaveliurl
	); %opts_secret = map { $_ => 1} qw(
		superverbose ttytteristas
	); %opts_can_set = map { $_ => 1 } qw(
		url pause dmurl dmpause superverbose ansi verbose
		update uurl rurl wurl avatar ttytteristas frurl track
		rlurl noprompt shorturl newline wrap verify autosplit
		notimeline queryurl trendurl colourprompt colourme
		colourdm colourreply colourwarn coloursearch idurl
		urlopen delurl notrack dmdelurl favsurl myfavsurl
		favurl favdelurl slowpost notifies filter colourdefault
		rtsofmeurl followurl leaveurl dmupdate
		#createliurl updateliurl delliurl getliurl getlisurl
		#statusliurl followliurl leaveliurl
	); %opts_others = map { $_ => 1 } qw(
		lynx curl seven silent maxhist noansi lib hold status
		daemon timestamp twarg user anonymous script readline
		leader ssl rc norc vcheck apibase notifytype olib exts
		nonewrts synch runcommand
	); %valid = (%opts_can_set, %opts_others);
	$rc = (defined($rc) && length($rc)) ? $rc : "";
	$supreturnto = $verbose + 0;
	unless ($norc) {
		my $rcf =
			($rc =~ m#^/#) ? $rc : "$ENV{'HOME'}/.ttytterrc${rc}";
		if (open(W, $rcf)) {
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
				} elsif ($key =~ /^extpref_/) {
					$$key = $value;
				} elsif (!$valid{$key}) {
			warn "** setting $key not supported in this version\n";
				}
			}
			close(W);
		} elsif (length($rc)) {
			die("couldn't access rc file $rcf: $!\n".
	"to use defaults, use -norc or don't specify the -rc option.\n\n");
		}
	}
	$seven ||= 0;
	$lib ||= "";
	$parent = $$;
	$script = 1 if (length($runcommand));

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

	# stub namespace for multimodules and (eventually) state saving
	undef %store;
	$store = \%store;

	die(
"** you may not use -olib or -lib with -exts.\n" .
"** -olib and -lib are now deprecated in favour of multi-module extensions.\n".
"** if your extension is multi-module aware, add it to -exts instead.\n")
		if (length($exts) && $exts ne '0' &&
			(length($olib) || length($lib)));
	if (length($olib)) {
		warn "** executing olib: $olib\n";
		warn "** WARNING: old-style extensions are now deprecated!\n";
		eval($olib);
	}
	if (length($lib)) {
		warn "** attempting to load old-style extension: $lib\n";
		warn "** WARNING: old-style extensions are now deprecated!\n";
		require $lib;
	}
	unless ($seven) {
		eval
'use utf8;binmode($stdin,":utf8");binmode($stdout,":utf8");return 1' ||
	die("$@\nthis perl doesn't fully support UTF-8. use -seven.\n");
	# this is for the prinput utf8 validator.
	# adapted from http://mail.nl.linux.org/linux-utf8/2003-03/msg00087.html
	# eventually this will be removed when 5.6.x support is removed,
	# and Perl will do the UTF-8 validation for us.
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

}
END {
	&killkid unless ($in_backticks); # this is disgusting
}

#### COMMON STARTUP ####

# do we have POSIX::Termios? (usually we do)
eval 'use POSIX; $termios = new POSIX::Termios;';
print $stdout "-- termios test: $termios\n" if ($verbose);
	
# wrap warning
die(
"** dude, what the hell kind of terminal can't handle a 5 character line?\n")
	if ($wrap > 1 && $wrap < 5);
print $stdout "** warning: prompts not wrapped for wrap < 70\n"
	if ($wrap > 1 && $wrap < 70);

# reject stupid combinations
die("you can't use automatic ratelimits with -noratelimit.\nuse -pause=#sec\n")
	if ($noratelimit && $pause eq 'auto');
die("you can't use -synch with -script or -daemon.\n")
	if ($synch && ($script || $daemon));
die("-script and -daemon cannot be used together.\n")
	if ($script && $daemon);

# set up menu codes
$is_background = 0;
$alphabet = "abcdefghijkLmnopqrstuvwxyz";
%store_hash = ();
$mini_split = 250; # i.e., 10 tweets for the mini-menu (/th)
# leaving 50 tweets for the foreground temporary menus
$tweet_counter = 0;
%dm_store_hash = ();
$dm_counter = 0;

# set up threading management
$in_reply_to = 0;
$expected_tweet_ref = undef;

# interpret -script at this level
if ($script) {
	$noansi = $noprompt = 1;
	$silent = ($verbose) ? 0 : 1;
	$pause = $vcheck = $slowpost = $verify = 0;
}

### now instantiate the TTYtter dynamic API ###
### based off the defaults later in script. ####

# first we need to load any extensions specified by -exts
# this is the multi-module aware extensions loader that will replace -lib
# and -olib.
if (length($exts) && $exts ne '0') {
	$multi_module_mode = -1; # mark as loader stage

	print "** attempting to load extensions\n" unless ($silent);
	# unescape \,
	$j=0; $xstring = "ESCAPED_STRING";
	while($exts =~ /$xstring$j/) { $j++; }
	$xstring .= $j;
	$exts =~ s/\\,/$xstring/g;
	foreach $file (split(/,/, $exts)) {
#TODO
# wildcards?
		$file =~ s/$xstring/,/g;
		print "** loading $file\n" unless ($silent);

		die("** sorry, you cannot load the same extension twice.\n")
			if ($master_store->{$file}->{'loaded'});

		# prepare its working space in $store and load the module
		$master_store->{$file} = { 'loaded' => 1 };
		$store = \%{ $master_store->{$file} };
		$EM_DONT_CARE = 0;
		$EM_SCRIPT_ON = 1;
		$EM_SCRIPT_OFF = -1;
		$extension_mode = $EM_DONT_CARE;
		die("** file not found: $!\n") if (! -r "$file");
		require $file; # and die if bad
		die("** failed to load: $@\n") if ($@);

		# check type of extension (interactive or non-interactive). if
		# we are in the wrong mode, bail out.
		if ($extension_mode) {
			die(
"** this extension requires -script. this may conflict with other extensions\n".
"   you are loading, which may have their own requirements.\n")
			if ($extension_mode == $EM_SCRIPT_ON && !$script);
			die(
"** this extension cannot work with -script. this may conflict with other\n".
"   extensions you are loading, which may have their own requirements.\n")
			if ($extension_mode == $EM_SCRIPT_OFF && $script);
		}

		# pick off all the subroutine references it makes for storage
		# in an array to iterate and chain over later.

		# these methods are multi-module safe
		foreach $arry (qw(
			handle exception tweettype conclude dmhandle dmconclude
			heartbeat precommand prepost postpost addaction)) {
			if (defined($$arry)) {
				$aarry = "m_$arry";
				push(@$aarry, [ $file, $$arry ]);
				undef $$arry;
			}
		}
		# these methods are NOT multi-module safe
		# if a extension already hooked one of
		# these and another extension tries to hook it, fatal error.
		foreach $arry (qw(
			authenticate prompt main autocompletion)) {
			if (defined($$arry)) {
				$sarry = "l_$arry";
				if (defined($$sarry)) {
					die(
"** double hook of unsafe method \"$arry\" -- you cannot use this extension\n".
"   with the other extensions you are loading. see the documentation.\n");
				}
				$$sarry = $$arry;
				undef $$arry;
			}
		}
		# these methods are deprecated
		foreach $arry (qw(console choosecolour)) {
			if (defined($$arry)) {
				die(
"** method \"$arry\" is no longer supported in this version. you must\n".
"   update this extension for this version of TTYtter.\n");
			}
		}
	}
	# success! enable multi-module support in the TTYtter API and then
	# dispatch calls through the multi-module system instead.
	$multi_module_mode = 1; # mark as completed loader

	$handle = \&multihandle;
	$exception = \&multiexception;
	$tweettype = \&multitweettype;
	$conclude = \&multiconclude;
	$dmhandle = \&multidmhandle;
	$dmconclude = \&multidmconclude;
	$heartbeat = \&multiheartbeat;
	$precommand = \&multiprecommand;
	$prepost ||= \&multiprepost;
	$postpost ||= \&multipostpost;
	$addaction ||= \&multiaddaction;
} else {
	# the old API single-end-point system

	$multi_module_mode = 0; # not executing multi module endpoints

	$handle ||= \&defaulthandle;
	$exception ||= \&defaultexception;
	$tweettype ||= \&defaulttweettype;
	$conclude ||= \&defaultconclude;
	$dmhandle ||= \&defaultdmhandle;
	$dmconclude ||= \&defaultdmconclude;
	$heartbeat ||= \&defaultheartbeat;
	$precommand ||= \&defaultprecommand;
	$prepost ||= \&defaultprepost;
	$postpost ||= \&defaultpostpost;
	$addaction ||= \&defaultaddaction;
}

# unsafe methods use the single-end-point
$authenticate ||= $l_authenticate || \&defaultauthenticate;
$prompt ||= $l_prompt || \&defaultprompt;
$main ||= $l_main || \&defaultmain;

# $autocompletion is special:
if ($termrl) {
	$termrl->Attribs()->{'completion_function'} =
		$autocompletion || $l_autocompletion ||
			\&defaultautocompletion;
}

# validate the notify method the user chose, if any.
# we can't do this in BEGIN, because it may not be instantiated yet,
# and we have to do it after loading modules because it might be in one.
if (length($notifytype) && $notifytype ne '0' &&
		$notifytype ne '1' && !$status) {
		# NOT $script! scripts have a use case for notifiers!
	$notifytype="notifier_${notifytype}";
	eval 'return &$notifytype(undef)' ||
		die("** invalid notification framework $notifytype: $@\n");
	# warning if someone didn't tell us what notifies they wanted.
	warn "-- warning: you specified -notifytype, but no -notifies\n"
		if (!$silent && !length($notifies));

} else {
	undef $notifytype;
}

# set up track tags
if (length($tquery) && $tquery ne '0') {
	my $xtquery = &tracktags_tqueryurlify($tquery);
	die("** custom tquery is over 140 length: $xtquery\n")
		if (length($xtquery) > 139);
	@trackstrings = ($xtquery);
} else {
	&tracktags_makearray;
}

# compile filter
exit(1) if (!&filter_compile);

# finally, compile notifies. we do this regardless of notifytype, so that
# an extension can look at it if it wants to.
&notify_compile;

if ($termrl) {
	$streamout = $stdout; # this is just simpler instead of dupping
        warn(<<"EOF") if ($] < 5.006);
***********************************************************
** -readline may not function correctly on Perls < 5.6.0 **
***********************************************************
EOF
} else {
	# dup $stdout for benefit of various other scripts
	open(DUPSTDOUT, ">&STDOUT") ||
		warn("** warning: could not dup $stdout: $!\n");
	binmode(DUPSTDOUT, ":utf8") unless ($seven);
	$streamout = \*DUPSTDOUT;
}
if ($silent) {
	close($stdout);
	open($stdout, ">>/dev/null"); # KLUUUUUUUDGE
}

# after this point, die() will cause problems

# initialize our route back out so background can talk to foreground
pipe(W, P) || die("pipe() error [or your Perl doesn't support it]: $!\n");
select(P); $|++;
binmode(P, ":utf8") unless ($seven);
binmode(W, ":utf8") unless ($seven);

# default command line options

$anonymous ||= 0;
undef $user if ($anonymous);
if ($ssl) {
	print $stdout "-- using SSL for default URLs.\n";
}
$http_proto = ($ssl) ? 'https' : 'http';

$apibase ||= "${http_proto}://api.twitter.com/1";
$nonewrts ||= 0;
$url ||= ($anonymous)
	? "${apibase}/statuses/public_timeline.json"
	: ($nonewrts)
	?  "${apibase}/statuses/friends_timeline.json"
	: "${apibase}/statuses/home_timeline.json";
$update ||= "${apibase}/statuses/update.json";
$rurl ||= "${apibase}/statuses/mentions.json";
$uurl ||= "${apibase}/statuses/user_timeline.json";
$idurl ||= "${apibase}/statuses/show";
$delurl ||= "${apibase}/statuses/destroy";

$rtsofmeurl ||= "${apibase}/statuses/retweets_of_me.json";

$wurl ||= "${apibase}/users/show.json";

$frurl ||= "${apibase}/friendships/exists.json";
$followurl ||= "${apibase}/friendships/create";
$leaveurl ||= "${apibase}/friendships/destroy";

$rlurl ||= "${apibase}/account/rate_limit_status.json";

$dmurl ||= "${apibase}/direct_messages.json";
$dmupdate ||= "${apibase}/direct_messages/new.json";
$dmdelurl ||= "${apibase}/direct_messages/destroy";

$favsurl ||= "${apibase}/favorites";
$myfavsurl ||= "${apibase}/favorites.json";
$favurl ||= "${apibase}/favorites/create";
$favdelurl ||= "${apibase}/favorites/destroy";

$queryurl ||= "http://api.twitter.com/1/search.json";
$trendurl ||= "http://api.twitter.com/1/trends/current.json";

# pick ONE!
#$shorturl ||= "http://api.tr.im/v1/trim_simple?url=";
$shorturl ||= "http://is.gd/api.php?longurl=";

# figure out the domain to stop shortener loops
&generate_shortdomain;

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
$slowpost ||= 0;
$twarg ||= undef;

$verbose ||= $superverbose;
$dmpause = 4 if (!defined $dmpause); # NOT ||= ... zero is a VALID value!
$dmpause = 0 if ($anonymous);
$dmpause = 0 if ($pause eq '0');
$ansi = ($noansi) ? 0 :
	(($ansi || $ENV{'TERM'} eq 'ansi' || $ENV{'TERM'} eq 'xterm-color')
		? 1 : 0);
$whoami = (split(/\:/, $user, 2))[0] unless ($anonymous);

# synch overrides these options.
if ($synch) {
	$pause = 0;
	$dmpause = ($dmpause) ? 1 : 0;
}

$dmcount = $dmpause;
$lastshort = undef;

# ANSI sequences
$colourprompt ||= "CYAN";
$colourme ||= "YELLOW";
$colourdm ||= "GREEN";
$colourreply ||= "RED";
$colourwarn ||= "MAGENTA";
$coloursearch ||= "CYAN";
$colourdefault ||= "OFF";
$ESC = pack("C", 27);
$BEL = pack("C", 7);
&generate_ansi;

# to force unambiguous bareword interpretation
$true = 'true';
sub true { return 'true'; }
$false = 'false';
sub false { return 'false'; }
$null = undef;
sub null { return undef; }

select($stdout); $|++;

# figure out what our user agent should be
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
&update_authenticationheaders;

# update check
if ($vcheck && !length($status)) {
	$vs = &updatecheck;
} else {
	$vs =
"-- no version check performed (use /vcheck, or -vcheck to check on startup)\n"
	unless ($script || $status);
}
print $stdout $vs; # and then again when client starts up

# initial login tests and command line controls
$phase = 0;
$didhold = $hold;
$hold = -1 if ($hold == 1 && !$script);
for(;;) {
	$rv = 0;
	die(
	"sorry, you can't tweet anonymously. use an authenticated username.\n")
		if ($anonymous && length($status));
	die(
"sorry, status too long: reduce by @{[ length($status)-140 ]} chars, ".
"or use -autosplit={word,char,cut}.\n")
		if (length($status) > 140 && !$autosplit);
	($status, $next) = &csplit($status, ($autosplit eq 'char' ||
			$autosplit eq 'cut') ? 1 : 0)
		if (!length($next));
	if ($autosplit eq 'cut' && length($next)) {
		print "-- warning: input autotrimmed to 140 bytes\n";
		$next = "";
	}
	if (length($status) && $phase) {
		print "post attempt "; $rv = &updatest($status, 0);
	} else {
		print "test-login "; 
		$data = &backticks($baseagent, '/dev/null', undef,
					$url, undef, @wind);
		$rv = $?;
	}
	if ($rv || &is_fail_whale($data) || &is_json_error($data)) {
		if (&is_fail_whale($data)) {
			print "FAILED -- Fail Whale detected\n";
		} elsif ($x = &is_json_error($data)) {
			print "FAILED!\n*** server reports: \"$x\"\n";
			print "check your password or configuration.\n";
		} else {
			$x = $rv >> 8;
			print
		"FAILED. ($x) bad password, login or URL? server down?\n";
		}
		print "access failure on: ";
		print (($phase) ? $update : $url);
		print "\n";
		print "--- data received ---\n$data\n--- data received ---\n"
			if ($superverbose);
		if (--$hold) {
			print
			"trying again in 2 minutes, or kill process now.\n\n";
			sleep 120;
			next;
		}
		if ($didhold) {
			print "giving up after $didhold tries.\n";
		} else {
			print
			"to automatically wait for a connect, use -hold.\n";
		}
		exit(1);
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
exit(0) if (length($status));

#### BOT/DAEMON MODE STARTUP ####

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

#### INTERACTIVE MODE and CONSOLE STARTUP ####

print <<"EOF";

######################################################        +oo=========oo+ 
         ${EM}TTYtter ${TTYtter_VERSION}.${padded_patch_version} (c)2010 cameron kaiser${OFF}                @             @
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

# these three functions are outside of the usual API assertions for clarity.
# they represent the main loop, which by default is the interactive console.
# the main loop can be redefined.

sub defaultprompt {
	my $rv = ($noprompt) ? "" : "TTYtter> ";
	my $rvl = ($noprompt) ? 0 : 9;
	return ($rv, $rvl) if (shift);
	$wrapseq = 0;
	print $stdout "${CCprompt}$rv${OFF}" unless ($termrl);
}
sub defaultaddaction { return 0; }
sub defaultmain {
	if (length($runcommand)) {
		&prinput($runcommand);
		&sync_n_quit;
	}
	@history = ();
	if ($termrl) {
		while(defined ($_ = $termrl->readline((&$prompt(1))[0]))) {
			$rv = &prinput($_);
			last if ($rv < 0);
			&sync_console unless (!$rv || !$synch);
		}
	} else {
		&$prompt;
		while(<>) { #not stdin so we can read from script files
			$rv = &prinput($_);
			last if ($rv < 0);
			&sync_console unless (!$rv || !$synch);
			&$prompt;
		}
		&sync_n_quit if ($script);
	}
}

# start the background process
# this has to be last or the background process can't see the full API
if ($child = open(C, "|-")) {
	close(P);
	binmode(C, ":utf8") unless ($seven);
} else {
	close(W);
	goto MONITOR;
}
$SIG{'PIPE'} = $SIG{'BREAK'} = $SIG{'INT'} = \&end_me;
select(C); $|++; select($stdout);

# handshake for synchronicity mode, if we want it.
if ($synch) {
	# we will get two replies for this.
	print C "synm---------------\n";
	&thump;
	# the second will be cleared by the console
}

# start the 
&$main;
# loop until we quit and then we'll
&sync_n_quit if ($script);
# else
exit;

#### command processor ####

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
		return 1;
	}

	if (!$slowpost && !$verify && # we assume you know what you're doing!
		($_ eq 'h' || $_ eq 'help' || $_ eq 'quit' || $_ eq 'q' ||
			/^TTYtter>/ ||
			$_ eq 'exit')) {
		
		&add_history($_);
		unless ($_ eq 'exit' || /^TTYtter>/) {
			print $stdout "*** did you mean /$_ ?\n";
			print $stdout
				"*** to send this as a command, type /%%\n";
		} else {
			print $stdout
				"*** did you really mean to tweet \"$_\"?\n";
		}
		print $stdout "*** to tweet it anyway, type %%\n";
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
	$i = 0; # flag

	if (/^\%(\%|-\d+)(--|-\d+)?/) {
		($i, $proband, $r, $s) = &sub_helper($1, $2);
		return 0 if (!$i);

		s/^\%${r}${s}/$proband/;
	}
	if (/[^\\]\%(\%|-\d+)(--|-\d+)?$/) {
		($i, $proband, $r, $s) = &sub_helper($1, $2);
		return 0 if (!$i);

		s/\%${r}${s}$/$proband/;
	}
	# handle variables second, in case they got in history somehow ...
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

	return 0 unless length; # actually possible to happen
				# with control char filters and history.

	# handle history display
	if ($_ eq '/history' || $_ eq '/h') {
		@history = (($_, @history)[0..&min(scalar(@history),
			$maxhist)]) if ($termrl); # this is fricking gross.
		for ($i = scalar(@history); $i >= 1; $i--) {
			print $stdout "\t$i\t$history[($i-1)]\n";
		}
		return 0;
	}	

	&add_history($_);

	my $slash_first = ($_ =~ m#^/#);

	return -1 if ($_ eq '/quit' || $_ eq '/q' || $_ eq '/bye' ||
			$_ eq '/exit');

	return 0 if (scalar(&$addaction($_)));

	# add commands here

#TODO
# expand into a DMdumper sometime
	if (m#^/zipet (...)#) {
		$k = &get_dm($1);
		warn "$k->{'sender'}->{'screen_name'} said $k->{'text'}\n";
		return 0;
	}

	if (m#^/du(mp)? ([zZ]?[a-zA-Z][0-9])$#) {
		my $code = lc($2);
		my $tweet = &get_tweet($code);
		my $k;
		my $sn;
		my $id;
		my @superfields = (
			[ "user", "screen_name" ], # must always be first
			[ "retweeted_status", "id" ],
			[ "user", "geo_enabled" ],
		);
		my $superfield;

		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
	
		foreach $superfield (@superfields) {
			my $sfn = join('->', @{ $superfield });
			my $sfk = "{'" . join("'}->{'", @{ $superfield }) .
				"'}";
			my $sfv;
			eval "\$sfv = &descape(\$tweet->$sfk);";
			print $stdout
				substr("$sfn                        ", 0, 23) .
				" $sfv\n";
			$sn = $sfv if (!length($sn) && length($sfv));
		}
		# geo is special
		print $stdout "geo->coordinates        (" .
			join(', ', @{ $tweet->{'geo'}->{'coordinates'} })
			. ")\n";
		foreach $k (sort keys %{ $tweet }) {
			next if (ref($tweet->{$k}));
			print $stdout
				substr("$k                        ", 0, 23) .
					" " . &descape($tweet->{$k}) . "\n";
		}
		# include a URL to the tweet per @augmentedfourth
		$urlshort = "http://twitter.com/$sn/statuses/$tweet->{'id'}";
		print $stdout
			"-- %URL% is now $urlshort (/short to shorten)\n";
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
	if (($_ eq '/sh' || $_ eq '/short') && length($urlshort)) {
		$_ = "/short $urlshort";
		print $stdout "*** assuming you meant %URL%: $_\n";
		# and fall through to ...
	}
	if (m#^/sh(ort)? (https?://[^ ]+)#) {
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
		&$conclude;
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
	# remove it from array, regenerate $track, call tracktags_makearray
	# and then sync
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
		$track = join(' ', @ptags);
		&tracktags_makearray;
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
			$value = $track; # falls thru to sync
			&tracktags_makearray;
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
				&filter_compile if ($key eq 'filter');
				&notify_compile if ($key eq 'notifies');

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
			$value = &tracktags_tqueryurlify($value);
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
|  complete list  |  /follow username           follow a username
|                 |  /leave username            stop following a username
+-----------------+  /dm username message       send a username a DM
+--- TWEET AND DM SELECTION -------------------------------------------------+
| all DMs and tweets have menu codes (letters + number, d for DMs). example: |
|      a5> <ttytter> Send me Dr Pepper http://www.floodgap.com/TTYtter       |
|      [DM da0][ttytter/Sun Jan 32 1969] I think you are cute                |
| /reply a5 message                 replies to tweet a5                      |
|      example: /reply a5 I also like Dr Pepper                              |
|      becomes  \@ttytter I also like Dr Pepper     (and is threaded)         |
| /thread a5                        if a5 is part of a thread (the username  |
|                                    has a \@) then show all posts up to that |
| /url a5                           opens all URLs in tweet a5               |
|      Mac OS X users, do first: /set urlopen open %U                        |
|      Dummy terminal users, try /set urlopen lynx -dump %U | more           |
| /delete a5                        deletes tweet a5, if it's your tweet     |
| /rt a5                            retweets tweet a5: RT \@tytter: Send me...|
+-- Abbreviations: /re, /th, /url, /del --- menu codes wrap around at end ---+
=====> /reply, /delete and /url work for direct message menu codes too! <=====
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
            WANT TO VERIFY YOUR TWEETS BEFORE POSTING? /set verify 1
                       or use the -verify command line option.
For more, like readline support, UTF-8, SSL, proxies, etc., see the docs.

** READ THE COMPLETE DOCUMENTATION: http://www.floodgap.com/software/ttytter/

 TTYtter $TTYtter_VERSION is (c)2010 cameron kaiser + contributors.
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
		my ($prompt, $prolen) = (&$prompt(1));
		$prolen = " " x $prolen;
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
#TODO
# add +count parameter or page number?
		my $mode = $1;
		my $uname = $3;
		
		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout "-- synchronous /again command for $uname\n"
			if ($verbose);
		my $my_json_ref =
		&grabjson("${uurl}?screen_name=${uname}", 0);

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
			print $stdout &wwrap(
				"-- update covers $ts1 thru $ts2\n");
			}
		}
		&$conclude;
		unless ($mode eq 'w' || $mode eq 'wf') {
			return 0;
		} # else fallthrough
	}
	if ($_ =~ m#^/w(hois|a|again)?\s+\@?([^\s]+)#) {
		my $uname = $2;
#TODO
# last status/created at if not part of again
# and also if user is protected
# 'status'->{'text','another one down. two more milestones to go. I love it when I\'m awesome.','created_at','Thu Dec 10 05:57:20 +0000 2009'}

		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout "-- synchronous /whois command for $uname\n"
			if ($verbose);
		my $my_json_ref =
		&grabjson("${wurl}?screen_name=${uname}", 0);

		if (defined($my_json_ref) && ref($my_json_ref) eq 'HASH' &&
				length($my_json_ref->{'screen_name'})) {
			my $sturl = undef;
			my $purl =
				&descape($my_json_ref->{'profile_image_url'});
			if ($avatar && length($purl) && $purl !~
m#^http://[^.]+\.(twimg\.com|twitter\.com).+/images/default_profile_\d+_normal.png#) {
				my $exec = $avatar;
				my $fext;
				($purl =~ /\.([a-z0-9A-Z]+)$/) &&
					($fext = $1);
				if ($purl !~ /['\\]/) { # careful!
					$exec =~ s/\%U/'$purl'/g;
					$exec =~ s/\%N/$uname/g;
					$exec =~ s/\%E/$fext/g;
					print $stdout "\n($exec)\n";
					system($exec);
				}
			}
			my $verified =
				($my_json_ref->{'verified'} eq 'true') ?
				"${EM}(Verified Account)${OFF}" : '';
			print $stdout <<"EOF"; 

${CCprompt}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} ($uname) (f:$my_json_ref->{'friends_count'}/$my_json_ref->{'followers_count'}) (u:$my_json_ref->{'statuses_count'}) $verified
EOF
			print $stdout
"\"@{[ &descape($my_json_ref->{'description'}) ]}\"\n"
				if (length($my_json_ref->{'description'}));
			if (length($my_json_ref->{'url'})) {
				$sturl = 
				$urlshort = &descape($my_json_ref->{'url'});
				$urlshort =~ s/^\s+//;
				$urlshort =~ s/\s+$//;
				print $stdout "${EM}URL:${OFF}\t\t$urlshort\n";
			}
			print $stdout
"${EM}Location:${OFF}\t@{[ &descape($my_json_ref->{'location'}) ]}\n"
				if (length($my_json_ref->{'location'}));
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
			print $stdout
	"-- %URL% is now $urlshort (/short shortens, /url opens)\n"
				if (defined($sturl));
		}
		return 0;
	}
		
	if ($_ eq '/again' || $_ eq '/a') { # the asynchronous form
#TODO
# add count parameter or page number?
		print C "reset--------------\n";
		&sync_semaphore;
		return 0;
	}

	if (m#^/th(read)? ([zZ]?[a-zA-Z][0-9])$#) {
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
				push(@{ $thread_ref },
					&fix_geo_api_data($next));
				$id = $next->{'in_reply_to_status_id'} || 0;
			}
		}
		&tdisplay($thread_ref, 'thread', 0, 1); # use the mini-menu
		return 0;
	}

	if ($_ eq '/url' && length($urlshort)) {
		$_ = "/url $urlshort";
		print $stdout "*** assuming you meant %URL%: $_\n";
		# and fall through to ...
	}
	if (m#^/url (http|gopher|https|ftp)://.+# && s#^/url ##) {
		&openurl($_);
		return 0;
	}
	if (m#^/url ([dDzZ]?[a-zA-Z][0-9])$#) {
		my $code = lc($1);
		my $tweet;
		$urlshort = undef;

		if ($code =~ /^d/ && length($code) == 3) {
			$tweet = &get_dm($code); # USO!
			if (!defined($tweet)) {
				print $stdout
					"-- no such DM (yet?): $code\n";
				return 0;
			}
		} else {
			$tweet = &get_tweet($code);
			if (!defined($tweet)) {
				print $stdout
					"-- no such tweet (yet?): $code\n";
				return 0;
			}
		} 
		my $text = &descape($tweet->{'text'});
		# findallurls
		while ($text
#	=~ s#(http|https|ftp|gopher)://([a-zA-Z0-9_~/:%\-\+\.\=\&\?\#,]+)##) {
# sigh. I HATE YOU TINYARRO.WS
#TODO
# eventually we will have to put a punycode implementation into openurl
# to handle things like Mac OS X's open which don't understand UTF-8 URLs.
	=~ s#(http|https|ftp|gopher)://([^'\\]+?)('|\\|\s|$)##) {
			my $url = $1 . "://$2";
			$url =~ s/[\.\?]$//;
			&openurl($url);
		}
		print $stdout "-- sorry, couldn't find any URL.\n"
			if (!defined($urlshort));
		return 0;
	}

	if (s/^\/(favourites|favorites|faves|favs|fl)\s*//) {
#TODO
# add count parameter or page number?
		my $my_json_ref;
		if (length) {
			$my_json_ref = &grabjson("${favsurl}/${_}.json", 0);
		} else {
			if ($anonymous) {
				print $stdout
		"-- sorry, you can't haz favourites if you're anonymous.\n";
			} else {
				print $stdout
				"-- synchronous /favourites user command\n"
					if ($verbose);
				$my_json_ref = &grabjson($myfavsurl, 0);
			}
		}
		if (defined($my_json_ref)
				&& ref($my_json_ref) eq 'ARRAY') {
			if (scalar(@{ $my_json_ref })) {
				my $w = "-==- favourites " x 10;
				$w = $EM . substr($w, 0, $wrap || 79) . $OFF;
				print $stdout "$w\n";
				&tdisplay($my_json_ref, "favourites");
				print $stdout "$w\n";
			} else {
				print $stdout
		"-- no favourites found, boring impartiality concluded.\n";
			}
		}
		&$conclude;
		return 0;
	}
	if (
m#^/(un)?f(rt|retweet|a|av|ave|avorite|avourite)? ([zZ]?[a-zA-Z][0-9])$#) {
		my $mode = $1;
		my $secondmode = $2;
		my $code = lc($3);
		$secondmode = ($secondmode eq 'retweet') ? 'rt' : $secondmode;
		my $tweet = &get_tweet($code);
		if ($mode eq 'un' && $secondmode eq 'rt') {
			print $stdout
				"-- hmm. seems contradictory. no dice.\n";
			return 0;
		}
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		&cordfav($tweet->{'id'}, 1,
			(($mode eq 'un') ? $favdelurl : $favurl),
			  &descape($tweet->{'text'}),
			(($mode eq 'un') ? 'removed' : 'created'));
		if ($secondmode eq 'rt') {
			$_ = "/rt $code";
			# and fall through
		} else {
			return 0;
		}
	}

	# Retweet API and manual RTs
	if (s#^/(e?)r(etweet|t) ([zZ]?[a-zA-Z][0-9])\s*##) {
#TODO
# when newRT API actually used by people, facultatively use for
# simple RTs.
		my $mode = $1;
		my $code = lc($3);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		#$in_reply_to = $tweet->{'id'}; # maybe later.
		#$expected_tweet_ref = $tweet;
		$retweet = "RT @" .
			&descape($tweet->{'user'}->{'screen_name'}) .
			": " . &descape($tweet->{'text'});
		if ($mode eq 'e') {
			&add_history($retweet);
			print $stdout &wwrap(
				"-- ok, %RT% and %% are now \"$retweet\"\n");
			return 0;
		}
		$_ = (length) ? "$retweet $_" : $retweet;
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
	}
	if (m#^/(re)?rts?of?me?$# && !$nonewrts) {
#TODO
# when more fields are added, integrate them over the JSON_ref
		my $mode = $1;
		my $my_json_ref = &grabjson($rtsofmeurl, 0);
		if (defined($my_json_ref)
			&& ref($my_json_ref) eq 'ARRAY'
				&& scalar(@{ $my_json_ref })) {
			&tdisplay($my_json_ref, "rtsofme");
		}
		&$conclude;
		if ($mode eq 're') {
			$_ = '/re'; # and fall through ...
		} else {
			return 0;
		}
	}

	if (m#^/del(ete)? ([zZ]?[a-zA-Z][0-9])$#) {
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
	# DM delete version
	if (m#^/del(ete)? ([dD][a-zA-Z][0-9])$#) {
		my $code = lc($2);
		my $dm = &get_dm($code);
		if (!defined($dm)) {
			print $stdout "-- no such DM (yet?): $code\n";
			return 0;
		}
		print $stdout &wwrap(
			"-- verify you want to delete: " .
		"(from @{[ &descape($dm->{'sender'}->{'screen_name'}) ]}) ".
			"\"@{[ &descape($dm->{'text'}) ]}\"");
		print $stdout
"\n-- sure you want to delete? (only y or Y is affirmative): ";
		chomp($answer = lc(<$stdin>));
		if ($answer ne 'y') {
			warn "-- ok, DM is NOT deleted.\n";
			return 0;
		}
		&deletedm($dm->{'id'}, 1);
		return 0;
	}

	if (s#^/(v)?re(ply)? ([zZ]?[a-zA-Z][0-9]) ## && length) {
		my $mode = $1;
		my $code = lc($3);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $target = &descape($tweet->{'user'}->{'screen_name'});
		$_ = '@' . $target . " $_";
		unless ($mode eq 'v') {
			$in_reply_to = $tweet->{'id'};
			$expected_tweet_ref = $tweet;
		} else {
			$_ = ".$_";
		}
		$readline_completion{'@'.$target}++ if ($termrl);
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
	}
	# DM reply version
	if (s#^/(dm)?re(ply)? ([dD][a-zA-Z][0-9]) ## && length) {
		my $code = lc($3);
		my $dm = &get_dm($code);
		if (!defined($dm)) {
			print $stdout "-- no such DM (yet?): $code\n";
			return 0;
		}
		# in the future, add DM in_reply_to here
		my $target = &descape($dm->{'sender'}->{'screen_name'});
		$readline_completion{'@'.$target}++ if ($termrl);
		$_ = "/dm $target $_";
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		# and fall through to ...
	}

	if ($_ eq '/replies' || $_ eq '/re') {
#TODO
# add count parameter or page number?
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

	# DMs
	if ($_ eq '/dm' || $_ eq '/dmrefresh' || $_ eq '/dmr') {
		&dmthump;
		return 0;
	}
	if ($_ eq '/dmagain' || $_ eq '/dma') {
#TODO
# add count parameter or page number?
		print C "dmreset------------\n";
		&sync_semaphore;
		return 0;
	}
	if (s#^/dm \@?([^\s]+)\s+## && length)  {
		return &common_split_post($_, undef, $1);
	}

	# follow and leave users
	if (m#^/(follow|leave|unfollow) \@?([^\s]+)$#) {
		my $m = $1;
		my $u = lc($2);
		&foruuser($u, 1,
			(($m eq 'follow') ? $followurl : $leaveurl),
			(($m eq 'follow') ? 'started' : 'stopped'));
		return 0;
	}

#TODO
# 1.2
# list format: xyz/pdq. if no slash, use this user's.
# /autolist, /autolistoff (/al, /alo): add lists to timeline
#	statusliurl
# /fal, /lalo (follow and leave at the same time as /al, /alo)
#	followliurl leaveliurl
# follow and leave lists
#
# create list
#	createliurl
# update list
#	updateliurl
# show all lists (of me or a user)
#	getlisurl
# show a list
#	getliurl
# delete list (with _delete)
#	delliurl
# add users to list NEED URL
# delete users from list NEED URL

	&sync_n_quit if ($_ eq '/end' || $_ eq '/e');

	#####
	#
	# below this point, we are posting
	#
	#####

	if (m#^/me\s#) {
		$slash_first = 0; # kludge!
	}

	if ($slash_first) {
		if (!m#^//#) {
			print $stdout "*** invalid command\n";
			print $stdout "*** to pass as a tweet, type /%%\n";
			return 0;
		}
		s#^/##; # leave the second slash on
	}

TWEETPRINT: # fugly! FUGLY!
	return &common_split_post($_, $in_reply_to, undef);
}

# this is the common code used by standard updates and by the /dm command.
sub common_split_post {
	my $k = shift;
	my $in_reply_to = shift;
	my $dm_user = shift;
	
	my $dm_lead = (length($dm_user)) ? "/dm $dm_user " : '';
	my $ol = "$dm_lead$k";

	my (@tweetstack) = &csplit($k, ($autosplit eq 'char' ||
		$autosplit eq 'cut') ? 1 : 0);
	my $m = shift(@tweetstack);
	if (scalar(@tweetstack)) {
		$l = "$dm_lead$m";
		$history[0] = $l;
		if (!$autosplit) {
			print $stdout &wwrap(
"*** sorry, too long to send; ".
"truncated to \"$l\" (@{[ length($m) ]} chars)\n");
	print $stdout "*** use %% for truncated version, or append to %%.\n";
			return 0;
		}
		print $stdout &wwrap(
			"*** over 140; autosplitting to \"$l\"\n");
	}
	# there was an error; stop autosplit, restore original command
	if (&updatest($m, 1, $in_reply_to, $dm_user)) {
		$history[0] = $ol;
		return 0;
	}
	if (scalar(@tweetstack)) {
		$k = shift(@tweetstack);
		$l = "$dm_lead$k";
		&add_history($l);
		print $stdout &wwrap("*** next part is ready: \"$l\"\n");
		print $stdout "*** (this will also be automatically split)\n"
			if (length($k) > 140);
		print $stdout
		"*** to send this next portion, use %%.\n";
	}
	return 1;
}

# helper functions for the command line processor.
sub add_history {
	my $h = shift;

	@history = (($h, @history)[0..&min(scalar(@history), $maxhist)]);
	$termrl->addhistory($h) if ($termrl);
}
sub sub_helper {
	# ($i, $proband, $r, $s) = &sub_helper($1, $2);
	my $r = shift;
	my $s = shift;
	my $x;
	my $q;
	my $proband;

	if ($r eq '%') {
		$x = -1;
	} else {
		$x = $r + 0;
	}
	if (!$x || $x < -(scalar(@history))) {
		print $stdout "*** illegal history index\n";
		return (0, $_, undef, undef, undef);
	}
	$proband = $history[-($x + 1)];
	if ($s eq '--') {
		$q = 1;
	} else {
		$q = -(0+$s);
	} 
	if ($q) {
		my $j;
		my $c;
		for($j=0; $j<$q; $j++) {
			$c++ if ($proband =~ s/\s+[^\s]+$//);
		}
		if ($j != $c) {
			print $stdout "*** illegal word index\n";
			return (0, $_, undef, undef, undef);
		}
	}
	return (1, $proband, $r, $s);
}

# this is used for synchronicity mode to make sure we receive the
# GA semaphore from the background before printing another prompt.
sub sync_console {
	&thump;
	&dmthump unless (!$dmpause);
}
sub sync_semaphore {
	if ($synch) {
		my $k = '';

		while(!length($k)) {
			sysread(W, $k, 1);
		} # wait for semaphore
	}
}

#### this is the background part of the process ####

MONITOR:
%store_hash = ();
$is_background = 1;
$first_synch = $synchronous_mode = 0;
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
$SIG{'BREAK'} = $SIG{'INT'} = 'IGNORE'; # we only respond to SIGKILL/SIGTERM

# loop until we are killed or told to stop.
# we receive instructions on stdin, and send data back on our pipe().
for(;;) {
	&$heartbeat;
	&update_effpause;
	$wrapseq = 0; # remember, we don't know when commands are sent.
	&refresh($interactive, $previous_last_id) unless ($timeleft
		|| (!$effpause && !$interactive));
	$previous_last_id = $last_id;
	if ($dmpause && ($effpause || $synch)) {
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
	# nrvs is tricky with synchronicity
	if (!$synch || ($synch && $synchronous_mode && !$dm_first_time)) {
		print $stdout $notify_rate;
		$notify_rate = "";
		print $stdout $vs;
		$vs = "";
	}
#	else { print $stdout "$synch $synchronous_mode $dm_first_time\n"; }
	print P "0" if ($synchronous_mode && $interactive);
	$interactive = 0;
	$timeleft = ($effpause) ? $effpause : 60;
	if($timeleft=select($rout=$rin, undef, undef, ($timeleft||$effpause))) {
		sysread(STDIN, $rout, 20);
		next if (!length($rout));
		# background communications central command code
		# we received a command from the console, so let's look at it.
		if ($rout =~ /^pipet (..)/) {
			my $key = &get_tweet($1);
			my $ms = $key->{'menu_select'} || 'XX';
			my $ds = $key->{'created_at'} || 'argh, no created_at';
			$ds =~ s/\s/_/g;
			my $src = $key->{'source'} || 'unknown';
			$src =~ s/\|//g; # shouldn't be any anyway.
			$key = substr(( "$ms ".(0+$key->{'id'})." ".
		(0+$key->{'in_reply_to_status_id'})." ".
		(0+$key->{'retweeted_status'}->{'id'})." ".
		($key->{'user'}->{'geo_enabled'} || "false") . " ".
		($key->{'geo'}->{'coordinates'}->[0]). " ".
		($key->{'geo'}->{'coordinates'}->[1]). " ".
		$key->{'user'}->{'screen_name'}." $ds $src|".$key->{'text'}.
			$space_pad), 0, 1024);
			print P $key;
		} elsif ($rout =~ /^piped (..)/) {
			my $key = $dm_store_hash{$1};
			my $ms = $key->{'menu_select'} || 'XX';
			my $ds = $key->{'created_at'} || 'argh, no created_at';
			$ds =~ s/\s/_/g;
			$key = substr(( "$ms ".(0+$key->{'id'})." ".
		$key->{'sender'}->{'screen_name'}." $ds ".$key->{'text'}.
			$space_pad), 0, 1024);
			print P $key;
		} elsif ($rout =~ /^sync/) {
			print $stdout "-- synced; exiting at ",
					scalar localtime, "\n"
				if ($verbose);
			exit $laststatus;
		} elsif ($rout =~ /^synm/) {
			$first_synch = $synchronous_mode = 1;
			print $stdout "-- background is now synchronous\n"
				if ($verbose);
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
					&filter_compile
						if ($key eq 'filter');
					&notify_compile
						if ($key eq 'notifies');
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

#### internal implementation functions for the twitter API. DON'T ALTER ####

# manage automatic rate limiting by checking our max.
#TODO
# autoslowdown as we run out of requests, then speed up when hour
# has passed.
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
# this is computed to give you approximately 50% over the limit for client
# requests
# first, how many requests do we want to make an hour? $dmpause in a sec
						$effpause =
				$rate_limit_rate - ($rate_limit_rate * 0.5);
# second, take requests away for $dmpause (e.g., 4:1 means reduce by 25%)
						$effpause -=
				((1/$dmpause) * $effpause) if ($dmpause);
#TODO
# take 1 request away for replies (i.e., cut effpause in half)
# take 1 request away for each /autolist subscription (i.e., each one,
# cut effpause in half)

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

# thump for timeline
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
		my $r = &grabjson("$queryurl?${k}&rpp=20&result_type=recent",
				0, 1); # $last_id, 1);
			push(@streams, $r)
				if (defined($r) &&
					ref($r) eq 'ARRAY' &&
					scalar(@{ $r }));
		}
	}

	# add stream for replies ... maybe later

	# add stream for lists we have on with /autolist
#TODO
# autolist

	# now, streamix all the streams into my_json_ref, discarding duplicates
	# a simple hash lookup is no good; it has to be iterative. because of
	# that, we might as well just splice it in here and save a sort later.
	# remember, the most recent tweets are FIRST.
	if (scalar(@streams)) {
		my $j;
		my $k;
		my $l = scalar(@{ $my_json_ref });
		my $m;
		my $n;

		foreach $n (@streams) {
			SMIX0: foreach $j (@{ $n }) {
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

# handle (i.e., display) an array of tweets in standard format
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
# maybe an ma0-mz9?
				$tweet_counter = $mini_split;
				for(0..9) {
					undef $store_hash{"zz$_"};
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
			if ($filter_c && &$filter_c(&descape($j->{'text'}))) {
				$filtered++;
				next;
			}

			$wrapseq++;
			$key = (($is_background) ? '' : 'z' ).
				substr($alphabet, $tweet_counter/10, 1) .
				$tweet_counter % 10;
			$tweet_counter = 
				($tweet_counter == 259) ? $mini_split :
				($tweet_counter == ($mini_split - 1))
					? 0 : ($tweet_counter+1);
			$j->{'menu_select'} = $key;
			$store_hash{lc($key)} = $j;
			$printed += scalar(&$handle($j,
			($class || (($id <= $relative_last_id) ? 'again' :
				undef))));
		}
	}
	print $stdout "-- sorry, nothing to display.\n"
		if (($interactive || $verbose) && !$printed);
	return (&max(0+$my_json_ref->[0]->{'id'}, $last_id), $j);
}

# thump for DMs
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
	my $key;

	if ($disp_max) { # an empty list can be valid
		if ($dm_first_time) {
			print $stdout
			"-- checking for most recent direct messages:\n";
			$disp_max = 2;
			$interactive = 1;
		}
		for($i = $disp_max; $i > 0; $i--) {
			$g = ($i-1);
			my $j = $my_json_ref->[$g];
			next if ($j->{'id'} <= $last_dm);
			next if (!length($j->{'sender'}->{'screen_name'}));
			$wrapseq++;
			$key = substr($alphabet, $dm_counter/10, 1) .
				$dm_counter % 10;
			$dm_counter = 
				($dm_counter == 259) ? 0 :
				($dm_counter+1);
			$j->{'menu_select'} = $key;
			$dm_store_hash{lc($key)} = $j;
			$printed += scalar(&$dmhandle($j));
		}
		$max = 0+$my_json_ref->[0]->{'id'};
	}
	print $stdout "-- sorry, no new direct messages.\n"
		if (($interactive || $verbose) && !$printed && !$dm_first_time);
	$last_dm = &max($last_dm, $max);
	$dm_first_time = 0 if ($last_dm || !scalar(@{ $my_json_ref }));
	print $stdout "-- dm bookmark is $last_dm.\n" if ($verbose);
	&$dmconclude;
}	

# post an update
# this is a general API function that handles status updates and sending DMs.
sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $in_reply_to = shift;
	my $user_name_dm = shift;
	my $urle = '';
	my $i;
	my $subpid;
	my $istring;

	my $verb = (length($user_name_dm)) ? "DM $user_name_dm" : 'tweet';

	if ($anonymous) {
		print $stdout
		"-- sorry, you can't $verb if you're anonymous.\n"
			if ($interactive);
		return 99;
	}

	my $payload = (length($user_name_dm)) ? 'text' : 'status';
	$string = &$prepost($string) unless ($user_name_dm);

	# YES, you *can* verify and slowpost. I thought about this and I
	# think I want to allow it.
	if ($verify && !$status) {
		my $answer;

		warn &wwrap("-- verify you want to $verb: \"$string\"\n");
		print $stdout
			"-- send to server? (only y or Y is affirmative): ";
		chomp($answer = lc(<$stdin>));
		if ($answer ne 'y') {
			warn "-- ok, NOT sent to server.\n";
			return 97;
		}
	}

	$in_reply_to = ($in_reply_to > 0) ?
		"&in_reply_to_status_id=$in_reply_to" : '';
	$user_name_dm = (length($user_name_dm)) ?
		"&user=$user_name_dm" : '';

	# to avoid unpleasantness with UTF-8 interactions, this will simply
	# turn the whole thing into a hex string and insert %, thus URL
	# escaping the whole thing whether it needs it or not. ugly? well ...
	$istring = $string;
	eval 'utf8::encode($istring)' unless ($seven);
	$istring = unpack("H".(&ulength($istring)*2), $istring);
	for($i = 0; $i < length($istring); $i+=2) {
		$urle .= '%' . substr($istring, $i, 2);
	}
	#&update_authenticationheaders;

	my $i =
	"source=TTYtter&${payload}=${urle}${in_reply_to}${user_name_dm}";
	$slowpost += 0; if ($slowpost && !$script && !$status && !$silent) {
		if($pid = open(SLOWPOST, '-|')) {
			print $stdout &wwrap(
	"-- waiting $slowpost seconds to $verb, ^C cancels: \"$string\"\n");
			close(SLOWPOST); # this should wait for us
			if ($? > 256) {
				print $stdout
					"\n-- not sent, cancelled by user\n";
				return 97;
			}
			print $stdout "-- sending to server\n";
		} else {
			$in_backticks = 1; # defeat END sub
			$SIG{'BREAK'} = $SIG{'INT'} = sub {
				exit 254;
			};
			sleep $slowpost;
			exit 0;
		}
	}
	my $return = &backticks($baseagent, '/dev/null', undef,
		(length($user_name_dm)) ? $dmupdate : $update, $i, @wend);
	print $stdout "-- return --\n$return\n-- return --\n"
		if ($superverbose);
	if ($? > 0) {
		$x = $? >> 8;
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: connect timeout or no confirmation received ($x)
*** to attempt a resend, type %%${OFF}
EOF
		return $?;
	}
	my $ec;
	if ($ec = &is_json_error($return)) {
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: server error message received
*** "$ec"${OFF}
EOF
		return 98;
	}

	unless ($user_name_dm) {
		$lasttwit = $string;
		&$postpost($string);
	}
	return 0;
}

# this dispatch routine replaces the common logic of deletest, deletedm,
# follow, leave and the favourites system.
# this is a modified, abridged version of &updatest.
sub central_cd_dispatch {
	my ($payload, $interactive, $update) = (@_);
	#&update_authenticationheaders;
	my $return = &backticks($baseagent, '/dev/null', undef,
		$update, $payload, @wend);
	print $stdout "-- return --\n$return\n-- return --\n"
		if ($superverbose);
	if ($? > 0) {
		$x = $? >> 8;
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: connect timeout or no confirmation received ($x)
*** to attempt again, type %%${OFF}
EOF
		return ($?, '');
	}
	my $ec;
	if ($ec = &is_json_error($return)) {
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: server error message received
*** "$ec"${OFF}
EOF
		return (98, $return);
	}
	return (0, $return);
}

# delete a status
sub deletest {
	my $id = shift;
	my $interactive = shift;

	my $update = "${delurl}/${id}.json";
	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $update);
	print $stdout "-- tweet id #${id} has been removed\n"
		if ($interactive && !$en);
#TODO
# getting this even with success
# looks like this is a Twitter bug
	print $stdout "*** (was the tweet already deleted?)\n"
		if ($interactive && $en);
	return 0;
}

# delete a DM
sub deletedm {
	my $id = shift;
	my $interactive = shift;

	my $update = "${dmdelurl}/${id}.json";
	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $update);
	print $stdout "-- DM id #${id} has been removed\n"
		if ($interactive && !$en);
	print $stdout "*** (was the DM already deleted?)\n"
		if ($interactive && $en);
	return 0;
}

# create or destroy a favourite
sub cordfav {
	my $id = shift;
	my $interactive = shift;
	my $basefav = shift;
	my $text = shift;
	my $verb = shift;

	my $update = "${basefav}/${id}.json";
	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $update);
	print $stdout "-- favourite $verb for tweet id #${id}: \"$text\"\n"
		if ($interactive && !$en);
	print $stdout "*** (was the favourite already ${verb}?)\n"
		if ($interactive && $en);
	return 0;
}

# follow or unfollow a user
sub foruuser {
	my $uname = shift;
	my $interactive = shift;
	my $basef = shift;
	my $verb = shift;

	my $update = "${basef}/${uname}.json?screen_name=${uname}";
	my ($en, $em) = &central_cd_dispatch("screen_name=$uname",
		$interactive, $update);
	print $stdout "-- ok, you have $verb following user $uname.\n"
		if ($interactive && !$en);
	return 0;
}

#### TTYtter internal API utility functions ####
# ... which your API can call

# use time locale information if available
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

# format a tweet based on user options
sub standardtweet {
	my $ref = shift;
	my $nocolour = shift;

	my $sn = &descape($ref->{'user'}->{'screen_name'});
	my $tweet = &descape($ref->{'text'});
	my $colour;
	my $g;
	my $h;

	# wordwrap really ruins our day here, thanks a lot, @augmentedfourth
	# have to insinuate the ansi sequences after the string is wordwrapped

	$g = $colour = ${'CC' . scalar(&$tweettype($ref, $sn, $tweet)) }
		unless ($nocolour);
	$colour = $OFF . $colour
		unless ($nocolour);

	$sn = "\@$sn" if ($ref->{'in_reply_to_status_id'} > 0);
	$sn = "*$sn" if ($ref->{'source'} =~ /TTYtter/ && $ttytteristas);
	$tweet = "${menu_select}<$sn> $tweet";
	# br3nda's modified timestamp patch
	if ($timestamp) {
		my ($time, $ts) = &wraptime($ref->{'created_at'});
		$tweet = "[$ts] $tweet";
	}
	
	# pull it all together
	$tweet = &wwrap($tweet, ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0)
		if ($wrap); # remember to account for prompt length on #1
	$tweet =~ s/^([^<]*)<([^>]+)>/${g}\1<${EM}\2${colour}>/
		unless ($nocolour);
	$tweet =~ s/\n*$//;
	$tweet .= ($nocolour) ? "\n" : "$OFF\n";

	# highlight anything that we have in track
	if(scalar(@tracktags)) { # I'm paranoid
		foreach $h (@tracktags) {
			$h =~ s/^"//; $h =~ s/"$//; # just in case
$tweet =~ s/(^|[^a-zA-Z0-9])($h)([^a-zA-Z0-9]|$)/\1${EM}\2${colour}\3/ig
			unless ($nocolour);
		}
	}

	# smb's underline/bold patch goes on last (modified for lists)
	$tweet =~
	s/(^|[^a-zA-Z0-9_])\@([a-zA-Z0-9_\-\/]+)/\1\@${UNDER}\2${colour}/g
		unless ($nocolour);

	return $tweet;
}

# format a DM based on standard user options
sub standarddm {
	my $ref = shift;
	my $nocolour = shift;

	my ($time, $ts) = &wraptime($ref->{'created_at'});
	my $text = &descape($ref->{'text'});
	my $g = &wwrap("[DM d$ref->{'menu_select'}][".
		&descape($ref->{'sender'}->{'screen_name'}) .
		"/$ts] $text", ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0);

	$g =~ s/^\[DM ([^\/]+)\//${CCdm}[DM ${EM}\1${OFF}${CCdm}\//
		unless ($nocolour);
	$g =~ s/\n*$//;
	$g .= ($nocolour) ? "\n" : "$OFF\n";
	$g =~ s/(^|[^a-zA-Z0-9_])\@(\w+)/\1\@${UNDER}\2${OFF}${CCdm}/g
		unless ($nocolour);
	return $g;
}

# for future expansion: this is the declared API callable method
# for executing a command as if the console had typed it.
sub ucommand {
	die("** can't call &ucommand during multi-module loading.\n")
		if ($multi_module_mode == -1);
	&prinput(@_);
}

# your application can also call &grabjson to get a hashref
# corresponding to parsed JSON from an arbitrary resource.
# see that function later on.


#### DEFAULT TTYtter INTERNAL API METHODS ####
# don't change these here. instead, use -lib=yourlibrary.pl and set them there.
# note that these are all anonymous subroutine references.
# anything you don't define is overwritten by the defaults.
# it's better'n'superclasses.
# NOTE: defaultaddaction, defaultmain and defaultprompt
# are all defined in the "console" section above for
# clarity.

# this first set are the multi-module aware ones.

# the standard iterator for multi-module methods
sub multi_module_dispatch {
	my $default = shift;
	my $dispatch_chain = shift;
	my $rv_handler = shift;
	my @args = @_;

	my $dispatch_ref;
	# $*_call_default is a global
	$did_call_default = 0;
	$this_call_default = 0;
	$multi_module_context = 0;

	if ($rv_handler == 0) {
		$rv_handler = sub {
			return 0;
		};
	}

	# fall through to default if no dispatch chain
	if (!scalar(@{ $dispatch_chain })) {
		return &$default(@args);
	}
	foreach $dispatch_ref (@{ $dispatch_chain }) {
		# each reference has the code, and the file that specified it.
		# set up a multi-module context and run that function. if the
		# default ever gets called, we log it to tell the multi-module
		# handler to call the default at the end.

		my $rv;
		my $irv;
		my $caller = (caller(1))[3];
		$caller =~ s/^main::multi//;

		$multi_module_context = 1; # defaults then know to defer
		$this_call_default = 0;
		$store = $master_store->{ $dispatch_ref->[0] };
		print "-- calling \$$caller in $dispatch_ref->[0]\n"
			if ($verbose);
		my $code_ref = $dispatch_ref->[1];
		$rv = &$rv_handler(@irv = &$code_ref(@args));
		$multi_module_context = 0;
		if ($rv & 4) {
			# rv_handler indicating to call default and halt
			# if it was called.
			return &$default(@args) if ($did_call_default);
		}
		if ($rv & 2) {
			# rv_handler indicating to make new @args from @irv
			@args = @irv;
		}
		if ($rv & 1) {
			# rv_handler indicating to halt early. do so.
			return (wantarray) ? @irv : $irv[0];
		}
	}
	$multi_module_context = 0;
	return &$default(@args) if ($did_call_default);
	return (wantarray) ? @irv : $irv[0];
}
		
# these are the stubs that call the dispatcher.
sub multiaddaction {
	&multi_module_dispatch(\&defaultaddaction, \@m_addaction, sub{
		# return immediately on the first extension to accept
		return (shift>0);
	}, @_);
}
sub multiconclude {
	&multi_module_dispatch(\&defaultconclude, \@m_conclude, 0, @_);
}
sub multidmconclude {
	&multi_module_dispatch(\&defaultdmconclude, \@m_dmconclude, 0, @_);
}
#handlr
sub multidmhandle {
	&multi_module_dispatch(\&defaultdmhandle, \@m_dmhandle, sub {
		my $rv = shift;

		# skip default calls.
		return 0 if ($this_call_default);

		# if not a default call, and the DM was refused for
		# processing by this extension, then the DM is now
		# suppressed. do not call any other extensions after this.
		# even if it ends in suppression, we still call the default
		# if it was ever called before.
		return 5 if ($rv == 0);

		# if accepted in any manner, keep calling.
		return 0;
	}, @_);
}
sub multiexception {
	# this is a secret option for people who want to suppress errors.
	if ($exception_is_maskable) {
		&multi_module_dispatch(\&defaultexception, \@m_exception, sub {
			my $rv = shift;

			# same logic as handle/dmhandle, except return -1-
			# to mask from subsequent extensions.
			return 0 if ($this_call_default);
			return 5 if ($rv);
			return 0;
		}, @_);
	} else {
		&multi_module_dispatch(
			\&defaultexception, \@m_exception, 0, @_);
	}
}
sub multihandle {
	&multi_module_dispatch(\&defaulthandle, \@m_handle, sub {
		my $rv = shift;

		# skip default calls.
		return 0 if ($this_call_default);

		# if not a default call, and the tweet was refused for
		# processing by this extension, then the tweet is now
		# suppressed. do not call any other extensions after this.
		# even if it ends in suppression, we still call the default
		# if it was ever called before.
		return 5 if ($rv==0);

		# if accepted in any manner, keep calling.
		return 0;
	}, @_);
}
sub multiheartbeat {
	&multi_module_dispatch(\&defaultheartbeat, \@m_heartbeat, 0, @_);
}
sub multiprecommand {
	&multi_module_dispatch(\&defaultprecommand, \@m_precommand, sub {
		return 2; # feed subsequent chains the result.
	}, @_);
}
sub multiprepost {
	&multi_module_dispatch(\&defaultprepost, \@m_prepost, sub {
		return 2; # feed subsequent chains the result.
	}, @_);
}
sub multipostpost {
	&multi_module_dispatch(\&defaultpostpost, \@m_postpost, 0, @_);
}
sub multitweettype {
	&multi_module_dispatch(\&defaulttweettype, \@m_tweettype, sub {
		# if this module DID NOT call default, exit now.
		return (!$this_call_default);
	}, @_);
}

sub flag_default_call { $this_call_default++; $did_call_default++; }

# now the actual default methods

sub defaultexception {
	(&flag_default_call, return) if ($multi_module_context);
	shift;
	print $stdout "${MAGENTA}@_${OFF}";
	$laststatus = 1;
}
sub defaulthandle {
	(&flag_default_call, return) if ($multi_module_context);
	my $tweet_ref = shift;
	my $class = shift;
	my $dclass = ($verbose) ? "{$class,$tweet_ref->{'id'}} " :  '';
	my $sn = &descape($tweet_ref->{'user'}->{'screen_name'});
	my $tweet = &descape($tweet_ref->{'text'});
	my $stweet = &standardtweet($tweet_ref);
	my $menu_select = $tweet_ref->{'menu_select'};

	$menu_select = (length($menu_select) && !$script)
		? "${menu_select}> " : '';

	print $streamout $menu_select . $dclass . $stweet;
	unless (length($class) || !$last_id) { # interactive? first time?
		$class = scalar(&$tweettype($tweet_ref, $sn, $tweet));
		&$notifytype($class, &standardtweet($tweet_ref, 1), $tweet_ref)
			if ($notify_list{$class} && $notifytype);
	}
	return 1;
}

sub defaulttweettype {
	(&flag_default_call, return) if ($multi_module_context);
	my $ref = shift;
	my $sn = shift;
	my $tweet = shift;

	# br3nda's and smb's modified colour patch
	unless ($anonymous) {
		if ($sn eq $whoami) {
			# if it's me speaking, colour the line yellow
			return 'me';
		} elsif ($tweet =~ /\@$whoami(\b|$)/i) {
			# if I'm in the tweet, colour red
			return 'reply';
		} 
	}
	if ($ref->{'class'} eq 'search') { # anonymous allows this too
		# if this is a search result, colour cyan
		return 'search';
	}
	return 'default';
}

sub defaultconclude {
	(&flag_default_call, return) if ($multi_module_context);
	if ($filtered && $filter_attribs{'count'}) {
		print $stdout "-- (filtered $filtered tweets)\n";
		$filtered = 0;
	}
}

sub defaultdmhandle {
	(&flag_default_call, return) if ($multi_module_context);
	my $dm_ref = shift;
	print $streamout &standarddm($dm_ref);
	&$notifytype('DM', &standarddm($dm_ref, 1), $dm_ref)
		if ($notify_list{'dm'} && $last_dm && $notifytype);
	return 1;
}

sub defaultdmconclude {
	(&flag_default_call, return) if ($multi_module_context);
}

sub defaultheartbeat {
	(&flag_default_call, return) if ($multi_module_context);
}

# not much sense to multi-module protect these.
sub defaultprecommand { return ("@_"); }
sub defaultprepost { return ("@_"); }

sub defaultpostpost {
	(&flag_default_call, return) if ($multi_module_context);
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
			'/reply', '/url', '/thread',
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
	if ($text =~ m#https?://#) {
		return (&urlshorten($text) || $text);
	}

	# "I got nothing."
	return ();
}
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
	return ($lynx) ? ("-auth=$whoami:$pass") :
		($curl) ? ("-u", "$whoami:$pass") : # no --basic now (ktj)
		die("authenticating for an unknown browser: wtf\n");
}

#### built-in notification routines ####

# growl for Mac OS X
sub notifier_growl {
	my $class = shift;
	my $text = shift;
	my $ref = shift; # not used in this version

	if (!defined($class) || !defined($growl_notify_path)) {
		# we are being asked to initialize
		$growl_notify_path = &wherecheck("trying to find growlnotify",
			"growlnotify",
"growlnotify must be installed to use growl notifications. check your\n" .
			"documentation for how to do this.\n");
		if (!defined($class)) {
			return 1 if ($script);
			$class = 'Growl support activated';
			$text = 
'You can configure notifications for TTYtter in the Growl preference pane.';
		}
	}
	open(GROWL, "|$growl_notify_path -n 'TTYtter' 'TTYtter: $class'");
	binmode(GROWL, ":utf8") unless ($seven);
	print GROWL $text;
	close(GROWL);
	return 1;
}

# libnotify for {Linux,whatevs}
# this is EXPERIMENTAL, and requires this patch to notify-send:
# http://trac.galago-project.org/ticket/147
# why it has not already been applied is fricking beyond me, it makes
# sense. would YOU want arbitrary characters on the command line
# separated only from overwriting your home directory by a quoting routine?
sub notifier_libnotify {
	my $class = shift;
	my $text = shift;
	my $ref = shift; # not used in this version

	if (!defined($class) || !defined($notify_send_path)) {
		# we are being asked to initialize
		$notify_send_path = &wherecheck("trying to find notify-send",
			"notify-send",
"notify-send must be installed to use libnotify, and it must be modified\n".
"for standard input. see the documentation for how to do this.\n");
		if (!defined($class)) {
			return 1 if ($script);
			$class = 'libnotify support activated';
			$text =
'Congratulations, your notify-send is correctly configured for TTYtter.';
		}
	}
	# figure out the time to display based on length of tweet
	my $t = 1000+50*length($text); # about 150-180wpm read speed
	open(NOTIFYSEND,
		"|$notify_send_path -t $t -f - 'TTYtter: $class'");
	binmode(NOTIFYSEND, ":utf8") unless ($seven);
	print NOTIFYSEND $text;
	close(NOTIFYSEND);
	return 1;
}

#### IPC routines for communicating between the foreground + background ####

# this is the central routine that takes a rolling tweet code, figures
# out where that tweet is, and returns something approximating a tweet
# structure (or the actual tweet structure itself if it can).
sub get_tweet {
	my $code = lc(shift);
	return undef if ($code !~ /^z?[a-z][0-9]$/);
	my $source = ($code =~ /^z/) ? 1 : 0;
	my $k = '';
	my $l = '';
	my $w = {'user' => {}};

	if ($is_background) {
		if ($source == 1) { # foreground only
			return undef;
		}
		return $store_hash{$code};
	}
	return $store_hash{$code} if ($source); # foreground c/foreground twt

	print C "pipet $code ----------\n";
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	return undef if ($k !~ /[^\s]/);
	$k =~ s/\s+$//; # remove trailing spaces
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	($w->{'menu_select'}, $w->{'id'}, $w->{'in_reply_to_status_id'},
		$w->{'retweeted_status'}->{'id'},
		$w->{'user'}->{'geo_enabled'},
		$w->{'geo'}->{'coordinates'}->[0],
		$w->{'geo'}->{'coordinates'}->[1],
		$w->{'user'}->{'screen_name'}, $w->{'created_at'},
			$l) = split(/\s/, $k, 10);
	($w->{'source'}, $w->{'text'}) = split(/\|/, $l, 2);
	return undef if (!length($w->{'text'})); # not possible
	$w->{'created_at'} =~ s/_/ /g;
	return $w;
}


# this is the analogous function for a rolling DM code. it is somewhat
# simpler as DM codes are always rolling and have no foreground store
# currently, so it always executes a background request.
sub get_dm {
	my $code = lc(shift);
	my $k = '';
	my $l = '';
	my $w = {'sender' => {}};

	return undef if (length($code) != 3 || $code !~ s/^d// ||
				$code !~ /^[a-z][0-9]$/);
	print C "piped $code ----------\n"; # internally two alphanum, recall
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	return undef if ($k !~ /[^\s]/);
	$k =~ s/\s+$//; # remove trailing spaces
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	($w->{'menu_select'}, $w->{'id'},
		$w->{'sender'}->{'screen_name'}, $w->{'created_at'},
			$w->{'text'}) = split(/\s/, $k, 5);
	return undef if (!length($w->{'text'})); # not possible
	$w->{'created_at'} =~ s/_/ /g;
	return $w;
}


sub thump { print C "update-------------\n"; &sync_semaphore; }
sub dmthump { print C "dmthump------------\n"; &sync_semaphore; }

sub sync_n_quit {
	if ($child) {
		print $stdout "waiting for child ...\n" unless ($silent);
		print C "sync---------------\n";
		waitpid $child, 0;
		$child = 0;
		print $stdout "exiting.\n" unless ($silent);
		exit ($? >> 8);
	}
	exit;
}

sub synckey {
	my $key = shift;
	my $value = shift;
	print $stdout "*** (transmitting to background)\n";
	print C (substr("=$key                           ", 0, 19) . "\n");
	print C (substr(($value . $space_pad), 0, 1024));
	sleep 1;
}

#### url management (/url, /short) ####

sub generate_shortdomain {
	my $x;
	my $y;

	undef $shorturldomain;
	($shorturl =~ m#^http://([^/]+)/#) && ($x = $1);
	# chop off any leading hostname stuff (like api., etc.)
	while(1) {
		$y = $x;
		$x =~ s/^[^\.]*\.//;
		if ($x !~ /\./) { # a cut too far
			$shorturldomain = "http://$y/";
			last;
		}
	}
	print $stdout "-- warning: couldn't parse shortener service\n"
		if (!length($shorturldomain));
}

sub openurl {
	my $comm = $urlopen;
	my $url = shift;
	$urlshort = $url;
	$comm =~ s/\%U/'$url'/g;
	print $stdout "($comm)\n";
	system("$comm");
}

sub urlshorten {
	my $url = shift;
	my $rc;
	my $cl;

	return $url if ($url =~ /^$shorturldomain/i); # stop loops
	$cl = "$simple_agent \"${shorturl}$url\"";
	print $stdout "$cl\n" if ($superverbose);
	chomp($rc = `$cl`);
	return ($urlshort = (($rc =~ m#^http://#) ? $rc : undef));
}

##### optimizers -- these compile into an internal format #####

# utility routine for tquery support
sub tracktags_tqueryurlify {
	my $value = shift;
	$value =~ s/([^ a-z0-9A-Z_])/"%".unpack("H2",$1)/eg;
	$value =~ s/\s/+/g;
	$value = "q=$value" if ($value !~ /^q=/);
	return $value;
}

# tracking subroutines
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
	&tracktags_compile;
}	
# run when array is altered (based on @kellyterryjones' code)
sub tracktags_compile {
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

# notifications compiler
sub notify_compile {
	if ($notifies) {
		my $w;

		undef %notify_list;
		foreach $w (split(/,/, $notifies)) {
			$notify_list{$w} = 1;
		}
	}
}

# filter compiler
sub filter_compile {
	undef %filter_attribs;
	undef $filter_c;
	if ($filter) {
		$filter =~ s/^['"]//;
		$filter =~ s/['"]$//;
		# note attributes
		$filter_attribs{$1}++ while ($filter =~ s/^([a-z]+),//);
		my $b = <<"EOF";
		\$filter_c = sub {
			local \$_ = shift;
			return ($filter);
		};
EOF
		#print $b;
		eval $b;
		if (!defined($filter_c)) {
			print $stdout ("** syntax error in your filter: $@\n");
			return 0;
		}
	}
	return 1;
}

#### common system subroutines follow ####

sub updatecheck {
	my $vcheck_url =
		"http://www.floodgap.com/software/ttytter/01current.txt";
	my $vs;
	my $tverify;
	my $inversion;
	my $bversion;
	my $rcnum;
	my $download;
	my $maj;
	my $min;
	my $s1, $s2, $s3;

	print $stdout "-- checking version at $vcheck_url\n";
	$vs = `$simple_agent $vcheck_url`;
	($vs, $s1, $s2, $s3) = split(/--__--\n/s, $vs);
	$s1 = undef if ($s1 !~ /^\*/) ;
	$s2 = undef if ($s2 !~ /^\*/) ;
	$s3 = undef if ($s3 !~ /^\*/) ;
	chomp($vs);
	($tverify, $inversion, $bversion, $rcnum, $download, $bdownload) =
		split(/;/, $vs, 6);
	if ($tverify ne 'ttytter') {
		$vs = "-- warning: unable to verify version\n";
	} else {
		if ($my_version_string eq $bversion) {
			$vs =
"** REMINDER: you are using a beta version (${my_version_string}b${TTYtter_RC_NUMBER})\n";
			$vs .=
"** NEW RELEASE CANDIDATE AVAILABLE: build $rcnum **\n" .
"** get it: $bdownload\n$s2"
			if ($TTYtter_RC_NUMBER < $rcnum);
			$vs .= "** (this is the most current beta)\n"
				if ($TTYtter_RC_NUMBER == $rcnum);
			$vs .= "$s1$s3";
			return $vs;
		}
		if ($my_version_string eq $inversion && $TTYtter_RC_NUMBER) {
			$vs =
"** FINAL RELEASE NOW AVAILABLE for version $inversion **\n" .
"** get it: $download\n$s2$s1";
			return $vs;
		}
		($inversion =~/^(\d+\.\d+)\.(\d+)$/) && ($maj = 0+$1,
			$min = 0+$2);
		if (0+$TTYtter_VERSION < $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION < $min)) {
			$vs =
	"** NEWER TTYtter VERSION NOW AVAILABLE: $inversion **\n" .
	"** get it: $download\n$s2$s1";
		} elsif (0+$TTYtter_VERSION > $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION > $min)) {
			$vs = 
	"** unable to identify your version of TTYtter\n$s1";
		} else {
			$vs =
	"-- your version of TTYtter is up to date ($inversion)\n$s1";
		}
	}
	return $vs;
}

sub end_me { exit; } # which falls through to ...
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
	#exit;
}

sub generate_ansi {
	my $k;

	$BLUE = ($ansi) ? "${ESC}[34;1m" : '';
	$RED = ($ansi) ? "${ESC}[31;1m" : '';
	$GREEN = ($ansi) ? "${ESC}[32;1m" : '';
	$YELLOW = ($ansi) ? "${ESC}[33m" : '';
	$MAGENTA = ($ansi) ? "${ESC}[35m" : '';
	$CYAN = ($ansi) ? "${ESC}[36m" : '';

	$EM = ($ansi) ? "${ESC}[1m" : '';
	$UNDER = ($ansi) ? "${ESC}[4m" : '';
	$OFF = ($ansi) ? "${ESC}[0m" : '';

	foreach $k (qw(prompt me dm reply warn search default)) {
		${"colour$k"} = uc(${"colour$k"});
		if (!defined($${"colour$k"})) {
			print $stdout
		"-- warning: bogus colour '".${"colour$k"}."'\n";
		} else {
			eval("\$CC$k = \$".${"colour$k"});
		}
	}
}


# authenticate sets $whoami, sphincter says $what
sub update_authenticationheaders {
#TODO
# needs to stop asking for password all the damn time when not given
	(@auth) = ($anonymous) ? "" : &$authenticate;
	if ($lynx) {
		$simple_agent = "$baseagent -nostatus -source";

		@wend = ('-nostatus');
		@weld = (@wend, '-source');
		@wend = (@wend, @auth);
		@wand = (@wend, '-source');
		@wind = (@wand);
		@wend = (@wend, '-post_data');
		$stringify_args = sub {
			my $basecom = shift;
			my $resource = shift;
			my $data = shift;
			my @k = join("\n", @_);

			$basecom = "$basecom \"$resource\" -";
			return ($basecom, "@k", $data);
		};
	} else {
		$simple_agent = "$baseagent -s -m 13";

		@wend = ('-s', '-m', '13', '-H', 'Expect:');
		@weld = @wend;
		@wend = (@wend, @auth);
		@wand = (@wend);
		@wind = @wend;
		$stringify_args = sub {
			my $basecom = shift;
			my $resource = shift;
			my $data = shift;
			my $p;
			my $l = '';

			foreach $p (@_) {
				if ($p =~ /^-/) {
					$l .= "\n" if (length($l));
					$l .= "$p ";
					next;
				}
				$l .= $p;
			}
			$l .= "\nurl = \"$resource\"\n";
			$l .= "data = \"$data\"\n" if length($data);
			return ("$basecom -K -", $l, undef);
		};
	}
}


sub grabjson {
	my $data;
	my $url = shift;
	my $last_id = shift;
	my @agent = (shift) ? @weld : @wand;
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
	my @cargs = ($baseagent,
			'/dev/null', undef, "$url$xurl", undef, @agent);
	chomp($data = &backticks(@cargs));
	my $k = $? >> 8;

	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;
	#print unpack("H90", $data);

	if (!length($data) || $k == 28 || $k == 7 || $k == 35) {
		&$exception(1, "*** warning: timeout or no data\n");
		return undef;
	}

	# old non-JSON based error reporting code still supported
	if ($data =~ /^\[?\]?<!DOCTYPE\s+html/i || $data =~ /^(Status:\s*)?50[0-9]\s/ || $data =~ /^<html>/i || $data =~ /^<\??xml\s+/) {
		print $stdout $data if ($superverbose);
		if (&is_fail_whale($data)) {
			&$exception(2, "*** warning: Twitter Fail Whale\n");
		} else {
		&$exception(2, "*** warning: Twitter error message received\n" .
			(($data =~ /<title>Twitter:\s*([^<]+)</) ?
				"*** \"$1\"\n" : ''));
		}
		return undef;
	}
	if ($data =~ /^rate\s*limit/i) {
		print $stdout $data if ($superverbose);
		&$exception(3,
"*** warning: exceeded API rate limit for this interval.\n" .
"*** no updates available until interval ends.\n");
		return undef;
	}

	if ($k > 0) {
		&$exception(4,
"*** warning: unexpected error code ($k) from user agent\n");
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
"*** warning: unexpected HTTP return code $code from server\n");
		return undef;
	}

# process the JSON data ... simplemindedly, because I just write utter crap,
# am not a professional programmer, and don't give a flying fig whether
# kludges suck or no.

	# test for error/warning conditions with trivial case
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1/s
		|| $data =~ /(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1\}/s) {
		print $stdout $data if ($superverbose);
		&$exception(2, "*** warning: server $2 message received\n" .
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
	# first, generate a syntax tree.
	$tdata = $data;
	1 while $tdata =~ s/'[^']+'//;
	$tdata =~ s/-?[0-9]+\.?[0-9]*([eE][+-][0-9]+)?//g;
		# have to handle floats *and* their exponents
	$tdata =~ s/(true|false|null)//g;
	$tdata =~ s/\s//g;

	print $stdout "$tdata\n" if ($superverbose);

	# now verify the syntax tree.
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
# it seems that :[], or :[]} should be accepted as valid in the syntax tree
# since identica uses this as possible for null properties
# ,[], shouldn't be, etc.
		if ($tdata =~ /(^|[^:])\[\]($|[^},])/) { # oddity
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
	($data =~ s/([^'])'\s*:\s*(true|false|null|\'|\{|\[|-?[0-9])/\1\',\2/);

	# finally, single quotes, just before interpretation.
	$data =~ s/$ssqqmask/\\'/g;

	# now somewhat validated, so safe (?) to eval() into a Perl struct
	eval "\$my_json_ref = $data;";
	print $stdout "$data => $my_json_ref $@\n"  if ($superverbose);

	# do a sanity check
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!defined($my_json_ref));


	# normalize the data into a standard form. what this currently does
	# is the following gyrations:
	# - if the source of this JSON data source is the Search API, translate
	#   its fields into the standard API.
	# - if the tweet is an newRT, unwrap it so that the full tweet text is
	#   revealed (unless -nonewrts).
	# - if this appears to be a tweet, put in a stub geo hash if one does
	#   not yet exist.
	# one day I would like this code to go the hell away.
	if (defined($my_json_ref) && ref($my_json_ref) eq 'ARRAY') {
		my $i;
		my $rt;

		foreach $i (@{ $my_json_ref }) {
			# normalize geo. if this has a source and it has a
			# favorited, then it is probably a tweet and we will
			# add a stub geo hash if one doesn't exist yet.
			if ($kludge_search_api_adjust || 
					($i->{'favorited'} && $i->{'source'})){
				$i = &fix_geo_api_data($i);
			}

			# normalize Search
			if ($kludge_search_api_adjust) {
				# hopefully this hack can die with API v2.
				$i->{'class'} = "search";
				$i->{'user'}->{'screen_name'} =
					$i->{'from_user'};
				# translate time stamps
				# Fri Mar 20 13:18:18 +0000 2009 (twitter) vs
				# Fri, 20 Mar 2009 16:35:56 +0000 (search)
				$i->{'created_at'} =~
	s/(...), (..) (...) (....) (..:..:..) (.....)/\1 \3 \2 \5 \6 \4/;
			}

			# normalize newRTs
			# if we get newRTs with -nonewrts, oh well
			if (!$nonewrts && ($rt = $i->{'retweeted_status'})) {
				# reconstruct the RT in a "canonical" format
				# without truncation
				$i->{'text'} =
		"RT \@$rt->{'user'}->{'screen_name'}" . ': ' . $rt->{'text'};
			}
		}
	}

	$laststatus = 0;
	return $my_json_ref;
}

sub fix_geo_api_data {
	my $ref = shift;
	$ref->{'geo'}->{'coordinates'} ||= [ "undef", "undef" ];
	return $ref;
}

sub is_fail_whale {
	# is this actually the dump from a fail whale?
	my $data = shift;
	return ($data =~ m#<title>Twitter.+Over.+capacity.*</title>#i);
}

sub is_json_error {
	# is this actually a JSON error message? if so, extract it
	my $data = shift;
	if ($data =~ /(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1\}/s) {
		return $3;
	}
	return undef;
}

sub backticks {
	# more efficient/flexible backticks system
	my $comm = shift;
	my $rerr = shift;
	my $rout = shift;
	my $resource = shift;
	my $data = shift;
	my $buf = '';
	my $undersave = $_;
	my $pid;

	($comm, $args, $data) = &$stringify_args($comm, $resource, $data, @_);
	print $stdout "$comm\n$args\n$data\n" if ($superverbose);
	if(open(BACTIX, '-|')) {
		while(<BACTIX>) {
			$buf .= $_;
		} close(BACTIX);
		$_ = $undersave;
		return $buf; # and $? is still in $?
	} else {
		$in_backticks = 1;
		if (length($rerr)) {
			close(STDERR); 
			open(STDERR, ">$rerr");
		}
		if (length($rout)) {
			close(STDOUT);
			open(STDOUT, ">$rout");
		}
		if(open(FRONTIX, "|$comm")) {
			print FRONTIX "$args\n";
			print FRONTIX "$data" if (length($data));
			close(FRONTIX);
		} else {
			die(
			"backticks() failure for $comm $rerr $rout @_: $!\n");
		}
		$rv = $? >> 8;
		exit $rv;
	}
}

sub wherecheck {
	my ($prompt, $filename, $fatal) = (@_);
	my (@paths) = split(/\:/, $ENV{'PATH'});
	my $setv = '';

	unshift(@paths, '/usr/bin'); # the usual place
	@paths = ('') if ($filename =~ m#^/#); # for absolute paths

	print $stdout "$prompt ... " unless ($silent);
	foreach(@paths) {
		if (-r "$_/$filename") {
			$setv = "$_/$filename";
			1 while $setv =~ s#//#/#;
			print $stdout "$setv\n" unless ($silent);
			last;
		}
	}
	if (!length($setv)) {
		print $stdout "not found.\n";
		if ($fatal) {
			print $stdout $fatal;
			exit(1);
		}
	}
	return $setv;
}

sub screech {
	print $stdout "\n\n${BEL}${BEL}@_";
	if ($is_background) {
		kill 9, $parent;
		kill 9, $$;
	} elsif ($child) {
		kill 9, $child;
		kill 9, $$;
	}
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
		$x =~ s/\\u2028/\\n/g;
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
	$buf =~ s/[ \t]+$//;
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

# take a string and return up to 140 CHARS plus the rest.
sub csplit { return &cosplit(@_, sub { return   length(shift); }); }
# take a string and return up to 140 BYTES plus the rest.
sub usplit { return &cosplit(@_, sub { return &ulength(shift); }); }
sub cosplit {
	# this is the common code for &csplit and &usplit.
	# this is tricky because we don't want to split up UTF-8 sequences, so
        # we let Perl do the work since it internally knows where they end.
	my $orig_k = shift;
	my $mode = shift;
	my $lengthsub = shift;
	my $z;
	my @m;
	my $q;
	my $r;

	$mode += 0;
	$k = $orig_k;

	# optimize whitespace
	$k =~ s/^\s+//;
	$k =~ s/\s+$//;
	$k =~ s/\s+/ /g;
	$z = &$lengthsub($k);
	return ($k) if ($z <= 140); # also handles the trivial case

	# this needs to be reply-aware, so we put @'s at the beginning of
	# the second half too (and also Ds for DMs)
	$r .= $1 if ($k =~ s/^(\@[^\s]+\s)\s*// ||
			$k =~ s/^(D\s+[^\s]+\s)\s*//);  # not while -- just one
	$k = "$r$k";

	my $i = 140;
	$i-- while(($z = &$lengthsub($q = substr($k, 0, $i))) > 140);
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
		return (&cosplit($orig_k, 1, $lengthsub))
			if (!length($q) && !$mode);
			# it totally failed. fall back on charsplit.
		if (&$lengthsub($q) < 140) {
			$m =~ s/^\s+//;
			return($q, "$r$m")
		}
	}
	($q =~ s/\s+([^\s]+)$//) && ($m = "$1$m");
	return (&cosplit($orig_k, 1, $lengthsub)) if (!length($q) && !$mode);
		# it totally failed. fall back on charsplit.
	return ($q, "$r$m");
}

