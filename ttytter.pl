#!/usr/bin/perl -s
#########################################################################
#
# TTYtter v2.1 (c)2007-2012 cameron kaiser (and contributors).
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
	# dynamically changing PERL_SIGNALS doesn't work in Perl 5.14+ (bug
	# 92246). we deal with this by forcing -signals_use_posix if the
	# environment variable wasn't already set.
	if ($] >= 5.014000 && $ENV{'PERL_SIGNALS'} ne 'unsafe') {
		$signals_use_posix = 1;
	} else {
		$ENV{'PERL_SIGNALS'} = 'unsafe';
	}
	
	$command_line = $0; $0 = "TTYtter";
	$TTYtter_VERSION = "2.1";
	$TTYtter_PATCH_VERSION = 0;
	$TTYtter_RC_NUMBER = 0; # non-zero for release candidate
	# this is kludgy, yes.
	$LANG = $ENV{'LANG'} || $ENV{'GDM_LANG'} || $ENV{'LC_CTYPE'} ||
			$ENV{'ALL'};
	$my_version_string = "${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}";
	(warn ("$my_version_string\n"), exit) if ($version);

	$space_pad = " " x 1024;
	$background_is_ready = 0;

	# for multi-module extension handling
	$multi_module_mode = 0;
	$multi_module_context = 0;
	$muffle_server_messages = 0;
	undef $master_store;
	undef %push_stack;

	$padded_patch_version = substr($TTYtter_PATCH_VERSION . " ", 0, 2);

	%opts_boolean = map { $_ => 1 } qw(
		ansi noansi verbose superverbose ttytteristas noprompt
		seven silent hold daemon script anonymous readline ssl
		newline vcheck verify noratelimit notrack nonewrts notimeline
		synch exception_is_maskable mentions simplestart
		location readlinerepaint nocounter notifyquiet
		signals_use_posix dostream nostreamreplies streamallreplies
		nofilter
	); %opts_sync = map { $_ => 1 } qw(
		ansi pause dmpause ttytteristas verbose superverbose
		url rlurl dmurl newline wrap notimeline lists dmidurl
		queryurl track colourprompt colourme notrack
		colourdm colourreply colourwarn coloursearch colourlist idurl
		notifies filter colourdefault backload searchhits dmsenturl
		nostreamreplies mentions wtrendurl atrendurl filterusers
		filterats filterrts filteratonly filterflags nofilter
	); %opts_urls = map {$_ => 1} qw(
		url dmurl uurl rurl wurl frurl rlurl update shorturl
		apibase queryurl idurl delurl dmdelurl favsurl
		favurl favdelurl followurl leaveurl
		dmupdate credurl blockurl blockdelurl friendsurl
		modifyliurl adduliurl delliurl getliurl getlisurl getfliurl
		creliurl delliurl deluliurl crefliurl delfliurl
		getuliurl getufliurl dmsenturl rturl rtsbyurl dmidurl
		statusliurl followliurl leaveliurl followersurl
		oauthurl oauthauthurl oauthaccurl oauthbase wtrendurl
		atrendurl frupdurl lookupidurl rtsofmeurl
	); %opts_secret = map { $_ => 1} qw(
		superverbose ttytteristas
	); %opts_comma_delimit = map { $_ => 1 } qw(
		lists notifytype notifies filterflags filterrts filterats
		filterusers filteratonly
	); %opts_space_delimit = map { $_ => 1 } qw(
		track
	);

	   %opts_can_set = map { $_ => 1 } qw(
		url pause dmurl dmpause superverbose ansi verbose
		update uurl rurl wurl avatar ttytteristas frurl track
		rlurl noprompt shorturl newline wrap verify autosplit
		notimeline queryurl colourprompt colourme
		colourdm colourreply colourwarn coloursearch colourlist idurl
		urlopen delurl notrack dmdelurl favsurl
		favurl favdelurl slowpost notifies filter colourdefault
		followurl leaveurl dmupdate mentions backload
		lat long location searchhits blockurl blockdelurl woeid
		nocounter linelength friendsurl followersurl lists
		modifyliurl adduliurl delliurl getliurl getlisurl getfliurl
		creliurl delliurl deluliurl crefliurl delfliurl atrendurl
		getuliurl getufliurl dmsenturl rturl rtsbyurl wtrendurl
		statusliurl followliurl leaveliurl dmidurl nostreamreplies
		frupdurl filterusers filterats filterrts filterflags
		filteratonly nofilter rtsofmeurl
	); %opts_others = map { $_ => 1 } qw(
		lynx curl seven silent maxhist noansi hold status
		daemon timestamp twarg user anonymous script readline
		leader ssl rc norc vcheck apibase notifytype exts
		nonewrts synch runcommand authtype oauthkey oauthsecret
		tokenkey tokensecret credurl keyf readlinerepaint
		simplestart exception_is_maskable oldperl notco
		notify_tool_path oauthurl oauthauthurl oauthaccurl oauthbase
		signals_use_posix dostream eventbuf streamallreplies
	); %valid = (%opts_can_set, %opts_others);
	$rc = (defined($rc) && length($rc)) ? $rc : "";
	unless ($norc) {
		my $rcf =
			($rc =~ m#^/#) ? $rc : "$ENV{'HOME'}/.ttytterrc${rc}";
		if (open(W, $rcf)) {
			# 5.14 sets this lazily, so this gives us a way out
			eval 'binmode(W, ":utf8")' unless ($seven);
			while(<W>) {
				chomp;
				next if (/^\s*$/ || /^#/);
				s/^-//;
				($key, $value) = split(/\=/, $_, 2);
				if ($key eq 'rc') {
			warn "** that's stupid, setting rc in an rc file\n";
				} elsif ($key eq 'norc') {
			warn "** that's dumb, using norc in an rc file\n";
				} elsif (length $$key) {
					; # carry on
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
	warn "** -twarg is deprecated\n" if (length($twarg));
	$seven ||= 0;
	$oldperl ||= 0;
	$parent = $$;
	$script = 1 if (length($runcommand));
	$supreturnto = $verbose + 0;
	$postbreak_time = 0;
	$postbreak_count = 0;

	# our minimum official support is now 5.8.6.
	if ($] < 5.008006 && !$oldperl) {
		die(<<"EOF");

*** you are using a version of Perl in "extended" support: $] ***
the minimum tested version of Perl now required by TTYtter is 5.8.6.

Perl 5.005 thru 5.8.5 probably can still run TTYtter, but they are not
tested with it. if you want to suppress this warning, specify -oldperl on
the command line, or put oldperl=1 in your .ttytterrc. bug patches will 
still be accepted for older Perls; see the TTYtter home page for info.

for Perl 5.005, remember to also specify -seven.

EOF
	}

	# defaults that our extensions can override
	$last_id = 0;
	$last_dm = 0;
	# a correct fix for -daemon would make this unlimited, but this
	# is good enough for now.
	$print_max ||= ($daemon) ? 999999 : 250; # shiver

	$suspend_output = -1;

	# try to find an OAuth keyfile if we haven't specified key+secret
	# no worries if this fails; we could be Basic Auth, after all
	$whine = (length($keyf)) ? 1 : 0;
	$keyf ||= "$ENV{'HOME'}/.ttytterkey";
	$keyf = "$ENV{'HOME'}/.ttytterkey${keyf}" if ($keyf !~ m#/#);
	$attempted_keyf = $keyf;
	if (!length($oauthkey) && !length($oauthsecret) # set later
			&& !length($tokenkey)
			&& !length($tokensecret) && !$oauthwizard) {
		my $keybuf = '';
		if(open(W, $keyf)) {
			while(<W>) {
				chomp;
				s/\s+//g;
				$keybuf .= $_;
			}
			close(W);
			my (@pairs) = split(/\&/, $keybuf);
			foreach(@pairs) {
				my (@pair) = split(/\=/, $_, 2);
				$oauthkey = $pair[1]
					if ($pair[0] eq 'ck');
				$oauthsecret = $pair[1]
					if ($pair[0] eq 'cs');
				$tokenkey = $pair[1]
					if ($pair[0] eq 'at');
				$tokensecret = $pair[1]
					if ($pair[0] eq 'ats');
			}
			die("** tried to load OAuth tokens from $keyf\n".
	"  but it seems corrupt or incomplete. please see the documentation,\n".
	"  or delete the file so that we can try making your keyfile again.\n")
				if ((!length($oauthkey) ||
					!length($oauthsecret) ||
					!length($tokenkey) ||
					!length($tokensecret)));
		} else {
			die("** couldn't open keyfile $keyf: $!\n".
	"if you want to run the OAuth wizard to create this file, add ".
				"-oauthwizard\n")
				if ($whine);
			$keyf = ''; # i.e., we loaded nothing from a key file
		}
	}

	# try to init Term::ReadLine if it was requested
	# (shakes fist at @br3nda, it's all her fault)
	%readline_completion = ();
	if ($readline && !$silent && !$script) {
		$ENV{"PERL_RL"} = "TTYtter" if (!length($ENV{'PERL_RL'}));
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
		# readline repaint can't be tested here. we cache our
		# result later.
	} else {
		$stdout = \*STDOUT;
		$stdin = \*STDIN;
	}
	$wrapseq = 0;
	$lastlinelength = -1;

	print $stdout "$leader\n" if (length($leader));

	# state information
	$lasttwit = '';
	$lastpostid = 0;

	# stub namespace for multimodules and (eventually) state saving
	undef %store;
	$store = \%store;

	$pack_magic = ($] < 5.006) ? '' : "U0";
	$utf8_encode = sub { ; };
	$utf8_decode = sub { ; };
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

		eval <<'EOF';
		$utf8_encode = sub { utf8::encode(shift); };
		$utf8_decode = sub { utf8::decode(shift); };
EOF
	}
	$wraptime = sub { my $x = shift; return ($x, $x); };
	if ($timestamp) {
		my $fail = "-- can't use custom timestamps.\nspecify -timestamp by itself to use Twitter's without module.\n";
		if (length($timestamp) > 1) { # pattern specified
			eval 'use Date::Parse;return 1' ||
				die("$@\nno Date::Parse $fail");
			eval 'use Date::Format;return 1' ||
				die("$@\nno Date::Format $fail");
			$timestamp = "%Y-%m-%d %k:%M:%S"
				if ($timestamp eq "default" ||
				    $timestamp eq "def");
			$wraptime = sub {
				my $time = str2time(shift);
				my $stime = time2str($timestamp, $time);
				return ($time, $stime);
			};
		}
	}
}
END {
	&killkid unless ($in_backticks || $in_buffer); # this is disgusting
}

#### COMMON STARTUP ####

# if we requested POSIX signals, or we NEED posix signals (5.14+), we
# must check if we have POSIX signals actually
if ($signals_use_posix) {
	eval 'use POSIX';
	# God help the system that doesn't have SIGTERM
	$j = eval 'return POSIX::SIGTERM' ;
	die(<<"EOF") if (!(0+$j));
*** death permeates me ***
your configuration requires using POSIX signalling (either Perl 5.14+ or
you specifically asked with -signals_use_posix). however, either you don't
have POSIX.pm, or it doesn't work. 

TTYtter requires 'unsafe' Perl signals (which are of course for its
purposes perfectly safe). unfortunately, due to Perl bug 92246 5.14+ must
use POSIX.pm, or have the switch set before starting TTYtter. run one of
 
export PERL_SIGNALS=unsafe # sh, bash, ksh, etc.
setenv PERL_SIGNALS unsafe # csh, tcsh, etc.
 
and restart TTYtter, or use Perl 5.12 or earlier (without specifying
-signals_use_posix).
EOF
}

# do we have POSIX::Termios? (usually we do)
eval 'use POSIX; $termios = new POSIX::Termios;';
print $stdout "-- termios test: $termios\n" if ($verbose);

# check the TRLT version. versions < 1.3 won't work with 2.0.
if ($termrl && $termrl->ReadLine eq 'Term::ReadLine::TTYtter') {
	eval '$trlv = $termrl->Version;';
	die (<<"EOF") if (length($trlv) && 0+$trlv < 1.3);
*** death permeates me ***
you need to upgrade your Term::ReadLine::TTYtter to at least version 1.3
to use TTYtter 2.x, or bad things will happen such as signal mismatches,
unexpected quits, and dogs and cats living peacefully in the same house.

EOF
	print $stdout "** t.co support needs Term::ReadLine:TTYtter 1.4+ (-notco to ignore)\n"
		if (length($trlv) && !$notco && 0+$trlv < 1.4);
}

# try to get signal numbers for SIG* from POSIX. use internals if failed.
eval 'use POSIX; $SIGUSR1 = POSIX::SIGUSR1; $SIGUSR2 = POSIX::SIGUSR2; $SIGHUP = POSIX::SIGHUP; $SIGTERM = POSIX::SIGTERM';
# from <sys/signal.h>
$SIGHUP ||= 1;
$SIGTERM ||= 15;
$SIGUSR1 ||= 30;
$SIGUSR2 ||= 31;
	
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

# set up menu codes and caches
$is_background = 0;
$alphabet = "abcdefghijkLmnopqrstuvwxyz";
%store_hash = ();
$mini_split = 250; # i.e., 10 tweets for the mini-menu (/th)
# leaving 50 tweets for the foreground temporary menus
$tweet_counter = 0;
%dm_store_hash = ();
$dm_counter = 0;
%id_cache = ();
%filter_next = ();

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

# first we need to load any extensions specified by -exts.
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
		die("** $file not found: $!\n") if (! -r "$file");
		require $file; # and die if bad
		die("** $file failed to load: $@\n") if ($@);
		die("** consistency failure: reference failure on $file\n")
			if (!$store->{'loaded'});

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
			heartbeat precommand prepost postpost addaction
			eventhandle listhandle userhandle shutdown)) {
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
			getpassword prompt main autocompletion)) {
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
	$prepost = \&multiprepost;
	$postpost = \&multipostpost;
	$addaction = \&multiaddaction;
	$shutdown = \&multishutdown;
	$userhandle = \&multiuserhandle;
	$listhandle = \&multilisthandle;
	$eventhandle = \&multieventhandle;

} else {
	# the old API single-end-point system

	$multi_module_mode = 0; # not executing multi module endpoints

	$handle = \&defaulthandle;
	$exception = \&defaultexception;
	$tweettype = \&defaulttweettype;
	$conclude = \&defaultconclude;
	$dmhandle = \&defaultdmhandle;
	$dmconclude = \&defaultdmconclude;
	$heartbeat = \&defaultheartbeat;
	$precommand = \&defaultprecommand;
	$prepost = \&defaultprepost;
	$postpost = \&defaultpostpost;
	$addaction = \&defaultaddaction;
	$shutdown = \&defaultshutdown;
	$userhandle = \&defaultuserhandle;
	$listhandle = \&defaultlisthandle;
	$eventhandle = \&defaulteventhandle;
}

# unsafe methods use the single-end-point
$prompt = $l_prompt || \&defaultprompt;
$main = $l_main || \&defaultmain;
$getpassword = $l_getpassword || \&defaultgetpassword;

# $autocompletion is special:
if ($termrl) {
	$termrl->Attribs()->{'completion_function'} =
		$l_autocompletion || \&defaultautocompletion;
}

# fetch_id is based off last_id, if an extension set it
$fetch_id = $last_id || 0;

# validate the notify method the user chose, if any.
# we can't do this in BEGIN, because it may not be instantiated yet,
# and we have to do it after loading modules because it might be in one.
@notifytypes = ();
if (length($notifytype) && $notifytype ne '0' &&
		$notifytype ne '1' && !$status) {
	# NOT $script! scripts have a use case for notifiers!

	%dupenet = ();
	foreach $nt (split(/\s*,\s*/, $notifytype)) {
		$fnt="notifier_${nt}";
		(warn("** duplicate notification $nt was ignored\n"), next)
			if ($dupenet{$fnt});
		eval 'return &$fnt(undef)' ||
			die("** invalid notification framework $nt: $@\n");
		$dupenet{$fnt}=1;
	}
	@notifytypes = keys %dupenet;
	$notifytype = join(',', @notifytypes);
	# warning if someone didn't tell us what notifies they wanted.
	warn "-- warning: you specified -notifytype, but no -notifies\n"
		if (!$silent && !length($notifies));
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

# compile filterflags
&filterflags_compile;

# compile filters
exit(1) if (!&filter_compile);
$filterusers_sub = &filteruserlist_compile(undef, $filterusers);
$filterrts_sub = &filteruserlist_compile(undef, $filterrts);
$filteratonly_sub = &filteruserlist_compile(undef, $filteratonly);
exit(1) if (!&filterats_compile);

# compile lists
exit(1) if (!&list_compile);

# finally, compile notifies. we do this regardless of notifytype, so that
# an extension can look at it if it wants to.
&notify_compile;

# check that we are using a sensible authtype, based on our guessed user agent
$authtype ||= "oauth";
die("** supported authtypes are basic or oauth only.\n")
if ($authtype ne 'basic' && $authtype ne 'oauth');

if ($termrl) {
	$streamout = $stdout; # this is just simpler instead of dupping
        warn(<<"EOF") if ($] < 5.006);
***********************************************************
** -readline may not function correctly on Perls < 5.6.0 **
***********************************************************
EOF
	print $stdout "-- readline using ".$termrl->ReadLine."\n";
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

# after this point, die() may cause problems

# initialize our route back out so background can talk to foreground
pipe(W, P) || die("pipe() error [or your Perl doesn't support it]: $!\n");
select(P); $|++;
binmode(P, ":utf8") unless ($seven);
binmode(W, ":utf8") unless ($seven);

# default command line options

$anonymous ||= 0;
$ssl ||= 1;
die("** -anonymous is no longer supported with Twitter (you must use -apibase also)\n")
	if ($anonymous && !length($apibase));
undef $user if ($anonymous);
print $stdout "-- using SSL for default URLs.\n" if ($ssl);
$http_proto = ($ssl) ? 'https' : 'http';

$lat ||= undef;
$long ||= undef;
$location ||= 0;
$linelength ||= 140;
$oauthbase ||= $apibase || "${http_proto}://api.twitter.com";
# this needs to be AFTER oauthbase so that apibase can set oauthbase.
$apibase ||= "${http_proto}://api.twitter.com/1.1";
$nonewrts ||= 0;

# special case: if we explicitly refuse backload, don't load initially.
$backload = 30 if (!defined($backload)); # zero is valid!
$dont_refresh_first_time = 1 if (!$backload);

$searchhits ||= 20;
$url ||= "${apibase}/statuses/home_timeline.json";

$oauthurl ||= "${oauthbase}/oauth/request_token";
$oauthauthurl ||= "${oauthbase}/oauth/authorize";
$oauthaccurl ||= "${oauthbase}/oauth/access_token";

$credurl ||= "${apibase}/account/verify_credentials.json";
$update ||= "${apibase}/statuses/update.json";
$rurl ||= "${apibase}/statuses/mentions_timeline.json";
$uurl ||= "${apibase}/statuses/user_timeline.json";
$idurl ||= "${apibase}/statuses/show.json";
$delurl ||= "${apibase}/statuses/destroy/%I.json";

$rturl ||= "${apibase}/statuses/retweet";
$rtsbyurl ||= "${apibase}/statuses/retweets/%I.json";
$rtsofmeurl ||= "${apibase}/statuses/retweets_of_me.json";

$wurl ||= "${apibase}/users/show.json";

$frurl ||= "${apibase}/friendships/show.json";
$followurl ||= "${apibase}/friendships/create.json";
$leaveurl ||= "${apibase}/friendships/destroy.json";
$blockurl ||= "${apibase}/blocks/create.json";
$blockdelurl ||= "${apibase}/blocks/destroy.json";
$friendsurl ||= "${apibase}/friends/ids.json";
$followersurl ||= "${apibase}/followers/ids.json";
$frupdurl ||= "${apibase}/friendships/update.json";
$lookupidurl ||= "${apibase}/users/lookup.json";

$rlurl ||= "${apibase}/application/rate_limit_status.json";

$dmurl ||= "${apibase}/direct_messages.json";
$dmsenturl ||= "${apibase}/direct_messages/sent.json";
$dmupdate ||= "${apibase}/direct_messages/new.json";
$dmdelurl ||= "${apibase}/direct_messages/destroy.json";
$dmidurl ||= "${apibase}/direct_messages/show.json";

$favsurl ||= "${apibase}/favorites/list.json";
$favurl ||= "${apibase}/favorites/create.json";
$favdelurl ||= "${apibase}/favorites/destroy.json";

$getlisurl ||= "${apibase}/lists/list.json";
$creliurl ||= "${apibase}/lists/create.json";
$delliurl ||= "${apibase}/lists/destroy.json";
$modifyliurl ||= "${apibase}/lists/update.json";
$deluliurl ||= "${apibase}/lists/members/destroy_all.json";
$adduliurl ||= "${apibase}/lists/members/create_all.json";
$getuliurl ||= "${apibase}/lists/memberships.json";
$getufliurl ||= "${apibase}/lists/subscriptions.json";
$delfliurl ||= "${apibase}/lists/subscribers/destroy.json";
$crefliurl ||= "${apibase}/lists/subscribers/create.json";
$getfliurl ||= "${apibase}/lists/subscribers.json";
$getliurl ||= "${apibase}/lists/members.json";
$statusliurl ||= "${apibase}/lists/statuses.json";

$streamurl ||= "https://userstream.twitter.com/2/user.json";
$dostream ||= 0;
$eventbuf ||= 0;

$queryurl ||= "${apibase}/search/tweets.json";
# no more $trendurl in 2.1.
$wtrendurl ||= "${apibase}/trends/place.json";
$atrendurl ||= "${apibase}/trends/closest.json";

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
undef $shadow_history;
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
$colourlist ||= "OFF";
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

# whoops, no Lynx here if we are not using Basic Auth
	die(
"sorry, OAuth is not currently supported with Lynx.\n".
"you must use SSL cURL, or specify -authtype=basic.\n")
		if ($lynx && $authtype ne 'basic' && !$anonymous);

# streaming API has multiple prereqs. not fatal; we just fall back on the
# REST API if not there.
unless($status) {
if (!$dostream || $authtype eq 'basic' || !$ssl || $script || $anonymous || $synch) {
		$reason = (!$dostream) ? "(no -dostream)"
			: ($script) ? "(-script)"
			: (!$ssl) ? "(no SSL)"
			: ($anonymous) ? "(-anonymous)"
			: ($synch) ? "(-synch)"
			: ($authtype eq 'basic') ? "(no OAuth)"
			: "(it's funkatron's fault)";
		print $stdout
	"-- Streaming API disabled $reason (TTYtter will use REST API only)\n";
		$dostream = 0;
	} else {
		print $stdout "-- Streaming API enabled\n";

		# streams change mentions behaviour; we get them automatically.
		# warn the user if the current settings are suboptimal.
		if ($mentions) {
			if ($nostreamreplies) {
				print $stdout
"** warning: -mentions and -nostreamreplies are very inefficient together\n";
			} else {
				print $stdout
"** warning: -mentions not generally needed in Streaming mode\n";
			}
		}
	}
} else { $dostream = 0; } # -status suppresses streaming
if (!$dostream && $streamallreplies) {
	print $stdout
"** warning: -streamallreplies only works in Streaming mode\n";
}

# create and cache the logic for our selected user agent
if ($lynx) {
	$simple_agent = "$baseagent -nostatus -source";

	@wend = ('-nostatus');
	@wind = (@wend, '-source'); # GET agent
	@wend = (@wend, '-post_data'); # POST agent
	# we don't need to have the request signed by Lynx right now;
	# it doesn't know how to pass custom headers. so this is simpler.
	$stringify_args = sub {
		my $basecom = shift;
		my $resource = shift;
		my $data = shift;
		my $dont_do_auth = shift;
		my $k = join("\n", @_);

		# if resource is an arrayref, then it's a GET with URL
		# and args (mostly generated by &grabjson)
		$resource = join('?', @{ $resource })
			if (ref($resource) eq 'ARRAY');
		die("wow, we have a bug: Lynx only works with Basic Auth\n")
			if ($authtype ne 'basic' && !$dont_do_auth);
		$k = "-auth=".$mytoken.':'.$mytokensecret."\n".$k
			unless ($dont_do_auth);
		$k .= "\n";
		$basecom = "$basecom \"$resource\" -";
		return ($basecom, $k, $data);
	};
} else {
	$simple_agent = "$baseagent -s -m 20";

	@wend = ('-s', '-m', '20', '-A', "TTYtter/$TTYtter_VERSION",
			'-H', 'Expect:');
	@wind = @wend;
	$stringify_args = sub {
		my $basecom = shift;
		my $resource = shift;
		my $data = shift;
		my $dont_do_auth = shift;
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
		$l .= "\n";

		# sign our request (Basic Auth or oAuth)
		unless ($dont_do_auth) {
			if ($authtype eq 'basic') {
				$l .= "-u ".$mytoken.":".$mytokensecret."\n";
			} else {
				my $nonce;
				my $timestamp;
				my $sig;
				my $verifier = '';
				my $header;
				my $ttoken = (length($mytoken) ?
					(' oauth_token=\\"'.$mytoken.'\\",') :
						'');

				($timestamp, $nonce, $sig, $verifier) =
					&signrequest($resource, $data);
				$header = <<"EOF";
-H "Authorization: OAuth oauth_nonce=\\"$nonce\\", oauth_signature_method=\\"HMAC-SHA1\\", oauth_timestamp=\\"$timestamp\\", oauth_consumer_key=\\"$oauthkey\\", oauth_signature=\\"$sig\\",${ttoken}${verifier} oauth_version=\\"1.0\\""
EOF
				print $stdout $header if ($superverbose);
				$l .= $header;
			}
		}

		# if resource is an arrayref, then it's a GET with URL
		# and args (mostly generated by &grabjson)
		$resource = join('?', @{ $resource })
			if (ref($resource) eq 'ARRAY');
		$l .= "url = \"$resource\"\n";
		$l .= "data = \"$data\"\n" if length($data);
		return ("$basecom -K -", $l, undef);
	};
}

# update check
if ($vcheck && !length($status)) {
	$vs = &updatecheck(0);
} else {
	$vs =
"-- no version check performed (use /vcheck, or -vcheck to check on startup)\n"
	unless ($script || $status);
}
print $stdout $vs; # and then again when client starts up

## make sure we have all the authentication pieces we need for the
## chosen method (authtoken handles this for Basic Auth;
## this is where we validate OAuth)

# if we use OAuth, then don't use any Basic Auth credentials we gave
# unless we specifically say -authtype=basic
if ($authtype eq 'oauth' && length($user)) {
	print "** warning: -user is ignored when -authtype=oauth (default)\n";
	$user = undef;
}
$whoami = (split(/\:/, $user, 2))[0] unless ($anonymous || !length($user));

# yes, this is plaintext. obfuscation would be ludicrously easy to crack,
# and there is no way to hide them effectively or fully in a Perl script.
# so be a good neighbour and leave this the fark alone, okay? stealing
# credentials is mean and inconvenient to users. this is blessed by
# arrangement with Twitter. don't be a d*ck. thanks for your cooperation.
$oauthkey = (!length($oauthkey) || $oauthkey eq 'X') ?
	"XtbRXaQpPdfssFwdUmeYw" : $oauthkey;
$oauthsecret = (!length($oauthsecret) || $oauthsecret eq 'X') ?
	"csmjfTQPE8ZZ5wWuzgPJPOBR9dyvOBEtHT5cJeVVmAA" : $oauthsecret;

unless ($anonymous) {
# if we are using Basic Auth, ignore any user token we may have in
# our keyfile
if ($authtype eq 'basic') {
	$tokenkey = undef;
	$tokensecret = undef;
}
# but if we are using OAuth, we can request one, unless we are in script
elsif ($authtype eq 'oauth' && (!length($keyf) || $oauthwizard)) {
	if (length($oauthkey) && length($oauthsecret) && 
			!length($tokenkey) && !length($tokensecret)) {
		# we have a key, we don't have the user token
		# but we can't get that with -script
		if ($script) {
			print $streamout <<"EOF";
AUTHENTICATION FAILURE
YOU NEED TO GET AN OAuth KEY, or use -authtype=basic
(run TTYtter without -script or -runcommand for help)
EOF
			exit;
		}
		# run the wizard, which writes a keyfile for us
		$keyf ||= $attempted_keyf;
		print $stdout <<"EOF";

+----------------------------------------------------------------------------+
|| WELCOME TO TTYtter: Authorize TTYtter by signing into Twitter with OAuth ||
+----------------------------------------------------------------------------+
Looks like you're starting TTYtter for the first time, and/or creating a
keyfile. Welcome to the most user-hostile, highly obfuscated, spaghetti code
infested and obscenely obscure Twitter client that's out there. You'll love it.

TTYtter generates a keyfile that contains credentials for you, including your
access tokens. This needs to be done JUST ONCE. You can take this keyfile with
you to other systems. If you revoke TTYtter's access, you must remove the
keyfile and start again with a new token. You need to do this once per account
you use with TTYtter; only one account token can be stored per keyfile. If you
have multiple accounts, use -keyf=... to specify different keyfiles. KEEP THESE
FILES SECRET.

** This wizard will overwrite $keyf
Press RETURN/ENTER to continue or CTRL-C NOW! to abort.
EOF
		$j = <STDIN>;
		print $stdout "\nRequest from $oauthurl ...";
		($tokenkey, $tokensecret) = &tryhardfortoken($oauthurl,
			"oauth_callback=oob");
		$mytoken = $tokenkey;
		$mytokensecret = $tokensecret; # needs to be in both places
		# kludge in case user does not specify SSL and this is
		# Twitter: we know Twitter supports SSL
		($oauthauthurl =~ /twitter/) &&
			($oauthauthurl =~ s/^http:/https:/);
		print $stdout <<"EOF";

1. Visit, in your browser, ALL ON ONE LINE,

${oauthauthurl}?oauth_token=$mytoken

2. If you are not already signed in, fill in your username and password.

3. Verify that TTYtter is the requesting application, and that its permissions
are as you expect (read your timeline, see who you follow and follow new
people, update your profile, post tweets on your behalf and access your
direct messages). IF THIS IS NOT CORRECT, PRESS CTRL-C NOW!

4. Click Authorize app.

5. A PIN will appear. Enter it below.

EOF
		$j = '';
		while(!(0+$j)) {
			print $stdout "Enter PIN> ";
			chomp($j = <STDIN>);
		}
		print $stdout "\nRequest from $oauthaccurl ...";
		($tokenkey, $tokensecret) = &tryhardfortoken($oauthaccurl,
			"oauth_verifier=$j");

		$oauthkey = "X";
		$oauthsecret = "X";
		open(W, ">$keyf") ||
			die("Failed to write keyfile $keyf: $!\n");
		print W <<"EOF";
ck=${oauthkey}&cs=${oauthsecret}&at=${tokenkey}&ats=${tokensecret}
EOF
		close(W);
		chmod(0600, $keyf) || print $stdout
		"Warning: could not change permissions on $keyf : $!\n";
		print $stdout <<"EOF";
Written keyfile $keyf

Now, restart TTYtter to use this keyfile.
(To choose between multiple keyfiles other than the default .ttytterkey,
 tell TTYtter where the key is using -keyf=... .)

EOF
		exit;
	}
	# if we get three of the four, this must have been command line
	if (length($oauthkey) && length($oauthsecret) && 
			(!length($tokenkey) || !length($tokensecret))) {
		my $error = undef;
		my $k;
		foreach $k (qw(oauthkey oauthsecret tokenkey tokensecret)) {
			$error .= "** you need to specify -$k\n"
				if (!length($$k));
		}
		if (length($error)) {
			print $streamout <<"EOF";

you are missing portions of the OAuth sequence. either create a keyfile
and point to it with -keyf=... or add these missing pieces:
$error
then restart TTYtter, or use -authtype=basic.
EOF
			exit;
		}
	}
} elsif ($retoke && length($keyf)) {
	# start the "re-toke" wizard to convert DM-less cloned app keys.
	# dup STDIN for systems that can only "close" it once
	open(STDIN2, "<&STDIN") || die("couldn't dup STDIN: $!\n");
	print $stdout <<"EOF";

+-------------------------------------------------------------------------+
|| The Re-Toke Wizard: Generate a new TTYtter keyfile for your app/token ||
+-------------------------------------------------------------------------+
Twitter is requiring tokens to now have specific permissions to READ
direct messages. This will be enforced by 1 July 2011. If you find you are
unable to READ direct messages, you will need this wizard. DO NOT use this
wizard if you are NOT using a cloned app key (1.2 and on) -- use -oauthwizard.

This wizard will create a new keyfile for you from your app/user keys/tokens.
You do NOT need this wizard if you are using TTYtter for a purpose that does
not require direct message access. For example, if TTYtter is acting as
your command line posting agent, or you are only using it to read your
timeline, you do NOT need a new token. You also do not need a new token to
SEND a direct message, only to READ ones this account has received.

You SHOULD NOT need this wizard if your app key was cloned after 1 June 2011.
However, you can still use it if you experience this specific issue with DMs,
or need to rebuild your keyfile for any other reason.

** This wizard will overwrite the key at $keyf
** To change this, restart TTYtter with -retoke -keyf=/path/to/keyfile
Press RETURN/ENTER to continue, or CTRL-C NOW! to abort.
EOF

	$j = <STDIN>;
	print $stdout <<"EOF";

First: let's get your API key, consumer key and consumer secret.
Start your browser.
1. Log into https://twitter.com/ with your desired account.
2. Go to this URL. You must be logged into Twitter FIRST!

https://dev.twitter.com/apps

3. Click the TTYtter cloned app key you need to regenerate or upgrade.
4. Click Edit Application Settings.
5. Make sure Read, Write & Private Message is selected, and click the
   "Save application" button.
6. Select All (CTRL/Command-A) on the next screen, copy (CTRL/Command-C) it,
   and paste (CTRL/Command-V) it into this window. (You can also cut and
   paste a smaller section if I can't understand your browser's layout.)
7. Press ENTER/RETURN and CTRL-D when you have pasted the window contents.
EOF

	$q = $/;
	PASTE1LOOP: for(;;) {
		print $stdout <<"EOF";

-- Press ENTER and CTRL-D AFTER you have pasted the window contents! ---------
Go ahead:
EOF
		undef $/;
		$j = <STDIN2>;
		print $stdout <<"EOF";

-- EOF -----------------------------------------------------------------------
Processing ...

EOF
		$j =~ s/[\r\n]/ /sg;

		# process this. as a checksum, API key should == consumer key.
		$ck = '';
		$cs = '';
		($j =~ /Consumer key\s+([-a-zA-Z0-9_]{10,})\s+/) && ($ck = $1);
		($j =~ /Consumer secret\s+([-a-zA-Z0-9_]{10,})\s+/) &&
			($cs = $1);

		if (!length($ck) || !length($cs)) {
			# escape hatch
			print $stdout <<"EOF";
Something's wrong: I could not find your consumer key or consumer
secret in that text. If this was a misfired paste, please restart the wizard.
Otherwise, bug me at \@ttytter or ckaiser\@floodgap.com. Please don't send
keys or secrets to either address.

EOF
			exit;
		}
		last PASTE1LOOP;
	}
	# this part is similar to the retoke.
	$oauthkey = $ck;
	$oauthsecret = $cs;
	print $stdout "\nI'm testing this key to see if it works.\n";
	print $stdout "Request from $oauthurl ...";
	($tokenkey, $tokensecret) = &tryhardfortoken($oauthurl,
		"oauth_callback=oob");
	$mytoken = $tokenkey;
	$mytokensecret = $tokensecret;
	# kludge in case user does not specify SSL and this is
	# Twitter: we know Twitter supports SSL
	($oauthauthurl =~ /twitter/) && ($oauthauthurl =~ s/^http:/https:/);
	$/ = $q;
	print $stdout <<"EOF";

Okay, your consumer key is ==> $ck
 and your consumer secret  ==> $cs

IF THIS IS WRONG, PRESS CTRL-C NOW AND RESTART THE WIZARD!

Now we will verify your Imperial battle station is fully operational by
signing in with OAuth.

1. Visit, in your browser, ALL ON ONE LINE (you should still be logged in),

${oauthauthurl}?oauth_token=$mytoken

2. Verify that your app is the requesting application, and that its permissions
are as you expect (read your timeline, see who you follow and follow new
people, update your profile, post tweets on your behalf and access your
direct messages). IF THIS IS NOT CORRECT, PRESS CTRL-C NOW!

3. Click Authorize app.

4. A PIN will appear. Enter it below.

EOF
	print $stdout "Enter PIN> ";
	chomp($j = <STDIN>);
	print $stdout "\nRequest from $oauthaccurl ...";
	($at, $ats) = &tryhardfortoken($oauthaccurl, "oauth_verifier=$j");

	print $stdout <<"EOF";

Consumer key =========> $ck
Consumer secret ======> $cs
Access token =========> $at
Access token secret ==> $ats

EOF
	open(W, ">$keyf") || (print $stdout ("Unable to write to $keyf: $!\n"),
			exit);
	print W "ck=$ck&cs=$cs&at=$at&ats=$ats\n";
	close(W);
	chmod(0600, $keyf) || print $stdout
"Warning: could not change permissions on $keyf : $!\n";
	print $stdout "Keys written to regenerated keyfile $keyf\n";
	print $stdout "Now restart TTYtter.\n";	
	exit;
}

# now, get a token (either from Basic Auth, the keyfile or OAuth)
($mytoken, $mytokensecret) = &authtoken;
} # unless anonymous

# if we are testing the stream, this is where we split
if ($streamtest) {
	print $stdout ">>> STREAMING CONNECT TEST <<< (kill process to end)\n";
	&start_streaming; } # this never returns in this mode

# initial login tests and command line controls
if ($statusurl) {
	$shorstatusturl = &urlshorten($statusurl);
	$status = ((length($status)) ? "$status " : "") . $shorstatusturl;
}
$phase = 0;
$didhold = $hold;
$hold = -1 if ($hold == 1 && !$script);
$credentials = '';
$status = pack("U0C*", unpack("C*", $status))
	unless ($seven || !length($status) || $LANG =~ /8859/); # kludgy also
if ($status eq '-') {
	chomp(@status = <STDIN>);
	$status = join("\n", @status);
}
for(;;) {
	$rv = 0;
	die(
	"sorry, you can't tweet anonymously. use an authenticated username.\n")
		if ($anonymous && length($status));
	die(
"sorry, status too long: reduce by @{[ &length_tco($status)-$linelength ]} chars, ".
"or use -autosplit={word,char,cut}.\n")
		if (&length_tco($status) > $linelength && !$autosplit);
	($status, $next) = &csplit($status, ($autosplit eq 'char' ||
			$autosplit eq 'cut') ? 1 : 0)
		if (!length($next));
	if ($autosplit eq 'cut' && length($next)) {
		print "-- warning: input autotrimmed to $linelength bytes\n";
		$next = "";
	}
	if (!$anonymous && !length($whoami) && !length($status)) {
		# we must be using OAuth tokens. we'll need
		# to get our screen name from Twitter. we DON'T need this
		# if we're just posting with -status.
		print "(checking credentials) "; $data =
		$credentials = &backticks($baseagent, '/dev/null', undef,
			$credurl, undef, $anonymous, @wind);
		$rv = $? || &is_fail_whale($data) || &is_json_error($data);
	}
	if (!$rv && length($status) && $phase) {
		print "post attempt "; $rv = &updatest($status, 0);
	} else {
		# no longer a way to test anonymous logins
		unless ($rv || $anonymous) {
			print "test-login "; 
			$data = &backticks($baseagent, '/dev/null', undef,
					$url, undef, $anonymous, @wind);
			$rv = $?;
		}
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
		print
	"--- data received ($hold) ---\n$data\n--- data received ($hold) ---\n"
			if ($superverbose);
		if ($hold && --$hold) {
			print
			"trying again in 1 minute, or kill process now.\n\n";
			sleep 60;
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
&sigify(sub { ; }, qw(USR1 PWR XCPU));
&sigify(sub { $background_is_ready++ }, qw(USR2 SYS UNUSED XFSZ));
if (length($credentials)) {
	print "-- processing credentials: ";
	$my_json_ref = &parsejson($credentials);
	$whoami = lc($my_json_ref->{'screen_name'});
	if (!length($whoami)) {
		print "FAILED!\nis your account suspended, or wrong token?\n";
		exit;
	}
	print "logged in as $whoami\n";
	$credlog = "-- you are logged in as $whoami\n";
}

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
		$bufferpid = 0;
		if ($dostream) {
			&sigify(sub {
				kill $SIGHUP, $nursepid if ($nursepid);
				kill $SIGHUP, $bufferpid if ($bufferpid);
				kill 9, $curlpid if ($curlpid);
				sleep 1;
				# send myself a shutdown
				kill 9, $nursepid if ($nursepid);
				kill 9, $bufferpid if ($bufferpid);
				kill 9, $curlpid if ($curlpid);
				kill 9, $$;
			}, qw(TERM HUP PIPE));
			&sigify("IGNORE", qw(INT));
			$bufferpid = &start_streaming;
			$rin = '';	
			vec($rin, fileno(STBUF), 1) = 1;
		}
		$parent = 0;
		$dmcount = 1 if ($dmpause); # force fetch
		$is_background = 1;
		DAEMONLOOP: for(;;) {
			my $snooze;
			my $nfound;
			my $wake;

			&$heartbeat;
			&update_effpause;
			&refresh(0);
			$dont_refresh_first_time = 0;
			if ($dmpause) {
				if (!--$dmcount) {
					&dmrefresh(0);
					$dmcount = $dmpause;
				}
			}
			# service events on the streaming socket, if
			# we have one.
			$snooze = ($effpause || 0+$pause || 60);
			$wake = time() + $snooze;
			if (!$bufferpid) {
				sleep $snooze;
			} else {
				my $read_failure = 0;
				SLEEP_AGAIN: for(;;) {
					$nfound = select($rout = $rin,
						undef, undef, $snooze);
					if ($nfound &&
					vec($rout, fileno(STBUF), 1)==1) {
						my $buf = '';
						my $rbuf = '';
						my $len;

						sysread(STBUF, $buf, 1);
						if (!length($buf)) {
							$read_failure++;
							# a stuck ready FH says
							# our buffer is dead;
							# see MONITOR: below.
							if ($read_failure>100){
print $stdout "*** unrecoverable failure of buffer process, aborting\n";
								exit;
							}
							next SLEEP_AGAIN;
						}
						$read_failure = 0;
						if ($buf !~ /^[0-9a-fA-F]+$/) {
							print $stdout
		"-- warning: bogus character(s) ".unpack("H*", $buf)."\n"
							if ($superverbose);
							next SLEEP_AGAIN;
						}
						while (length($buf) < 8) {
				# don't read 8 -- read 1. that means we can
				# skip trailing garbage without a window.
							sysread(STBUF,$rbuf,1);
						if ($rbuf =~ /[0-9a-fA-F]/) {
								$buf .= $rbuf;
							} else {
							print $stdout
	"-- warning: bogus character(s) ".unpack("H*", $rbuf)."\n"
						if ($superverbose);
							$buf = ''
							if(length($rbuf));
							}
						}
					print $stdout "-- length packet: $buf\n"
							if ($superverbose);
						$len = hex($buf);
						$buf = '';
						while (length($buf) < $len) {
							sysread(STBUF, $rbuf,
							($len-length($buf)));
							$buf .= $rbuf;
						}
						&streamevents(
							&parsejson($buf) );
						$snooze = $wake - time();
						next SLEEP_AGAIN if
							($snooze > 0);
					}
					last SLEEP_AGAIN;
				}
			}
		 }
	}
	die("uncaught fork() exception\n");
}

#### INTERACTIVE MODE and CONSOLE STARTUP ####

unless ($simplestart) {
	print <<"EOF";

######################################################        +oo=========oo+ 
         ${EM}TTYtter ${TTYtter_VERSION}.${padded_patch_version} (c)2012 cameron kaiser${OFF}                @             @
EOF
	$e = <<'EOF';
                 ${EM}all rights reserved.${OFF}                         +oo=   =====oo+
       ${EM}http://www.floodgap.com/software/ttytter/${OFF}            ${GREEN}a==:${OFF}  ooo
                                                            ${GREEN}.++o++.${OFF} ${GREEN}..o**O${OFF}
  freeware under the floodgap free software license.        ${GREEN}+++${OFF}   :O${GREEN}:::::${OFF}
        http://www.floodgap.com/software/ffsl/              ${GREEN}+**O++${OFF} #   ${GREEN}:ooa${OFF}
                                                                   #+$$AB=.
         ${EM}tweet me: http://twitter.com/ttytter${OFF}                      #;;${YELLOW}ooo${OFF};;
            ${EM}tell me: ckaiser@floodgap.com${OFF}                          #+a;+++;O
######################################################           ,$B.${RED}*o***${OFF} O$,
#                                                                a=o${RED}$*O*O*$${OFF}o=a
# when ready, hit RETURN/ENTER for a prompt.                        @${RED}$$$$$${OFF}@
# type /help for commands or /quit to quit.                         @${RED}o${OFF}@o@${RED}o${OFF}@
# starting background monitoring process.                           @=@ @=@
#
EOF
	$e =~ s/\$\{([A-Z]+)\}/${$1}/eg; print $stdout $e;
} else {
	print <<"EOF";
TTYtter ${TTYtter_VERSION}.${padded_patch_version} (c)2012 cameron kaiser
all rights reserved. freeware under the floodgap free software license.
http://www.floodgap.com/software/ffsl/

tweet me: http://twitter.com/ttytter * tell me: ckaiser\@floodgap.com
type /help for commands or /quit to quit.
starting background monitoring process.

EOF
}
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
	print C "rsga---------------\n";
	$dont_use_counter = $nocounter;
	eval '$termrl->hook_no_counter';
	$tco_sub = sub { return &main::fastturntotco(shift); };
	eval '$termrl->hook_no_tco';
	if ($termrl) {
		while(defined ($_ = $termrl->readline((&$prompt(1))[0]))) {
			kill $SIGUSR1, $child; # suppress output
			$rv = &prinput($_);
			kill $SIGUSR2, $child; # resume output
			last if ($rv < 0);
			&sync_console unless (!$rv || !$synch);
			if ($dont_use_counter ne $nocounter) {
				# only if we have to -- this is expensive
				$dont_use_counter = $nocounter;
				eval '$termrl->hook_no_counter'
			}
		}
	} else {
		&$prompt;
		while(<>) { #not stdin so we can read from script files
			kill $SIGUSR1, $child; # suppress output
			$rv = &prinput(&uforcemulti($_));
			kill $SIGUSR2, $child; # resume output
			last if ($rv < 0);
			&sync_console unless (!$rv || !$synch);
			&$prompt;
		}
		&sync_n_quit if ($script);
	}
}

# SIGPIPE in particular must be trapped in case someone kills the background
# or, in streaming mode, buffer processes. we can't recover from that.
# the streamer MUST have been initialized before we start these signal
# handlers, or the streamer will try to run them too. eeek!
#
# DO NOT trap SIGCHLD: we generate child processes that die normally.
&sigify(\&end_me, qw(PIPE INT));
&sigify(\&repaint, qw(USR1 PWR XCPU));
sub sigify {
	# this routine abstracts setting signals to a subroutine reference.
	# check and see if we have to use POSIX.pm (Perl 5.14+) or we can
	# still use $SIG for proper signalling. We prefer the latter, but
	# must support the former.
	my $subref = shift;
	my $k;

	if ($signals_use_posix) {
		my @w;
		my $sigaction = POSIX::SigAction->new($subref);
		while ($k = shift) {
			my $e = &posix_signal_of($k);
			# some signals may not exist on all systems.
			next if (!(0+$e));
			POSIX::sigaction($e, $sigaction)
				|| die("sigaction failure: $! $@\n");
		}
	} else {
		while ($k = shift) { $SIG{$k} = $subref; }
	}
}
sub posix_signal_of {
	die("never call posix_signal_of if signals_use_posix is false\n")
		if (!$signals_use_posix);

	# this assumes that POSIX::SIG* returns a scalar int value.
	# not all signals exist on all systems. this ensures zeroes are
	# returned for locally bogus ones.
	return 0+(eval("return POSIX::SIG".shift));
}

sub send_repaint {
	unless ($wrapseq){
		return;
	}
	$wrapseq = 0;
	return if ($daemon);
	if ($child) {
		# we are the parent, call our repaint
		&repaint;
	} else {
		# we are not the parent, call the parent to repaint itself
		kill $SIGUSR1, $parent; # send SIGUSR1
	}
}
sub repaint {
	# try to speed this up, since we do it a lot.
	$wrapseq = 0;
	return &$repaintcache if ($repaintcache) ;

	# cache our repaint function (no-op or redisplay)
	$repaintcache = sub { ; }; # no-op
	return unless ($termrl &&
		($termrl->Features()->{'canRepaint'} || $readlinerepaint));
	return if ($daemon);
	$termrl->redisplay; $repaintcache = sub { $termrl->redisplay; };
}
sub send_removereadline {
	# this just stubs into its own removereadline
	return &$removereadlinecache if ($removereadlinecache);

	$removereadlinecache = sub { ; };
	return unless ($termrl && $termrl->Features()->{'canRemoveReadline'});
	return if ($daemon);
	$termrl->removereadline;
	$removereadlinecache = sub { $termrl->removereadline; };
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
eval'$termrl->hook_background_control' if ($termrl);
select(C); $|++; select($stdout);

# handshake for synchronicity mode, if we want it.
if ($synch) {
	# we will get two replies for this.
	print C "synm---------------\n";
	&thump;
	# the second will be cleared by the console
}

# wait for background to become ready
sleep 1 while (!$background_is_ready);

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
		&$utf8_encode($probe);
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
			/^TTYtter>/ || $_ eq 'ls' || $_ eq '?' ||
			m#^help /# || $_ eq 'exit')) {
		
		&add_history($_);
		unless ($_ eq 'exit' || /^TTYtter>/ || $_ eq 'ls') {
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

	# handle history substitution (including /%%, %%--, %%*, etc.)
	$i = 0; # flag

	if (/^\%(\%|-\d+)(--|-\d+|\*)?/) {
		($i, $proband, $r, $s) = &sub_helper($1, $2, $_);
		return 0 if (!$i);

		$s = quotemeta($s);
		s/^\%${r}${s}/$proband/;
	}
	if (/[^\\]\%(\%|-\d+)(--|-\d+|\*)?$/) {
		($i, $proband, $r, $s) = &sub_helper($1, $2, $_);
		return 0 if (!$i);

		$s = quotemeta($s);
		s/\%${r}${s}$/$proband/;
	}
	# handle variables second, in case they got in history somehow ...
	$i = 1 if (s/^\%URL\%/$urlshort/ || s/\%URL\%$/$urlshort/);
	$i = 1 if (s/^\%RT\%/$retweet/ || s/\%RT\%$/$retweet/);

	# and escaped history
	s/^\\\%/%/;

	if ($i) {
		print $stdout "(expanded to \"$_\")\n" ;
		$in_reply_to = $expected_tweet_ref->{'id_str'} || 0
			if (defined $expected_tweet_ref &&
				ref($expected_tweet_ref) eq 'HASH');
	} else {
		$expected_tweet_ref = undef;
	}

	return 0 unless length; # actually possible to happen
				# with control char filters and history.

	&add_history($_);
	$shadow_history = $_;

	# handle history display
	if ($_ eq '/history' || $_ eq '/h') {
		for ($i = scalar(@history); $i >= 1; $i--) {
			print $stdout "\t$i\t$history[($i-1)]\n";
		}
		return 0;
	}	

	my $slash_first = ($_ =~ m#^/#);

	return -1 if ($_ eq '/quit' || $_ eq '/q' || $_ eq '/bye' ||
			$_ eq '/exit');

	return 0 if (scalar(&$addaction($_)));

	# add commands here

	# dumper
	if (m#^/du(mp)? ([zZ]?[a-zA-Z]?[0-9]+)$#) {
		my $code = lc($2);
		unless ($code =~ /^d[0-9][0-9]+$/) { # this is a DM.
		my $tweet = &get_tweet($code);
		my $k;
		my $sn;
		my $id;
		my @superfields = (
			[ "user", "screen_name" ], # must always be first
			[ "retweeted_status", "id_str" ],
			[ "user", "geo_enabled" ],
			[ "place", "id" ],
			[ "place", "country_code" ],
			[ "place", "full_name" ],
			[ "place", "place_type" ],
			[ "tag", "type" ],
			[ "tag", "payload" ],
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
				substr("$sfn                          ", 0, 25).
				" $sfv\n";
			$sn = $sfv if (!length($sn) && length($sfv));
		}
		# geo is special
		print $stdout "geo->coordinates          (" .
			join(', ', @{ $tweet->{'geo'}->{'coordinates'} })
			. ")\n";
		foreach $k (sort keys %{ $tweet }) {
			next if (ref($tweet->{$k}));
			print $stdout
				substr("$k                          ", 0, 25) .
					" " . &descape($tweet->{$k}) . "\n";
		}
		# include a URL to the tweet per @augmentedfourth
		$urlshort =
		"${http_proto}://twitter.com/$sn/statuses/$tweet->{'id_str'}";
		print $stdout
			"-- %URL% is now $urlshort (/short to shorten)\n";
		return 0;
		} # if dxxxx, fall through to the below.
	}

	if (m#^/du(mp)? ([dD][a-zA-Z]?[0-9]+)$#) {
		my $code = lc($2);
		my $dm = &get_dm($code);
		my $k;
		my $sn;
		my $id;
		my @superfields = (
			[ "sender", "screen_name" ], # must always be first
		);

		if (!defined($dm)) {
			print $stdout "-- no such DM (yet?): $code\n";
			return 0;
		}
	
		foreach $superfield (@superfields) {
			my $sfn = join('->', @{ $superfield });
			my $sfk = "{'" . join("'}->{'", @{ $superfield }) .
				"'}";
			my $sfv;
			eval "\$sfv = &descape(\$dm->$sfk);";
			print $stdout
				substr("$sfn                          ", 0, 25).
				" $sfv\n";
			$sn = $sfv if (!length($sn) && length($sfv));
		}

		foreach $k (sort keys %{ $dm }) {
			next if (ref($dm->{$k}));
			print $stdout
				substr("$k                          ", 0, 25) .
					" " . &descape($dm->{$k}) . "\n";
		}
		return 0;
	}

	# evaluator
	if (m#^/ev(al)? (.+)$#) {
		$k = eval $2;
		print $stdout "==> ";
		print $streamout "$k $@\n";
		return 0;
	}

	# version check
	if (m#^/v(ersion)?check$# || m#^/u(pdate)?check$#) {
		print $stdout &updatecheck(1);
		return 0;
	}

	# url shortener routine
	if (($_ eq '/sh' || $_ eq '/short') && length($urlshort)) {
		$_ = "/short $urlshort";
		print $stdout "*** assuming you meant %URL%: $_\n";
		# and fall through to ...
	}
	if (m#^/sh(ort)? (https?|gopher)(://[^ ]+)#) {
		my $url = $2 . $3;
		my $answer = (&urlshorten($url) || 'FAILED -- %% to retry');
		print $stdout "*** shortened to: ";
		print $streamout ($answer . "\n");
		return 0;
	}

	# getter for internal value settings
	if (/^\/r(ate)?l(imit)?$/) {
		$_ = '/print rate_limit_rate';
		# and fall through to ...
	}

	if ($_ eq '/p' || $_ eq '/print') {
		foreach $key (sort keys %opts_can_set) {
			print $stdout "*** $key => $$key\n"
				if (!$opts_secret{$key});
		}
		return 0;
	}
	if (/^\/p(rint)?\s+([^ ]+)/) {
		my $key = $2;
		if ($valid{$key} ||
				$key eq 'effpause' ||
				$key eq 'rate_limit_rate' ||
				$key eq 'rate_limit_left') {
			my $value = &getvariable($key);
			print $stdout "*** ";
			print $stdout "(read-only value) "
				if (!$opts_can_set{$key});
			print $stdout "$key => $value\n";

		# I don't see a need for these in &getvariable, so they are
		# not currently supported. whine if you disagree.

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
	if (/^\/se(arch)?\s+(\+\d+\s+)?(.+)\s*$/) {
		my $countmaybe = $2;
		my $kw = $3;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		$countmaybe ||= $searchhits;
		$kw = &url_oauth_sub($kw);
		$kw = "q=$kw" if ($kw !~ /^q=/);

		my $r = &grabjson("$queryurl?$kw", 0, 0, $countmaybe, {
					"type" => "search",
					"payload" => $k
				}, 1);
		if (defined($r) && ref($r) eq 'ARRAY' && scalar(@{ $r })) {
			&dt_tdisplay($r, 'search');
		} else {
			print $stdout "-- sorry, no results were found.\n";
		}
		&$conclude;
		return 0;
	}
	if ($_ eq '/notrack') { # special case
		print $stdout "*** all tracking keywords cancelled\n";
		$track = '';
		&setvariable('track', $track, 1);
		return 0;
	}
	if (s/^\/troff\s+// && s/\s*// && length) {
	# remove it from array, regenerate $track, call tracktags_makearray
	# and then sync
		my $k;
		my $l = '';
		my $q = 0;
		my %w;
		$_ = lc($_);
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
		&setvariable('track', $track, 1);
		return 0;
	}

	if (s#^/tre(nds)?\s*##) {
		my $t = undef;
		my $wwoeid = (length) ? $_ : $woeid;
		$wwoeid ||= "1";
		my $r = &grabjson("${wtrendurl}?id=${wwoeid}",
				0, 0, 0, undef, 1);
		my $fr = ($wwoeid && $wwoeid ne '1') ?
			" FOR WOEID $wwoeid" : ' GLOBALLY';

		if (defined($r) && ref ($r) eq 'ARRAY') {
			$t = $r->[0]->{'trends'};
		}
		if (defined($t) && ref($t) eq 'ARRAY') {
			my $i;
			my $j;

			print $stdout "${EM}<<< TRENDING TOPICS${fr} >>>${OFF}\n";
			foreach $j (@{ $t }) {
				my $k = &descape($j->{'name'});
				my $l = ($k =~ /\sOR\s/) ? $k :
					($k =~ /^"/) ? $k :
					('"' . $k . '"');
				print $streamout "/search $l\n";
				$k =~ s/\sOR\s/ /g;
				$k = '"' . $k . '"' if ($k =~ /\s/
					&& $k !~ /^"/);
				print $streamout "/tron $k\n";
			}
			print $stdout "${EM}<<< TRENDING TOPICS >>>${OFF}\n";
		} else {
			print $stdout
"-- sorry, trends not available for WOEID $wwoeid.\n";
		}
		return 0;
	}

	# woeid finder based on lat/long
	if ($_ eq '/woeids') {
		my $max = 10;
		if (!$lat && !$long) {
			print $stdout
			"-- set your location with lat/long first.\n";
			return 0;
		}
		my $r = &grabjson("$atrendurl?lat=$lat&long=$long", 0, 0, 0,
			undef, 1);
		if (defined($r) && ref($r) eq 'ARRAY') {
			my $i;
			foreach $i (@{ $r }) {
				my $woeid = &descape($i->{'woeid'});
				my $nm = &descape($i->{'name'}) . ' (' .
					&descape($i->{'countryCode'}) .')';
				print $streamout "$nm\n/set woeid $woeid\n";
				last unless ($max--);
			}
		} else {
			print $stdout
"-- sorry, couldn't get a supported WOEID for your location.\n";
		}
		return 0;
	}

	1 if (s/^\/#([^\s]+)/\/tron #\1/);
	# /# command falls through to tron
	if (s/^\/tron\s+// && s/\s*$// && length) {
		$_ = lc($_);
		$track .= " " if (length($track));
		$_ = "/set track ${track}$_";
		# fall through to set
	}
	if (/^\/track ([^ ]+)/) {
		s#^/#/set #;
		# and fall through to set
	}

	# /listoff
	if (s/^\/list?off\s+// && s/\s*$// && length) {
		if (/,/ || /\s+/) {
			print $stdout "-- one list at a time please\n";
			return 0;
		}
		if (!scalar(@listlist)) {
			print $stdout
	"-- ok! that was easy! (you don't have any lists in your timeline)\n";
			return 0;
		}
		my $w;
		my $newlists = '';
		my $didfilter = 0;
		foreach $w (@listlist) {
			my $x = join('/', @{ $w });
			if ($x eq $_ || "$whoami$_" eq $x ||
					"$whoami/$_" eq $x) {
				print $stdout "*** ok, filtered $x\n";
				$didfilter = 1;
			} else {
				$newlists .= (length($newlists)) ? ",$x"
					: $x;
			}
		}
		if ($didfilter) {
			&setvariable('lists', $newlists, 1);
		} else {
			print $stdout "*** hmm, no such list? current value:\n";
			print $stdout "*** lists => ",
				&getvariable('lists'), "\n";
		}
		return 0;
	}

	# /liston
	if (s/^\/list?on\s+// && s/\s*$// && length) {
		if (/,/ || /\s+/) {
			print $stdout "-- one list at a time please\n";
			return 0;
		}
		my $uname;
		my $lname;
		if (m#/#) {
			($uname, $lname) = split(m#/#, $_, 2);
		} else {
			$lname = $_;
			$uname = '';
		}
		if (!length($uname) && $anonymous) {
			print $stdout
"-- you must specify a username for a list when anonymous.\n";
			return 0;
		}
		$uname ||= $whoami;

		# check the list validity
		my $my_json_ref = &grabjson(
		"${statusliurl}?owner_screen_name=${uname}&slug=${lname}",
			0, 0, 0, undef, 1);
		if (!$my_json_ref || ref($my_json_ref) ne 'ARRAY') {
			print $stdout
			"*** list $uname/$lname seems bogus; not added\n";
			return 0;
		}

		$_ = "/add lists $uname/$lname";
		# fall through to add
	}
	if (s/^\/a(uto)?lists?\s+// && s/\s*$// && length) {
		s/\s+/,/g if (!/,/);
		print $stdout
	"--- warning: lists aren't checked en masse; make sure they exist\n";
		$_ = "/set lists $_";
		# and fall through to set
	}

	# setter for internal value settings
	# shortcut for boolean settings
	if (/^\/s(et)? ([^ ]+)\s*$/) {
		my $key = $2;
		$_ = "/set $key 1"
			if($opts_boolean{$key} && $opts_can_set{$key});
		# fall through to three argument version
	}
	if (/^\/uns(et)? ([^ ]+)\s*$/) {
		my $key = $2;
		if ($opts_can_set{$key} && $opts_boolean{$key}) {
			&setvariable($key, 0, 1);
			return 0;
		}
		&setvariable($key, undef, 1);
		return 0;
	}
	# stubs out to set variable
	if (/^\/s(et)? ([^ ]+) (.+)\s*$/) {
		my $key = $2;
		my $value = $3;
		&setvariable($key, $value, 1);
		return 0;
	}
	# append to a variable (if not boolean)
	if (/^\/ad(d)? ([^ ]+) (.+)\s*$/) {
		my $key = $2;
		my $value = $3;
		if ($opts_boolean{$key}) {
			print $stdout
				"*** why are you appending to a boolean?\n";
			return 0;
		}
		if (length(&getvariable($key))) {
			$value = " $value" if ($opts_space_delimit{$key});
			$value = ",$value" if ($opts_comma_delimit{$key});
		}
		&setvariable($key, &getvariable($key).$value, 1);
		return 0;
	}
	# delete from a variable (if not boolean)
	if (/^\/del ([^ ]+) (.+)\s*$/) {
		my $key = $1;
		my $value = $2;
		my $old;
		if ($opts_boolean{$key}) {
			print $stdout
				"*** why are you deleting from a boolean?\n";
			return 0;
		}
		if (!length($old = &getvariable($key))) {
			print $stdout "*** $key is already empty\n";
			return 0;
		}
		my $del =
			($opts_space_delimit{$key}) ? '\s+' :
			($opts_comma_delimit{$key}) ? '\s*,\s*' :
			undef;
		if (!defined($del)) {
			# simple substitution
			1 while ($old =~ s/$value//g);
		} else {
			1 while ($old =~ s/$del$value($del)/\1/g);
			1 while ($old =~ s/^$value$del//);
			1 while ($old =~ s/$del$value//);
		}
		&setvariable($key, $old, 1);
		return 0;
	}
	# I thought about implementing a /pdel but besides being ugly
	# I don't think most people will push a truncated setting. tell me
	# if I'm wrong.

	# stackable settings
	if (/^\/pu(sh)? ([^ ]+)\s*$/) {
		my $key = $2;
		if ($opts_can_set{$key}) {
			if ($opts_boolean{$key}) {
				$_ = "/push $key 1";
				# fall through to three argument version
			} else {
				if (!$opts_can_set{$key}) {
					print $stdout
					"*** setting is not stackable: $key\n";
					return 0;
				}
				my $old = &getvariable($key);
				push(@{ $push_stack{$key} }, $old);
				print $stdout
					"--- saved on stack for $key: $old\n";
				return 0;
			}
		}
	}

	# common code for set and append
	if (/^\/(pu|push|pad|padd) ([^ ]+) (.+)\s*$/) {
		my $comm = $1;
		my $key = $2;
		my $value = $3;
		$comm = ($comm =~ /^pu/) ? "push" : "padd";
		if ($opts_boolean{$key} && $comm eq 'padd') {
			print $stdout
				"*** why are you appending to a boolean?\n";
			return 0;
		}
		if (!$opts_can_set{$key}) {
			print $stdout
				"*** setting is not stackable: $key\n";
			return 0;
		}
		my $old = &getvariable($key);
		$old += 0 if ($opts_boolean{$key});
		push(@{ $push_stack{$key} }, $old);
		print $stdout "--- saved on stack for $key: $old\n";
		if ($comm eq 'padd' && length($old)) {
			$value = " $value" if ($opts_space_delimit{$key});
			$value = ",$value" if ($opts_comma_delimit{$key});
			$old .= $value;
		} else {
			$old = $value;
		}
		&setvariable($key, $old, 1);
		return 0;
	}
	# we assume that if the setting is in the push stack, it's valid
	if (/^\/pop ([^ ]+)\s*$/) {
		my $key = $1;
		if (!scalar(@{ $push_stack{$key} })) {
			print $stdout
				"*** setting is not stacked: $key\n";
			return 0;
		}
		&setvariable($key, pop(@{ $push_stack{$key} }), 1);
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
   /replies                          o@BOOOOOOOOO#@+     ==================
      shows replies and mentions.    o@BOB@B$B@BO#@+     USE + FOR A COUNT:
                                     o@*.a@o a@o.$@+ /re +30 => last 30 replies
   /quit resumes your boring life.   o@B$B@o a@A$#@+ ========================== 
EOF
		&linein("PRESS RETURN/ENTER>");
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
		&linein("PRESS RETURN/ENTER>");
		print <<"EOF";



Use /set to turn on options or set them at runtime. There is a BIG LIST!

>> EXAMPLE: WANT ANSI? /set ansi 1
                       or use the -ansi command line option.
            WANT TO VERIFY YOUR TWEETS BEFORE POSTING? /set verify 1
                       or use the -verify command line option.
For more, like readline support, UTF-8, SSL, proxies, etc., see the docs.

** READ THE COMPLETE DOCUMENTATION: http://www.floodgap.com/software/ttytter/

 TTYtter $TTYtter_VERSION is (c)2012 cameron kaiser + contributors.
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
	if ($_ eq '/cls' || $_ eq '/clear') {
		if ($ansi) {
			print $stdout "${ESC}[H${ESC}[2J\n";
		} else {
			print $stdout ("\n" x ($ENV{'ROWS'} || 50));
		}
		return 0;
	}
	if ($_ eq '/refresh' || $_ eq '/thump' || $_ eq '/r') {
		print $stdout "-- /refresh in streaming mode is pretty impatient\n"
			if ($dostream);
		&thump;
		return 0;
	}
	if (m#^/a(gain)?(\s+\+\d+)?$#) { # the asynchronous form
		my $countmaybe = $2;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		if ($countmaybe > 999) {
			print $stdout "-- greedy bastard, try +fewer.\n";
			return 0;
		}
		$countmaybe = sprintf("%03i", $countmaybe);
		print $stdout "-- background request sent\n" unless ($synch);
		
		print C "reset${countmaybe}-----------\n";
		&sync_semaphore;
		return 0;
	}

	# this is for users -- list form is below
	if ($_ =~ m#^/(w)?a(gain)?\s+(\+\d+\s+)?([^\s/]+)$#) { #synchronous form
		my $mode = $1;
		my $uname = lc($4);

		my $countmaybe = $3;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		
		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout
		"-- synchronous /again command for $uname ($countmaybe)\n"
			if ($verbose);
		my $my_json_ref =
		&grabjson("${uurl}?screen_name=${uname}&include_rts=true",
			0, 0, $countmaybe, undef, 1);
		&dt_tdisplay($my_json_ref, 'again');
		unless ($mode eq 'w' || $mode eq 'wf') {
			return 0;
		} # else fallthrough
	}
	if ($_ =~ m#^/w(hois|a|again)?\s+(\+\d+\s+)?\@?([^\s]+)#) {
		my $uname = lc($3);
		$uname =~ s/^\@//;
		$readline_completion{'@'.$uname}++ if ($termrl);
		print $stdout "-- synchronous /whois command for $uname\n"
			if ($verbose);
		my $my_json_ref =
		&grabjson("${wurl}?screen_name=${uname}", 0, 0, 0, undef, 1);

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
					print $stdout "\n";
					print $stdout "($exec)\n"
						if ($verbose);
					system($exec);
				}
			}
			print $streamout "\n";
			&userline($my_json_ref, $streamout);
			print $streamout &wwrap(
"\"@{[ &strim(&descape($my_json_ref->{'description'})) ]}\"\n")
			if (length(&strim($my_json_ref->{'description'})));
			if (length($my_json_ref->{'url'})) {
				$sturl = 
				$urlshort = &descape($my_json_ref->{'url'});
				$urlshort =~ s/^\s+//;
				$urlshort =~ s/\s+$//;
				print $streamout "${EM}URL:${OFF}\t\t$urlshort\n";
			}
			print $streamout &wwrap(
"${EM}Location:${OFF}\t@{[ &descape($my_json_ref->{'location'}) ]}\n")
				if (length($my_json_ref->{'location'}));
			print $streamout <<"EOF";
${EM}Picture:${OFF}\t@{[ &descape($my_json_ref->{'profile_image_url'}) ]}

EOF
			unless ($anonymous || $whoami eq $uname) {
				my $g = &grabjson(
	"$frurl?source_screen_name=$whoami&target_screen_name=$uname", 0, 0, 0,
					undef, 1);
				print $streamout &wwrap(
	"${EM}Do you follow${OFF} this user? ... ${EM}$g->{'relationship'}->{'target'}->{'followed_by'}${OFF}\n")
					if (ref($g) eq 'HASH');
				my $g = &grabjson(
	"$frurl?source_screen_name=$uname&target_screen_name=$whoami", 0, 0, 0,
					undef, 1);
				print $streamout &wwrap(
"${EM}Does this user follow${OFF} you? ... ${EM}$g->{'relationship'}->{'target'}->{'followed_by'}${OFF}\n")
					if (ref($g) eq 'HASH');
				print $streamout "\n";
			}
			print $stdout &wwrap(
	"-- %URL% is now $urlshort (/short shortens, /url opens)\n")
				if (defined($sturl));
		}
		return 0;
	}
		
	if (m#^/(df|doesfollow)\s+\@?([^\s]+)$#) {
		if ($anonymous) {
			print $stdout "-- who follows anonymous anyway?\n";
			return 0;
		}
		$_ = "/doesfollow $2 $whoami";
		print $stdout "*** assuming you meant: $_\n";
		# fall through to ...
	}
	if (m#^/(df|doesfollow)\s+\@?([^\s]+)\s+\@?([^\s]+)$#) {
		my $user_a = $2;
		my $user_b = $3;
		if ($user_a =~ m#/# || $user_b =~ m#/#) {
			print $stdout "--- sorry, this won't work on lists.\n";
			return 0;
		}
		my $g = &grabjson(
"${frurl}?source_screen_name=${user_a}&target_screen_name=${user_b}", 0, 0, 0,
				undef, 1);
		if ($msg = &is_json_error($g)) {
			print $stdout <<"EOF";
${MAGENTA}*** warning: server error message received
*** "$ec"${OFF}
EOF
		} elsif ($g->{'relationship'}->{'target'}) {
			print $stdout "--- does $user_a follow ${user_b}? => ";
			print $streamout "$g->{'relationship'}->{'target'}->{'followed_by'}\n"
		} else {
			print $stdout
"-- sorry, bogus server response, try again later.\n";
		}
		return 0;
	}

	# this is dual-headed and supports both lists and regular followers.
	if(s#^/(frs|friends|fos|followers)(\s+\+\d+)?\s*##) {
		my $countmaybe = $2;
		my $mode = $1;
		my $arg = lc($_);
		my $lname = '';
		my $user = '';
		my $what = '';
		$arg =~ s/^@//;
		$who = $arg;
		($who, $lname) = split(m#/#, $arg, 2) if (m#/#);
		if (length($lname) && !length($user) && $anonymous) {
			print $stdout
		"-- you must specify a username for a list when anonymous.\n";
			return 0;
		}
		$who ||= $whoami;
		if (!length($lname)) {
			$what = ($mode eq 'frs' || $mode eq 'friends')
				? "friends" : "followers";
			$mode = ($mode eq 'frs' || $mode eq 'friends')
				? $friendsurl : $followersurl;
		} else {
			$what = ($mode eq 'frs' || $mode eq 'friends')
				? "friends/members" : "followers/subscribers";
			$mode = ($mode eq 'frs' || $mode eq 'friends')
				? $getliurl : $getfliurl;
			$user = "&owner_screen_name=${who}&slug=${lname}";
			$who = "list $who/$lname";
		}
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		$countmaybe ||= 20;

		# we use the undocumented count= support to, by default,
		# reduce the JSON parsing overhead. if we always had to take
		# all 100, we really eat it on parsing. the downside is that,
		# per @episod, the stuff we get is "less" fresh.
		my $countper = ($countmaybe < 100) ? $countmaybe : 100;

		if (!length($lname)) {
			# we need to get IDs, then call lookup. right now it's
			# limited to 5000 because that is the limit for API 1.1
			# without having to do pagination here too. sorry.
			if ($countmaybe >= 5000) {
				print $stdout
"-- who do you think you are? Scoble? currently limited to 4999 or less\n";
				return 0;
			}

			# grab all the IDs
			my $ids_ref = &grabjson(
	"$mode?count=${countmaybe}&screen_name=${who}&stringify_ids=true",
					0, 0, 0, undef, 1);
			return 0 if (!$ids_ref || ref($ids_ref) ne 'HASH' ||
				!$ids_ref->{'ids'});
			$ids_ref = $ids_ref->{'ids'};
			return 0 if (ref($ids_ref) ne 'ARRAY');
			my @ids = @{ $ids_ref };
			@ids = sort { 0+$a <=> 0+$b } @ids;
				# make it somewhat deterministic

			my $dount = &min($countmaybe, scalar(@ids));
			my $swallow = &min(100, $dount);
			my @usarray = undef; shift(@usarray); # force underflow
			my $l_ref = undef;

			# for each block of $countper, emit
			my $printed = 0;

			FFABIO: while ($dount--) {
				if (!scalar(@usarray)) {
					my @next_ids;

					last FFABIO if (!scalar(@ids));

					# if we asked for less than 100, get
					# that. otherwise,
					# get the top 100 off that list (or
					# the list itself, if 100 or less)
					if (scalar(@ids) <= $swallow) {
						@next_ids = @ids;
						@ids = ();			
					} else {
						@next_ids =
							@ids[0..($swallow-1)];
						@ids = @ids[$swallow..$#ids];
					}

					# turn it into a list to pass to
					# lookupidurl and get the list
					$l_ref = &postjson($lookupidurl,
			"user_id=".&url_oauth_sub(join(',', @next_ids)));
					last FFABIO if(ref($l_ref) ne 'ARRAY');
					@usarray = sort
					{ 0+($a->{'id'}) <=> 0+($b->{'id'}) }
						@{ $l_ref };
					last if (!scalar(@usarray));
				}
				&$userhandle(shift(@usarray));
				$printed++;
			}
			print $stdout "-- sorry, no $what found for $who.\n"
				if (!$printed);
			return 0;
		}

		# lists
		# loop through using the cursor until desired number.
		my $cursor = -1; # initial value
		my $printed = 0;
		my $nofetch = 0; 
		my $json_ref = undef;
		my @usarray = undef; shift(@usarray); # force underflow

		# this is a simpler version of the above.
		FABIO: while($countmaybe--) {
			if(!scalar(@usarray)) {
				last FABIO if ($nofetch);
				$json_ref = &grabjson(
			"${mode}?count=${countper}&cursor=${cursor}${user}",
					0, 0, 0, undef, 1);
				@usarray = @{ $json_ref->{'users'} };
				last FABIO if (!scalar(@usarray));
				$cursor = $json_ref->{'next_cursor_str'} ||
					$json_ref->{'next_cursor'} || -1;
				$nofetch = ($cursor < 1) ? 1 : 0;
			}
			&$userhandle(shift(@usarray));
			$printed++;
		}
		print $stdout "-- sorry, no $what found for $who.\n"
			if (!$printed);
		return 0;
	}

	# threading
	if (m#^/th(read)?\s+(\+\d+\s+)?([zZ]?[a-zA-Z]?[0-9]+)$#) {
		my $countmaybe = $2;
		if (length($countmaybe)) {
			print $stdout
			"-- /thread does not (yet) support +count\n";
			return 0;
		}
		my $code = lc($3);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $limit = 9;
		my $id = $tweet->{'retweeted_status'}->{'id_str'} ||
			$tweet->{'in_reply_to_status_id_str'};
		my $thread_ref = [ $tweet ];
		while ($id && $limit) {
			print $stdout "-- thread: fetching $id\n"
				if ($verbose);
			my $next = &grabjson("${idurl}?id=${id}", 0, 0, 0,
				undef, 1);
			$id = 0;
			$limit--;
			if (defined($next) && ref($next) eq 'HASH') {
				push(@{ $thread_ref },
					&fix_geo_api_data($next));
				$id = $next->{'retweeted_status'}->{'id_str'}
					|| $next->{'in_reply_to_status_id_str'}
					|| 0;
			}
		}
		&tdisplay($thread_ref, 'thread', 0, 1); # use the mini-menu
		return 0;
	}

	# pull out entities. this works for DMs and tweets.
	# btw: T.CO IS WACK.
	if (m#^/ent?(ities)? ([dDzZ]?[a-zA-Z]?[0-9]+)$#) {
		my $v;
		my $w;
		my $thing;
		my $genurl;
		my $code = lc($2);
		my $hash;
		if ($code !~ /[a-z]/) {
			# this is an optimization: we don't need to get
			# the old tweet since we're going to fetch it anyway.
			$hash = { "id_str" => $code };
			$thing = "tweet";
			$genurl = $idurl;
		} elsif ($code =~ /^d.[0-9]+$/) {
			$hash = &get_dm($code);
			$thing = "DM";
			$genurl = $dmidurl;
		} else {
			$hash = &get_tweet($code);
			$thing = "tweet";
			$genurl = $idurl;
		}

		if (!defined($hash)) {
			print $stdout "-- no such $thing (yet?): $code\n";
			return 0;
		}

		my $id = $hash->{'id_str'};
		$hash = &grabjson("${genurl}?id=${id}", 0, 0, 0, undef, 1);
		if (!defined($hash) || ref($hash) ne 'HASH') {
		print $stdout "-- failed to get entities from server, sorry\n";
				return 0;
		}

		# if a retweeted status, get the status.
		$hash = $hash->{'retweeted_status'}
			if (defined($hash->{'retweeted_status'}) &&
				ref($hash->{'retweeted_status'}) eq 'HASH');
		
		my $didprint = 0;
		# Twitter puts entities in multiple fields.
		foreach $w (qw(media urls)) {
			my $p = $hash->{'entities'}->{$w};
			next if (!defined($p) || ref($p) ne 'ARRAY');
			foreach $v (@{ $p }) {
				next if (!defined($v) || ref($v) ne 'HASH');
				next if (!length($v->{'url'}) ||
					(!length($v->{'expanded_url'}) &&
					 !length($v->{'media_url'})));
				my $u1 = &descape($v->{'url'});
				my $u2 = &descape($v->{'expanded_url'});
				my $u3 = &descape($v->{'media_url'});
				my $u4 = &descape($v->{'media_url_https'});
				$u2 = $u4 || $u3 || $u2;
				print $stdout "$u1 => $u2\n";
				$urlshort = $u4 || $u3 || $u1;
				$didprint++;
			}
		}
		if ($didprint) {
			print $stdout &wwrap(
	"-- %URL% is now $urlshort (/url opens)\n");
		} else {
			print $stdout "-- no entities or URLs found\n";
		}
		return 0;
	}

	if (($_ eq '/url' || $_ eq '/open') && length($urlshort)) {
		$_ = "/url $urlshort";
		print $stdout "*** assuming you meant %URL%: $_\n";
		# and fall through to ...
	}
	if (m#^/(url|open)\s+(http|gopher|https|ftp)://.+# &&
			s#^/(url|open)\s+##) {
		&openurl($_);
		return 0;
	}
	if (m#^/(url|open) ([dDzZ]?[a-zA-Z]?[0-9]+)$#) {
		my $code = lc($2);
		my $tweet;
		my $genurl = undef;
		$urlshort = undef;

		if ($code =~ /^d/ && length($code) > 2) {
			$tweet = &get_dm($code); # USO!
			if (!defined($tweet)) {
				print $stdout
					"-- no such DM (yet?): $code\n";
				return 0;
			}
			$genurl = $dmidurl;
		} else {
			$tweet = &get_tweet($code);
			if (!defined($tweet)) {
				print $stdout
					"-- no such tweet (yet?): $code\n";
				return 0;
			}
			$genurl = $idurl;
		} 

		# to be TOS-compliant, we must try entities first to use
		# t.co wrapped links. this is a tiny version of /entities.
		unless ($notco) {
			my $id = $tweet->{'retweeted_status'}->{'id_str'}
				|| $tweet->{'id_str'};
			my $hash;

			# only fetch if we have to. if we already fetched
			# because we were given a direct id_str instead of a
			# menu code, then we already have the entities.
			if ($code !~ /^[0-9]+$/) {
				$hash = &grabjson("${genurl}?id=${id}",
					0, 0, 0, undef, 1);
			} else {
				# MAKE MONEY FAST WITH OUR QUICK CACHE PLAN
				$hash = $tweet;
			}
			if (defined($hash) && ref($hash) eq 'HASH') {
				my $w;
				my $v;
				my $didprint = 0;

				# Twitter puts entities in multiple fields.
				foreach $w (qw(media urls)) {
					my $p = $hash->{'entities'}->{$w};
					next if (!defined($p) ||
						ref($p) ne 'ARRAY');
					foreach $v (@{ $p }) {
						next if (!defined($v) ||
							ref($v) ne 'HASH');
						next if (!length($v->{'url'}) ||
							(!length($v->{'expanded_url'}) &&
					 		!length($v->{'media_url'})));
						my $u1 = &descape($v->{'url'});
						&openurl($u1);
						$didprint++;
					}
				}
				print $stdout
				"-- sorry, couldn't find any URL.\n"
					if (!$didprint);
				return 0;
			}
			print $stdout
				"-- unable to use t.co URLs, using fallback\n";
		}
		# that failed, so fall back on the old method.
		my $text = &descape($tweet->{'text'});
		# findallurls
		while ($text
	=~ s#(h?ttp|h?ttps|ftp|gopher)://([a-zA-Z0-9_~/:%\-\+\.\=\&\?\#,]+)##){
# sigh. I HATE YOU TINYARRO.WS
#TODO
# eventually we will have to put a punycode implementation into openurl
# to handle things like Mac OS X's open which don't understand UTF-8 URLs.
# when we do, uncomment this again
#	=~ s#(http|https|ftp|gopher)://([^'\\]+?)('|\\|\s|$)##) {
			my $url = $1 . "://$2";
			$url = "h$url" if ($url =~ /^ttps?:/);
			$url =~ s/[\.\?]$//;
			&openurl($url);
		}
		print $stdout "-- sorry, couldn't find any URL.\n"
			if (!defined($urlshort));
		return 0;
	}

#TODO
	if (s/^\/(favourites|favorites|faves|favs|fl)(\s+\+\d+)?\s*//) {
		my $my_json_ref;
		my $countmaybe = $2;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;

		if (length) {
			$my_json_ref = &grabjson("${favsurl}?screen_name=$_",
				0, 0, $countmaybe, undef, 1);
		} else {
			if ($anonymous) {
				print $stdout
		"-- sorry, you can't haz favourites if you're anonymous.\n";
			} else {
				print $stdout
				"-- synchronous /favourites user command\n"
					if ($verbose);
				$my_json_ref = &grabjson($favsurl, 0, 0,
					$countmaybe, undef, 1);
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
m#^/(un)?f(rt|retweet|a|av|ave|avorite|avourite)? ([zZ]?[a-zA-Z]?[0-9]+)$#) {
		my $mode = $1;
		my $secondmode = $2;
		my $code = lc($3);
		$secondmode = ($secondmode eq 'retweet') ? 'rt' : $secondmode;
		if ($mode eq 'un' && $secondmode eq 'rt') {
			print $stdout
				"-- hmm. seems contradictory. no dice.\n";
			return 0;
		}
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		&cordfav($tweet->{'id_str'}, 1,
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
	if (s#^/([oe]?)r(etweet|t) ([zZ]?[a-zA-Z]?[0-9]+)\s*##) {
		my $mode = $1;
		my $code = lc($3);
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		# use a native retweet unless we can't (or user used /ort /ert)
		unless ($nonewrts || length || length($mode)) {
			# we don't always get rs->text, so we simulate it.
			my $text = &descape($tweet->{'text'});
			$text =~ s/^RT \@[^\s]+:\s+//
				if ($tweet->{'retweeted_status'}->{'id_str'});
			print $stdout "-- status retweeted\n"
				unless(&updatest($text, 1, 0, undef,
					$tweet->{'retweeted_status'}->{'id_str'}
					|| $tweet->{'id_str'}));
			return 0;
		}
		# we can't or user requested /ert /ort
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

        if (m#^/(re)?rts?of?me?(\s+\+\d+)?$# && !$nonewrts) {
#TODO
# when more fields are added, integrate them over the JSON_ref
                my $mode = $1;
                my $countmaybe = $2;
                $countmaybe =~ s/[^\d]//g if (length($countmaybe));
                $countmaybe += 0;
                
                my $my_json_ref = &grabjson($rtsofmeurl, 0, 0, $countmaybe);
                &dt_tdisplay($my_json_ref, "rtsofme");
                if ($mode eq 're') {
                        $_ = '/re'; # and fall through ...
                } else {
                        return 0;
                }
        }
	if (m#^/rts?of\s+([zZ]?[a-zA-Z]?[0-9]+)$# && !$nonewrts) {
		my $code = lc($1);
		my $tweet = &get_tweet($code);
		my $id;

		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		$id = $tweet->{'retweeted_status'}->{'id_str'} ||
			$tweet->{'id_str'};
		if (!$id) {
			print $stdout "-- hmmm, that tweet is major bogus.\n";
			return 0;
		}
		my $url = $rtsbyurl;
		$url =~ s/%I/$id/;
		my $users_ref = &grabjson("$url", 0, 0, 100, undef, 1);
		return if (!defined($users_ref) || ref($users_ref) ne 'ARRAY');
		my $k = scalar(@{ $users_ref });
		if (!$k) {
			print $stdout
				"-- no known retweeters, or they're private.\n";
			return 0;
		}
		my $j;
		foreach $j (@{ $users_ref }) {
			&$userhandle($j->{'user'});
		}
		return 0;
	}

	# enable and disable NewRTs from users
	# we allow this even if newRTs are off from -nonewrts
	if (s#^/rts(on|off)\s+## && length) {
		&rtsonoffuser($_, 1, ($1 eq 'on'));
		return 0;
	}

	if (m#^/del(ete)?\s+([zZ]?[a-zA-Z]?[0-9]+)$#) {
		my $code = lc($2);
		unless ($code =~ /^d[0-9][0-9]+$/) { # this is a DM.
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
		print $stdout "\n";
		$answer = lc(&linein(
	"-- sure you want to delete? (only y or Y is affirmative):"));
		if ($answer ne 'y') {
			print $stdout "-- ok, tweet is NOT deleted.\n";
			return 0;
		}
		$lastpostid = -1 if ($tweet->{'id_str'} == $lastpostid);
		&deletest($tweet->{'id_str'}, 1);
		return 0;
		} # dxxx falls through to ...
	}
	# DM delete version
	if (m#^/del(ete)? ([dD][a-zA-Z]?[0-9]+)$#) {
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
		print $stdout "\n";
		$answer = lc(&linein(
	"-- sure you want to delete? (only y or Y is affirmative):"));
		if ($answer ne 'y') {
			print $stdout "-- ok, DM is NOT deleted.\n";
			return 0;
		}
		&deletedm($dm->{'id_str'}, 1);
		return 0;
	}
	# /deletelast
	if (m#^/de?l?e?t?e?last$#) {
		if (!$lastpostid) {
			print $stdout "-- you haven't posted yet this time!\n";
			return 0;
		}
		if ($lastpostid == -1) {
			print $stdout "-- you already deleted it!\n";
			return 0;
		}
		print $stdout &wwrap(
"-- verify you want to delete: \"$lasttwit\"");
		print $stdout "\n";
		$answer = lc(&linein(
	"-- sure you want to delete? (only y or Y is affirmative):"));
		if ($answer ne 'y') {
			print $stdout "-- ok, tweet is NOT deleted.\n";
			return 0;
		}
		&deletest($lastpostid, 1);
		$lastpostid = -1;
		return 0;
	}

	if (s#^/(v)?re(ply)? ([zZ]?[a-zA-Z]?[0-9]+) ## && length) {
		my $mode = $1;
		my $code = lc($3);
		unless ($code =~ /^d[0-9][0-9]+/) { # this is a DM
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $target = &descape($tweet->{'user'}->{'screen_name'});
		$_ = '@' . $target . " $_";
		unless ($mode eq 'v') {
			$in_reply_to = $tweet->{'id_str'};
			$expected_tweet_ref = $tweet;
		} else {
			$_ = ".$_";
		}
		$readline_completion{'@'.lc($target)}++ if ($termrl);
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
		}  else {
			# this is a DM, reconstruct it
			$_ = "/${mode}re $code $_";
			# and fall through to ...
		}
	}
	# DM reply version
	if (s#^/(dm)?re(ply)? ([dD][a-zA-Z]?[0-9]+) ## && length) {
		my $code = lc($3);
		my $dm = &get_dm($code);
		if (!defined($dm)) {
			print $stdout "-- no such DM (yet?): $code\n";
			return 0;
		}
		# in the future, add DM in_reply_to here
		my $target = &descape($dm->{'sender'}->{'screen_name'});
		$readline_completion{'@'.lc($target)}++ if ($termrl);
		$_ = "/dm $target $_";
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		# and fall through to /dm
	}
	# replyall (based on @FunnelFiasco's extension)
	if (s#^/(v)?r(eply)?(to)?a(ll)? ([zZ]?[a-zA-Z]?[0-9]+) ## && length) {
		my $mode = $1;
		my $code = $5;

		# common code from /vreply
		my $tweet = &get_tweet($code);
		if (!defined($tweet)) {
			print $stdout "-- no such tweet (yet?): $code\n";
			return 0;
		}
		my $target = &descape($tweet->{'user'}->{'screen_name'});
		my $text = $_;
		$_ = '@' . $target;
		unless ($mode eq 'v') {
			$in_reply_to = $tweet->{'id_str'};
			$expected_tweet_ref = $tweet;
		} else {
			$_ = ".$_";
		}

		# don't repeat the target or myself; track other mentions
		my %did_mentions = map { $_ => 1 } (lc($target));
		my $reply_tweet = &descape($tweet->{'text'});

		while($reply_tweet =~ s/\@(\w+)//) {
			my $name = $1;
			my $mame = lc($name); # preserve camel case
			next if ($mame eq $whoami || $did_mentions{$mame}++);
			$_ .= " \@$name";
		}
		$_ .= " $text";

		# add everyone in did_mentions to readline_completion
		grep { $readline_completion{'@'.$_}++ } (keys %did_mentions)
			if ($termrl);

		# and fall through to post
		print $stdout &wwrap("(expanded to \"$_\")");
		print $stdout "\n";
		goto TWEETPRINT; # fugly! FUGLY!
	}

	if (m#^/re(plies)?(\s+\+\d+)?$#) {
		my $countmaybe = $2;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		
		if ($anonymous) {
			print $stdout
		"-- sorry, how can anyone reply to you if you're anonymous?\n";
		} else {
			# we are intentionally not keeping track of "last_re"
			# in this version because it is not automatically
			# updated and may not act as we expect.
			print $stdout "-- synchronous /replies command\n"
				if ($verbose);
			my $my_json_ref = &grabjson($rurl, 0, 0, $countmaybe,
				undef, 1);
			&dt_tdisplay($my_json_ref, "replies");
		}
		return 0;
	}

	# DMs
	if ($_ eq '/dm' || $_ eq '/dmrefresh' || $_ eq '/dmr') {
		&dmthump;
		return 0;
	}
	# /dmsent, /dmagain
	if (m#^/dm(s|sent|a|again)(\s+\+\d+)?$#) {
		my $mode = $1;
		my $countmaybe = $2;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		if ($countmaybe > 999) {
			print $stdout "-- greedy bastard, try +fewer.\n";
			return 0;
		}
		$countmaybe = sprintf("%03i", $countmaybe);
		print $stdout "-- background request sent\n" unless ($synch);
		
		$mode = ($mode =~ /^s/) ? 's' : 'd';
		print C "${mode}mreset${countmaybe}---------\n";
		&sync_semaphore;
		return 0;
	}
	if (s#^/dm \@?([^\s]+)\s+## && length)  {
		return &common_split_post($_, undef, $1);
	}

	# follow and leave users
	if (m#^/(follow|leave|unfollow) \@?([^\s/]+)$#) {
		my $m = $1;
		my $u = lc($2);
		&foruuser($u, 1,
			(($m eq 'follow') ? $followurl : $leaveurl),
			(($m eq 'follow') ? 'started' : 'stopped'));
		return 0;
	}

	# follow and leave lists. this is, frankly, pointless; it does
	# nothing other than to mark you. otherwise, /liston and /listoff
	# actually add lists to your timeline.
	if (m#^/(l?follow|l?leave|l?unfollow) \@?([^\s/]*)/([^\s/]+)$#) {
		my $m = $1;
		my $uname = lc($2);
		my $lname = lc($3);

		if (!length($uname) || $uname eq $whoami) {
			print $stdout &wwrap(
"** you can't mark/unmark yourself as a follower of your own lists!\n");
			print $stdout &wwrap(
"** to add/remove your own lists from your timeline, use /liston /listoff\n");
			return 0;
		}
		if ($m !~ /^l/) {
			print $stdout &wwrap(
"-- to mark/unmark you as a follower of a list, use /lfollow /lleave\n");
			print $stdout &wwrap(
"-- to add/remove your own lists from your timeline, use /liston /listoff\n");
			return 0;
		}

		my $r = &postjson(
			($m ne 'lfollow') ? $delfliurl : $crefliurl,
			"owner_screen_name=$uname&slug=$lname");
		if ($r) {
			my $t = ($m eq 'lfollow') ? "" : "un";
			print $stdout &wwrap(
"*** ok, you are now ${t}marked as a follower of $uname/${lname}.\n");
			my $c = ($t eq 'un') ? "off" : "on";
			$t = ($t eq 'un') ? "remove from" : "add to";
			print $stdout &wwrap(
"--- to also $t your timeline, use /list${c}\n");
		}
		return 0;	
	}

	# block and unblock users
	if (m#^/(block|unblock) \@?([^\s/]+)$#) {
		my $m = $1;
		my $u = lc($2);
		if ($m eq 'block') {	
			$answer = lc(&linein(
	"-- sure you want to block $u? (only y or Y is affirmative):"));
			if ($answer ne 'y') {
				print $stdout "-- ok, $u is NOT blocked.\n";
				return 0;
			}
		}
		&boruuser($u, 1,
			(($m eq 'block') ? $blockurl : $blockdelurl),
			(($m eq 'block') ? 'started' : 'stopped'));
		return 0;
	}

	# list support
	# /withlist (/withlis, /with, /wl)
	if (s#^/(withlist|withlis|withl|with|wl)\s+([^/\s]+)\s+## &&
			($lname=lc($2)) && s/\s*$// && length) {
		my $comm = '';
		my $args = '';
		my $dont_return = 0;
		if ($anonymous) {
			print $stdout "-- no list love for anonymous\n";
			return 0;
		}
		if (/\s+/) {
			($comm, $args) = split(/\s+/, $_, 2);
		} else {
			$comm = $_;
		}
		
		my $return;
		# this is a Twitter bug -- it will not give you the
		# new slug in the returned hash.
		my $state = "modified list $lname (WAIT! then /lists to see new slug)";
		if ($comm eq 'create') {
			my $desc;
			($args, $desc) = split(/\s+/, $args, 2)
				if ($args =~ /\s+/);
			if ($args ne 'public' && $args ne 'private') {
				print $stdout
					"-- must specify public or private\n";
				return 0;
			}
			$state = "created new list $lname (mode $args)";
			$desc = "description=".&url_oauth_sub($desc)."&"
				if (length($desc));
			$return = &postjson($creliurl,
				"${desc}mode=$args&name=$lname");
		} elsif ($comm eq 'private' || $comm eq 'public') {
			$return = &postjson($modifyliurl,
		"mode=$comm&owner_screen_name=${whoami}&slug=${lname}");
		} elsif ($comm eq 'desc' || $comm eq 'description') {
			if (!length($args)) {
				print $stdout "-- $comm needs an argument\n";
				return 0;
			}
			$return = &postjson($modifyliurl,
				"description=".&url_oauth_sub($args).
			"&owner_screen_name=${whoami}&slug=${lname}");
		} elsif ($comm eq 'name') {
			if (!length($args)) {
				print $stdout "-- $comm needs an argument\n";
				return 0;
			}
			$return = &postjson($modifyliurl,
				"name=".&url_oauth_sub($args).
			"&owner_screen_name=${whoami}&slug=${lname}");
			$state = "RENAMED list $lname (WAIT! then /lists to see new slug)";
		} elsif ($comm eq 'add' || $comm eq 'adduser' ||
				($comm eq 'delete' && length($args))) {
			my $u = ($comm eq 'delete') ? $deluliurl : $adduliurl;
			$state = ($comm eq 'delete')
				? "user(s) deleted from list $lname"
				: "user(s) added to list $lname";
			if ($args !~ /,/ || $args =~ /\s+/) {
				1 while ($args =~ s/\s+/,/);
			}
			if ($args =~ /\s*,\s+/ || $args =~ /\s+,\s*/) {
				1 while ($args =~ s/\s+//);
			}
			if (!length($args)) {
				print $stdout "-- illegal/missing argument\n";
				return 0;
			}
			print $stdout "--- warning: user list not checked\n";
			$return = &postjson($u,
			"owner_screen_name=${whoami}".
				"&screen_name=".&url_oauth_sub($args).
				"&slug=${lname}");
		} elsif ($comm eq 'delete' && !length($args)) {
			$state = "deleted list $lname";
			print $stdout
				"-- verify you want to delete list $lname\n";
			my $answer = lc(&linein(
		"-- sure you want to delete? (only y or Y is affirmative):"));
			if ($answer ne 'y') {
				print $stdout "-- ok, list is NOT deleted.\n";
				return 0;
			}
			$return = &postjson($delliurl,
			"owner_screen_name=${whoami}&slug=${lname}");
			if ($return) {
				# check and see if this is in our autolists.
				# if it is, delete it there too.
				my $value = &getvariable('lists');
				&setvariable('lists', $value, 1)
				if ($value=~s#(^|,)${whoami}/${lname}($|,)##);
			}
		} elsif ($comm eq 'list') { # synonym for /list
			$_ = "/list /$lname";
			$dont_return = 1; # and fall through
		} else {
			print $stdout "*** illegal list operation $comm\n";
		}
		if ($return) {
			print $stdout "*** ok, $state\n";
		}
		return 0 unless ($dont_return);
	}
	
	# /a to show statuses in a list
	if (m#^/a(gain)?\s+(\+\d+\s+)?\@?([^\s/]*)/([^\s/]+)#) {
		my $uname = lc($3);
		if ($anonymous && !length($uname)) {
	print $stdout "-- you must specify a username when anonymous.\n";
			return 0;
		}
		my $lname = lc($4);
		my $countmaybe = $2;
		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		$uname ||= $whoami;

		my $my_json_ref = &grabjson(
		"${statusliurl}?owner_screen_name=${uname}&slug=${lname}",
			0, 0, $countmaybe, undef, 1);
		&dt_tdisplay($my_json_ref, "again");
		return 0;
	}

	# /lists command: if @, show their lists. if @?../... show that list.
	# trivially duplicates /frs and /fos for lists
	# also handles /listfos and /listfrs
	if (length($whoami) &&
			(m#^/list?s?$# || m#^/list?f[ro](llower|iend)?s$#)) {
		$_ .= " $whoami";
	}
	if (m#^/lis(t|ts|t?fos|tfollowers|t?frs|tfriends)?\s+(\+\d+\s+)?(\@?[^\s]+)$#) {
		my $mode = $1;
		my $countmaybe = $2;
		my $uname = lc($3);
		my $lname = '';

		$mode = ($mode =~ /^t?fo/) ? 'fo' :
			($mode =~ /^t?fr/) ? 'fr' :
			'';
		$uname =~ s/^\@//;
		($uname, $lname) = split(m#/#, $uname, 2) if ($uname =~ m#/#);
		if ($anonymous && !length($uname) && length($mode)) {
	print $stdout "-- you must specify a username when anonymous.\n";
			return 0;
		}
		$uname ||= $whoami;
		if (length($lname) && length($mode)) {
			print $stdout "-- specify username only\n";
			return 0;
		}

		$countmaybe =~ s/[^\d]//g if (length($countmaybe));
		$countmaybe += 0;
		$countmaybe ||= 20;

		# this is copied from /friends and /followers (q.v.)
		my $countper = ($countmaybe < 100) ? $countmaybe : 100;

		my $cursor = -1; # initial value
		my $nofetch = 0; 
		my $printed = 0;
		my $json_ref = undef;
		my @usarray = undef; shift(@usarray); # force underflow
		my $furl = (length($lname)) ? ($getliurl."?owner_")
			: ($mode eq '') ? ($getlisurl."?")
			: ($mode eq 'fo') ? ($getuliurl."?")
			: ($getufliurl."?");
		$furl .= "screen_name=${uname}";
		$furl .= "&slug=${lname}" if (length($lname));

		LABIO: while($countmaybe--) {
			if(!scalar(@usarray)) {
				last LABIO if ($nofetch);
				$json_ref = &grabjson(
			"${furl}&count=${countper}&cursor=${cursor}", 0, 0, 0,
					undef, 1);
				@usarray = @{ ((length($lname)) ?
					$json_ref->{'users'} :
					$json_ref
				) };
				last LABIO if (!scalar(@usarray));
				if (length($lname)) {
				$cursor = $json_ref->{'next_cursor_str'} ||
					$json_ref->{'next_cursor'} || -1;
				$nofetch = ($cursor < 1) ? 1 : 0;
				} else { $nofetch = 1; }
			}
			my $list_ref = shift(@usarray);
			if (length($lname)) {
				&$userhandle($list_ref);
			} else {
				# lists/list returns their lists AND the
				# ones they subscribe to, different from 1.0.
				# right now we just deal with that.
				#next if ($uname ne
				#	$list_ref->{'user'}->{'screen_name'});

				# listhandle?
				my $list_name =
"\@$list_ref->{'user'}->{'screen_name'}/@{[ &descape($list_ref->{'slug'}) ]}";
				my $list_full_name =
					(length($list_ref->{'name'})) ?
&descape($list_ref->{'name'})."${OFF} ($list_name)" : $list_name;
				my $list_mode =
			(lc(&descape($list_ref->{'mode'})) ne 'public') ?
" ${EM}(@{[ ucfirst(&descape($list_ref->{'mode'})) ]})${OFF}" : "";
				print $streamout <<"EOF";
${CCprompt}$list_full_name${OFF} (f:$list_ref->{'member_count'}/$list_ref->{'subscriber_count'})$list_mode
EOF
			my $desc = &strim(&descape($list_ref->{'description'}));
				my $klen = ($wrap || 79) - 9;
				$klen = 10 if ($klen < 0);
				$desc = substr($desc, 0, $klen)."..."
					if (length($desc) > $klen);
				print $streamout (' "' . $desc . '"' . "\n")
					if (length($desc));
			}
			$printed++;
		}
		if (!$printed) {
			print $stdout ((length($lname))
			? "-- list $uname/$lname does not follow anyone.\n"
				: ($mode eq 'fr')
			? "-- user $uname doesn't follow any lists.\n"
				: ($mode eq 'fo')
			? "-- user $uname isn't followed by any lists.\n"
			: "-- no lists found for user $uname.\n");
		}
		return 0;
	}

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
			"*** over $linelength; autosplitting to \"$l\"\n");
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
			if (length($k) > $linelength);
		print $stdout
		"*** to send this next portion, use %%.\n";
	}
	return 1;
}

# helper functions for the command line processor.
sub add_history {
	my $h = shift;

	@history = (($h, @history)[0..&min(scalar(@history), $maxhist)]);
	if ($termrl) {
		if ($termrl->Features()->{'canSetTopHistory'}) {
			$termrl->settophistory($h);
		} else {
			$termrl->addhistory($h);
		}
	}
}
sub sub_helper {
	my $r = shift;
	my $s = shift;
	my $g = shift;
	my $x;
	my $q = 0;
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
	} elsif ($s eq '*') {
		if ($x != -1 || !length($shadow_history)) {
			print $stdout
				"*** can only %%* on most recent command\n";
			return (0, $_, undef, undef, undef);
		}
		# we assume it's at the end; it's only relevant there
		$proband = substr($shadow_history, length($g)-(2+length($r)));
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

# wrapper function to get a line from the terminal.
sub linein {
	my $prompt = shift;
	my $return;

	return 'y' if ($script);

	$prompt .= " ";
	if ($termrl) {
		$dont_use_counter = 1;
		eval '$termrl->hook_no_counter';
		$return = $termrl->readline($prompt);
		$dont_use_counter = $nocounter;
		eval '$termrl->hook_no_counter';
	} else {
		print $stdout $prompt;
		chomp($return = lc(<$stdin>));
	}
	return $return;
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

# allow foreground process to squelch us
# we have to cover all the various versions of 30/31 signals on various
# systems just in case we are on a system without POSIX.pm. this set should
# cover Linux 2.x/3.x, AIX, Mac OS X, *BSD and Solaris. we have to assert
# these signals before starting streaming, or we may "kill" ourselves by
# accident because it is possible to process a tweet before these are
# operational.
&sigify(sub {
	$suspend_output ^= 1 if ($suspend_output != -1);
	$we_got_signal = 1;
}, qw(USR1 PWR XCPU));
&sigify( sub {
	$suspend_output = -1; $we_got_signal = 1;
}, qw(USR2 SYS UNUSED XFSZ));
&sigify("IGNORE", qw(INT)); # don't let slowpost kill us

# now we can safely initialize streaming
if ($dostream) {
	@events = ();
	$lasteventtime = time();
	&sigify(sub {
		print $stdout "-- killing processes $nursepid $bufferpid\n"
			if ($verbose);
		kill $SIGHUP, $nursepid if ($nursepid);
		kill $SIGHUP, $bufferpid if ($bufferpid);
		kill 9, $curlpid if ($curlpid);
		sleep 1;
		# send myself a shutdown
		kill 9, $nursepid if ($nursepid);
		kill 9, $bufferpid if ($bufferpid);
		kill $SIGTERM, $$;
	}, qw(HUP)); # use SIGHUP etc. from parent process to signal end
	$bufferpid = &start_streaming;
	vec($rin, fileno(STBUF), 1) = 1;
} else {
	&sigify("IGNORE", qw(HUP)); # we only respond to SIGKILL/SIGTERM
}

$interactive = $previous_last_id = $we_got_signal = 0;
$suspend_output = -1;
$stream_failure = 0;
$dm_first_time = ($dmpause) ? 1 : 0;
$stuck_stdin = 0;

# tell the foreground we are ready
kill $SIGUSR2, $parent;

# loop until we are killed or told to stop.
# we receive instructions on stdin, and send data back on our pipe().
for(;;) {
	&$heartbeat;
	&update_effpause;
	$wrapseq = 0; # remember, we don't know when commands are sent.
	&refresh($interactive, $previous_last_id) unless
		(!$effpause && !$interactive);
	$dont_refresh_first_time = 0;
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
DONT_REFRESH:
	# nrvs is tricky with synchronicity
	if (!$synch || ($synch && $synchronous_mode && !$dm_first_time)) {
		$k = length($notify_rate) + length($vs) + length($credlog);
		if ($k) {
			&send_removereadline if ($termrl);
			print $stdout $notify_rate;
			print $stdout $vs;
			print $stdout $credlog;
			$wrapseq = 1;
		}
		$notify_rate = "";
		$vs = "";
		$credlog = "";
	}
	print P "0" if ($synchronous_mode && $interactive);
	&send_repaint if ($termrl);

	# this core loop is tricky. most signals will not restart the call.
	# -- respond to alarms if we are ignoring our timeout.
	# -- do not respond to bogus packets if a signal handler triggered it.
	# -- clear our flag when we detect a signal handler has been called.

	# if our master select is interrupted, we must restart with the
	# appropriate time taken from effpause. however, most implementations
	# don't report timeleft, so we must.
	$restarttime = time() + $effpause;
RESTART_SELECT:
	&send_repaint if ($termrl);
	$interactive = 0;
	$we_got_signal = 0; # acknowledge all signals
	if ($effpause == undef) { # -script and anonymous have no effpause.
		print $stdout "-- select() loops forever\n" if ($verbose);
		$nfound = select($rout = $rin, undef, undef, undef);
	} else {
		$actualtime = $restarttime - time();
		print $stdout "-- select pending ($actualtime sec left)\n"
			if ($superverbose);
		if ($actualtime <= 0) {
			$nfound = 0;
		} else {
			$nfound = select(
				$rout = $rin, undef, undef, $actualtime);
		}
	}
	if ($nfound > 0) {
		my $len;

		# service the streaming socket first, if we have one.
		if ($dostream) {
		if (vec($rout, fileno(STBUF), 1) == 1) {
			my $json_ref;
			my $buf = '';
			my $rbuf;
			my $reads = 0;

			print $stdout "-- data on streaming socket\n"
				if ($superverbose);
			
			# read until we get eight hex digits. this forces the
			# data stream to synchronize.
			# first, however, make sure we actually have valid
			# data, or we sit here and slow down the user.
			sysread(STBUF, $buf, 1);
			if (!length($buf)) {
				# if we get a "ready" but there's actually
				# no data, that means either 1) a signal
				# occurred on the buffer, which we need to
				# ignore, or 2) something killed the
				# buffer, which is unrecoverable. if we keep
				# getting repeated ready-no data situations,
				# it's probably the latter.
				$stream_failure++;
				&screech(<<"EOF") if ($stream_failure > 100);

*** fatal error ***
something killed the streaming buffer process. I can't recover from this.
please restart TTYtter.
EOF
				goto DONESTREAM;
			}
			$stream_failure = 0;
			if ($buf !~ /^[0-9a-fA-F]+$/) {
				print $stdout
	"-- warning: bogus character(s) ".unpack("H*", $buf)."\n"
						if ($superverbose);
				goto DONESTREAM;
			}
			while (length($buf) < 8) {
				# don't read 8 -- read 1. that means we can
				# skip trailing garbage without a window.
				sysread(STBUF, $rbuf, 1);
				$reads++;
				if ($rbuf =~ /[0-9a-fA-F]/) {
					$buf .= $rbuf;
					$reads = 0;
				} else {
					print $stdout
	"-- warning: bogus character(s) ".unpack("H*", $rbuf)."\n"
						if ($superverbose);
					$buf = ''
					if (length($rbuf)); # bogus data
				}
				print $stdout
	"-- master, I am stuck: $reads reads on stream and no valid data\n"
				if ($reads > 0 && ($reads % 1000) == 0);
			}
			print $stdout "-- length packet: $buf\n"
				if ($superverbose);
			$len = hex($buf);
			$buf = '';
			while (length($buf) < $len) {
				sysread(STBUF, $rbuf, ($len-length($buf)));
				$buf .= $rbuf;
			}

			print $stdout
	"-- streaming data ($len) --\n$buf\n-- streaming data --\n\n" 
				if ($superverbose);
			$json_ref = &parsejson($buf);
			push(@events, $json_ref);

			if (scalar(@events) > $eventbuf || (scalar(@events) &&
					(time()-$lasteventtime) > $effpause)){
				sleep 5 while ($suspend_output > 0);
				&streamevents(@events);
				&send_repaint if ($termrl);
				@events = ();
				$lasteventtime = time();
			}
		}
		DONESTREAM: print $stdout "-- done with streaming events\n"
			if ($superverbose);
		}

		# then, check if there is data on our control socket.
		# command packets should always be (initially) 20 characters.
		# if we come up short, it's either a bug, signal or timeout.
		if ($we_got_signal) {
			goto RESTART_SELECT;
		}
		goto RESTART_SELECT if(vec($rout, fileno(STDIN), 1) != 1);
		print $stdout "-- waiting for data ", scalar localtime, "\n"
			if ($superverbose);
		if(sysread(STDIN, $rout, 20) != 20) {
			# if we get repeated "ready" but no data on STDIN,
			# like the streaming buffer, we probably lost our
			# IPC and we should die here.
			if (++$stuck_stdin > 100) {
				print $stdout "parent is dead; we die too\n";
				kill 9,$$;
			}
			goto RESTART_SELECT;
		}
		$stuck_stdin = 0;
		# background communications central command code
		# we received a command from the console, so let's look at it.
		print $stdout "-- command received ", scalar
				localtime, " $rout" if ($verbose);
		if ($rout =~ /^rsga/) {
			$suspend_output = 0; # reset our status
			goto RESTART_SELECT;
		} elsif ($rout =~ /^pipet (..)/) {
			my $key = &get_tweet($1);
			my $ms = $key->{'menu_select'} || 'XX';
			my $ds = $key->{'created_at'} || 'argh, no created_at';
			$ds =~ s/\s/_/g;
			my $src = $key->{'source'} || 'unknown';
			$src =~ s/\|//g; # shouldn't be any anyway.
			$key = substr(( "$ms ".($key->{'id_str'})." ".
		($key->{'in_reply_to_status_id_str'})." ".
		($key->{'retweeted_status'}->{'id_str'})." ".
		($key->{'user'}->{'geo_enabled'} || "false") . " ".
		($key->{'geo'}->{'coordinates'}->[0]). " ".
		($key->{'geo'}->{'coordinates'}->[1]). " ".
		$key->{'place'}->{'id'} . " ".
		$key->{'place'}->{'country_code'} ." ".
		$key->{'place'}->{'place_type'} . " ".
		unpack("${pack_magic}H*", $key->{'place'}->{'full_name'})." ".
		$key->{'tag'}->{'type'}. " ". # NO SPACES!
		unpack("${pack_magic}H*", $key->{'tag'}->{'payload'}). " ".
		($key->{'retweet_count'} || "0") . " " .
		$key->{'user'}->{'screen_name'}." $ds $src|".
			unpack("${pack_magic}H*", $key->{'text'}).
			$space_pad), 0, 1024);
			print P $key;
			goto RESTART_SELECT;
		} elsif ($rout =~ /^piped (..)/) {
			my $key = $dm_store_hash{$1};
			my $ms = $key->{'menu_select'} || 'XX';
			my $ds = $key->{'created_at'} || 'argh, no created_at';
			$ds =~ s/\s/_/g;
			$key = substr(( "$ms ".($key->{'id_str'})." ".
		$key->{'sender'}->{'screen_name'}." $ds ".
			unpack("${pack_magic}H*", $key->{'text'}).
			$space_pad), 0, 1024);
			print P $key;
			goto RESTART_SELECT;
		} elsif ($rout =~ /^ki ([^\s]+) /) {
			my $key = $1;
			my $module;
			sysread(STDIN, $module, 1024);
			$module =~ s/\s+$//;
			$module = pack("H*", $module);
			print $stdout "-- fetch for module $module key $key\n"
				if ($verbose);
			print P substr(unpack("${pack_magic}H*",
				$master_store->{$module}->{$key}).$space_pad,
					0, 1024);
			goto RESTART_SELECT;
		} elsif ($rout =~ /^kn ([^\s]+) /) {
			my $key = $1;
			my $module;
			sysread(STDIN, $module, 1024);
			$module =~ s/\s+$//;
			$module = pack("H*", $module);
			print $stdout "-- nulled module $module key $key\n"
				if ($verbose);
			$master_store->{$module}->{$key} = undef;
			goto RESTART_SELECT;
		} elsif ($rout =~ /^ko ([^\s]+) /) {
			my $key = $1;
			my $value;
			my $module;
			sysread(STDIN, $module, 1024);
			$module =~ s/\s+$//;
			$module = pack("H*", $module);
			sysread(STDIN, $value, 1024);
			$value =~ s/\s+$//;
			print $stdout
				"-- set module $module key $key = $value\n"
				if ($verbose);
			$master_store->{$module}->{$key} = pack("H*", $value);
			goto RESTART_SELECT;
		} elsif ($rout =~ /^sync/) {
			print $stdout "-- synced; exiting at ",
					scalar localtime, "\n"
				if ($verbose);
			exit $laststatus;
		} elsif ($rout =~ /^synm/) {
			$first_synch = $synchronous_mode = 1;
			print $stdout "-- background is now synchronous\n"
				if ($verbose);
		} elsif ($rout =~ /([\=\?\+])([^ ]+)/) {
			$comm = $1;
			$key =$2;
			if ($comm eq '?') {
				print P substr("${$key}$space_pad", 0, 1024);
			} else {
				sysread(STDIN, $value, 1024);
				$value =~ s/\s+$//;
				$interactive = ($comm eq '+') ? 0 : 1;
				if ($key eq 'tquery') {
					print $stdout
					"*** custom query installed\n"
						if ($interactive || $verbose);
					print $stdout
					"$value" if ($verbose);
					@trackstrings = ();
					# already URL encoded
					push(@trackstrings, $value);
				} else {
					$$key = $value;
					print $stdout
					"*** changed: $key => $$key\n"
						if ($interactive || $verbose);

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
					&list_compile
						if ($key eq 'lists');
					&filterflags_compile
						if ($key eq 'filterflags');
					$filterrts_sub =
						&filteruserlist_compile(
							$filterrts_sub, $value)
						if ($key eq 'filterrts');
					$filterusers_sub =
						&filteruserlist_compile(
							$filterusers_sub,$value)
						if ($key eq 'filterusers');
					$filteratonly_sub =
						&filteruserlist_compile(
							$filteratonly_sub,
								$value)
						if ($key eq 'filteratonly');
					&filterats_compile
						if ($key eq 'filterats');
				}
			}
			goto RESTART_SELECT;
		} else {
			$interactive = 1;
			($fetchwanted = 0+$1, $fetch_id = 0, $last_id = 0)
				if ($rout =~ /^reset(\d+)/);
			($dmfetchwanted = 0+$1, $last_dm = 0)
				if ($rout =~ /^dmreset(\d+)/);
			if ($rout =~ /^smreset/) { # /dmsent
				$dmfetchwanted = 0+$1
					if ($rout =~ /(\d+)/);
				&dmrefresh(1, 1);
				&send_repaint if ($termrl);
				# we do not want to force a refresh.
				goto DONT_REFRESH;
			}
			if ($rout =~ /^dm/) {
				&dmrefresh($interactive);
				&send_repaint if ($termrl);
				$dmcount = $dmpause;
				goto DONT_REFRESH;
			}
		}
	} else {
		if ($we_got_signal || $nfound == -1) {
			# we need to restart the call. we might be waiting
			# longer, but this is unavoidable.
			goto RESTART_SELECT;
		}
		print $stdout
"-- routine refresh (effpause = $effpause, $dmcount to next dm) ",
			scalar localtime, "\n" if ($verbose);
	}
}

#### internal implementation functions for the twitter API. DON'T ALTER ####

# manage automatic rate limiting by checking our max.
#TODO
# autoslowdown as we run out of requests, then speed up when hour
# has passed.
sub update_effpause {
	return ($effpause = undef) if ($script); # for select()
	if ($pause ne 'auto' && $noratelimit) {
		$effpause = (0+$pause) || undef;
		return;
	}
	$effpause = (0+$pause) || undef
		 if ($anonymous || (!$pause && $pause ne 'auto'));
	if (!$rate_limit_next && !$anonymous && ($pause > 0 ||
		$pause eq 'auto')) {

		# Twitter 1.0 used a simple remaining_hits and
		# hourly_limit. 1.1 uses multiple rate endpoints. we
		# are only interested in certain specific ones, though
		# we currently fetch them all and we might use more later.

		$rate_limit_next = 5;
		$rate_limit_ref = &grabjson($rlurl, 0, 0, 0, undef, 1);

		if (defined $rate_limit_ref &&
				ref($rate_limit_ref) eq 'HASH') {

		# of mentions_timeline, home_timeline and search/tweets,
		# choose the MOST restrictive and normalize that.

			$rate_limit_left = &min(
0+$rate_limit_ref->{'resources'}->{'statuses'}->{'\\/statuses\\/home_timeline'}->{'remaining'},
				&min(
0+$rate_limit_ref->{'resources'}->{'statuses'}->{'\\/statuses\\/mentions_timeline'}->{'remaining'},
0+$rate_limit_ref->{'resources'}->{'search'}->{'\\/search\\/tweets'}->{'remaining'}));
			$rate_limit_rate = &min(
0+$rate_limit_ref->{'resources'}->{'statuses'}->{'\\/statuses\\/home_timeline'}->{'limit'},
				&min(
0+$rate_limit_ref->{'resources'}->{'statuses'}->{'\\/statuses\\/mentions_timeline'}->{'limit'},
0+$rate_limit_ref->{'resources'}->{'search'}->{'\\/search\\/tweets'}->{'limit'}));
			if ($rate_limit_left < 3 && $rate_limit_rate) {
				$estring = 
"*** warning: API rate limit imminent";
				if ($pause eq 'auto') {
					$estring .=
				"; temporarily halting autofetch";
					$effpause = 0;
				}
				&$exception(5, "$estring\n");
			} else {
				if ($pause eq 'auto') {

# the new rate limits do not require us to reduce our fetching for mentions,
# direct messages or search, because they pull from different buckets, and
# their rate limits are roughly the same.
					$effpause = 5*$rate_limit_rate;
					# this will usually be 75s
# for lists, however, we have to drain the list bucket faster, so for every
# list AFTER THE FIRST ONE we subscribe to, add rate_limit_rate to slow.
# for search, it has 180 requests, so we don't care so much. if this
# changes later, we will probably need something similar to this for
# cases where the search array is > 1.
					$effpause += ((scalar(@listlist)-1)*
						$rate_limit_rate)
					if (scalar(@listlist) > 1);

					if (!$effpause) {
						print $stdout
"-- rate limit rate failure: using 180 second fallback\n";
						$effpause = 180;
					}

					# we don't go under sixty.
					$effpause = 60 if ($effpause < 60);
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
"-- notification: API rate limit is${adverb} ${rate_limit_rate} req/15min\n"
				if ($last_rate_limit != $rate_limit_rate);
			$last_rate_limit = $rate_limit_rate;
		} else {
			$rate_limit_next = 0;
			$effpause = ($pause eq 'auto') ? 180 : 0+$pause;
			print $stdout
"-- failed to fetch rate limit (rate is $effpause sec)\n"
				if ($verbose);
		}
	} else {
		$rate_limit_next-- unless ($anonymous);
	}
}

# streaming API support routines

### INITIALIZE STREAMING
### spin off a nurse process to proxy data from curl, and a buffer process
### to protect the background process from signals curl may generate.

sub start_streaming {
	$bufferpid = 0;
	unless ($streamtest) {
		if($bufferpid = open(STBUF, "-|")) {
			# streaming processes initialized
			return $bufferpid;
		}
	}

	# now within buffer process
	# verbosity does not work here, so force both off.
	$verbose = 0;
	$superverbose = 0;

	$0 = "TTYtter (streaming buffer thread)";
	$in_buffer = 1;
	# set up signal handlers
	$streampid = 0;
	&sigify(sub {
		# in an earlier version we wrote a disconnect packet to the
		# pipe in this handler. THIS IS NOT SAFE on certain OS/Perl
		# combinations. I moved this down to the HELLOAGAINNURSE loop,
		# or otherwise you get random seg faults.
		$i = $streampid;
		$streampid = 0;
		waitpid $i, 0 if ($i);
	}, qw(CHLD PIPE));
	&sigify(sub {
		$i = $streampid;
		$streampid = 0; # suppress handler above
		kill ($SIGHUP, $i) if ($i);
		waitpid $i, 0 if ($i);
		kill 9, $curlpid if ($curlpid && !$i);
		kill 9, $$;
	}, qw(HUP TERM));
	&sigify("IGNORE", qw(INT));

	$packets_read = 0; # part of exponential backoff
	$wait_time = 0;

	# open the nurse process
	HELLOAGAINNURSE: $w = "{\"packet\" : \"connect\", \"payload\" : {} }";
	select(STDOUT); $|++;
	printf STDOUT ("%08x%s", length($w), $w);
	close(NURSE);
	if (!$packets_read) { $wait_time += (($wait_time) ? $wait_time : 1) }
		else { $wait_time = 0; }
	$packets_read = 0;
	$wait_time = ($wait_time > 60) ? 60 : $wait_time;
	if ($streampid = open(NURSE, "-|")) {
		# within the buffer process
		select(NURSE); $|++; select(STDOUT);
		my $rin = '';
		vec($rin,fileno(NURSE),1) = 1;
		my $datasize = 0;
		my $buf = '';
		my $cuf = '';
		my $duf = '';

		# read the curlpid from the stream
		read(NURSE, $curlpax, 8);
		$curlpid = hex($curlpax);

		# if we are testing the socket, just emit data.
		if ($streamtest) {
			my $c;

			for(;;) {
				sysread(NURSE, $c, 1);
				print STDOUT $c;
			}
		}
		HELLONURSE: while(1) {
			# restart nurse process if it/curl died
			goto HELLOAGAINNURSE if(!$streampid);

			# read a line of text (hopefully numbers)
			chomp($buf = <NURSE>);
			# should be nothing but digits and whitespace.
			# if anything else, we're getting garbage, and we
			# should reconnect.
			if ($buf =~ /[^0-9\r\l\n\s]+/s) {
				close(NURSE);
				kill 9, $streampid if ($streampid);
					# and SIGCHLD will reap
				kill 9, $curlpid if ($curlpid);
				goto HELLOAGAINNURSE;
			}
			$datasize = 0+$buf;
			next HELLONURSE if (!$datasize);
			$datasize--;
			read(NURSE, $duf, $datasize);
			# don't send broken entries
			next HELLONURSE if (length($duf) < $datasize);
			# yank out all \r\n
			1 while $duf =~ s/[\r\n]//g;
			$duf = "{ \"packet\" : \"data\", \"pid\" : \"$streampid\", \"curlpid\" : \"$curlpid\", \"payload\" : $duf }";
			printf STDOUT ("%08x%s", length($duf), $duf);
			$packets_read++;
		}
	} else {
		# within the nurse process
		$0 = "TTYtter (waiting $wait_time sec to connect to stream)";
		sleep $wait_time;
		$curlpid = 0;
		$replarg = ($streamallreplies) ? '&replies=all' : '';
		&sigify(sub {
			kill 9, $curlpid if ($curlpid);
			waitpid $curlpid, 0 unless (!$curlpid);
			$curlpid = 0;
			kill 9, $$;
		}, qw(CHLD PIPE));
		&sigify(sub {
			kill 9, $curlpid if ($curlpid);
		}, qw(INT HUP TERM)); # which will cascade into SIGCHLD
		($comm, $args, $data) = &$stringify_args($baseagent,
			[ $streamurl, "delimited=length${replarg}" ],
			undef, undef,
			'-s',
			'-A', "TTYtter_Streaming/$TTYtter_VERSION",
			'-N',
			'-H', 'Expect:');
		($curlpid = open(K, "|$comm")) || die("failed curl: $!\n");
		printf STDOUT ("%08x", $curlpid);

		# "DIE QUICKLY"
		$0 = "TTYtter (streaming socket nurse thread to ${curlpid})";

		select(K); $|++; select(STDOUT); $|++;
		print K "$args\n";
		close(K);
		waitpid $curlpid, 0;
		$curlpid = 0;
		kill 9, $$;
	}
}

# handle a set of events acquired from the streaming socket.
# ordinarily only the background is calling this.
sub streamevents {
	my (@events) = (@_);
	my $w;
	my @x;
	my %k; # need temporary dedupe

	foreach $w (@events) {
		my $tmp;

		# don't send non-data events (yet).
		next if ($w->{'packet'} ne 'data');

		# try to get PID information if available for faster shutdown
		$nnursepid = 0+($w->{'pid'});
		if ($nnursepid != $nursepid) {
			$nursepid = $nnursepid;
			print $stdout
"-- got new pid of streaming nurse socket process: $nursepid\n"
				if ($verbose);
		}
		$ncurlpid = 0+($w->{'curlpid'});
		if ($ncurlpid != $curlpid) {
			$curlpid = $ncurlpid;
			print $stdout
"-- got new pid of streaming curl process: $ncurlpid\n"
				if ($verbose);
		}

		# we don't use this (yet).
		next if ($w->{'payload'}->{'friends'});

		sleep 5 while ($suspend_output > 0);

		# dispatch tweets
		if ($w->{'payload'}->{'text'} && !$notimeline) {
			# normalize the tweet first.
			my $payload = &normalizejson($w->{'payload'});
			my $sid = $payload->{'id_str'};

			$payload->{'tag'}->{'type'} = 'timeline';
			$payload->{'tag'}->{'payload'} = 'stream';

			# filter replies from streaming socket if the
			# user requested it. use $tweettype to determine
			# this so the user can interpose custom logic.
			if ($nostreamreplies) {
				my $sn = &descape(
					$payload->{'user'}->{'screen_name'});
				my $text = &descape($payload->{'text'});
				next if (&$tweettype($payload, $sn, $text) eq
					'reply');
			}

			# finally, filter everything else and dedupe.
			unless (length($id_cache{$sid}) ||
					$filter_next{$sid} ||
						$k{$sid}) {
				&tdisplay([ $payload ]);
				$k{$sid}++;
			}

			# roll *_id so that we don't do unnecessary work	
			# testing the API. don't roll fetch_id, search uses
			# it. don't roll if last_id was zero, because that
			# means we are streaming *before* the API backfetch.
			$last_id = $sid unless (!$last_id);
		}

		# dispatch DMs
		elsif (($tmp = $w->{'payload'}->{'direct_message'}) &&
				$dmpause) {
			&dmrefresh(0, 0, [ $tmp ]);
			# don't roll last_dm yet.
		}

		# must be an event. see if standardevent can make sense of it.
		elsif (!$notimeline) {
			$w = $w->{'payload'};
			my $sou_sn =
				&descape($w->{'source'}->{'screen_name'});
			if (!length($sou_sn) || !$filterusers_sub ||
					!&$filterusers_sub($sou_sn)) {
				&send_removereadline if ($termrl);
				&$eventhandle($w);
				$wrapseq = 1;
				&send_repaint if ($termrl);
			}
		}
	}
}

# REST API support
#
# thump for timeline
# THIS MUST ONLY BE RUN BY THE BACKGROUND.
sub refresh {
	my $interactive = shift;
	my $relative_last_id = shift;
	my $k;
	my $my_json_ref = undef;
	my $i;
	my @streams = ();
	my $dont_roll_back_too_far = 0;

	# this mixes all the tweet streams (timeline, hashtags, replies
	# and lists) into a single unified data river.
	# backload can be zero, but this will still work since &grabjson
	# sees a count of zero as "default."

	# first, get my own timeline
	# note that anonymous has no timeline (but they can sample the
	# stream)
	unless ($notimeline || $anonymous) {
		# in streaming mode, use $last_id
		# in API mode, use $fetch_id
		my $base_json_ref = &grabjson($url,
			($dostream) ? $last_id : $fetch_id,
			0,
			(($last_id) ? 250 : $fetchwanted || $backload), {
				"type" => "timeline",
				"payload" => "api"
			}, 1);
		# if I can't get my own timeline, ABORT! highest priority!
		return if (!defined($base_json_ref) ||
			ref($base_json_ref) ne 'ARRAY');

		# we have to filter against the ID cache right now, because
		# we might not have any other streams!
		if ($fetch_id && $last_id) {
			$my_json_ref = [];
			my $l;
			my %k; # need temporary dedupe
			foreach $l (@{ $base_json_ref }) {
				unless (length($id_cache{$l->{'id_str'}}) ||
						$filter_next{$l->{'id_str'}} ||
						$k{$l->{'id_str'}}) {
					push(@{ $my_json_ref }, $l);
					$k{$l->{'id_str'}}++;
				}
			}
		} else {
			$my_json_ref = $base_json_ref;
		}
	}

	# add stream for replies, if requested
	if ($mentions) {
		# same thing
		my $r = &grabjson($rurl,
			($dostream && !$nostreamreplies) ? $last_id : $fetch_id,
			0,
			(($last_id) ? 250
			: $fetchwanted || $backload), {
				"type" => "reply",
				"payload" => ""
			}, 1);
		push(@streams, $r)
			if (defined($r) &&
				ref($r) eq 'ARRAY' &&
				scalar(@{ $r }));
	}

	# next handle hashtags and tracktags
	# failure here does not abort, because search may be down independently
	# of the main timeline.
	if (!$notrack && scalar(@trackstrings)) {
		my $r;
		my $k;
		my $l;

		if (!$last_id) {
			$l = &min($backload, $searchhits);
		} else {
			$l = (($fetchwanted) ? $fetchwanted :
				&max(100, $searchhits));
		}
		# temporarily squelch server complaints (see below)
		$muffle_server_messages = 1 unless ($verbose);
		foreach $k (@trackstrings) {
		# use fetch_id here in both modes.
		$r = &grabjson("$queryurl?${k}&result_type=recent",
				$fetch_id, 0, $l, {
					"type" => "search",
					"payload" => $k
				}, 1);
		# depending on the state of the search API, we might be using
		# a bogus search ID that is too far back. so if this fails,
		# try again with last_id, but not if we're streaming (it
		# will always fetch zero).
			if (!defined($r) || ref($r) ne 'ARRAY' || !$dostream) {
		print $stdout "-- search retry $k attempted with last_id\n"
				if ($verbose);
		$r = &grabjson("$queryurl?${k}&result_type=recent",
				$last_id, 0, $l, {
					"type" => "search",
					"payload" => $k
				}, 1);
				$dont_roll_back_too_far = 1;
			}
		# or maybe not even then?
			if (!defined($r) || ref($r) ne 'ARRAY') {
		print $stdout "-- search retry $k attempted with zero!\n"
				if ($verbose);
		$r = &grabjson("$queryurl?${k}&result_type=recent",
				0, 0, $l, {
					"type" => "search",
					"payload" => $k
				}, 1);
				$dont_roll_back_too_far = 1;
			}
			push(@streams, $r)
				if (defined($r) &&
					ref($r) eq 'ARRAY' &&
					scalar(@{ $r }));
		}
		$muffle_server_messages = 0;
	}

	# add stream for lists we have on with /set lists, and tag it with
	# the list.
	if (scalar(@listlist)) {
		foreach $k (@listlist) {
			# always use fetch_id
			my $r = &grabjson(
		"${statusliurl}?owner_screen_name=".$k->[0].'&slug='.$k->[1],
				$fetch_id, 0,
				(($last_id) ? 250 : $fetchwanted), {
					"type" => "list",
					"payload" => ($k->[0] ne $whoami) ?
						"$k->[0]/$k->[1]" :
						"$k->[1]"
				}, 1);
			push(@streams, $r)
				if (defined($r) && ref($r) eq 'ARRAY' &&
					scalar(@{ $r }));
		}
	}

	$fetchwanted = 0; # done with that.
	# now, streamix all the streams into my_json_ref, discarding duplicates
	# a simple hash lookup is no good; it has to be iterative. because of
	# that, we might as well just splice it in here and save a sort later.
	# the streammix logic is unnecessarily complex, probably.
	# remember, the most recent tweets are FIRST.
	if (scalar(@streams)) {
		my $j;
		my $k;
		my $l = scalar(@{ $my_json_ref });
		my $m;
		my $n;

		foreach $n (@streams) {
			SMIX0: foreach $j (@{ $n }) {
				my $id = $j->{'id_str'}; # for ease of use
				# possible to happen if search tryhard is on
				next SMIX0 if ($id < $fetch_id);

				# filter this lot against the id cache
				# and any tweets we just filtered.
				next SMIX0 if (length($id_cache{$id}) &&
					$fetch_id);
				next SMIX0 if ($filter_next{$id} &&
					$fetch_id);

				if (!$l) { # degenerate case
					push (@{ $my_json_ref }, $j);
					$l++;
					next SMIX0;
				}

				# find the same ID, or one just before,
				# and splice in
				$m = -1;
				SMIX1: for($i=0; $i<$l; $i++) {
					next SMIX0 # it's a duplicate
					if($my_json_ref->[$i]->{'id_str'} == $id);
					if($my_json_ref->[$i]->{'id_str'} < $id) {
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
	%filter_next = ();

	# fetch_id gyration. initially start with last_id, then roll. we
	# want to keep a window, though, so we try to pick a sensible value
	# that doesn't fetch too much but includes some overlap. we can't
	# do computations on the ID itself, because it's "opaque."
	$fetch_id = 0 if ($last_id == 0);
	&send_removereadline if ($termrl);
	if ($dont_refresh_first_time) {
		$last_id = &max($my_json_ref->[0]->{'id_str'}, $last_id);
	} else {
		($last_id, $crap) =
			&tdisplay($my_json_ref, undef, $relative_last_id);
	}
	my $new_fi = (scalar(@{ $my_json_ref })) ?
		$my_json_ref->[(scalar(@{ $my_json_ref })-1)]->{'id_str'} :
		'';
	# try to widen the window to a "reasonable amount"
	$fetch_id = ($fetch_id == 0) ? $last_id :
		(length($new_fi) && $new_fi ne $last_id
			&& $new_fi > $fetch_id) ? $new_fi :
		($relative_last_id > 0 && $relative_last_id ne $last_id &&
				$relative_last_id > $fetch_id) ?
			$relative_last_id : $fetch_id;
	
	print $stdout
"-- last_id $last_id, fetch_id $fetch_id, rollback $relative_last_id\n".
"-- (@{[ scalar(keys %id_cache) ]} cached)\n"
		if ($verbose);
	&send_removereadline if ($termrl);
	&$conclude;
	$wrapseq = 1;
	&send_repaint if ($termrl);
} 

# convenience function for filters (see below)
sub killtw { my $j = shift; $filtered++; $filter_next{$j->{'id_str'}}++
		if ($is_background); }

# handle (i.e., display) an array of tweets in standard format
sub tdisplay { # used by both synchronous /again and asynchronous refreshes
	my $my_json_ref = shift;
	my $class = shift;
	my $relative_last_id = shift;
	my $mini_id = shift;
	my $printed = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $save_counter = -1;
	my $i;
	my $j;

	if ($disp_max) { # null list may be valid if we get code 304
		unless ($is_background) { # reset store hash each console
			if ($mini_id) {
#TODO
# generalize this at some point instead of hardcoded menu codes
# maybe an ma0-mz9?
				$save_counter = $tweet_counter;
				$tweet_counter = $mini_split;
				for(0..9) {
					undef $store_hash{"zz$_"};
				}
			}# else {
			#	$tweet_counter = $back_split;
			#	%store_hash = ();
			#}
		}
		for($i = $disp_max; $i > 0; $i--) {
			my $g = ($i-1);
			$j = $my_json_ref->[$g];
			my $id = $j->{'id_str'};
			my $sn = $j->{'user'}->{'screen_name'};
			next if (!length($sn));
			$sn = lc(&descape($sn));

			#
			# implement filter stages:
			# do so in such a way that we can toss tweets out
			# quickly, because multiple layers eat CPU!
			#

			# zeroth: if this is us, do not filter.
			if (($anonymous || $sn ne $whoami) && !($nofilter)) {

			# first, filterusers. this is very fast.
			# do for the tweet
			(&killtw($j), next) if
				($filterusers_sub &&
				&$filterusers_sub($sn));
			# and if the tweet has a retweeted status, do for
			# that.
			(&killtw($j), next) if
				($j->{'retweeted_status'} &&
				 $filterusers_sub &&
				&$filterusers_sub(lc(&descape($j->
					{'retweeted_status'}->
					{'user'}->{'screen_name'}))));

			# second, filterrts. this is almost as fast.
			(&killtw($j), next) if
				($filterrts_sub &&
				 length($j->{'retweeted_status'}->{'id_str'})&&
				&$filterrts_sub($sn));

			# third, filteratonly. this has a fast case and a
			# slow case.
			my $tex = &descape($j->{'text'});
			(&killtw($j), next) if
				($filteratonly_sub &&
				&$filteratonly_sub($sn) && # fast test
				 $tex !~ /\@$whoami\b/i);  # slow test

			# fourth, filterats. this is somewhat expensive.
			(&killtw($j), next) if ($filterats_c &&
				&$filterats_c($tex));
			
			# finally, classic -filter. this is the most expensive.
			(&killtw($j), next) if ($filter_c && &$filter_c($tex));
			}

			# damn it, user may actually want this tweet.
			# assign menu codes and place into caches
			$key = (($is_background) ? '' : 'z' ).
				substr($alphabet, $tweet_counter/10, 1) .
				$tweet_counter % 10;
			$tweet_counter = 
				($tweet_counter == 259) ? $mini_split :
				($tweet_counter == ($mini_split - 1))
					? 0 : ($tweet_counter+1);
			$j->{'menu_select'} = $key;
			$key = lc($key);

			# recover ID cache memory: find the old ID with this
			# menu code and remove it, then add the new one
			# except if this is the foreground. we don't use this
			# in the foreground.
			if ($is_background) {
				delete $id_cache{$store_hash{$key}->{'id_str'}};
				$id_cache{$id} = $key;
			}

			# finally store in menu code cache
			$store_hash{$key} = $j;

			sleep 5 while ($suspend_output > 0);
			&send_removereadline if ($termrl);
			$wrapseq++;

			$printed += scalar(&$handle($j,
			($class || (($id <= $relative_last_id) ? 'again' :
				undef))));
		}
	}
	$tweet_counter = $save_counter if ($save_counter > -1);
	sleep 5 while ($suspend_output > 0);
	&$exception(6,"*** warning: more tweets than menu codes; truncated\n")
		if (scalar(@{ $my_json_ref }) > $print_max);
	if (($interactive || $verbose) && !$printed) {
		&send_removereadline if ($termrl);
		print $stdout "-- sorry, nothing to display.\n";
		$wrapseq = 1;
	}
	return (&max($my_json_ref->[0]->{'id_str'}, $last_id), $j);
}

sub dt_tdisplay {
	my $my_json_ref = shift;
	my $class = shift;
	if (defined($my_json_ref)
		&& ref($my_json_ref) eq 'ARRAY'
			&& scalar(@{ $my_json_ref })) {
		my ($crap, $art) = &tdisplay($my_json_ref, $class);
		unless ($timestamp) {
			my ($time, $ts1) = &$wraptime(
$my_json_ref->[(&min($print_max,scalar(@{ $my_json_ref }))-1)]->{'created_at'});
			my ($time, $ts2) = &$wraptime($art->{'created_at'});
			print $stdout &wwrap(
				"-- update covers $ts1 thru $ts2\n");
		}
		&$conclude;
	}
}

# thump for DMs
sub dmrefresh {
	my $interactive = shift;
	my $sent_dm = shift;
	# for streaming API to inject DMs it receives
	my $my_json_ref = shift;

	if ($anonymous) {
		print $stdout
			"-- sorry, you can't read DMs if you're anonymous.\n"
			if ($interactive);
		return;
	}

	# no point in doing this if we can't even get to our own timeline
	# (unless user specifically requested it, or our timeline is off)
	return if (!$interactive && !$last_id && !$notimeline); # NOT last_dm

	$my_json_ref = &grabjson((($sent_dm) ? $dmsenturl : $dmurl),
		(($sent_dm) ? 0 : $last_dm), 0, $dmfetchwanted, undef, 1)
			if (!defined($my_json_ref) ||
				ref($my_json_ref) ne 'ARRAY');
	return if (!defined($my_json_ref)
		|| ref($my_json_ref) ne 'ARRAY');

	my $orig_last_dm = $last_dm;
	$last_dm = 0 if ($sent_dm);

	$dmfetchwanted = 0;
	my $printed = 0;
	my $max = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $g;
	my $key;

	if ($disp_max) { # an empty list can be valid
		if ($dm_first_time) {
			sleep 5 while ($suspend_output > 0);
			&send_removereadline if ($termrl);
			print $stdout
			"-- checking for most recent direct messages:\n";
			$disp_max = 2;
			$interactive = 1;
		}
		for($i = $disp_max; $i > 0; $i--) {
			$g = ($i-1);
			my $j = $my_json_ref->[$g];
			next if (!$sent_dm && $j->{'id_str'} <= $last_dm);
			next if (!length($j->{'sender'}->{'screen_name'}) ||
				!length($j->{'recipient'}->{'screen_name'}));

			$key = substr($alphabet, $dm_counter/10, 1) .
				$dm_counter % 10;
			$dm_counter = 
				($dm_counter == 259) ? 0 :
				($dm_counter+1);
			$j->{'menu_select'} = $key;
			$dm_store_hash{lc($key)} = $j;

			sleep 5 while ($suspend_output > 0);
			&send_removereadline if ($termrl);
			$wrapseq++;

			$printed += scalar(&$dmhandle($j));
		}
		$max = $my_json_ref->[0]->{'id_str'};
	}
	sleep 5 while ($suspend_output > 0);
	if (($interactive || $verbose) && !$printed && !$dm_first_time) {
		&send_removereadline if ($termrl);
		print $stdout (($sent_dm)
			? "-- you haven't sent anything yet.\n"
			: "-- sorry, no new direct messages.\n");
		$wrapseq = 1;
	}
	$last_dm = ($sent_dm) ? $orig_last_dm 
		: &max($last_dm, $max);
	$dm_first_time = 0 if ($last_dm || !scalar(@{ $my_json_ref }));
	print $stdout "-- dm bookmark is $last_dm.\n" if ($verbose);
	&$dmconclude;
	&send_repaint if ($termrl);
}	

# post an update
# this is a general API function that handles status updates and sending DMs.
sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $in_reply_to = shift;
	my $user_name_dm = shift;
	my $rt_id = shift; # even if this is set, string should also be set.
	my $urle = '';
	my $i;
	my $subpid;
	my $istring;

	my $verb = (length($user_name_dm)) ? "DM $user_name_dm" :
			($rt_id) ? 'RE-tweet' :
			'tweet';

	if ($anonymous) {
		print $stdout
		"-- sorry, you can't $verb if you're anonymous.\n"
			if ($interactive);
		return 99;
	}

	# "the pastebrake"
	if (!$slowpost && !$verify && !$script) {
		if ((time() - $postbreak_time) < 5) {
			$postbreak_count++;
			if ($postbreak_count == 3) {
				print $stdout
		"-- you're posting pretty fast. did you mean to do that?\n".
		"-- waiting three seconds before taking the next set of tweets\n".
		"-- hit CTRL-C NOW! to kill TTYtter if you accidentally pasted in this window\n";
				sleep 3;
				$postbreak_count = 0;
			}
		} else {
			$postbreak_count = 0;
		}
		$postbreak_time = time();
	}

	my $payload = (length($user_name_dm)) ? 'text' : 'status';
	$string = &$prepost($string) unless ($user_name_dm || $rt_id);

	# YES, you *can* verify and slowpost. I thought about this and I
	# think I want to allow it.
	if ($verify && !$status) {
		my $answer;

		print $stdout
			&wwrap("-- verify you want to $verb: \"$string\"\n");
		$answer = lc(&linein(
			"-- send to server? (only y or Y is affirmative):"));
		if ($answer ne 'y') {
			print $stdout "-- ok, NOT sent to server.\n";
			return 97;
		}
	}

	unless ($rt_id) {
		$urle = '';
		foreach $i (unpack("${pack_magic}C*", $string)) {
			my $k = chr($i);
			if ($k =~ /[-._~a-zA-Z0-9]/) {
				$urle .= $k;
			} else {
				$k = sprintf("%02X", $i);
				$urle .= "%$k";
			}
		}
	}

	$user_name_dm = (length($user_name_dm)) ?
		"&user=$user_name_dm" : '';

	my $i = '';
	$i .= "source=TTYtter&" if ($authtype eq 'basic');
	$i .= "in_reply_to_status_id=${in_reply_to}&" if ($in_reply_to > 0);
	if (!$rt_id && defined $lat && defined $long && $location) {
		print $stdout "-- using lat/long: ($lat, $long)\n";
		$i .= "lat=${lat}&long=${long}&";
	} elsif ((defined $lat || defined $long) && $location && !$rt_id) {
		print $stdout
		"-- warning: incomplete location ($lat, $long) ignored\n";
	}
	$i .= "${payload}=${urle}${user_name_dm}" unless ($rt_id);
	$i .= "id=$rt_id" if ($rt_id);
	$slowpost += 0; if ($slowpost && !$script && !$status && !$silent) {
		if($pid = open(SLOWPOST, '-|')) {
			# pause background so that it doesn't kill itself
			# when this signal occurs.
			kill $SIGUSR1, $child;
			print $stdout &wwrap(
	"-- waiting $slowpost seconds to $verb, ^C cancels: \"$string\"\n");
			close(SLOWPOST); # this should wait for us
			if ($? > 256) {
				print $stdout
					"\n-- not sent, cancelled by user\n";
				return 97;
			}
			print $stdout "-- sending to server\n";
			kill $SIGUSR2, $child;
			&send_removereadline if ($termrl && $dostream);
		} else {
			$in_backticks = 1; # defeat END sub
			&sigify(sub { exit 254; }, qw(BREAK INT TERM PIPE));
			sleep $slowpost;
			exit 0;
		}
	}
	my $return = &backticks($baseagent, '/dev/null', undef,
		(length($user_name_dm)) ? $dmupdate :
		($rt_id) ? "$rturl/${rt_id}.json" :
		$update, $i, 0, @wend);
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
	if ($ec = &is_fail_whale($return) ||
			$return =~ /^\[?\]?<!DOCTYPE\s+html/i ||
			$return =~ /^(Status:\s*)?50[0-9]\s/ ||
			$return =~ /^<html>/i ||
			$return =~ /^<\??xml\s+/) {
		print $stdout <<"EOF" if ($interactive);
${MAGENTA}*** warning: Twitter Fail Whale${OFF}
EOF
		return 98;
	}
	$lastpostid = &parsejson($return)->{'id_str'};
	unless ($user_name_dm || $rt_id) {
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
	my $return = &backticks($baseagent, '/dev/null', undef,
		$update, $payload, 0, @wend);
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

# the following functions may be user-exposed in a future version of
# TTYtter, but are officially still "private interfaces."
# delete a status
sub deletest {
	my $id = shift;
	my $interactive = shift;
	my $url = $delurl;

	$url =~ s/%I/$id/;
	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $url);
	print $stdout "-- tweet id #${id} has been removed\n"
		if ($interactive && !$en);
	print $stdout "*** (was the tweet already deleted?)\n"
		if ($interactive && $en);
	return 0;
}

# delete a DM
sub deletedm {
	my $id = shift;
	my $interactive = shift;

	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $dmdelurl);
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

	my ($en, $em) = &central_cd_dispatch("id=$id", $interactive, $basefav);
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

	my ($en, $em) = &central_cd_dispatch("screen_name=$uname",
		$interactive, $basef);
	print $stdout "-- ok, you have $verb following user $uname.\n"
		if ($interactive && !$en);
	return 0;
}

# block or unblock a user
sub boruuser {
	my $uname = shift;
	my $interactive = shift;
	my $basef = shift;
	my $verb = shift;

	my ($en, $em) = &central_cd_dispatch("screen_name=$uname",
		$interactive, $basef);
	print $stdout "-- ok, you have $verb blocking user $uname.\n"
		if ($interactive && !$en);
	return 0;
}

# enable or disable retweets for a user
sub rtsonoffuser {
	my $uname = shift;
	my $interactive = shift;
	my $selection = shift;
	my $verb = ($selection) ? 'enabled' : 'disabled';
	my $tval = ($selection) ? 'true' : 'false';

	my ($en, $em) = &central_cd_dispatch(
		"retweets=${tval}&screen_name=${uname}",
		$interactive, $frupdurl);
	print $stdout "-- ok, you have ${verb} retweets for user $uname.\n"
		if ($interactive && !$en);
	return 0;
}

#### TTYtter internal API utility functions ####
# ... which your API *can* call

# gets and returns the contents of a URL (optionally pass a POST body)
sub graburl {
	my $resource = shift;
	my $data = shift;
	
	return &backticks($baseagent,
		'/dev/null', undef, $resource, $data,
		1, @wind);
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

	# prepend screen name "badges"
	$sn = "\@$sn" if ($ref->{'in_reply_to_status_id_str'} > 0);
	$sn = "+$sn" if ($ref->{'user'}->{'geo_enabled'} eq 'true' &&
		(($ref->{'geo'}->{'coordinates'}->[0] ne 'undef' &&
		length($ref->{'geo'}->{'coordinates'}->[0]) &&
		$ref->{'geo'}->{'coordinates'}->[1] ne 'undef' &&
		length($ref->{'geo'}->{'coordinates'}->[0])) ||
		length($ref->{'place'}->{'id'})));
	$sn = "%$sn" if (length($ref->{'retweeted_status'}->{'id_str'}));
	$sn = "*$sn" if ($ref->{'source'} =~ /TTYtter/ && $ttytteristas);
	# prepend list information, if this tweet originated from a list
	$sn = "($ref->{'tag'}->{'payload'})$sn"	
		if (length($ref->{'tag'}->{'payload'}) &&
			$ref->{'tag'}->{'type'} eq 'list');
	$tweet = "<$sn> $tweet";
	# twitter doesn't always do this right.
	$h = $ref->{'retweet_count'}; $h += 0; #$h = "${h}+" if ($h >= 100);
	# twitter doesn't always handle single retweets right. good f'n grief.
	$tweet = "(x${h}) $tweet" if ($h > 1 && !$nonewrts);
	# br3nda's modified timestamp patch
	if ($timestamp) {
		my ($time, $ts) = &$wraptime($ref->{'created_at'});
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
	unless ($nocolour) {
		# only do this after the < > portion.
		my $k = index($tweet, ">");
		my $botsub = substr($tweet, $k);
		my $topsub = substr($tweet, 0, $k);
		$botsub =~
s/(^|[^a-zA-Z0-9_])\@([a-zA-Z0-9_\/]+)/\1\@${UNDER}\2${colour}/g;
		$tweet = $topsub . $botsub;
	}

	return $tweet;
}

# format a DM based on standard user options
sub standarddm {
	my $ref = shift;
	my $nocolour = shift;

	my ($time, $ts) = &$wraptime($ref->{'created_at'});
	my $text = &descape($ref->{'text'});
	my $sns = &descape($ref->{'sender'}->{'screen_name'});
	if ($sns eq $whoami) {
		$sns = "->" . &descape($ref->{'recipient'}->{'screen_name'});
	}
	my $g = &wwrap("[DM d$ref->{'menu_select'}]".
		"[$sns/$ts] $text", ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0);

	$g =~ s/^\[DM ([^\/]+)\//${CCdm}[DM ${EM}\1${OFF}${CCdm}\//
		unless ($nocolour);
	$g =~ s/\n*$//;
	$g .= ($nocolour) ? "\n" : "$OFF\n";
	$g =~ s/(^|[^a-zA-Z0-9_])\@(\w+)/\1\@${UNDER}\2${OFF}${CCdm}/g
		unless ($nocolour);
	return $g;
}

# format an event record based on standard user options (mostly for
# streaming API, perhaps REST API one day)
sub standardevent {
	my $ref = shift;
	my $nocolour = shift;

	my $g = '>>> ';
	my $verb = &descape($ref->{'event'});
	
	# https://dev.twitter.com/docs/streaming-apis/messages

	if (length($verb)) { # see below for server-level events
		my $tar_sn = '@'.&descape($ref->{'target'}->{'screen_name'});
		my $sou_sn = '@'.&descape($ref->{'source'}->{'screen_name'});
		
		my $tar_list_name = '';
		my $tar_list_desc = '';
		
		# For all verbs starting with "list", get name and desc
		if ($verb =~ m/^list/ ) {
			$tar_list_name = &descape($ref->{'target_object'}->{'full_name'});
			$tar_list_desc = &descape($ref->{'target_object'}->{'description'});
		}
		
		if ($verb eq 'favorite' || $verb eq 'unfavorite') {
			my $rto = &destroy_all_tco($ref->{'target_object'});
			my $txt = &descape($rto->{'text'});
			$g .=
		"$sou_sn just ${verb}d ${tar_sn}'s tweet: \"$txt\"";
		} elsif ($verb eq 'follow') {
			$g .= "$sou_sn is now following $tar_sn";
		} elsif ($verb eq 'user_update') {
		$g .= "$sou_sn updated their profile (/whois $sou_sn to see)";
		} elsif ($verb eq 'list_member_added') {
			$g .= "$sou_sn added $tar_sn to the list \"$tar_list_desc\" ($tar_list_name)";
		} elsif ($verb eq 'list_member_removed') {
			$g .= "$sou_sn removed $tar_sn from the list \"$tar_list_desc\" ($tar_list_name)";
		} elsif ($verb eq 'list_user_subscribed') {
			$g .= "$sou_sn is now following the list \"$tar_list_desc\" ($tar_list_name) from $tar_sn";
		} elsif ($verb eq 'list_user_unsubscribed') {
		$g .= "$sou_sn is no longer following the list \"$tar_list_desc\" ($tar_list_name) from $tar_sn";
		} elsif ($verb eq 'list_created') {
			$g .= "$sou_sn created the new list \"$tar_list_desc\" ($tar_list_name)";
		} elsif ($verb eq 'list_destroyed') {
			$g .= "$sou_sn destroyed the list \"$tar_list_desc\" ($tar_list_name)";
		} elsif ($verb eq 'list_updated') {
			$g .= "$sou_sn updated the list \"$tar_list_desc\" ($tar_list_name)";
		} elsif ($verb eq 'block' || $verb eq 'unblock') {
			$g .= "$sou_sn ${verb}ed $tar_sn ($tar_sn is not ".
				"notified)";
		} elsif ($verb eq 'access_revoked') {
			$g .= "$sou_sn revoked oAuth access to $tar_sn";
		} elsif ($verb eq 'access_unrevoked') {
			$g .= "$sou_sn restored oAuth access to $tar_sn";
		} else {
			# try to handle new types of events we don't
			# recognize yet.
			$verb .= ($verb =~ /e$/) ? 'd' : 'ed';
			$g .= "$sou_sn $verb $tar_sn (basic)";
		}

	# server events ("public stream messages") are handled differently.
	# we support almost all except for the ones that are irrelevant to
	# this medium.

	} elsif ($ref->{'delete'}) {
		# this is the best we can do -- it's already on the screen!
		# we don't want to make it easy which tweet it is, since that
		# would be embarrassing, so just say a delete occurred.
		$g .=
		"tweet ID# ".$ref->{'delete'}->{'status'}->{'id_str'}.
			" deleted by server";
	} elsif ($ref->{'status_withheld'}) {
		# Twitter doesn't document id_str as available here. check.
		if (!length($ref->{'status_withheld'}->{'id_str'})) {
			# do nothing right now
		} else { $g .=
		"tweet ID# ".$ref->{'status_withheld'}->{'id_str'}.
			" censored by server in your country";
		}
	} elsif ($ref->{'user_withheld'}) {
		$g .=
		"user ID# ".$ref->{'user_withheld'}->{'user_id'}.
			" censored by server in your country";
	} elsif ($ref->{'disconnect'}) {
		$g .=
		"DISCONNECTED BY SERVER (".$ref->{'disconnect'}->{'code'}.
			"); will retry: ".$ref->{'disconnect'}->{'reason'};
	} else {
		# we have no idea what this is. just BS our way out.
		$g .= "unknown server event received (non-fatal)";
	}

	if ($timestamp) {
		my ($time, $ts) = &$wraptime($ref->{'created_at'});
		$g = "[$ts] $g";
	}

	$g = &wwrap("$g\n", ($wrapseq <= 1) ? ((&$prompt(1))[1]) : 0);
	# highlight screen names
	$g =~
s/(^|[^a-zA-Z0-9_])\@([a-zA-Z0-9_\-\/]+)/\1\@${UNDER}\2${OFF}/g
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
# don't change these here. instead, use -exts=yourlibrary.pl and set there.
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

	local $dispatch_ref; # on purpose; get_key/set_key may need it
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
sub multieventhandle {
	&multi_module_dispatch(\&defaulteventhandle, \@m_eventhandle, sub {
		my $rv = shift;

		# skip default calls.
		return 0 if ($this_call_default);

		# if not a default call, and the event was refused for
		# processing by this extension, then the event is now
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
sub multishutdown {
	return if ($shutdown_already_called++);
	&multi_module_dispatch(\&defaultshutdown, \@m_shutdown, 0, @_);
}

sub multiuserhandle {
	&multi_module_dispatch(\&defaultuserhandle, \@m_userhandle, sub{
		# skip default calls.
		return 0 if ($this_call_default);

		# return immediately on the first extension to accept
		return (shift>0);
	}, @_);
}
sub multilisthandle {
	&multi_module_dispatch(\&defaultlisthandle, \@m_listhandle, sub{
		# skip default calls.
		return 0 if ($this_call_default);

		# return immediately on the first extension to accept
		return (shift>0);
	}, @_);
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
	my $msg_code = shift;
	return if ($msg_code == 2 && $muffle_server_messages);
	my $message = "@_";
	$message =~ s/\n*$//sg;
	if ($timestamp) {
		my ($time, $ts) = &$wraptime(scalar(localtime));
		$message = "[$ts] $message";
		$message =~ s/\n/\n[$ts] /sg;
	}
	&send_removereadline if ($termrl);
	$wrapseq = 1;
	print $stdout "${MAGENTA}${message}${OFF}\n";
	&send_repaint if ($termrl);
	$laststatus = 1;
}
sub defaultshutdown { 
	(&flag_default_call, return) if ($multi_module_context);
}
sub defaultlisthandle {
	(&flag_default_call, return) if ($multi_module_context);
	my $list_ref = shift;

	print $streamout "*** for future expansion ***\n";

	return 1;
}
sub defaulthandle {
	(&flag_default_call, return) if ($multi_module_context);
	my $tweet_ref = shift;
	my $class = shift;
	my $dclass = ($verbose) ? "{$class,$tweet_ref->{'id_str'}} " :  '';
	my $sn = &descape($tweet_ref->{'user'}->{'screen_name'});
	my $tweet = &descape($tweet_ref->{'text'});
	my $stweet = &standardtweet($tweet_ref);
	my $menu_select = $tweet_ref->{'menu_select'};
	
	$menu_select = (length($menu_select) && !$script)
		? (($menu_select =~ /^z/) ?
			"${EM}${menu_select}>${OFF} " :
			"${menu_select}> ")
		: '';

	print $streamout $menu_select . $dclass . $stweet;
	&sendnotifies($tweet_ref, $class);
	return 1;
}
sub defaultuserhandle {
	(&flag_default_call, return) if ($multi_module_context);

	my $user_ref = shift;
	&userline($user_ref, $streamout);
	my $desc = &strim(&descape($user_ref->{'description'}));
	my $klen = ($wrap || 79) - 9;
	$klen = 10 if ($klen < 0);
	$desc = substr($desc, 0, $klen)."..." if (length($desc) > $klen);
	print $streamout (' "' . $desc . '"' . "\n") if (length($desc));
	return 1;
}
sub userline { # used by both $userhandle and /whois
	my $my_json_ref = shift;
	my $fh = shift;

	my $verified =
		($my_json_ref->{'verified'} eq 'true') ?
		"${EM}(Verified)${OFF} " : '';
	my $protected =
		($my_json_ref->{'protected'} eq 'true') ?
		"${EM}(Protected)${OFF} " : '';
	print $fh <<"EOF"; 
${CCprompt}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} (@{[ &descape($my_json_ref->{'screen_name'}) ]}) (f:$my_json_ref->{'friends_count'}/$my_json_ref->{'followers_count'}) (u:$my_json_ref->{'statuses_count'}) ${verified}${protected}
EOF
	return;
}
sub sendnotifies { # this is a default subroutine of a sort, right?
	my $tweet_ref = shift;
	my $class = shift;

	my $sn = &descape($tweet_ref->{'user'}->{'screen_name'});
	my $tweet = &descape($tweet_ref->{'text'});

	# interactive? first time?
	unless (length($class) || !$last_id || !length($tweet)) {
		$class = scalar(&$tweettype($tweet_ref, $sn, $tweet));
		&notifytype_dispatch($class,
				&standardtweet($tweet_ref, 1), $tweet_ref)
			if ($notify_list{$class});
	}
}

sub defaulttweettype {
	(&flag_default_call, return) if ($multi_module_context);
	my $ref = shift;
	my $sn = shift;
	my $tweet = shift;

	# br3nda's and smb's modified colour patch
	unless ($anonymous) {
		if (lc($sn) eq $whoami) {
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
	if ($ref->{'tag'}->{'type'} eq 'list') { # anonymous allows this too
		return 'list';
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
	my $sns = &descape($dm_ref->{'sender'}->{'screen_name'});

	print $streamout &standarddm($dm_ref);
	&senddmnotifies($dm_ref) if ($sns ne $whoami);
	return 1;
}

sub senddmnotifies {
	my $dm_ref = shift;
	&notifytype_dispatch('DM', &standarddm($dm_ref, 1), $dm_ref)
		if ($notify_list{'dm'} && $last_dm);
}

sub defaulteventhandle {
	(&flag_default_call, return) if ($multi_module_context);
	my $event_ref = shift;
	# in this version, we silently filter delete events, but your
	# extension would still get them delivered.
	return 1 if ($event_ref->{'delete'});
	print $streamout &standardevent($event_ref);
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
		$readline_completion{'@'.lc($1)}++;
	}
	if ($line =~ /^[dD]\s+(\w+)\s+/) {
		$readline_completion{'@'.lc($1)}++;
	}
}

sub defaultautocompletion {
	my ($text, $line, $start) = (@_);
	my $qmtext = quotemeta($text);
	my @proband;
	my @rlkeys;

	# handle / completion
	if ($start == 0 && $text =~ m#^/#) {
		return sort grep(/^$qmtext/i, '/history',
			'/print', '/quit', '/bye', '/again',
			'/wagain', '/whois', '/thump', '/dm',
			'/refresh', '/dmagain', '/set', '/help',
			'/reply', '/url', '/thread', '/retweet', '/replyall',
			'/replies', '/ruler', '/exit', '/me', '/vcheck',
			'/oretweet', '/eretweet', '/fretweet', '/liston',
			'/listoff', '/dmsent', '/rtsof', '/rtson', '/rtsoff',
			'/lists', '/withlist', '/add', '/padd', '/push',
			'/pop', '/followers', '/friends', '/lfollow',
			'/lleave', '/listfollowers', '/listfriends',
			'/unset', '/verbose', '/short', '/follow', '/unfollow',
			'/doesfollow', '/search', '/tron', '/troff',
			'/delete', '/deletelast', '/dump',
			'/track', '/trends', '/block', '/unblock',
			'/fave', '/faves', '/unfave', '/eval');
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
		@proband = grep(/^\@$qmtext/i, @rlkeys);
		if (scalar(@proband)) {
			@proband = map { s/^\@//;$_ } @proband;
			return @proband;
		}
	}
	# definites that are left over, including @ if it were included
	if(scalar(@proband = grep(/^$qmtext/i, @rlkeys))) {
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

#### built-in notification routines ####

# growl for Mac OS X
sub notifier_growl {
	my $class = shift;
	my $text = shift;
	my $ref = shift; # not used in this version

	if (!defined($class) || !length($notify_tool_path)) {
		# we are being asked to initialize
		$notify_tool_path = &wherecheck("trying to find growlnotify",
			"growlnotify",
"growlnotify must be installed to use growl notifications. check your\n" .
			"documentation for how to do this.\n")
				unless ($notify_tool_path);
		if (!defined($class)) {
			return 1 if ($script || $notifyquiet);
			$class = 'Growl support activated';
			$text = 
'You can configure notifications for TTYtter in the Growl preference pane.';
		}
	}
	# handle this in the background for faster performance.
	# to avoid problems with SIGCHLD, we fork ourselves twice (mmm!),
	# leaving an orphan which init should grab (we need SIGCHLD for
	# proper backticks, so it can't be IGNOREd).
	my $gchild;
	if ($gchild = fork()) {
		# the parent harvests the child, which will die immediately.
		waitpid($gchild, 0);
		return 1;
	} elsif (!defined ($gchild)) {
		print $stdout "warning: failed growl fork: $!\n";
		return 1;
	}
	# this is the child. spawn, then exit and abandon our own child,
	# which init will reap. the problem with teen pregnancy is mounting.
	$in_backticks = 1;
	my $hchild;
	if ($hchild = fork()) {
		exit;
	} elsif (!defined ($hchild)) {
		print $stdout "warning: failed growl fork: $!\n";
		exit;
	}
	# this is the subchild, which is abandoned at a fire sta^W^W^Winit.
	open(GROWL, "|$notify_tool_path -n 'TTYtter' 'TTYtter: $class'");
	binmode(GROWL, ":utf8") unless ($seven);
	print GROWL $text;
	close(GROWL);
	exit;
}

# libnotify for {Linux,whatevs}
# this is EXPERIMENTAL, and requires this patch to notify-send:
# http://www.floodgap.com/software/ttytter/libnotifypatch.txt
# why it has not already been applied is fricking beyond me, it makes
# sense. would YOU want arbitrary characters on the command line
# separated only from overwriting your home directory by a quoting routine?
sub notifier_libnotify {
	my $class = shift;
	my $text = shift;
	my $ref = shift; # not used in this version

	if (!defined($class) || !defined($notify_tool_path)) {
		# we are being asked to initialize
		$notify_tool_path = &wherecheck("trying to find notify-send",
			"notify-send",
"notify-send must be installed to use libnotify, and it must be modified\n".
"for standard input. see the documentation for how to do this.\n")
			unless ($notify_tool_path);
		if (!defined($class)) {
			return 1 if ($script || $notifyquiet);
			$class = 'libnotify support activated';
			$text =
'Congratulations, your notify-send is correctly configured for TTYtter.';
		}
	}
	# figure out the time to display based on length of tweet
	my $t = 1000+50*length($text); # about 150-180wpm read speed
	open(NOTIFYSEND,
		"|$notify_tool_path -t $t -f - 'TTYtter: $class'");
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

#TODO
# implement querying the id_cache here. we need IPC for it, though.
	# if the code is all numbers, treat it like an id_str, and try
	# to get it from the server. we have similar code in get_dm.
	# the first tweet that is of relevance is ID 20. try /dump 20 :)
	return &grabjson("${idurl}?id=${code}", 0, 0, 0, undef, 1)
		if ($code =~ /^[0-9]+$/ && (0+$code > 19));

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

	print $stdout "-- querying background: $code\n" if ($verbose);
	kill $SIGUSR2, $child if ($child);
	print C "pipet $code ----------\n";
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	return undef if ($k !~ /[^\s]/);
	$k =~ s/\s+$//; # remove trailing spaces
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	($w->{'menu_select'}, $w->{'id_str'}, $w->{'in_reply_to_status_id_str'},
		$w->{'retweeted_status'}->{'id_str'},
		$w->{'user'}->{'geo_enabled'},
		$w->{'geo'}->{'coordinates'}->[0],
		$w->{'geo'}->{'coordinates'}->[1],
		$w->{'place'}->{'id'},
		$w->{'place'}->{'country_code'},
		$w->{'place'}->{'place_type'},
		$w->{'place'}->{'full_name'},
		$w->{'tag'}->{'type'},
		$w->{'tag'}->{'payload'},
		$w->{'retweet_count'}, 
		$w->{'user'}->{'screen_name'}, $w->{'created_at'},
			$l) = split(/\s/, $k, 17);
	($w->{'source'}, $k) = split(/\|/, $l, 2);
	$w->{'text'} = pack("H*", $k);
	$w->{'place'}->{'full_name'} = pack("H*",$w->{'place'}->{'full_name'});
	$w->{'tag'}->{'payload'} = pack("H*", $w->{'tag'}->{'payload'});
	return undef if (!length($w->{'text'})); # unpossible
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
	return undef if (length($code) < 3 || $code !~ s/^d//);

	# this is the aforementioned "similar code" (see get_tweet).
	# optimization: I doubt ANY of us can get DMIDs less than 9.
	return &grabjson("${dmidurl}?id=$code", 0, 0, 0, undef, 1)
		if ($code =~ /^[0-9]+$/ && (0+$code > 9));

	return undef if ($code !~ /^[a-z][0-9]$/);

	kill $SIGUSR2, $child if ($child); # prime pipe
	print C "piped $code ----------\n"; # internally two alphanum, recall
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	return undef if ($k !~ /[^\s]/);
	$k =~ s/\s+$//; # remove trailing spaces
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	($w->{'menu_select'}, $w->{'id_str'},
		$w->{'sender'}->{'screen_name'}, $w->{'created_at'},
			$l) = split(/\s/, $k, 5);
	$w->{'text'} = pack("H*", $l);
	return undef if (!length($w->{'text'})); # not possible
	$w->{'created_at'} =~ s/_/ /g;
	return $w;
}

# this function requests a $store key from the background. it only works
# if foreground.
sub getbackgroundkey {
	if ($is_background) {
		print $stdout "*** can't call getbackgroundkey from background\n";
		return undef;
	}
	my $key = shift;
	my $l;
	my $k;
	print C substr("ki $key ---------------------", 0, 19)."\n";
	my $ref = (length($dispatch_ref->[0])) ? ($dispatch_ref->[0]) :
		"DEFAULT";
	print C substr(unpack("${pack_magic}H*", $ref).$space_pad, 0, 1024);
	while(length($k) < 1024) {
		sysread(W, $l, 1024);
		$k .= $l;
	}
	$k =~ s/[^0-9a-fA-F]//g;
	print $stdout "-- background store fetch: $k\n" if ($verbose);
	return pack("H*", $k);
}

# this function sends a $store key to the background. it only works if
# foreground.
sub sendbackgroundkey {
	if ($is_background) {
		print $stdout "*** can't call sendbackgroundkey from background\n";
		return;
	}
	my $key = shift;
	my $value = shift;
	if (ref($value)) {
		print $stdout "*** send_key only supported for scalars\n";
		return;
	}
	if (!length($value)) {
		print C substr("kn $key ---------------------", 0, 19)."\n";
	} else {
		print C substr("ko $key ---------------------", 0, 19)."\n";
	}
	my $ref = (length($dispatch_ref->[0])) ? ($dispatch_ref->[0]) :
		"DEFAULT";
	print C substr(unpack("${pack_magic}H*", $ref).$space_pad, 0, 1024);
	return if (!length($value));
	print C substr(unpack("${pack_magic}H*", $value).$space_pad, 0, 1024);
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

# setter for internal variables, with all the needed side effects for those
# variables that are programmed to trigger internal actions when changed.
sub setvariable {
	my $key = shift;
	my $value = shift;
	my $interactive = 0+shift;

	$value =~ s/^\s+//;
	$value =~ s/\s+$//; # mostly to avoid problems with /(p)add

	if ($key eq 'script') { # this can never be changed by this routine
		print $stdout "*** script may only be changed on init\n";
		return 1;
	}
	if ($key eq 'tquery' && $value eq '0') { # undo tqueries
		$tquery = undef;
		$key = 'track';
		$value = $track; # falls thru to sync
		&tracktags_makearray;
	}
	if ($opts_can_set{$key} ||
			# we CAN set read-only variables during initialization
			($multi_module_mode == -1 && $valid{$key})) {
		if (length($value) > 1023) {
			# can't transmit this in a packet
			print $stdout "*** value too long\n";
			return 1;
		} elsif ($opts_boolean{$key} && $value ne '0' &&
				$value ne '1') {
			print $stdout "*** 0|1 only (boolean): $key\n";
			return 1;
		} elsif ($opts_urls{$key} &&
	$value !~ m#^(http|https|gopher)://#) {
			print $stdout "*** must be valid URL: $key\n";
			return 1;
		} else {
			KEYAGAIN: $$key = $value;
			print $stdout "*** changed: $key => $$key\n"
				if ($interactive || $verbose);

			# handle special values
			&generate_ansi if ($key eq 'ansi' ||
				$key =~ /^colour/);
			&generate_shortdomain if ($key eq 'shorturl');
			&tracktags_makearray if ($key eq 'track');
			&filter_compile if ($key eq 'filter');
			&notify_compile if ($key eq 'notifies');
			&list_compile if ($key eq 'lists');
			&filterflags_compile if ($key eq 'filterflags');
			$filterrts_sub = &filteruserlist_compile(
				$filterrts_sub, $value)
					if ($key eq 'filterrts');
			$filterusers_sub = &filteruserlist_compile(
				$filterusers_sub,$value)
					if ($key eq 'filterusers');
			$filteratonly_sub = &filteruserlist_compile(
				$filteratonly_sub, $value)
					if ($key eq 'filteratonly');
			&filterats_compile if ($key eq 'filterats');

			# transmit to background process sync-ed values
			if ($opts_sync{$key}) {
				&synckey($key, $value, $interactive);
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
		my $ivalue = &tracktags_tqueryurlify($value);
		if (length($ivalue) > 139) {
			print $stdout
		"*** custom query is too long (encoded: $ivalue)\n";
			return 1;
		} else {
			$tquery = $value;
			&synckey($key, $ivalue, $interactive);
		}
	} elsif ($valid{$key}) {
		print $stdout
		"*** read-only, must change on command line: $key\n";
		return 1;
	} else {
		print $stdout
		"*** not a valid option or setting: $key\n";
		return 1;
	}
	return 0;
}
sub synckey {
	my $key = shift;
	my $value = shift;
	my $interactive = 0+shift;
	my $commchar = ($interactive) ? '=' : '+';
	print $stdout "*** (transmitting to background)\n"
		if ($interactive || $verbose);
	return if (!$child); 
	kill $SIGUSR2, $child if ($child);
	print C
	(substr("${commchar}$key                           ", 0, 19) . "\n");
	print C (substr(($value . $space_pad), 0, 1024));
	sleep 1;
}

# getter for internal variables. right now this just returns the variable by
# name and a couple virtuals, but in the future this might be expanded.
sub getvariable {
	my $key = shift;
	if ($valid{$key}) {
		return $$key;
	}
	if ($key eq 'effpause' ||
			$key eq 'rate_limit_rate' ||
			$key eq 'rate_limit_left') {
		my $value;
		kill $SIGUSR2, $child if ($child);
		print C (substr("?$key                    ", 0, 19) . "\n");
		sysread(W, $value, 1024);
		$value =~ s/\s+$//;
		return $value;
	}
	return undef;
}

# compatibility stub for extensions calling the old wraptime
sub wraptime { return &$wraptime(@_); }

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
	$url = "http://gopher.floodgap.com/gopher/gw?".&url_oauth_sub($url)
		if ($url =~ m#^gopher://# && $comm !~ /^[^\s]*lynx/);
	$urlshort = $url;
	$comm =~ s/\%U/'$url'/g;
	print $stdout "($comm)\n";
	system("$comm");
}

sub urlshorten {
	my $url = shift;
	my $rc;
	my $cl;

	$url = "http://gopher.floodgap.com/gopher/gw?".&url_oauth_sub($url)
		if ($url =~ m#^gopher://#);
	return $url if ($url =~ /^$shorturldomain/i); # stop loops
	$url = &url_oauth_sub($url);
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
	$track =~ s/^'//; $track =~ s/'$//; $track = lc($track);
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
	# need to limit track tags to a certain number of pieces
	TAGBAG: foreach $k (@tracktags) {
		if (length($k) > 130) { # I mean, really
			print $stdout
				"-- warning: track tag \"$k\" is TOO LONG\n";
			next TAGBAG;
		}
		if (length($l)+length($k) > 150) { # balance of size/querytime
			push(@trackstrings, "q=".&url_oauth_sub($l));
			$l = '';
		}
		$l = (length($l)) ? "${l} OR ${k}" : "${k}";
	}
	push(@trackstrings, "q=".&url_oauth_sub($l)) if (length($l));
}

# notification multidispatch
sub notifytype_dispatch {
	return if (!scalar(@notifytypes));
	my $nt; foreach $nt (@notifytypes) { &$nt(@_); }
}

# notifications compiler
sub notify_compile {
	if ($notifies) {
		my $w;

		undef %notify_list;
		foreach $w (split(/\s*,\s*/, $notifies)) {
			$notify_list{$w} = 1;
		}
		$notifies = join(',', keys %notify_list);
	}
}

# lists compiler
# we don't check the validity of lists here; /liston and /listoff do that.
sub list_compile {
	my @oldlistlist = @listlist;
	my %already;

	undef @listlist;
	if ($lists) {
		my $w;
		my $u;
		my $l;
		foreach $w (split(/\s*,\s*/, $lists)) {
			$w =~ s/^@//;
			if ($w =~ m#/#) {
				($u, $l) = split(m#\s*/\s*#, $w, 2);
			} else {
				$l = $w;
			}
			if (!length($u) && $anonymous) {
print $stdout "*** must use fully specified lists when anonymous\n";
				@listlist = @oldlistlist;
				return 0;
			}
			$u ||= $whoami;
			if ($l =~ m#/#) {
print $stdout "*** syntax error in list $u/$l\n";
				@listlist = @oldlistlist;
				return 0;
			}
			if ($already{"$u/$l"}++) {
			print $stdout "*** duplicate list $u/$l ignored\n";
			} else {
				push(@listlist, [ $u, $l ]);
			}
		}
		$lists = join(',', keys %already);
	}
	return 1;
}

# -filterflags compiler (replaces old -filter syntax)
sub filterflags_compile {
	my $s = $filterflags;
	undef %filter_attribs;
	$s =~ s/^\s*['"]?\s*//;
	$s =~ s/\s*['"]?\s*$//;
	return if (!length($s));
	%filter_attribs = map { $_ => 1 } split(/\s*,\s*/, $s);
}

# -filterrts and -filterusers compiler. these simply use a list of usernames,
# so they are fast and the same code suffices. emit code to compile that
# just is one if-expression after another.
sub filteruserlist_compile {
	my $old = shift;
	my $s = shift;
	undef $k;
	$s =~ s/^\s*['"]?\s*//;
	$s =~ s/\s*['"]?\s*$//;
	return $k if (!length($s));
	my @us = map { $k=lc($_); "\$sn eq '$k'" } split(/\s*,\s*/, $s);
	my $uus = join(' || ', @us);
	my $uuus = <<"EOF";
		\$k = sub {
			my \$sn = shift;
			return 1 if ($uus);
			return 0;
		};
EOF
#	print $stdout $uuus;
	eval $uuus;
	if (!defined($k)) {
		print $stdout "** bogus name in user list (error = $@)\n";
		return $old;
	}
	return $k;
}

# -filterats compiler. this takes a list of usernames and then compiles a
# whole bunch of regexes.
sub filterats_compile {
	undef $filterats_c;
	my $s = $filterats;
	$s =~ s/^\s*['"]?\s*//;
	$s =~ s/\s*['"]?\s*$//;
	return 1 if (!length($s)); # undef
	my @us = map { $k=lc($_); "\$x=~/\\\@$k\\b/i" } split(/\s*,\s*/, $s);
	my $uus = join(' || ', @us);
	my $uuus = <<"EOF";
		\$filterats_c = sub {
			my \$x = shift;
			return 1 if ($uus);
			return 0;
		};
EOF
#	print $stdout $uuus;
	eval $uuus;
	if (!defined($filterats_c)) {
		print $stdout "** bogus name in user list (error = $@)\n";
		return 0;
	}
	return 1;
}

# -filter compiler. this is the generic case.
sub filter_compile {
	undef %filter_attribs unless (length($filterflags));
	undef $filter_c;
	if (length($filter)) {
		my $tfilter = $filter;
		$tfilter =~ s/^['"]//;
		$tfilter =~ s/['"]$//;
		# note attributes (compatibility)
		while ($tfilter =~ s/^([a-z]+),//) {
			my $atkey = $1;
			$filter_attribs{$atkey}++;
			print $stdout
		"** $atkey filter parameter should be in -filterflags\n";
		}
		my $b = <<"EOF";
		\$filter_c = sub {
			local \$_ = shift;
			return ($tfilter);
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
		"http://www.floodgap.com/software/ttytter/02current.txt";
	my $vrlcheck_url =
		"http://www.floodgap.com/software/ttytter/01readlin.txt";
	my $update_url = shift;

	my $vs = '';
	my $vvs;
	my $tverify;
	my $inversion;
	my $bversion;
	my $rcnum;
	my $download;
	my $maj;
	my $min;
	my $s1, $s2, $s3;
	my $update_trlt = undef;
	
	if ($termrl && $termrl->ReadLine eq 'Term::ReadLine::TTYtter') {
		my $trlv = $termrl->Version;
		print $stdout
	"-- checking Term::ReadLine::TTYtter version: $vrlcheck_url\n";
		$vvs = `$simple_agent $vrlcheck_url`;
		print $stdout "-- server response: $vvs\n" if ($verbose);
		($vvs, $s1, $s2, $s3) = split(/--__--\n/s, $vvs);
		$s1 = undef if ($s1 !~ /^\*/) ;
		$s2 = undef if ($s2 !~ /^\*/) ;
		$s3 = undef if ($s3 !~ /^\*/) ;
		chomp($vvs);
		# right now we're only using $inversion (no betas/rcs).
		($tverify, $inversion, $bversion, $rcnum, $download,
			$bdownload) = split(/;/, $vvs, 6);
		if ($tverify ne 'trlt') {
$vs .= "-- warning: unable to verify Term::ReadLine::TTYtter version\n";
		} else {
			if ($trlv < 0+$inversion) {
$vs .= "** NEW Term::ReadLine::TTYtter VERSION AVAILABLE: $inversion **\n" .
       "** GET IT: $download\n";
				$update_trlt = $download;
			} else {
$vs .= "-- your version of Term::ReadLine::TTYtter is up to date ($trlv)\n";
			}
		}
	}

	print $stdout "-- checking TTYtter version: $vcheck_url\n";
	$vvs = `$simple_agent $vcheck_url`;
	print $stdout "-- server response: $vvs\n" if ($verbose);
	($vvs, $s1, $s2, $s3) = split(/--__--\n/s, $vvs);
	$s1 = undef if ($s1 !~ /^\*/) ;
	$s2 = undef if ($s2 !~ /^\*/) ;
	$s3 = undef if ($s3 !~ /^\*/) ;
	chomp($vvs);
	($tverify, $inversion, $bversion, $rcnum, $download, $bdownload) =
		split(/;/, $vvs, 6);
	if ($tverify ne 'ttytter') {
		$vs .= "-- warning: unable to verify TTYtter version\n";
	} else {
		if ($my_version_string eq $bversion) {
			$vs .=
"** REMINDER: you are using a beta version (${my_version_string}b${TTYtter_RC_NUMBER})\n";
			$vs .=
"** NEW TTYtter RELEASE CANDIDATE AVAILABLE: build $rcnum **\n" .
"** get it: $bdownload\n$s2"
			if ($TTYtter_RC_NUMBER < $rcnum);
			$vs .= "** (this is the most current beta)\n"
				if ($TTYtter_RC_NUMBER == $rcnum);
			$vs .= "$s1$s3";
			if ($TTYtter_RC_NUMBER < $rcnum) {
				if ($update_url) {
					$vs .=
"-- %URL% is now $bdownload (/short shortens, /url opens)\n";
					$urlshort = $bdownload;
				}
			} elsif (length($update_trlt) && $update_url) {
				$urlshort = $update_trlt;
	$vs .= "-- %URL% is now $urlshort (/short shortens, /url opens)\n";
			}
			return $vs;
		}
		if ($my_version_string eq $inversion && $TTYtter_RC_NUMBER) {
			$vs .=
"** FINAL TTYtter RELEASE NOW AVAILABLE for version $inversion **\n" .
"** get it: $download\n$s2$s1";
			if ($update_url) {
				$vs .=
"-- %URL% is now $bdownload (/short shortens, /url opens)\n";
				$urlshort = $bdownload;
			}
			return $vs;
		}
		($inversion =~/^(\d+\.\d+)\.(\d+)$/) && ($maj = 0+$1,
			$min = 0+$2);
		if (0+$TTYtter_VERSION < $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION < $min)) {
			$vs .=
	"** NEWER TTYtter VERSION NOW AVAILABLE: $inversion **\n" .
	"** get it: $download\n$s2$s1";
			if ($update_url) {
				$vs .=
"-- %URL% is now $download (/short shortens, /url opens)\n";
				$urlshort = $download;
			}
			return $vs;
		} elsif (0+$TTYtter_VERSION > $maj ||
				(0+$TTYtter_VERSION == $maj &&
				 $TTYtter_PATCH_VERSION > $min)) {
			$vs .= 
	"** unable to identify your version of TTYtter\n$s1";
		} else {
			$vs .=
	"-- your version of TTYtter is up to date ($inversion)\n$s1";
		}
	}

	# if we got this far, then there is no TTYtter update, but maybe a
	# T:RL:T update, so we offer that as the URL
	if (length($update_trlt) && $update_url) {
		$urlshort = $update_trlt;
		$vs .= "-- %URL% is now $urlshort (/short shortens, /url opens)\n";
	}
	return $vs;
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
sub end_me { exit; } # which falls through to, via END, ...
sub killkid {
	# for streaming assistance
	if ($child) {
		print $stdout "\n\ncleaning up.\n";
		kill $SIGHUP, $child; # warn it about shutdown
		if (length($track)) {
			print $stdout "*** you were tracking:\n";
			print $stdout "-track='$track'\n";
		}
		if (length($filter)) {
			print $stdout "*** your current filter expression:\n";
			print $stdout "-filter='$filter'\n";
		}
		&generate_otabcomp;
		sleep 2 if ($dostream);
		kill 9, $curlpid if ($curlpid);
		kill 9, $child;
	}
	&$shutdown unless (!$shutdown);
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

	foreach $k (qw(prompt me dm reply warn search list default)) {
		${"colour$k"} = uc(${"colour$k"});
		if (!defined($${"colour$k"})) {
			print $stdout
		"-- warning: bogus colour '".${"colour$k"}."'\n";
		} else {
			eval("\$CC$k = \$".${"colour$k"});
		}
	}

	eval '$termrl->hook_use_ansi' if ($termrl);
}

# always POST
sub postjson {
	my $url = shift;
	my $postdata = shift; # add _method=DELETE for delete
	my $data;

	# this is copied mostly verbatim from grabjson
	chomp($data = &backticks($baseagent, '/dev/null', undef, $url,
		$postdata, 0, @wend));
	my $k = $? >> 8;

	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;

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

	# test for error/warning conditions with trivial case
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1/s
		|| $data =~ /(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1\}/s) {
		print $stdout $data if ($superverbose);
		&$exception(2, "*** warning: server $2 message received\n" .
			"*** \"$3\"\n");
		return undef;
	}

	return &parsejson($data);
}

# always GET
sub grabjson {
	my $data;
	my $url = shift;
	my $last_id = shift;
	my $is_anon = shift;
	my $count = shift;
	my $tag = shift;
	my $do_entities = shift;

	my $kludge_search_api_adjust = 0;
	my $my_json_ref = undef; # durrr hat go on foot
	my $i;
	my $tdata;
	my $seed;

	#undef $/; $data = <STDIN>;

	# we may need to sort our args for more flexibility here.
	my @xargs = (); my $i = index($url, "?");
	if ($i > -1) {
		# throw an error if "?" is at the end.
		push(@xargs, split(/\&/, substr($url, ($i+1))));
		$url = substr($url, 0, $i);
	}

	# count needs to be removed for the default case due to show, etc.
	push(@xargs, "count=$count") if ($count);
	# timeline control. this speeds up parsing since there's less data.
	# can't use skip_user: no SN
	push (@xargs, "since_id=${last_id}") if ($last_id);

	# request entities, which should be supported everywhere now
	push (@xargs, "include_entities=1") if ($do_entities);

	my $resource = (scalar(@xargs)) ?
		[ $url, join('&', sort @xargs) ] : $url;

	chomp($data = &backticks($baseagent,
			'/dev/null', undef, $resource, undef,
			$is_anon + $anonymous, @wind));
	my $k = $? >> 8;

	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;

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

	# test for error/warning conditions with trivial case
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1/s
		|| $data =~ /(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1\}/s) {
		print $stdout $data if ($superverbose);
		&$exception(2, "*** warning: server $2 message received\n" .
			"*** \"$3\"\n");
		return undef;
	}

	# if wrapped in statuses object, unwrap it
	# (and tag it to do more later)
        if ($data =~ s/^\s*(\{)\s*['"]statuses['"]\s*:\s*(\[.*\]).*$/$2/isg) {
		$kludge_search_api_adjust = 1;
	}

	$my_json_ref = &parsejson($data);

	# normalize the data into a standard form.
	# single tweets such as from statuses/show aren't arrays, so
	# we special-case for them.
	if (defined($my_json_ref) && ref($my_json_ref) eq 'HASH' &&
		$my_json_ref->{'favorited'} &&
		$my_json_ref->{'source'} &&
		((0+$my_json_ref->{'id'}) ||
			length($my_json_ref->{'id_str'}))) {
		$my_json_ref = &normalizejson($my_json_ref);
	}
	if (defined($my_json_ref) && ref($my_json_ref) eq 'ARRAY') {
		foreach $i (@{ $my_json_ref }) {
			$i = &normalizejson($i,$kludge_search_api_adjust,$tag);
		}
	}

	$laststatus = 0;
	return $my_json_ref;
}

# convert t.co into actual URLs. separate from normalizejson because other
# things need this. modified from /entities.
sub destroy_all_tco {
	my $hash = shift;
	return $hash if ($notco);
	my $v;
	my $w;

	# Twitter puts entities in multiple fields.
	foreach $w (qw(media urls)) {
		my $p = $hash->{'entities'}->{$w};
		next if (!defined($p) || ref($p) ne 'ARRAY');
		foreach $v (@{ $p }) {
			next if (!defined($v) || ref($v) ne 'HASH');
			next if (!length($v->{'url'}) ||
				(!length($v->{'expanded_url'}) &&
				 !length($v->{'media_url'})));
			my $u1 = quotemeta($v->{'url'});
			my $u2 = $v->{'expanded_url'};
			my $u3 = $v->{'media_url'};
			my $u4 = $v->{'media_url_https'};
			$u2 = $u4 || $u3 || $u2;
			$hash->{'text'} =~ s/$u1/$u2/;
		}
	}
	return $hash;
}

# takes a tweet structure and normalizes it according to settings.
# what this currently does is the following gyrations:
# - if there is no id_str, see if we can convert id into one. if
#   there is loss of precision, warn the user. same for
#   in_reply_to_status_id_str.
# - if the source of this JSON data source is the Search API, translate
#   its fields into the standard API.
# - if the calling function has specified a tag, tag the tweets, since
#   we're iterating through them anyway. the tag should be a hashref payload.
# - if the tweet is an newRT, unwrap it so that the full tweet text is
#   revealed (unless -nonewrts).
# - if this appears to be a tweet, put in a stub geo hash if one does
#   not yet exist.
# - if coordinates are flat string 'null', turn into a real null.
# one day I would like this code to go the hell away.
sub normalizejson {
	my $i = shift;
	my $kludge_search_api_adjust = shift;
	my $tag = shift;
	my $rt;

	# tag the tweet
	$i->{'tag'} = $tag if (defined($tag));

	# id -> id_str if needed
	if (!length($i->{'id_str'})) {
		my $k = "" + (0 + $i->{'id'});
		if ($k !~ /[eE][+-]/) {
			$i->{'id_str'} = $k;
		} else {
			# desperately try to convert
			$k =~ s/[eE][+-]\d+$//;
			$k =~ s/\.//g;
			# this is a hack, so we warn.
			&$exception(13,
"*** impending doom: ID overflows Perl precision; stubbed to $k\n");
			$i->{'id_str'} = $k;
		}
	}
	# irtsid -> irtsid_str (if there is one)
	if (!length($i->{'in_reply_to_status_id_str'}) &&
			$i->{'in_reply_to_status_id'}) {
		my $k = "" + (0+$i->{'in_reply_to_status_id'});
		if ($k !~ /[eE][+-]/) {
			$i->{'in_reply_to_status_id_str'} = $k;
		} else {
			# desperately try to convert
			$k =~ s/[eE][+-]\d+$//;
			$k =~ s/\.//g;
			# this is a hack, so we warn.
			&$exception(13,
"*** impending doom: IRT-ID overflows Perl precision; stubbed to $k\n");
			$i->{'in_reply_to_status_id_str'} = $k;
		}
	}

	# normalize geo. if this has a source and it has a
	# favorited, then it is probably a tweet and we will
	# add a stub geo hash if one doesn't exist yet.
	if ($kludge_search_api_adjust || 
			($i->{'favorited'} && $i->{'source'})){
		$i = &fix_geo_api_data($i);
	}

	# hooray! this just tags it
	if ($kludge_search_api_adjust) {
		$i->{'class'} = "search";
	}

	# normalize newRTs
	# if we get newRTs with -nonewrts, oh well
	if (!$nonewrts && ($rt = $i->{'retweeted_status'})) {
		# reconstruct the RT in a "canonical" format
		# without truncation, but detco it first
		$rt = &destroy_all_tco($rt);
		$i->{'retweeted_status'} = $rt;
		$i->{'text'} =
		"RT \@$rt->{'user'}->{'screen_name'}" . ': ' . $rt->{'text'};
	}

	return &destroy_all_tco($i);
}

# process the JSON data ... simplemindedly, because I just write utter crap,
# am not a professional programmer, and don't give a flying fig whether
# kludges suck or no. this used to be part of grabjson, but I split it out.
sub parsejson {
	my $data = shift;
	my $my_json_ref = undef; # durrr hat go on foot
	my $i;
	my $tdata;
	my $seed;
	my $bbqqmask;
	my $ddqqmask;
	my $ssqqmask;

	# test for single logicals
	return {
		'ok' => 1,
		'result' => (($1 eq 'true') ? 1 : 0),
		'literal' => $1,
			} if ($data =~ /^['"]?(true|false)['"]?$/);

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
	1 while $tdata =~ s/'[^']*'//; # empty strings are valid too ...
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
		# at this point all we should have are structural elements.
		# if something other than JSON structure is visible, then
		# the syntax tree is mangled. don't try to run it, it
		# might be unsafe. this exception was formerly uniformly
		# fatal. it is now non-fatal as of 2.1.
		if ($tdata =~ /[^\[\]\{\}:,]/) {
			&$exception(99, "*** JSON syntax error\n");
			print $stdout <<"EOF" if ($verbose);
--- data received ---
$data
--- syntax tree ---
$tdata
--- JSON PARSING ABORTED DUE TO SYNTAX TREE FAILURE --
EOF
			return undef;
		}
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
	if (!defined($my_json_ref)) {
		&$exception(99, "*** JSON syntax error\n");
		print $stdout <<"EOF" if ($verbose);
--- data received ---
$data
--- syntax tree ---
$tdata
--- JSON PARSING FAILED --
$@
--- JSON PARSING FAILED --
EOF
	}

	return $my_json_ref;
}

sub fix_geo_api_data {
	my $ref = shift;
	$ref->{'geo'}->{'coordinates'} = undef
		if ($ref->{'geo'}->{'coordinates'} eq 'null' ||
		    $ref->{'geo'}->{'coordinates'}->[0] eq '' ||
		    $ref->{'geo'}->{'coordinates'}->[1] eq '');
	$ref->{'geo'}->{'coordinates'} ||= [ "undef", "undef" ];
	return $ref;
}

sub is_fail_whale {
	# is this actually the dump from a fail whale?
	my $data = shift;
	return ($data =~ m#<title>Twitter.+Over.+capacity.*</title>#i ||
		$data =~ m#[\r\l\n\s]*DB_DataObject Error: Connect failed#s);
}

# {'errors':[{'message':'Rate limit exceeded','code':88}]}
sub is_json_error {
	# is this actually a JSON error message? if so, extract it
	my $data = shift;
	if ($data =~ /(['"])(warning|errors?)\1\s*:\s*/s) {
		if ($data =~ /^\s*\{/s) { # JSON object?
			my $dref = &parsejson($data);
			print $stdout "*** is_json_error returning true\n"
				if ($verbose);
			# support 1.0 and 1.1 error objects
			return $dref->{'error'} if (length($dref->{'error'}));
			return $dref->{'errors'}->[0]->{'message'}
				if (length($dref->{'errors'}->[0]->{'message'}));
			return (split(/\\n/, $dref->{'errors'}))[0]
				if(length($dref->{'errors'}));
		}
		return $data;
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
	my $dont_do_auth = shift;
	my $buf = '';
	my $undersave = $_;
	my $pid;
	my $args;

	($comm, $args, $data) = &$stringify_args($comm, $resource,
		$data, $dont_do_auth, @_);
	print $stdout "$comm\n$args\n$data\n" if ($superverbose);
	if(open(BACTIX, '-|')) {
		while(<BACTIX>) {
			$buf .= $_;
		} close(BACTIX);
		$_ = $undersave;
		return $buf; # and $? is still in $?
	} else {
		$in_backticks = 1;
		&sigify(sub {
			die(
		"** user agent not honouring timeout (caught by sigalarm)\n");
		}, qw(ALRM));
		alarm 120; # this should be sufficient
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

	push(@paths, '/usr/bin'); # the usual place
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

# &in($x, @y) returns true if $x is a member of @y
sub in { my $key = shift; my %mat = map { $_ => 1 } @_;
	return $mat{$key}; }

sub descape {
	my $x = shift;
	my $mode = shift;

	$x =~ s#\\/#/#g;

	# try to do something sensible with unicode
	if ($mode) { # this probably needs to be revised
		$x =~ s/\\u([0-9a-fA-F]{4})/"&#" . hex($1) . ";"/eg;
	} else {
		# intermediate form if HTML entities get in
		$x =~ s/\&\#([0-9]+);/'\u' . sprintf("%04x", $1)/eg;

		$x =~ s/\\u202[89]/\\n/g;

		# canonicalize Unicode whitespace
		1 while ($x =~ s/\\u(00[aA]0)/ /g);
		1 while ($x =~ s/\\u(200[0-9aA])/ /g);
		1 while ($x =~ s/\\u(20[25][fF])/ /g);
		if ($seven) {
			# known UTF-8 entities (char for char only)
			$x =~ s/\\u201[89]/\'/g;
			$x =~ s/\\u201[cCdD]/\"/g;

			# 7-bit entities (32-126) also ok
	$x =~ s/\\u00([2-7][0-9a-fA-F])/chr(((hex($1)==127)?46:hex($1)))/eg;

			# dot out the rest
			$x =~ s/\\u([0-9a-fA-F]{4})/./g;
			$x =~ s/[\x80-\xff]/./g;
		} else {
			# try to promote to UTF-8
			&$utf8_decode($x);

			# Twitter uses UTF-16 for high code points, which
			# Perl's UTF-8 support does not like as surrogates.
			# try to decode these here; they are always back-to-
			# back surrogates of the form \uDxxx\uDxxx
			$x =~
s/\\u([dD][890abAB][0-9a-fA-F]{2})\\u([dD][cdefCDEF][0-9a-fA-F]{2})/&deutf16($1,$2)/eg;

			# decode the rest
			$x =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/eg;
			$x = &uforcemulti($x);
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

# used by descape: turn UTF-16 surrogates into a Unicode character
sub deutf16 {
	my $one = hex(shift);
	my $two = hex(shift);
	# subtract 55296 from $one to yield top ten bits
	$one -= 55296; # $d800
	# subtract 56320 from $two to yield bottom ten bits
	$two -= 56320; # $dc00

	# experimentally, Twitter uses this endianness below (we have no BOM)
	# see RFC 2781 4.3
	return chr(($one << 10) + $two + 65536);
}
sub max { return ($_[0] > $_[1]) ? $_[0] : $_[1]; }
sub min { return ($_[0] < $_[1]) ? $_[0] : $_[1]; }
sub prolog { my $k = shift; 
	return "" if (!scalar(@_));
	my $l = shift; return (&$k($l) . &$k(@_)); }
# this is mostly a utility function for /eval. it is a recursive descent
# pretty printer.
sub a {
	my $w;
	my $x;
	return '' if(scalar(@_) < 1);
	if(scalar(@_) > 1) { $x = "(";
		foreach $w (@_) {
			$x .= &a($w);
		}
		return $x."), ";
	}
	$w = shift;
	if(ref($w) eq 'SCALAR') { return "\\\"". $$w . "\", "; }
	if(ref($w) eq 'HASH') { my %m = %{ $w };
		return "\n\t{".&prolog(\&a, %m)."}, "; }
	if(ref($w) eq 'ARRAY') { return "\n\t[".&prolog(\&a, @{ $w })."], "; }
	return "\"$w\", ";
}
sub ssa   { return (scalar(@_) ? ("('" . join("', '", @_) . "')") : "NULL"); }

sub strim { my $x=shift; $x=~ s/^\s+//; $x=~ s/\s+$//; return $x; }

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
sub uforcemulti { # forces multi-byte interpretation by abusing Perl
	my $x = shift;
	return $x if ($seven);
	$x = "\x{263A}".$x;
	return pack("${pack_magic}H*", substr(unpack("${pack_magic}H*",$x),6));
}
sub ulength { my @k; return (scalar(@k = unpack("${pack_magic}C*", shift))); }
sub uhex {
	# URL-encode an arbitrary string, even UTF-8
	# more versatile than the miniature one in &updatest
	my $k = '';
	my $s = shift;
	&$utf8_encode($s);

	foreach(split(//, $s)) {
		my $j = unpack("H256", $_);
		while(length($j)) {
			$k .= '%' . substr($j, 0, 2);
			$j = substr($j, 2);
		}
	}
	return $k;
}

# for t.co
# adapted from github.com/twitter/twitter-text-js/blob/master/twitter-text.js
# this is very hard to get right, and I know there are edge cases. this first
# one is designed to be quick and dirty because it needs to be fast more than
# it needs to be accurate, since T:RL:T calls it a LOT. however, it can be
# fooled, see below.
sub fastturntotco {
	my $s = shift;
	my $w;

	# turn domain names into http urls. this should look at .com, .net,
	# .etc., but things like you.suck.too probably *should* hit this
	# filter. this uses the heuristic that a domain name over some limit
	# is probably not actually a domain name.
	($s =~ s#\b(([a-zA-Z0-9-_]\.)+([a-zA-Z]){2,})\b#((length($w="$1")>45)?$w:"http://$w")#eg);

	# now turn all http and https URLs into t.co strings
	($s =~ s#\b(https?)://[a-zA-Z0-9-_]+[^\s]*?('|\\|\s|[\.;:,!\?]\s+|[\.;:,!\?]$|$)#\1://t.co/1234567\2#gi);
	return $s;
}
# slow t.co converter. this is for future expansion.
sub turntotco {
	return &fastturntotco(shift);
}

sub ulength_tco {
	my $w = shift;
	return &ulength(($notco) ? $w : &turntotco($w));
}
sub length_tco {
	my $w = shift;
	return length(($notco) ? $w : &turntotco($w));
}
# take a string and return up to $linelength CHARS plus the rest.
sub csplit { return &cosplit(@_, sub { return  &length_tco(shift); }); }
# take a string and return up to $linelength BYTES plus the rest.
sub usplit { return &cosplit(@_, sub { return &ulength_tco(shift); }); }
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
	return ($k) if ($z <= $linelength); # also handles the trivial case

	# this needs to be reply-aware, so we put @'s at the beginning of
	# the second half too (and also Ds for DMs)
	$r .= $1 while ($k =~ s/^(\@[^\s]+\s)\s*// ||
			$k =~ s/^(D\s+[^\s]+\s)\s*//);  # we have r/a, so while
	$k = "$r$k";

	my $i = $linelength;
	$i-- while(($z = &$lengthsub($q = substr($k, 0, $i))) > $linelength);
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
		if (&$lengthsub($q) < $linelength) {
			$m =~ s/^\s+//;
			return($q, "$r$m")
		}
	}
	($q =~ s/\s+([^\s]+)$//) && ($m = "$1$m");
	return (&cosplit($orig_k, 1, $lengthsub)) if (!length($q) && !$mode);
		# it totally failed. fall back on charsplit.
	return ($q, "$r$m");
}

### OAuth methods, including our own homegrown SHA-1 and HMAC ###
### no Digest:* required! ###
### these routines are not byte-safe and need a use bytes; before you call ###

# this is a modified, deciphered and deobfuscated version of the famous Perl
# one-liner SHA-1 written by John Allen. hope he doesn't mind.
sub sha1 {
	my $string = shift;
	print $stdout "string length: @{[ length($string) ]}\n"
		if ($showwork);

	my $constant = "D9T4C`>_-JXF8NMS^\$#)4=L/2X?!:\@GF9;MGKH8\\;O-S*8L'6";
	my @A = unpack('N*', unpack('u', $constant));
	my @K = splice(@A, 5, 4);
	my $M  = sub { # 64-bit warning
		my $x;
		my $m;
		($x = pop @_) - ($m=4294967296) * int($x / $m);
	};
	my $L = sub { # 64-bit warning
		my $n = pop @_;
		my $x;
		((($x = pop @_) << $n) | ((2 ** $n - 1) & ($x >> 32 - $n))) &
			4294967295;
	};
	my $l = '';
	my $r;
	my $a;
	my $b;
	my $c;
	my $d;
	my $e;
	my $us;
	my @nuA;
	my $p = 0;
	$string = unpack("H*", $string);

	do {
		my $i;
		$us = substr($string, 0, 128);
		$string = substr($string, 128);
		$l += $r = (length($us) / 2);
		print $stdout "pad length: $r\n" if ($showwork);
		($r++, $us .= "80") if ($r < 64 && !$p++);
		my @W = unpack('N16', pack("H*", $us) . "\000" x 7);
		$W[15] = $l * 8 if ($r < 57);
		foreach $i (16 .. 79) {
		    push(@W,
		&$L($W[$i - 3] ^ $W[$i - 8] ^ $W[$i - 14] ^ $W[$i - 16], 1));
		}
		($a, $b, $c, $d, $e) = @A;
		foreach $i (0 .. 79) {
		   my $qq = ($i < 20) ? ($b & ($c ^ $d) ^ $d) :
				($i < 40) ? ($b ^ $c ^ $d) :
				($i < 60) ? (($b | $c) & $d | $b & $c) :
				($b ^ $c ^ $d);
		    $t = &$M($qq + $e + $W[$i] + $K[$i / 20] + &$L($a, 5));
		    $e = $d;
		    $d = $c;
		    $c = &$L($b, 30);
		    $b = $a;
		    $a = $t;
		}
		@nuA = ($a, $b, $c, $d, $e);
		print $stdout "$a $b $c $d $e\n" if ($showwork);
		$i = 0;
		@A = map({ &$M($_ + $nuA[$i++]); } @A);
	} while ($r > 56);
	my $x = sprintf('%.8x' x 5, @A);
	@A = unpack("C*", pack("H*", $x));
	return($x, @A);
}

# heavily modified from MIME::Base64
sub simple_encode_base64 {
	my $result = '';
	my $input = shift;

	pos($input) = 0;
	while($input =~ /(.{1,45})/gs) {
		$result .= substr(pack("u", $1), 1);
		chop($result);
	}
	$result =~ tr|` -_|AA-Za-z0-9+/|;
	my $padding = (3 - length($input) % 3) % 3;
	$result =~ s/.{$padding}$/("=" x $padding)/e if ($padding);

	return $result;
}

# from RFC 2104/RFC 2202

sub hmac_sha1 {
	my $message = shift;
	my @key = (@_);
	my $opad;
	my $ipad;
	my $i;
	my @j;
	
	# sha1 blocksize is 512, so key should be 64 bytes

print $stdout " KEY HASH \n" if ($showwork);
	($i, @key) = &sha1(pack("C*", @key)) while (scalar(@key) > 64);
	push(@key, 0) while(scalar(@key) < 64);
	$opad = pack("C*", map { ($_ ^ 92) } @key);
	$ipad = pack("C*", map { ($_ ^ 54) } @key);

print $stdout " MESSAGE HASH \n" if ($showwork);
	($i, @j) = &sha1($ipad . $message);
print $stdout " FINAL HASH \n" if ($showwork);
	$i = pack("C*", @j); # output hash is 160 bits
	($i, @j) = &sha1($opad . $i);
	$i = &simple_encode_base64(pack("C20", @j));

	return $i;
}

# simple encoder for OAuth modified URL encoding (used for lots of things,
# actually)
# this is NOT UTF-8 safe
sub url_oauth_sub {
	my $x = shift;
	$x =~ s/([^-0-9a-zA-Z._~])/"%".uc(unpack("H*",$1))/eg; return $x;
}

# default method of getting password: ask for it. only relevant for Basic Auth,
# which is no longer the default.
sub defaultgetpassword {
	# original idea by @jcscoobyrs, heavily modified
	my $k;
	my $l;
	my $pass;

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
	return $pass;
}

# this returns an immutable token corresponding to the current authenticated
# session. in the case of Basic Auth, it is simply the user:password pair.
# it does not handle OAuth -- that is run by a separate wizard.
# the function then returns (token,secret) which for Basic Auth is token,undef.
# most of the time we will be using tokens in a keyfile, however, so this
# function runs in that case as a stub.
sub authtoken {
	my @foo;
	my $pass;
	my $sig;
	my $return;
	my $tries = ($hold > 3) ? $hold : 3;
		# give up on token if we don't get one

	return (undef,undef) if ($anonymous);
	return ($tokenkey,$tokensecret)
		if (length($tokenkey) && length($tokensecret));
	@foo = split(/:/, $user, 2);
	$whoami = $foo[0];
	die("choose -user=username[:password], or -anonymous.\n")
		if (!length($whoami) || $whoami eq '1');
	$pass = length($foo[1]) ? $foo[1] : &$getpassword;
	die("a password must be specified.\n") if (!length($pass));
	return ($whoami, $pass);
}

# this is a sucky nonce generator. I was looking for an awesome nonce
# generator, and then I realized it would only be used once, so who cares?
# *rimshot*
sub generate_nonce { unpack("H9000", pack("u", rand($$).$$.time())); }

# this signs a request with the token and token secret. the result is undef if
# Basic Auth. payload should already be URL encoded and *sorted*.
# this is typically called by stringify_args to get authentication information.
sub signrequest {

	# this horrible kludge is needed to account for both 5.005, or for
	# 5.6+ installs with no stdlibs and just a bare Perl, both of which
	# we support. I hope Larry Wall will forgive me for messing with
	# compiler internals next time I see him at church.
	BEGIN { $^H |= 0x00000008 unless ($] < 5.006); }

	my $resource = shift;
	my $payload = shift;

	# when we sign the initial request for an token, we obviously
	# don't have one yet, so mytoken/mytokensecret can be null.

	my $nonce = &generate_nonce;
	my @keybytes;
	my $sig_base;
	my $timestamp = time();
	return undef if ($authtype eq 'basic');

	# stub for oAuth 2.0
	return undef if (!length($oauthkey) || !length($oauthsecret));

	(@keybytes) = map { ord($_) }
		split(//, $oauthsecret.'&'.$mytokensecret);
	if (ref($resource) eq 'ARRAY' || length($payload)) {
		# split into _a and _b payloads lexically
		my $payload_a = '';
		my $payload_b = '';
		my $payload_c = ''; # this is for a special case
		my $w;
		my $aorb = 0;
		my $verifier = '';
		my $method = "GET";
		my $url;
	
		if (length($payload)) {
			$method = "POST";
			# this is a bit problematic since it won't be
			# sorted. we'll deal with this as we need to.
			if (ref($resource) eq 'ARRAY') {
				$url = &url_oauth_sub($resource->[0]);
				$payload .= "&" . $resource->[1];
			} else {
				$url = &url_oauth_sub($resource);
			}
		} elsif (ref($resource) eq 'ARRAY') {
			$url = &url_oauth_sub($resource->[0]);
			$payload = $resource->[1];
		} else {
			$url = &url_oauth_sub($resource);
		}

		# this is pretty simplistic but it's really all we need.
		# the exception is oauth_verifier: that has to be wormed
		# into the middle, and we assume it's just that.
		if ($payload !~ /^oauth_verifier/) {
			foreach $w (split(/\&/, $payload)) {
				$aorb = 1 if
					($w =~ /^[p-z]/ || $w =~ /^o[b-z]/);
				$w = &url_oauth_sub("${w}&");
				if ($aorb) {
					$payload_b .= $w;
				} else {
					$payload_a .= $w;
				}
			}
		} else {
			$payload_c = &url_oauth_sub($payload) . "%26";
			$payload_a = $payload_b = '';
			$payload =~ s/^oauth_verifier=//;
			$verifier = ' oauth_verifier=\\"' . $payload . '\\",';
		}
		$payload_b =~ s/%26$//;
		$sig_base = $method . "&" .
			$url . "&" .
			(length($payload_a) ? $payload_a : '').
			"oauth_consumer_key%3D" . $oauthkey . "%26" .
			"oauth_nonce%3D" . $nonce . "%26" .
			"oauth_signature_method%3DHMAC-SHA1%26" .
			"oauth_timestamp%3D" . $timestamp . "%26" .
			(length($mytoken) ? 
				("oauth_token%3D" . $mytoken . "%26") : '') .
			$payload_c .
			"oauth_version%3D1.0" .
			(length($payload_b) ? ("%26" . $payload_b) : '');
	} else {
		$sig_base = "GET&" .
			&url_oauth_sub($resource) . "&" .
			"oauth_consumer_key%3D" . $oauthkey . "%26" .
			"oauth_nonce%3D" . $nonce . "%26" .
			"oauth_signature_method%3DHMAC-SHA1%26" .
			"oauth_timestamp%3D" . $timestamp . "%26" .
			(length($mytoken) ? 
				("oauth_token%3D" . $mytoken . "%26") : '') .
			$payload_c . # could be part of it
			"oauth_version%3D1.0" ;
	}
	print $stdout
"token-secret: $mytokensecret\nconsumer-secret: $oauthsecret\nsig-base: $sig_base\n"
		if ($superverbose);
	return ($timestamp, $nonce,
		&url_oauth_sub(&hmac_sha1($sig_base, @keybytes)),
			$verifier);
}

# this takes a token request and "tries hard" to get it.
sub tryhardfortoken {
	my $url = shift;
	my $body = shift;
	my $tries = shift;
	my $rawtoken;
	$tries ||= 3;

	while($tries) {
		my $i;
		$rawtoken = &backticks($baseagent, '/dev/null', undef,
			$url, $body, 0, @wend);
		print $stdout ("token = $rawtoken\n")
			if ($superverbose);
		my (@keyarr) = split(/\&/, $rawtoken);
		my $got_token = '';
		my $got_secret = '';
		foreach $i (@keyarr) {
			my $key;
			my $value;

			($key, $value) = split(/\=/, $i);
			$got_token = $value if ($key eq 'oauth_token');
			$got_secret = $value if ($key eq 'oauth_token_secret');
		}
		if (length($got_token) && length($got_secret)) {
			print $stdout " SUCCEEDED!\n";
			return ($got_token, $got_secret);
		}
		print $stdout ".";
		$tries--;
	}
	print $stdout " FAILED!: \"$rawtoken\"\n";
die("unable to fetch token. here are some possible reasons:\n".
    " - root certificates are not updated (see documentation)\n".
    " - you entered your authentication information wrong\n".
    " - your computer's clock is not set correctly\n" .
    " - Twitter farted\n" .
    "fix these possible problems, or try again later.\n");
		exit;
}
