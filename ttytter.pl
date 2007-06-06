#!/usr/bin/perl -s
#
# TTYtter v0.4 (c)2007 cameron kaiser. all rights reserved.
# http://www.floodgap.com/software/ttytter/
#
# distributed under the floodgap free software license
# http://www.floodgap.com/software/ffsl/
#
# After all, we're flesh and blood. -- Oingo Boingo
# If someone writes an app and no one uses it, does his code run? -- me

require 5.005;
BEGIN {
	$ENV{'PERL_SIGNALS'} = 'unsafe';
	%valid = qw(
		url 1 lynx 1 curl 1 pause 1 user 1 seven 1
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
	$last_id = 0; # and let our lib set it if they want to

	unless ($seven) {
		eval "use utf8";
		binmode(STDIN, ":utf8");
		binmode(STDOUT, ":utf8");
	}
	if (length($lib)) {
		warn "** attempting to load library: $lib\n";
		require $lib;
	}
}

END {
	if ($child) {
		print STDOUT "\n\ncleaning up.\n";
		kill 15, $child;
	}
}

$TTYtter_VERSION = 0.4;

die("$TTYtter_VERSION\n") if ($version);
$url ||= "http://twitter.com/statuses/friends_timeline.json";
#$url = "http://twitter.com/statuses/public_timeline.json";
$update ||= "http://twitter.com/statuses/update.json";
# to force unambiguous bareword interpretation
$true = 'true';
sub true { return 'true'; }
$false = 'false';
sub false { return 'false'; }
$null = undef;
sub null { return undef; }
$pause ||= 60; # if not specified by -pause=
$verbose ||= 0;
$hold ||= 0;
$daemon ||= 0;

# default exposed methods
# don't change these here. instead, use -lib=yourlibrary.pl and set them there.
# note that these are all anonymous subroutine references.
# anything you don't define is overwritten by the defaults.
# it's better'n'superclasses.

sub defaultexception { shift; print STDOUT "@_"; }
$exception ||= \&defaultexception;
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
	$wend = "$wend --basic -m 10 -f -u $user";
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
		exit;
	}
	if ($status && !$phase) {
		print "SUCCEEDED!\n";
		$phase++;
		next;
	}
	last;
}
print "SUCCEEDED!\n";
exit if (length($status));

# [{"text":"\"quote test\" -- let's see what that does to the code.","id":56487562,"user":{"name":"Cameron Kaiser","profile_image_url":"http:\/\/assets2.twitter.com\/system\/user\/profile_image\/3841961\/normal\/me2.jpg?1176083923","screen_name":"doctorlinguist","description":"Christian conservative physician computer and road geek. Am I really as interesting as everyone says I am?","location":"Southern California","url":"http:\/\/www.cameronkaiser.com","id":3841961,"protected":false},"created_at":"Wed May 09 03:28:38 +0000 2007"},

# daemon mode

if ($daemon) {
	if ($child = fork()) {
		print STDOUT "*** detached daemon released. pid = $child\n";
		kill 15, $$;
		exit;
	} elsif (!defined($child)) {
		print STDOUT "*** fork() failed: $!\n";
		exit;
	} else {
		# using our regular MONITOR select() loop won't work, because
		# STDIN is almost always "ready." so we use a blunter one:
		$parent = 0;
		for(;;) { &refresh(0); sleep $pause; }
	}
	die("uncaught fork() exception\n");
}

# interactive mode

print <<"EOF";

######################################################        +oo=========oo+ 
          TTYtter $TTYtter_VERSION (c)2007 cameron kaiser.                 @             @
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
print STDOUT "-- verbosity enabled.\n\n" if ($verbose);
sleep 2;

if ($child = open(C, "|-")) { ; } else { goto MONITOR; }
select(C); $|++; select(STDOUT);

$history = '';
&prompt;
while(<>) {
	chomp;
	s/^\s+//;
	s/\s+$//;
	last if ($_ eq '/quit');

	if ($_ eq '%%:p' || $_ eq '/history') {
		print STDOUT "*** %% = \"$history\"\n";
		&prompt;
		next;
	}
	print STDOUT "(expanded to \"$_\")\n" if (s/^\%\%/$history/);
	$history = $_ unless ($_ eq '');

	if ($_ eq '/help') {
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

 TTYtter 0.4 is (c)2007 cameron kaiser. all rights reserved. this software
 is offered AS IS, with no guarantees. it is not endorsed by Obvious or the
 executives and developers of Twitter.

 --- twitter: doctorlinguist --- http://www.floodgap.com/software/ttytter/ ---

           *** subscribe to updates at http://twitter.com/ttytter
                                    or http://twitter.com/floodgap
               send your suggestions to me at ckaiser@floodgap.com

EOF
		&prompt;
		next;
	}
	if ($_ eq '/refresh' || $_ eq '/thump') {
		&thump;
		&prompt;
		next;
	}
	if ($_ eq '/again') {
		print C "reset----\n";
		&prompt;
		next;
	}

	if (/^$/) {
		&prompt;
		next;
	}

	if (length > 140) {
		$history = ($_ = substr($_, 0, 140));
		print STDOUT
			"*** sorry, tweet too long; truncated to \"$_\"\n";
		print STDOUT "*** type %% to use truncated version if ok.\n";
		&prompt;
		next;
	}
	&updatest($_, 1);
	&prompt;
}
exit;

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
$interactive = 0;

for(;;) {
	&refresh($interactive);
	$interactive = 0;
	if(select($rout=$rin, undef, undef, $pause)) {
		sysread(STDIN, $rout, 10);
		$last_id = 0 if ($rout =~ /^reset/);
		$interactive = 1;
		print STDOUT "-- command received\n" if ($verbose);
	} else {
		print STDOUT "-- routine refresh\n" if ($verbose);
	}
}

sub refresh {

# the refresh engine depends on later tweets having higher id numbers.
# Obvious, don't change this if you know what's good for you, ya twerps,
# or I will poison all of yer kitties. *pats my Burmese, who purrs*

	my $data;
	my $interactive = shift;
	my $tdata;
	my $seed;
	my $print_max;
	my $printed;
	my $xurl;

	$xurl = ($last_id) ? "?since_id=$last_id" : "";
	chomp($data = `$wand "$url$xurl" 2>/dev/null`);
	$data =~ s/[\r\l\n\s]*$//s;
	$data =~ s/^[\r\l\n\s]*//s;

	if (!length($data)) {
		&$exception(1, "*** warning: timeout or no data\n");
		return;
	}

	if ($data =~ /^<!DOCTYPE\s+html/i || $data =~ /^<html>/i) {
		&$exception(2, "*** warning: Twitter error message received\n" .
			(($data =~ /<title>Twitter:\s*([^<]+)</) ?
				"*** \"$1\"\n" : ''));
		return;
	}

# process the JSON data ... simplemindedly, because I just write utter crap,
# am not a professional programmer, and don't give a flying fig whether
# kludges suck or no.

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

	# trust, but verify. I'm sure twitter wouldn't send us malicious
	# or bogus JSON, but one day this might talk to something that would.
	# in particular, need to make sure nothing in this will eval badly or
	# run arbitrary code. that would really suck!
	$tdata = $data;
	1 while $tdata =~ s/'[^']+'//;
	$tdata =~ s/[0-9]+//g;
	$tdata =~ s/(true|false|null)//g;
	$tdata =~ s/\s//g;
	# the remaining stuff should just be enclosed in [ ], and only {}:,
	# for example, imagine if a bare semicolon were in this ...
	if ($tdata !~ s/^\[// || $tdata !~ s/\]$// || $tdata =~ /[^{}:,]/) {
		$tdata =~ s/'[^']*$//; # cut trailing strings
		if ($tdata !~ /[^{}:,]/) { # incomplete transmission
			&$exception(10, "*** JSON warning: connection cut\n");
			return;
		}
		if ($tdata =~ /\[\]/) { # oddity
			&$exception(11, "*** JSON warning: null list\n");
			return;
		}
		&screech
		("$data\n$tdata\nJSON IS UNSAFE TO EXECUTE! BAILING OUT!\n")
	}

	# have to turn colons into ,s or Perl will gripe. but INTELLIGENTLY!
	1 while ($data =~ s/([^'])':(true|false|null|\'|\{|[0-9])/\1\',\2/);

	# somewhat validated, so safe (errr ...) to eval() into a Perl struct
	eval "\$my_json_ref = $data;";
	&screech("$data\n$tdata\nJSON could not be parsed: $@\n")
		if (!length($my_json_ref->[0]->{'id'}));

	# it worked! (I think)
	# now print stuff out.
	$print_max = 19; # will do more with this later.
	$printed = 0;
	$max = 0;
	for($i = $print_max; $i >= 0; $i--) {
		next if ($my_json_ref->[$i]->{'id'} <= $last_id);
		next if
		(!length($my_json_ref->[$i]->{'user'}->{'screen_name'}));

		$g = 0+$my_json_ref->[0]->{'id'};
		$max = $g if ($max < $g);
		$printed += &$handle($my_json_ref->[$i]);
	}
	print STDOUT "-- sorry, nothing new.\n"
		if (($interactive || $verbose) && !$printed);
	$last_id = $max if ($max);
	print STDOUT "-- id bookmark is $last_id.\n" if ($verbose);
	&$conclude;
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
	} elsif ($seven) {
		$x =~ s/\\u([0-9a-fA-F]{4})/./g;
	} else {
		$x =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/eg;
	}
	return $x;
}

