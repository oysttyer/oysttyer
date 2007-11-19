#!/usr/bin/perl -s
#
# TTYtter v0.6 (c)2007 cameron kaiser. all rights reserved.
# http://www.floodgap.com/software/ttytter/
#
# distributed under the floodgap free software license
# http://www.floodgap.com/software/ffsl/
#
# After all, we're flesh and blood. -- Oingo Boingo
# If someone writes an app and no one uses it, does his code run? -- me

require 5.005;

#&grabjson;exit;
#$maxhist=19;while(<>){last if(&prinput($_));}exit;

BEGIN {
	$ENV{'PERL_SIGNALS'} = 'unsafe';
	%valid = qw(
		url 1 lynx 1 curl 1 pause 1 user 1 seven 1 dmurl 1
		dmpause 1 silent 1 superverbose 1 maxhist 1
		lib 1 verbose 1 hold 1 status 1 update 1 daemon 1
	);
	if (-r ($n = "$ENV{'HOME'}/.ttytterrc")) {
		open(W, $n) || die("wickedness: $!\n");
		while(<W>) {
			chomp;
			next if (/^\s*$/ || /^#/);
			($key, $value) = split(/\=/, $_, 2);
			$$key = $value if ($valid{$key} && !length($$key));
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

	unless ($seven) {
		eval "use utf8";
		binmode(STDIN, ":utf8");
		binmode(STDOUT, ":utf8");
	}
	if (length($lib)) {
		warn "** attempting to load library: $lib\n" unless ($silent);
		require $lib;
	}
}

END {
	if ($child) {
		print STDOUT "\n\ncleaning up.\n";
		kill 15, $child;
	}
}

$TTYtter_VERSION = 0.6;
$TTYtter_PATCH_VERSION = 1;

die("${TTYtter_VERSION}.${TTYtter_PATCH_VERSION}\n") if ($version);

if ($silent) {
	close(STDOUT);
	open(STDOUT, ">>/dev/null"); # KLUUUUUUUDGE
}

# defaults
#$url = "http://twitter.com/statuses/public_timeline.json";
$url ||= "http://twitter.com/statuses/friends_timeline.json";
$update ||= "http://twitter.com/statuses/update.json";
$dmurl ||= "http://twitter.com/direct_messages.json";
$dmpause = 4 if (!defined $dmpause); # NOT ||= ... zero is a VALID value!
$pause ||= 120;
$superverbose ||= 0;
$verbose ||= $superverbose;
$hold ||= 0;
$daemon ||= 0;
$maxhist ||= 19;

$dmcount = $dmpause;

# to force unambiguous bareword interpretation
$true = 'true';
sub true { return 'true'; }
$false = 'false';
sub false { return 'false'; }
$null = undef;
sub null { return undef; }

# default exposed methods
# don't change these here. instead, use -lib=yourlibrary.pl and set them there.
# note that these are all anonymous subroutine references.
# anything you don't define is overwritten by the defaults.
# it's better'n'superclasses.

sub defaultexception { shift; print STDOUT "@_"; }
$exception ||= \&defaultexception;
# [{"text":"\"quote test\" -- let's see what that does to the code.","id":56487562,"user":{"name":"Cameron Kaiser","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","screen_name":"doctorlinguist","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","url":"http:\/\/www.cameronkaiser.com","id":3841961,"protected":false},"created_at":"Wed May 09 03:28:38 +0000 2007"},
sub defaulthandle {
	my $ref = shift;
	my $g = '<' .  &descape($ref->{'user'}->{'screen_name'}) .
		'> ' .  &descape($ref->{'text'}) .  "\n";
	print STDOUT $g;
	return 1;
}
$handle ||= \&defaulthandle;

sub defaultconclude { ; }
$conclude ||= \&defaultconclude;

# {"recipient_id":3841961,"sender":{"url":"http:\/\/www.xanga.com\/the_shambleyqueen","name":"Staci Gainor","screen_name":"emo_mom","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/7460892\/normal\/Staci_070818__2_.jpg?1187488390","description":"mildly neurotic; slightly compulsive; keenly observant  Christian mom of four, including identical twins","location":"Pennsylvania","id":7460892,"protected":false},"created_at":"Fri Aug 24 04:03:14 +0000 2007","sender_screen_name":"emo_mom","recipient_screen_name":"doctorlinguist","recipient":{"url":"http:\/\/www.cameronkaiser.com","name":"Cameron Kaiser","screen_name":"doctorlinguist","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","id":3841961,"protected":false},"text":"that is so cool; does she have a bit of an accent? do you? :-) and do you like vegemite sandwiches?","sender_id":7460892,"id":8570802}
sub defaultdmhandle {
	my $ref = shift;
	my $g = '[DM '. &descape($ref->{'sender'}->{'screen_name'}) .
		'/'. $ref->{'created_at'} .
		'] '. &descape($ref->{'text'}) . "\n";
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
	if (!length($user) || $user !~ /:/ || $user =~ /[\s;><|]/);
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
	$wend = "$wend -auth=$user -nostatus";
	$wand = "$wend -source";
	$wend = "$wend -post_data";
} else {
	$wend = "$wend --basic -m 13 -f -u $user";
	$wand = "$wend";
	$wend = "$wend --data \@-";
}

# initial login tests and command line controls

$phase = 0;
for(;;) {
	$rv = 0;
	if (length($status) && $phase) {
		print "post attempt "; $rv = &updatest($status, 0);
	} else {
		print "test-login "; $data = `$wand $url 2>/dev/null`;
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
         TTYtter ${TTYtter_VERSION}.${TTYtter_PATCH_VERSION} (c)2007 cameron kaiser                 @             @
EOF
print <<'EOF';
                 all rights reserved.                         +oo=   =====oo+
       http://www.floodgap.com/software/ttytter/            a==:  ooo
                                                            .++o++. ..o**O
  freeware under the floodgap free software license.        +++   :O:::::
        http://www.floodgap.com/software/ffsl/              +**O++ #   :ooa
                                                                   #+$$AB=.
     tweet me: http://twitter.com/doctorlinguist                   #;;ooo;;
            tell me: ckaiser@floodgap.com                          #+a;+++;O
######################################################           ,$B.*o*** O$,
#                                                                a=o$*O*O*$o=a
# when ready, hit RETURN/ENTER for a prompt.                        @$$$$$@
# type /help for commands or /quit to quit.                         @o@o@o@
# starting background monitoring process.                           @=@ @=@
#
EOF
if ($superverbose) {
	print STDOUT "-- OMGSUPERVERBOSITYSPAM enabled.\n\n";
} else {
	print STDOUT "-- verbosity enabled.\n\n" if ($verbose);
}
sleep 2;

if ($child = open(C, "|-")) { ; } else { goto MONITOR; }
select(C); $|++; select(STDOUT);

sub defaultconsole {
	@history = ();
	&prompt;
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
		&prompt;
		return 0;
	}

	# handle history display
	if ($_ eq '/history' || $_ eq '/h') {
		for ($i = 1; $i <= scalar(@history); $i++) {
			print STDOUT "\t$i\t$history[($i-1)]\n";
		}
		&prompt;
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
		&prompt;
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
				&prompt;
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

	#print STDOUT join("|", @history); print STDOUT scalar(@history),"\n"; &prompt; return 0;

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
		print <<'EOF';

 TTYtter 0.6 is (c)2007 cameron kaiser. all rights reserved. this software
 is offered AS IS, with no guarantees. it is not endorsed by Obvious or the
 executives and developers of Twitter.

 --- twitter: doctorlinguist --- http://www.floodgap.com/software/ttytter/ ---

           *** subscribe to updates at http://twitter.com/ttytter
                                    or http://twitter.com/floodgap
               send your suggestions to me at ckaiser@floodgap.com

EOF
		&prompt;
		return 0;
	}
	if ($_ eq '/refresh' || $_ eq '/thump' || $_ eq '/r') {
		&thump;
		&prompt;
		return 0;
	}
	if ($_ eq '/again' || $_ eq '/a') {
		print C "reset----\n";
		&prompt;
		return 0;
	}

	if ($_ eq '/dm' || $_ eq '/dmrefresh' || $_ eq '/dmr') {
		print C "dmthump--\n";
		&prompt;
		return 0;
	}

	if ($_ eq '/dmagain' || $_ eq '/dma') {
		print C "dmreset--\n";
		&prompt;
		return 0;
	}

	if (m#^/me\s#) {
		$slash_first = 0; # kludge!
	}

	if ($slash_first) {
		if (!m#^//#) {
			print STDOUT "*** command not recognized\n";
			print STDOUT "*** to pass as a tweet, type /%%\n";
			&prompt;
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
		&prompt;
		return 0;
	}
	&updatest($_, 1);
	&prompt;
	return 0;
}

sub updatest {
	my $string = shift;
	my $interactive = shift;
	my $urle = '';
	my $i;
	my $subpid;
	
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
*** warning: connect timeout or no confirmation received ($x)
*** to attempt a resend, type %%
EOF
		return $?;
	}
	return 0;
}


sub prompt { print STDOUT "TTYtter> "; }
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
	if ($data =~ /^\s*\{\s*(['"])(warning|error)\1\s*:\s*\1([^\1]*)\1/s) {
		&$exception(2, "*** warning: Twitter $2 message received\n" .
			"*** $3\n");
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
	$tdata =~ s/[0-9]+//g;
	$tdata =~ s/(true|false|null)//g;
	$tdata =~ s/\s//g;

	print STDOUT "$tdata\n" if ($superverbose);

	# the remaining stuff should just be enclosed in [ ], and only {}:,
	# for example, imagine if a bare semicolon were in this ...
	if ($tdata !~ s/^\[// || $tdata !~ s/\]$// || $tdata =~ /[^{}:,]/) {
		$tdata =~ s/'[^']*$//; # cut trailing strings
		if ($tdata !~ /[^{}:,]/) { # incomplete transmission
			&$exception(10, "*** JSON warning: connection cut\n");
			return undef;
		}
		if ($tdata =~ /\[\]/) { # oddity
			&$exception(11, "*** JSON warning: null list\n");
			return undef;
		}
		&screech
		("$data\n$tdata\nJSON IS UNSAFE TO EXECUTE! BAILING OUT!\n")
	}

	# have to turn colons into ,s or Perl will gripe. but INTELLIGENTLY!
	1 while ($data =~ s/([^'])':(true|false|null|\'|\{|[0-9])/\1\',\2/);

	# somewhat validated, so safe (errr ...) to eval() into a Perl struct
	eval "\$my_json_ref = $data;";

	# null list can be valid sometimes
	if (!scalar(@{ $my_json_ref })) {
		return $my_json_ref;
	}

	# otherwise do a sanity check
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!length($my_json_ref->[0]->{'id'}));
	return $my_json_ref;
}

sub refresh {
	my $interactive = shift;
	my $my_json_ref = &grabjson($interactive, $url, $last_id);
	return if (!defined($my_json_ref) || !scalar(@{ $my_json_ref }));

	my $printed = 0;
	my $max = 0;
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
	print STDOUT "-- sorry, no new tweets.\n"
		if (($interactive || $verbose) && !$printed);
	$last_id = &max(0+$my_json_ref->[0]->{'id'}, $last_id);
	print STDOUT "-- id bookmark is $last_id.\n" if ($verbose);
	&$conclude;
} 

sub dmrefresh {
	my $interactive = shift;

	# no point in doing this if we can't even get to our own timeline
	# (unless user specifically requested it)
	return if (!$interactive && !$last_id); # NOT last_dm

	my $my_json_ref = &grabjson($interactive, $dmurl, $last_dm);
	return if (!defined($my_json_ref));

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
	print STDOUT "\n\n@_";
	kill 15, $parent;
	kill 15, $$;
	exit;
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
