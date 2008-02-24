#!/usr/bin/perl -s
#########################################################################
#
# TTYtter v0.7 (c)2007, 2008 cameron kaiser. all rights reserved.
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
#$maxhist=19;while(<>){last if(&prinput($_));}exit;

BEGIN {
	$TTYtter_VERSION = 0.7;
	$TTYtter_PATCH_VERSION = 1;

	(warn ("${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}\n"), exit)
		if ($version);

	$ENV{'PERL_SIGNALS'} = 'unsafe';
	%valid = qw(
		url 1 lynx 1 curl 1 pause 1 user 1 seven 1 dmurl 1
		dmpause 1 silent 1 superverbose 1 maxhist 1 noansi 1
		lib 1 verbose 1 hold 1 status 1 update 1 daemon 1
		timestamp 1 ansi 1 uurl 1 rurl 1 twarg 1 anonymous 1
		wurl 1
	);
	if (open(W, ($n = "$ENV{'HOME'}/.ttytterrc"))) {
		#open(W, $n) || die("wickedness: $!\n");
		while(<W>) {
			chomp;
			next if (/^\s*$/ || /^#/);
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
	$icount = 1;
	$last_id = 0;
	$last_dm = 0;
	$print_max = 20;

	if (length($lib)) {
		warn "** attempting to load library: $lib\n" unless ($silent);
		require $lib;
	}
	unless ($seven) {
		eval
'use utf8;binmode(STDIN,":utf8");binmode(STDOUT,":utf8");return 1' ||
	die("$@\nthis perl doesn't fully support UTF-8. use -seven.\n");
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
	&killkid;
}

sub killkid {
	if ($child) {
		print STDOUT "\n\ncleaning up.\n";
		kill 9, $child;
	}
}

if ($silent) {
	close(STDOUT);
	open(STDOUT, ">>/dev/null"); # KLUUUUUUUDGE
}

# defaults
$anonymous ||= 0;
$url ||= ($anonymous)
	? "http://twitter.com/statuses/public_timeline.json"
	: "http://twitter.com/statuses/friends_timeline.json";
$rurl ||= "http://twitter.com/statuses/replies.json";
$uurl ||= "http://twitter.com/statuses/user_timeline";
$wurl ||= "http://twitter.com/users/show";
$update ||= "http://twitter.com/statuses/update.json";
$dmurl ||= "http://twitter.com/direct_messages.json";
$dmpause = 4 if (!defined $dmpause); # NOT ||= ... zero is a VALID value!
$dmpause = 0 if ($anonymous);
$pause ||= 120;
$superverbose ||= 0;
$verbose ||= $superverbose;
$hold ||= 0;
$daemon ||= 0;
$maxhist ||= 19;
$ansi ||= ($noansi) ? 0 :
	(($ENV{'TERM'} eq 'ansi' || $ENV{'TERM'} eq 'xterm-color') ? 1 : 0);
$timestamp ||= 0;
$whoami = (split(/\:/, $user, 2))[0];
$twarg ||= undef;

$dmcount = $dmpause;

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
$BLUE = ($ansi) ? "${ESC}[34;1m" : '';
$RED = ($ansi) ? "${ESC}[31;1m" : '';
$GREEN = ($ansi) ? "${ESC}[32;1m" : '';
$YELLOW = ($ansi) ? "${ESC}[33m" : '';
$MAGENTA = ($ansi) ? "${ESC}[35m" : '';
$CYAN = ($ansi) ? "${ESC}[36m" : '';
$EM = ($ansi) ? "${ESC}[1;3m" : '';
$OFF = ($ansi) ? "${ESC}[0m" : '';

# default exposed methods
# don't change these here. instead, use -lib=yourlibrary.pl and set them there.
# note that these are all anonymous subroutine references.
# anything you don't define is overwritten by the defaults.
# it's better'n'superclasses.

sub defaultexception { shift; print STDOUT "${MAGENTA}@_${OFF}"; }
$exception ||= \&defaultexception;
# [{"text":"\"quote test\" -- let's see what that does to the code.","id":56487562,"user":{"name":"Cameron Kaiser","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","screen_name":"doctorlinguist","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","url":"http:\/\/www.cameronkaiser.com","id":3841961,"protected":false},"created_at":"Wed May 09 03:28:38 +0000 2007"},
sub defaulthandle {
	my $ref = shift;
	my $sn = &descape($ref->{'user'}->{'screen_name'});
	my $tweet = &descape($ref->{'text'});
	my $g = "<$sn> $tweet$OFF\n";
	# br3nda's modified timestamp patch
	if ($timestamp) {
		my $time = $ref->{'created_at'};
		my $ts = $time;
		if ($mtimestamp) {
			# avoid precompiling these in case .pm not present
			eval '$time = str2time($time);' ||
				die("str2time failed: $time $@ $!\n");
			eval '$ts = time2str($timestamp, $time);' ||
				die("time2str failed: $timestamp $time $@\n");
		}
		$g = "$ts $g";
	}
	# br3nda's modified colour patch
	unless ($anonymous) {
		if ($sn eq $whoami) {
			#if it's me speaking, colour the line yellow
			print STDOUT $YELLOW;
		} elsif ($tweet =~ /\@$whoami/i) {
			#if I'm in the tweet, colour red
			print STDOUT $RED;
		}
	}
	print STDOUT $g;
	return 1;
}
$handle ||= \&defaulthandle;

sub defaultconclude { ; }
$conclude ||= \&defaultconclude;

# {"recipient_id":3841961,"sender":{"url":"http:\/\/www.xanga.com\/the_shambleyqueen","name":"Staci Gainor","screen_name":"emo_mom","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/7460892\/normal\/Staci_070818__2_.jpg?1187488390","description":"mildly neurotic; slightly compulsive; keenly observant  Christian mom of four, including identical twins","location":"Pennsylvania","id":7460892,"protected":false},"created_at":"Fri Aug 24 04:03:14 +0000 2007","sender_screen_name":"emo_mom","recipient_screen_name":"doctorlinguist","recipient":{"url":"http:\/\/www.cameronkaiser.com","name":"Cameron Kaiser","screen_name":"doctorlinguist","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","id":3841961,"protected":false},"text":"that is so cool; does she have a bit of an accent? do you? :-) and do you like vegemite sandwiches?","sender_id":7460892,"id":8570802}
sub defaultdmhandle {
	my $ref = shift;
	my $time = $ref->{'created_at'};
	my $ts = $time;
	if ($mtimestamp) {
		# avoid precompiling these in case .pm not present
		eval '$time = str2time($time);' ||
			die("str2time failed: $time $@ $!\n");
		eval '$ts = time2str($timestamp, $time);' ||
			die("time2str failed: $timestamp $time $@\n");
	}
	my $g = "${GREEN}[DM ". &descape($ref->{'sender'}->{'screen_name'}) .
		'/'. $ts .
		'] '. &descape($ref->{'text'}) . "$OFF\n";
	print STDOUT $g;
	return 1;
}
$dmhandle ||= \&defaultdmhandle;

sub defaultdmconclude { ; }
$dmconclude ||= \&defaultdmconclude;

sub defaultheartbeat { ; }
$heartbeat ||= \&defaultheartbeat;

select(STDOUT); $|++;

die("$0: specify -user=username:password\n")
	if (!$anonymous && 
		(!length($user) || $user !~ /:/ || $user =~ /[\s;><|]/));
if ($lynx) {
	$wend = &wherecheck("trying to find Lynx", "lynx",
"specify -curl to use curl instead, or just let TTYtter autodetect stuff.\n");
} else {
	$wend = (($curl) ? &wherecheck("trying to find curl", "curl",
"specify -lynx to use Lynx instead, or just let TTYtter autodetect stuff.\n")
			: &wherecheck("trying to find curl", "curl"));
	if (!$curl && !length($wend)) {
		$wend = &wherecheck("failed. trying to find Lynx", "lynx",
	"you must have either Lynx or curl installed to use TTYtter.\n")
				if (!length($wend));
		$lynx = 1;
	}
}
if ($lynx) {
	$wend = "$wend -nostatus";
	$wend = "$wend -auth=$user" unless ($anonymous);
	$wand = "$wend -source";
	$wind = "$wand";
	$wend = "$wend -post_data";
} else {
	$wend = "$wend --basic -m 13 -f";
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
	if (length($status) && $phase) {
		print "post attempt "; $rv = &updatest($status, 0);
	} else {
		print "test-login "; $data = `$wind $url 2>/dev/null`;
		$rv = $?;
	}
	if ($rv) {
		$x = $rv >> 8;
		print "FAILED. ($x) bad username? bad url? resource down?\n";
		print "access failure on: ";
		print (($phase) ? $update : $url);
		print "\n";
		if ($hold) {
			print
			"trying again in 3 minutes, or kill process now.\n\n";
			sleep 180;
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
	if ($child = fork()) {
		print STDOUT "*** detached daemon released. pid = $child\n";
		kill 15, $$;
		exit 0;
	} elsif (!defined($child)) {
		print STDOUT "*** fork() failed: $!\n";
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
$e =~ s/\$\{([A-Z]+)\}/${$1}/eg; print STDOUT $e;
if ($superverbose) {
	print STDOUT "-- OMGSUPERVERBOSITYSPAM enabled.\n\n";
} else {
	print STDOUT "-- verbosity enabled.\n\n" if ($verbose);
}
sleep 2 unless ($silent);

if ($child = open(C, "|-")) { ; } else { goto MONITOR; }
select(C); $|++; select(STDOUT);

sub defaultprompt { print STDOUT "${CYAN}TTYtter>${OFF} "; }
$prompt ||= \&defaultprompt;

sub defaultconsole {
	@history = ();
	&$prompt;
	while(<>) {
		$rv = &prinput($_);
		last if ($rv);
	}
}

$console ||= \&defaultconsole;
&$console;
exit;

sub prinput {
	my $i;

	chomp;
	s/^\s+//;
	s/\s+$//;

	if (/^$/) {
		&$prompt;
		return 0;
	}

	# handle history display
	if ($_ eq '/history' || $_ eq '/h') {
		for ($i = 1; $i <= scalar(@history); $i++) {
			print STDOUT "\t$i\t$history[($i-1)]\n";
		}
		&$prompt;
		return 0;
	}	
	if (/^\%(\%|-\d+):p$/) {
		my $x = $1;
		if ($x eq '%') {
			print STDOUT "=> \"$history[0]\"\n";
		} else {
			$x += 0;
			if (!$x || $x < -(scalar(@history))) {
				print STDOUT "*** illegal index\n";
			} else {
				print STDOUT "=> \"$history[-($x + 1)]\"\n";
			}
		}
		&$prompt;
		return 0;
	}

	# handle history substitution (including /%%)
	$i = 0;
	if (/^(\/?)\%(\%|-\d+)/) {
		$i = 1;
		my $x = $2;
		my $y = $1;
		$_ = substr($_, 1) if ($y eq '/');
		if ($x eq '%') {
			s/^\%\%/$history[0]/;
		} else {
			$x += 0;
			if (!$x || $x < -(scalar(@history))) {
				print STDOUT "*** illegal index\n";
				&$prompt;
				return 0;
			} else {
				s/^\%-\d+/$history[-($x + 1)]/;
			}
		}
		$_ = "$y$_";
	}

	# and escaped history
	s/^\\\%/%/;

	print STDOUT "(expanded to \"$_\")\n" if ($i);
	@history = (($_, @history)[0..&min(scalar(@history), $maxhist)]);

	#print STDOUT join("|", @history); print STDOUT scalar(@history),"\n"; &$prompt; return 0;

	my $slash_first = ($_ =~ m#^/#);
	return -1 if ($_ eq '/quit' || $_ eq '/q');

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
     process.          .+++++++++: =@*.....=a$OOOB#;     ALL COMMANDS AND
                                   =@OoO@BAAA#@$o,          TWEETS ARE
                                   =@o  .+aaaaa:         --ASYNCHRONOUS--
   /again                          =@Aaaaaaaaaa*o*a;,    and don't always
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
		print "PRESS RETURN/ENTER> ";
		$j = <STDIN>;
		print <<"EOF";

 TTYtter $TTYtter_VERSION is (c)2008 cameron kaiser. all rights reserved. this software
 is offered AS IS, with no guarantees. it is not endorsed by Obvious or the
 executives and developers of Twitter.

 --- twitter: doctorlinguist --- http://www.floodgap.com/software/ttytter/ ---

           *** subscribe to updates at http://twitter.com/ttytter
                                    or http://twitter.com/floodgap
               send your suggestions to me at ckaiser\@floodgap.com

EOF
		&$prompt;
		return 0;
	}
	if ($_ eq '/ruler' || $_ eq '/ru') {
		print STDOUT <<"EOF";
                  1         2         3         4         5         6         7         8         9         0         1         2         3        XX
TTYtter> 1...5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5....0....5...XX
EOF
		&$prompt;
		return 0;
	}
	if ($_ eq '/refresh' || $_ eq '/thump' || $_ eq '/r') {
		&thump;
		&$prompt;
		return 0;
	}
	if ($_ =~ m#^/(w)?a(gain)?\s+([^\s]+)#) { # the synchronous form
		my $mode = $1;
		my $uname = $3;
		print STDOUT "-- synchronous /again command for $uname\n"
			if ($verbose);
		my $my_json_ref = &grabjson(1, "$uurl/${uname}.json", 0);

		if (defined($my_json_ref) && scalar(@{ $my_json_ref })) {
			&tdisplay($my_json_ref);
		} # since interactive=1, errors are propagated in grabjson
		&$conclude;
		unless ($mode eq 'w') {
			&$prompt;
			return 0;
		} # else fallthrough
	}
	if ($_ =~ m#^/w(hois|a|again)?\s+([^\s]+)#) {
		my $uname = $2;
		print STDOUT "-- synchronous /whois command for $uname\n"
			if ($verbose);
		my $my_json_ref = &grabjson(1, "$wurl/${uname}.json", 0);

# {"status":{"created_at":"Thu Jan 10 16:03:20 +0000 2008","text":"@ijastram grand theft probably.","id":584052732},"profile_text_color":"000000","profile_link_color":"0000ff","name":"Cameron Kaiser","profile_background_image_url":"http:\/\/s3.amazonaws.com\/twitter_production\/profile_background_images\/564672\/shbak.gif","profile_sidebar_fill_color":"e0ff92","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","followers_count":277,"screen_name":"doctorlinguist","profile_sidebar_border_color":"87bc44","profile_image_url":"http:\/\/s3.amazonaws.com\/twitter_production\/profile_images\/20933022\/me2_normal.jpg","location":"Southern California","profile_background_tile":true,"favourites_count":49,"following":false,"statuses_count":9878,"friends_count":99,"profile_background_color":"9ae4e8","url":"http:\/\/www.cameronkaiser.com","id":3841961,"utc_offset":-28800,"protected":false}

		if (defined $my_json_ref) {
			print STDOUT <<"EOF"; 

${CYAN}@{[ &descape($my_json_ref->{'name'}) ]}${OFF} ($uname) (f:$my_json_ref->{'friends_count'}/$my_json_ref->{'followers_count'}) (u:$my_json_ref->{'statuses_count'})
EOF
			print STDOUT
"\"@{[ &descape($my_json_ref->{'description'}) ]}\"\n"
				if (length($my_json_ref->{'description'}));
			print STDOUT
"${EM}Location:${OFF}\t@{[ &descape($my_json_ref->{'location'}) ]}\n"
				if (length($my_json_ref->{'location'}));
			print STDOUT
"${EM}URL:${OFF}\t\t@{[ &descape($my_json_ref->{'url'}) ]}\n"
				if (length($my_json_ref->{'url'}));
			print STDOUT <<"EOF";
${EM}Picture:${OFF}\t@{[ &descape($my_json_ref->{'profile_image_url'}) ]}

EOF
		}
		&$prompt;
		return 0;
	}
		
	if ($_ eq '/again' || $_ eq '/a') { # the asynchronous form
		print C "reset----\n";
		&$prompt;
		return 0;
	}

	if ($_ eq '/replies' || $_ eq '/re') {
		if ($anonymous) {
			print STDOUT
		"-- sorry, how can anyone reply to you if you're anonymous?\n";
		} else {
			# we are intentionally not keeping track of "last_re"
			# in this version because it is not automatically
			# updated and may not act as we expect.
			print STDOUT "-- synchronous /replies command\n"
				if ($verbose);
			my $my_json_ref = &grabjson(1, $rurl, 0);
			if (defined($my_json_ref) && scalar(@{$my_json_ref})) {
				&tdisplay($my_json_ref);
			} # since interactive=1, errors are shown by grabjson
			&$conclude;
		}
		&$prompt;
		return 0;
	}

	if ($_ eq '/dm' || $_ eq '/dmrefresh' || $_ eq '/dmr') {
		print C "dmthump--\n";
		&$prompt;
		return 0;
	}

	if ($_ eq '/dmagain' || $_ eq '/dma') {
		print C "dmreset--\n";
		&$prompt;
		return 0;
	}

	if (m#^/me\s#) {
		$slash_first = 0; # kludge!
	}

	if ($slash_first) {
		if (!m#^//#) {
			print STDOUT "*** command not recognized\n";
			print STDOUT "*** to pass as a tweet, type /%%\n";
			&$prompt;
			return 0;
		}
		s#^/##; # leave the second slash on
	}

	if (length > 140) {
		$_ = substr($_, 0, 140);
		# s.m.r.t. truncator (like Homer Simpson)
		s/[^a-zA-Z0-9]+$//;
		s/\s+[^\s]+$// if (length == 140);
		$history[0] = $_;
		print STDOUT
			"*** sorry, tweet too long; truncated to \"$_\"\n";
		print STDOUT "*** use %% for truncated version, or append to %%.\n";
		&$prompt;
		return 0;
	}
	&updatest($_, 1);
	&$prompt;
	return 0;
}

sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $urle = '';
	my $i;
	my $subpid;

	if ($anonymous) {
		print STDOUT "-- sorry, you can't tweet if you're anonymous.\n"
			if ($interactive);
		return 99;
	}
	# to avoid unpleasantness with UTF-8 interactions, this will simply
	# turn the whole thing into a hex string and insert %, thus URL
	# escaping the whole thing whether it needs it or not. ugly? well ...
	$string = unpack("H280", $string);
	for($i = 0; $i < length($string); $i+=2) {
		$urle .= '%' . substr($string, $i, 2);
	}
	$subpid = open(N,
		# I know the below is redundant. this is to remind me to see
		# if there is something cleverer to do with it later.
"|$wend $update 2>/dev/null >/dev/null") || do{
		print STDOUT "post failure: $!\n" if ($interactive);
		return 99;
	};
	print N "source=TTYtter&status=$urle\n";
	close(N);
	if ($? > 0) {
		$x = $? >> 8;
		print STDOUT <<"EOF" if ($interactive);
${MAGENTA}*** warning: connect timeout or no confirmation received ($x)
*** to attempt a resend, type %%${OFF}
EOF
		return $?;
	}
	return 0;
}


sub thump { print C "update---\n"; }

MONITOR:
# asynchronous monitoring process -- uses select() to receive from console

$rin = '';
vec($rin,fileno(STDIN),1) = 1;
# paranoia
unless ($seven) {
	binmode(STDIN, ":utf8");
	binmode(STDOUT, ":utf8");
}
$interactive = $timeleft = 0;
$dm_first_time = ($dmpause) ? 1 : 0;

for(;;) {
	&$heartbeat;
	&refresh($interactive) unless ($timeleft);
	if ($dmpause) {
		if ($dm_first_time) {
			&dmrefresh(0);
		} elsif (!$interactive) {
			if (!--$dmcount) {
				&dmrefresh($interactive); # using dm_first_time
				$dmcount = $dmpause;
			}
		}
	}
	$interactive = $timeleft = 0;
	if($timeleft=select($rout=$rin, undef, undef, ($timeleft || $pause))) {
		sysread(STDIN, $rout, 10);
		next if (!length($rout));
		$last_id = 0 if ($rout =~ /^reset/);
		$last_dm = 0 if ($rout =~ /^dmreset/);
		$interactive = 1;
		$icount++;
		print STDOUT "-- command received ($icount) ", scalar
			localtime, " $rout" if ($verbose);
		if ($rout =~ /^dm/) {
			&dmrefresh($interactive);
			$dmcount = $dmpause;
		} else {
			$timeleft = 0;
		}
	} else {
		$icount++;
		print STDOUT "-- routine refresh ($icount/$dmcount) ", scalar
			localtime, "\n" if ($verbose);
	}
}

# the refresh engine depends on later tweets having higher id numbers.
# Obvious, don't change this if you know what's good for you, ya twerps,
# or I will poison all of yer kitties. *pats my Burmese, who purrs*

sub grabjson {
	my $data;
	my $interactive = shift;
	my $url = shift;
	my $last_id = shift;
	my $tdata;
	my $seed;
	my $xurl;
	my $my_json_ref = undef; # durrr hat go on foot

	#undef $/; $data = <STDIN>;
	$xurl = ($last_id) ? "?since_id=$last_id" : "";
	print STDOUT "$wand \"$url$xurl\"\n" if ($superverbose);
	chomp($data = `$wand "$url$xurl" 2>/dev/null`);

	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;

	if (!length($data)) {
		&$exception(1, "*** warning: timeout or no data\n");
		return undef;
	}

	# old non-JSON based error reporting code still supported
	if ($data =~ /^<!DOCTYPE\s+html/i || $data =~ /^(Status:\s*)?50[0-9]\s/ || $data =~ /^<html>/i) {
		&$exception(2, "*** warning: Twitter error message received\n" .
			(($data =~ /<title>Twitter:\s*([^<]+)</) ?
				"*** \"$1\"\n" : ''));
		return undef;
	}
	if ($data =~ /^rate\s*limit/i) {
		&$exception(3,
"*** warning: exceeded API rate limit for this interval.\n" .
((($verbose) && $icount > 1) ? "*** total requests: $icount\n" : "") .
"*** no updates available until interval ends.\n");
		$icount = 0;
		return undef;
	}

# process the JSON data ... simplemindedly, because I just write utter crap,
# am not a professional programmer, and don't give a flying fig whether
# kludges suck or no.

	# test for error/warning conditions with trivial case
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*?)\1/s) {
		&$exception(2, "*** warning: Twitter $2 message received\n" .
			"*** \"$3\"\n");
		return undef;
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

	print STDOUT "$data\n" if ($superverbose);

	# trust, but verify. I'm sure twitter wouldn't send us malicious
	# or bogus JSON, but one day this might talk to something that would.
	# in particular, need to make sure nothing in this will eval badly or
	# run arbitrary code. that would really suck!
	$tdata = $data;
	1 while $tdata =~ s/'[^']+'//;
	$tdata =~ s/-?[0-9]+//g;
	$tdata =~ s/(true|false|null)//g;
	$tdata =~ s/\s//g;

	print STDOUT "$tdata\n" if ($superverbose);

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
	print STDOUT "$data => $my_json_ref $@\n"  if ($superverbose);

	# do a sanity check
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!defined($my_json_ref));

	return $my_json_ref;
}

sub refresh {
	my $interactive = shift;
	my $my_json_ref = &grabjson($interactive, $url, $last_id);
	return if (!defined($my_json_ref) ||
		ref($my_json_ref) ne 'ARRAY' ||
		!scalar(@{ $my_json_ref }));
	$last_id = &tdisplay($my_json_ref);
	print STDOUT "-- id bookmark is $last_id.\n" if ($verbose);
	&$conclude;
} 

sub tdisplay { # used by both synchronous /again and asynchronous refreshes
	my $my_json_ref = shift;
	my $printed = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $g;

	for($i = $disp_max; $i > 0; $i--) {
		$g = ($i-1);
		next if ($my_json_ref->[$g]->{'id'} <= $last_id);
		next if
		(!length($my_json_ref->[$g]->{'user'}->{'screen_name'}));

		$printed += &$handle($my_json_ref->[$g]);
	}
	print STDOUT "-- sorry, nothing to display.\n"
		if (($interactive || $verbose) && !$printed);
	return &max(0+$my_json_ref->[0]->{'id'}, $last_id);
}

sub dmrefresh {
	my $interactive = shift;
	if ($anonymous) {
		print STDOUT
			"-- sorry, you can't read DMs if you're anonymous.\n"
			if ($interactive);
		return;
	}

	# no point in doing this if we can't even get to our own timeline
	# (unless user specifically requested it)
	return if (!$interactive && !$last_id); # NOT last_dm

	my $my_json_ref = &grabjson($interactive, $dmurl, $last_dm);
	return if (!defined($my_json_ref)
		|| ref($my_json_ref) ne 'ARRAY');

	my $printed = 0;
	my $max = 0;
	my $disp_max = &min($print_max, scalar(@{ $my_json_ref }));
	my $i;
	my $g;

	if ($disp_max) { # an empty list can be valid
		if ($dm_first_time) {
			print STDOUT
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
	print STDOUT "-- sorry, no new direct messages.\n"
		if (($interactive || $verbose) && !$printed);
	$last_dm = &max($last_dm, $max);
	$dm_first_time = 0 if ($last_dm);
	print STDOUT "-- dm bookmark is $last_dm.\n" if ($verbose);
	&$dmconclude;
}	

sub wherecheck {
	my ($prompt, $filename, $fatal) = (@_);
	my (@paths) = split(/\:/, $ENV{'PATH'});
	my $setv = '';

	unshift(@paths, '/usr/bin'); # the usual place
	@paths = ('') if ($filename =~ m#^/#); # for absolute paths

	print STDOUT "$prompt ... ";
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
	print STDOUT "\n\n${BEL}${BEL}@_";
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
	if ($mode) {
		$x =~ s/\\u([0-9a-fA-F]{4})/"&#" . hex($1) . ";"/eg;
	} else {
		if ($seven) {
			$x =~ s/\\u([0-9a-fA-F]{4})/./g;
		} else {
			$x =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/eg;
		}
		$x =~ s/\&quot;/"/g;
		$x =~ s/\&apos;/'/g;
		$x =~ s/\&lt;/\</g;
		$x =~ s/\&gt;/\>/g;
		$x =~ s/\&amp;/\&/g;
	}
	return $x;
}

sub max { return ($_[0] > $_[1]) ? $_[0] : $_[1]; }
sub min { return ($_[0] < $_[1]) ? $_[0] : $_[1]; }
