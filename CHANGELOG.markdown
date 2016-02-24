#CHANGELOG

##Changes in version 2.6.1:

- Add the ability to share tweets via direct message with the `/qdm` command (Work towards of 2.7 milestone)
- Use the Twitter account in the prompt instead of `oysttyer` when `showusername` is true.
- Add ':large' to Twitter image URLs when `largeimages` is true.
- Add a space between tweets when `doublespace` is true.
- Fixed an issue where retweeted tweets displayed the wrong timestamp.
- Fixed an issue where tco were not destroyed in threads
- Display link to video file instead of link to video thumbnail in tweets
- Display video files in `/entities`
- Bring `/entities` back into Twitter TOS compliance and make it only open tco links (I.e. make it behave worse. Sorry)
- Add tab expansion for like and retweet (missed from 2.5.1)

##Changes in version 2.6.0:

- Finishes up newline support
- Correctly counts characters for strings with newlines that are being sent. I.e. `\n` counts as one character.
- Summary of newline behaviour already implemented:
	- Any `\n` in a tweet will be sent as a newline
	- To send a literal `\` followed by a `n` you have to escape and type `\\n`.
	- The `-newline` command line argument/option can now be optionally set to `-newline=replace` as well as on/off (`1` or `0`)
	- If newline is set to replace then you can specify what oysttyer uses for display of newlines using `-replacement_newline` and `-replacement_carriagereturn` or use the default replacement characters
	- Note: If using `-newline=replace` there is currently no way for oysttyer to differentiate between actual newlines and literal `\`s followed by literal `n`s and both will get replaced.

##Changes in version 2.5.2:

- Add /mute /unmute functionality

##Changes in version 2.5.1:

- favorites changed to likes (Twitter made everyone do it!)
- Quick, perhaps temporary, fix to allow users to specify their own oauthkey and oauthsecret in their .oysttyerrc to work around the current muzzling issues
- fix /vre to not break threading
- Allow custom newline replacement characters

##Changes in version 2.5.0:

- Rename to oysttyer
- Change API key, etc
- No new features or function changes since 2.4.2, just renaming

##Changes in version 2.4.2:

- Start implementing improved newline behaviour, towards 2.6.0 milestone.
- Can now send newlines with literal "\"  followed by literal "n".
- Allow sending longer DMs (2.7.0 milestone)
- Remove own username when replying to self.

##Changes in version 2.4.1:

- Fix "display" of multiple images in tweets so extensions can pick them up. Specifically so deshortify can underline them.

##Changes in version 2.4.0:

- Version checking url changed to this repo on Github so I don't have to spam Twitter everytime I've updated

##Changes in version 2.3.1:

- Update built-in help to reflect that /rt can be used to create quote tweets

##Changes in version 2.3.0:

- "Displays" multiple images if a tweet includes them; the urls of the additional images are appended to the tweet text
- /entities command now lists out both entities and extended\_entities.
- /url and /open open links from extended\_entities as well as entities. Duplicated links aren't opened.
	- Note: Due to perceived compliance with Twitter's Terms of Service the t.co links are opened for multiple images which unfortunately means that just one link gets opened no matter how many images are attached. Whether or not this is strictly required will be investigated and if we can open the links directly to the image files TTYtter will be updated to suit.

##Changes in version 2.2.4:

- No changes, I just forget to change version in ttytter.pl. Constantly distracted.

##Changes in version 2.2.3:

- Fix empty geo coordinates for quoted tweets
- Badge quoted tweets themselves as well as the parent

##Changes in version 2.2.2:

- Destroy tco in quoted tweets that are nested in new RTs. Missed this under 2.2.1

##Changes in version 2.2.1:

- Destroy tco in quoted tweets. Missed this under 2.2.0

##Changes in version 2.2.0:

This unofficial version is my first attempt at maintaining TTYtter and introduces quoted tweet support.

- Create quoted tweets. Simply append text to the /retweet command. You are allowed 116 chars and TTYtter should check and warn if you go over.
- Displays quoted tweets automatically. Parent tweets are identified with a quote mark (") whereas standard retweets keep the percentage symbol (%). The quoted tweet will be displayed immediately below the parent tweet as a fully functioning tweet (i.e. it gets a menu code). Straight retweets of quoted tweets also display the quoted tweets. However, like the Twitter website, no further recursion of quoted tweets are made, i.e. a quoted, quoted tweet isn't displayed. For that use the /thread command.
- filterrts extended to also apply to quoted tweets, etc.
- /thread command extended to support quoted tweets and recurse through for the same amount as it does for replies, etc.
- version checking of TTYtter disabled since this is all unofficial.

##Changes in version 2.1.0:

This version of TTYtter requires Twitter API 1.1. Twitter-alike services not compliant with API 1.1 will not work with this or any future version of TTYtter. If you need API 1.0 support, you must use 2.0.4 for as long as that support is available.

- Full compliance with Twitter API 1.1, including TOS limitations and rate limits.
- TTYtter now deshortens t.co links transparently for tweets and events, and uses t.co length computations when determining the length of a tweet. This feature can be disabled with -notco. If you are using Term::ReadLine:TTYtter 1.4 or higher, then this will also work in readline mode.
- Commands that accept menu codes can now also accept tweet or DM IDs, perfect for all you command-line jockeys.
- New /replyall command (thanks @FunnelFiasco).
- New /del command.
- User filtering (with new -filter\* options).
- Better description of the full range of streaming events (thanks @RealIvanSanchez).
- /push now works with non-Boolean options, simply pushing them to the stack (it still sets Booleans to true when pushed).
- The background will kill itself off correctly if the foreground process IPC connection is severed (i.e., the console died), preventing situations where the background would panic or peg the CPU in an endless loop.
- Geolocation now looks at and processes place ID, country code, name and place type, and tweets with a place ID will also be considered to have geolocation information (thanks @RealIvanSanchez).
- Using -twarg generates a warning. As previously warned, it will be removed in 3.0.
- -anonymous now requires -apibase, as a Twitter API 1.1 requirement.
- All bug fixes from 2.0.4.

##Changes in version 2.0.4 (bug fixes and critical improvements only; these fixes are also in 2.1.0):

2.0.x will be the last branch of TTYtter to support Twitter API 1.0. When the 1.0 API is shut down, all previous versions of TTYtter will fail to work and you must upgrade to 2.1.x.

- You can now correctly /push booleans that were originally false.
- /eval now correctly emits its answer to $streamout so that -runcommand works.
- /vcheck on T::RL::T now correctly reports the currently installed version rather than the server's version when the installed version is the same or newer.
- Error messages from Twitter are properly processed again, so that commands that really fail won't unexpectedly appear to succeed.
- Hangs or spurious errors in -daemon mode are now reduced.
- The list\_created event is now properly recognized in streaming mode.
- /entities on a retweet now properly refers back to the retweet.

##Changes in version 2.0.3:

- Various and sundry Unicode whitespace characters are now canonicalized into regular whitespace, which improves URL recognition and editing. This occurs whether -seven is on or not. (thanks @Ryuutei for the report)
- You can now turn the ability of a user to send NewRTs on and off with /rtson and /rtsoff, respectively, as a down payment on full filtering in 2.1. Note that this does not currently filter NewRTs out of the stream; this is a Twitter bug.
- The user\_update event is now properly recognized in streaming mode.

##Changes in version 2.0.2:

- /trends now accepts WOEID (either set with /set woeid or as an argument). If none is given, global trends are used instead (WOEID 1). The old $trendurl will be removed in 2.1, since this makes it superfluous. Speak now if this affects you.
- If you have a location set with /set lat and /set long, the new /woeids command will give you the top 10 locations Twitter supports that match it. You can then feed this to /trends, or set it yourself.
- Repairs another race condition where posting before signal handlers were ready could crash TTYtter (thanks @RealIvanSanchez for the report).
- The /entities command is now smarter about media URLs.
- The exponential backoff is now correctly implemented for reconnecting to the streaming API. If a connection fails, the timeout will automatically extend to a maximum of 60 seconds between attempts. In the meantime, TTYtter will transparently fall back on the REST API.
- Extension load failure messages are now more helpful (thanks @vlb for the patch).
- Prompts were supposed to be case-insensitive, and now they are (thanks @FunnelFiasco for the patch).
- /whois (and /wagain) and /trends now correctly emit to $streamout so that -runcommand works. 

##Changes in version 2.0.1:

- Expands UTF-8 support to understand UTF-16 surrogate pairs from supra-BMP code points, fixing the Malformed UTF-8 errors generated by Perl for certain characters.
- A race condition where TTYtter could accidentally kill the foreground in streaming mode is fixed (thanks @WofFS for the report).
- -backload=0 now properly populates $last\_id, even if no tweets are received after the initial "fetch," eliminating an issue with spuriously grabbing old tweets (thanks @Duncan_Rowland for the report).

##Changes in version 2.0.0:

- Introduces Streaming API support (opt-in) on systems satisfying prerequisites, using Twitter User Streams.
- Reworked event and select() handling for better reliability on a wider array of operating systems.
- List methods are now overhauled to remove deprecated endpoints. As a consequence, if your extension relied on the undocumented function &liurltourl, you must update it, as that function is no longer used for the current REST API revision.
- The old public\_timeline endpoint is deprecated by Twitter and has been removed. Anonymous users will only see tracked terms, if any.
- /tron, /troff and /track are now case-insensitive, matching the Search API (thanks @\_sequoia for the report).
- $conclude is now properly called after /again.
- Now that Twitter properly supports retweet counts greater than 100, so does TTYtter.
- Underlining of user names properly ignores hyphens.
- TTYtter will no longer run with Term::ReadLine::TTYtter versions prior to 1.3.
- Various cosmetic fixes.
- API changes: $eventhandle for receiving non-tweet/DM events from the Streaming API.
- -twarg, a very old holdover of the old single-extension API in TTYtter 0.x, is now deprecated; it does not scale in the multi-module environment. It will be removed in 3.0. Migrate your extensions now.
- -oldstatus, which was deprecated in 1.1.x, is now removed. If you are relying on the old behaviour, you must use 1.2.5.
- xAuth (not XAuth), which was deprecated in 1.2.x, is now removed. If you are relying on the old little-xAuth authentication system, you must use 1.2.5.

##Changes in version 1.2.5:

- Fixes for signals on Linux 3.x kernels, which includes newer releases of Debian and Ubuntu. If you are using readline mode, this requires Term::ReadLine::TTYtter 1.3, which is released simultaneously and has the following fixes:
	- Matching fixes for signals on Linux 3.x kernels.
	- CTRL-D as the first character on a line is now correctly seen as EOF, matching the non-readline version.
- URL-sniffing logic now uses the earlier, more conservative algorithm to eliminate spurious characters (thanks @fukr for the report).

##Changes in version 1.2.4:

- The -status=- patch in 1.2.3 broke passing statuses on the command line (that'll teach me to proof patches better). Fixed; thanks @dogsbodyorg for the spot.

##Changes in version 1.2.3:

- Signals restructured to allow $SIG or POSIX.pm-based signalling. The latter is preferred for Perl 5.14+; the former is preferred for for 5.8.6+, 5.10 or 5.12, and is the only supported method for unsupported Perls (viz., 5.8.5 and earlier). This should eliminate the need to manually set PERL\_SIGNALS to unsafe for Perl 5.14+, assuming that you have POSIX.pm. You can force TTYtter to use POSIX.pm signals with -signals\_use\_posix, but it's better to let it choose which method it prefers.
- Repairs to -retoke, which should once again work with dev.twitter.com.
- Tweak for multi-line -status=- (thanks @paulgrav for the patch).
- The old, undocumented debugging option -freezebug was obsolete as of 1.2, and now is completely removed.

##Changes in version 1.2.2:

- New /entities command extracts t.co links from tweets and DMs so you can see where they point.
- Fixed /trends to use new URL (thanks @Donearm for the report).
- Fixed /trends not to double-double-quote strings when they are already double-quoted. Because that would double-quote them double, you dig?

##Changes in version 1.2.1:

- Changes to Search API optimizer to accommodate other entities. (A more complete solution eliminating the optimizer entirely is planned for 2.0.)
- RAS syndrome corrected in keyfile generator (with thanks to the supremely pedantic @FunnelFiasco ;).

##Changes in version 1.2.0:

- Perl 5.8.6 is now the minimum tested version (but see this note on 5.005 and 5.6).
- xAuth support is now deprecated and will be removed in 2.0. Speak now if this will affect you.
- New list support, including building, editing and disposing of lists directly from the client, and mixing lists into your timeline dynamically. You can even turn off your regular timeline and just use a list as your timeline to see only a subset of users. Don't worry, your favourite grouping extensions still work too.
- Many commands can now take an optional +count, allowing limited pagination.
- NewRTs are now the default for /retweet, and the NewRT interface is now complete with retweet counts in tweets, NewRT marking for tweets and /rtsof. /thread also tracks NewRT linkages (thanks @augmentedfourth for the suggestion), and you can /delete them like any other tweet. Appending to a retweet or /oretweet uses the old RT format, or you can say -nonewrts.
- New users now authorize with standard OAuth, eliminating our dependence on the old Twitter key clone system. Users who already have cloned keys don't need to do anything; they will still work. New users should use OAuth. 1.2's -retoke credentials generator also uses OAuth.
- A "pastebrake" reduces spurious tweets caused by accidentally pasting into the TTYtter window.
- The promised /dmsent command is now implemented.
- TTYtter's fetch algorithm has been changed to a "sliding window" system to try harder to get tweets posted out of order, as well as cope with high frequency search keywords.
- You can now specify a custom path to your notify tool for both Growl and notify-send using -notify\_tool\_path=....
- You can use %%\* if you misfired an argument. For example, /re e5 right on bro followed by /re f4 %%\* becomes /re f4 right on bro
- The /vcheck command will now automatically populate %URL% with the appropriate URL, so now you can just /open it (thanks @dirtyHippy for the idea).
- -statusurl lets you shorten and append a URL to a -status (thanks @microlifter for the patch).
- .ttytterrc is treated as UTF-8 by default (thanks @kseistrup for the report; wontfixed for 1.1 for compatibility reasons).
- -backload=0 shouldn't load anything, and now it doesn't (thanks @jfriedl for the report; wontfixed for 1.1 for compatibility reasons).
- -lib and -olib are now completely removed.
- API changes: $userhandle for displaying user objects, and new library functions &postjson &getbackgroundkey &sendbackgroundkey.
- All bug fixes from 1.1.11 and 1.1.12.

##Changes in version 1.1.12 (bug fixes and critical improvements only; these fixes are also in 1.2.0):

- Patches for Perl 5.14 (thanks @rkfb for the report).
- Keyfiles can now be regenerated if they are corrupted or need to be updated with -retoke.
- /doesfollow should give true or false with -runcommand (thanks @kaleidoscopique for the report). Similarly, /short should also work, emitting the URL (thanks @microlifter for that report).
- Properly understands a new Twitter ad-hoc error format, which repairs some operations that would unexpectedly appear to succeed but didn't actually (thanks @augmentedfourth for the report).
- -readline autocomplete command list now up-to-date.

##Changes in version 1.1.11 (bug fixes and critical improvements only; these fixes are also in 1.2.0):

- Fixed a bug where TTYtter crashes ungracefully if OAuth credentials fail.
- Fixed regex in command processor that interpreted all commands starting with /p as /print.
- -notimeline is now properly recognized by /set as a boolean.
- One last issue related to URL shortening.

##Changes in version 1.1.10:

- Code adjustments to avoid double-decoding UTF-8 sequences internally (thanks @cristiangauma for the fix).
- Fixed crash in readline autocompletion when metacharacters were present (thanks @stormdragon2976 for the report).
- Optimized readline statistics are now case-insensitive so that weighting is more correct.
- Corrected flaw with -verify where prompts went to the wrong filehandle.
- Keyword terms in /trends are now quoted for search (thanks @WofFS for the report).
- /short more securely encodes its input so that certain URLs will not be shortened incorrectly (thanks @alexfalkenberg for the report).
- Custodial code cleanup pre-1.2.

##Changes in version 1.1.9:

- Signals now should operate correctly on Solaris and other systems using SIGXCPU/XFSZ (thanks @jgeorgi for the report).
- StatusNet and Identi.ca support is restored, using a shim that dynamically works up the missing stringified-int fields 1.1.8+ requires.
- -linelength lets you set an arbitrary linelength for Twitter-alike APIs not limited to 140 characters (the default is, of course, 140).
- -notifyquiet turns off the test notify sent by your chosen notification driver.
- -daemon mode is no longer limited by the need to assign menu codes, allowing it to accept ridiculously large data slurps.

##Changes related to Term::ReadLine::TTYtter version 1.2:

- T::RL::T now keeps up with changing terminal sizes, which should reduce overpaint (thanks @WofFS for the fully functioning patch).
- Pressing DEL at position 0 no longer causes the app to exit. This was, unbelievably, an intentional feature of T::RL::Perl.

##Changes in version 1.1.8:

- Emergency fix for signature errors (due to status IDs now overflowing the base ID fields). This may cause TTYtter to be incompatible with some Twitter-alike APIs; I can't do anything about that until they start supporting the \*\_str versions.
- Smoother fetching from the Search API.

##Changes in version 1.1.7:

- -daemon mode works again.
- New-format Twitter error messages are automatically unwrapped.
- Changes related to Term::ReadLine::TTYtter (version 1.1 is required for this support):
	- Perl 5.6 is now required explicitly to use T::RL::T. (You can still use 5.005 without -readline, but see the support note above).
	- Most UTF-8 characters should now be properly accepted, and more keyboard layouts work properly on more operating systems.
	- Prompts that are not transmitted to Twitter do not have the character counter, such as Y/N confirmation prompts and so on.
	- The character counter can be disabled completely with -nocounter (as an option to ttytter) for screen readers.
	- The prompt now defaults to ANSI off, unless you pass ttytter the -ansi option. This also allows you to turn ANSI on and off and the prompt will follow. (If you use T::RL::T 1.1 with TTYtter 1.1.6, you will notice that the prompt is no longer highlighted because 1.1.6 doesn't know how to synchronize ANSI state.)
- /unset now sets non-Boolean options now to undef so that it will "do the right thing."
- I swear, /troff no longer strips quotes off quoted terms. If it does, give me your exact track list and the keyword you used. I swear by all that is holy I fixed it this time!
- API tweak: &wraptime, which was "optimized" out in 1.1.6, has been restored as a stub in 1.1.7 for compatibility.

##Changes in version 1.1.6:

- 1.1.6 is a very large systems update, touching quite a bit of low-level code. In particular, this version requires full POSIX signals to function at all, whereas previous versions only needed them in certain circumstances: your system must support either or both of SIGUSR1/2 or SIGPWR/SYS (i.e., signals 30 and 31), which are used as software interrupt signals between the foreground and background processes, or TTYtter will crash or hang. This has been verified to work on all the supported systems above.
- If your TTYtter abruptly quits when you type commands, your system does not support these signals correctly. Send me a report so that I can investigate a workaround.
- Support for repaintable readline prompts, when combined with a supporting driver such as Term::ReadLine::TTYtter. T::RL::T is custom-designed for this purpose, including dynamic repainting, history synchronization, background signaling, improvements to UTF-8 support and even a character counter. You can add support to your favourite readline driver with some extra stub functions. If you use T::RL::T as your readline driver (which is now the default for -readline if it is installed), /vcheck and -vcheck check its version too. This driver is a beta. It is still in development. Expect bugs.
- Location support with -location, -lat and -long. Your account must be geo-enabled, which cannot be done from TTYtter; you must do it from the Twitter web interface. You can then set a (default) location with -lat/-long, and use -location to toggle if/when to send it.
- /block and /unblock for those users you hate, like @dickc.
- The foreground now sends squelch signals to the background when a command is running, which should reduce command output stepping on background updates.
- -searchhits specifies how many search results to grab from the Search API, both with /search (thanks @jdvalentine) and tracked results.
- /set [boolean] can now be used to set a Boolean option to 1, like /set ansi. Similarly, /unset can now set an option to zero (or literal string "0"). These commands are mostly intended for booleans and may not work right with other options.
- -status can now be passed a line of text over standard input if you use -status=- (that's dash "status" equals dash), which is useful for scripts that can't trust their input but really want to use -hold (speaking of, a bug with -hold holding for an incorrect duration should now be fixed too). If your script can't cope with this and absolutely needs the old behaviour, -oldstatus is available as a deprecated stopgap to use the old -status behaviour, but may disappear in future versions.
- Faster UTF-8 processing.
- Growl notifications on Mac OS X are now asynchronous, which significantly improves their processing speed.
- Background event loop rewritten to drive select() in a more compatible fashion, which should eliminate random freezes (-freezebug is still in 1.1.6 for purposes of debugging, just in case).
- TTYtter now tells you what readline driver it is using, if any. You can set the PERL\_RL environment variable to override this (such as Gnu, Perl, TTYtter or Stub).
- All prompts now use -readline when enabled.
- Command line options didn't always override what was in the .ttytterrc file. Fixed.
- Retweeting a tweet with UTF-8 characters should no longer generate a signature error.
- Foreground menu codes are now shown in bold to set them off from background updates.
- -simplestart prints an abbreviated startup banner for slower systems or more dire screen readers.
- JSON fetches are more compatible with arbitrary OAuth signature algorithms, which should help extension authors and /eval jockeys.
- The -readline TAB completion routine now includes all the supported commands (thanks again @jdvalentine).
- API changes: new library functions &sendnotifies and &senddmnotifies, which decouple notification from &defaulthandle and &defaultdmhandle respectively. This allows extensions to send their own notifications without relying on the default handlers (thanks @stormdragon2976 for the use case). In TTYtter 2.0, with the next major revision of the internal API, this idea will be explored much further.

##Changes in version 1.1.5:

- Backed out select() debugging code due to way too many false positives. It can be re-enabled with -freezebug for testers.
- Small custodial changes in progress.

##Changes in version 1.1.4:

- You can now ask for additional tweets to backfill your timeline with -backload=[number]. Careful with this option: Twitter can ignore it, and often does, and loading large amounts of data can dramatically slow TTYtter down. This is a down payment on pagination, to come in the very near future.
- You can now specify multiple arguments to -notifytype, such as =growl,libnotify. You will probably need an extension for your particular notification scheme. (suggested by @stormdragon2976)
- Correctly recognizes the StatusNet "fail whale" (thanks @seppo0010 and @yrvn).
- Adjusted user-agent timeouts for iffier links.
- Rescue code for buggy user-agents that ignore timeouts.
- More HTML entities are deciphered in both regular and -seven modes.
- A platform-inless dependent change of the default keyfile umask for better security (thanks @herrold).
- Gopher URLs are now forwarded to the Floodgap Gopher proxy, since Firefox 4 is dropping Gopher support, unless -urlopen uses lynx as its user agent, and /short on gopher URLs adds the proxy on to get an HTTP URL. (Hey, this is a text client. I have to support gopherspace.)

##Changes in version 1.1.3:

- The JSON parser incorrectly rejects some null strings, which can interfere with logging into OAuth. Fixed. (thanks @alfredhallmert)
- Metacharacters in URLs are now (should be) correctly rejected when fed to the TAB-shortener in -readline. (thanks @johndalton)
- Replies now take priority always over search results with -mentions.
- Exception messages are now timestamped also if -timestamp is on. (suggested by @colindean)
- /cls command to clear the screen. (suggested by @schapendonk)
- Spurious failure with perl -c in 5.005 worked around.
- Corrections to messages and the introductory blurb.

##Changes in version 1.1.2:

- -status with UTF-8 characters now works correctly again from the command line (as long as your locale is set correctly, of course). (thanks @jlm314)
- $shutdown now correctly fires even if a child process was not launched.

##Changes in version 1.1.1:

- Corrected (fingers crossed) OAuth signature bugs and UTF-8 problems. Tested on Ubuntu 10.04, Mac OS X 10.6/10.5/10.4 (PPC and x86), AIX and NetBSD 5 with 5.005 through 5.10.1, so if it doesn't work for you, I'll just find a quiet corner and shoot myself. Yes, it's actually shorter than 1.1.0 due to some efficiencies that were possible. (thanks @j4mie, @dariuus, @seppo0010 and many others for data points)
- When looking for tools, TTYtter will now check your path first before its built-in locations. (thanks @seppo0010)
- Better handling for impoverished environments where $HOME may not be defined.
- New mention in Guinness Book of World Records for quickest replacement of a version of TTYtter. It's in the back somewhere, near record number of hours watching Monty Python while singing from the Hungarian Bongosok.

##Changes in version 1.1.0 (this version is an updated form of the public beta, released as is due to the switchover; expect minor bugs, which will be rectified in 1.1.1):

- Official support for OAuth, which is now the default method of authentication. OAuth requires cURL -- Lynx will not work. Basic Auth is still supported for users of StatusNet and Identi.ca, and still works with Lynx, but you must ask for it with -authtype=basic. After 16 August 2010, only TTYtter 1.1.0 and later will be able to access Twitter due to the Basic Auth shutdown. No earlier version of TTYtter will work! Read the main page for how to get your credentials converted to OAuth. You only have to do this once per account.
- Foreground menu codes now roll continuously and wrap around instead of resetting with every foreground command (except for /thread, which still uses zz0 to zz9). This is the completion of the menu code change first introduced in 1.0.0.
- Support for automatically fetching replies with -mentions, even from users you do not follow.
- /deletelast deletes the most recent tweet you made, if you don't like using proper safety nets like -verify or -slowpost.
- /doesfollow command (part of 1.0.4, but originated with the aborted 1.1.0 public beta), telling you if a user follows another or if a user follows you.
- For users requiring -seven, certain single character entities will now be translated from UTF-8 to the nearest ISO-8859-1 equivalent (part of 1.0.4, but originated with the 1.1.0 public beta). This table will expand in the future.
- Various API changes: -lib and -olib are now removed; new library functions; $getpassword and $shutdown (suggested by @colindean).
- All bug fixes from 1.0.3 and 1.0.4. 

##Changes in version 1.0.4 (these fixes are also in 1.1.0):

- Search API URLs corrected to Twitter-specified URLs.
- NewRTs now appear in user timelines and mentions, thanks to new improvements in the Twitter API.
- Ported /doesfollow and the improved UTF-8 entity translation for -seven from the forthcoming revised 1.1 beta.

##Changes in version 1.0.3 (bug fixes and critical improvements only; these fixes are also in 1.1.0):

- Search API URLs now transitioned to the api.twitter.com endpoint, as the old ones will be eventually shut down.
- When terminating TTYtter correctly exits with the right error status now (thanks @jlm314).
- Reply username matching is now a bit less greedy.
- Spaces are trimmed off URLs in /whois.

##Changes in version 1.0.2:

- Missed one of the bleeding colour bugs into the -readline prompt that was supposed to be fixed in 1.0.1. Fixed for sure this time. (thanks @tjh)
- Updated API URLs.
- Search API support streams more reliably and is compatible with future changes to the Search API search method.

##Changes in version 1.0.1:

- Fixed JSON parser to avoid bailout with certain large GeoAPI coordinates. (thanks @pssdbt)
- TTYtter now counts in UTF-8 characters, not bytes, now that I have confirmation of full support in the Twitter API. 140 character tweets and DMs are now fully supported, and also work with -autosplit.
- Multi-module loader properly insulates non-fatal errors from the extension. This should improve compatibility. (thanks @colindean)
- Error messages won't foul prompt colour in -readline mode anymore (thanks @wireghoul).
- -synch mode updates are only triggered now for successful posting, not on overlength tweets, etc.

##Changes in version 1.0.0:

- Source code reorganized and in some cases completely rewritten.
- Multi-module system for the TTYtter API allows you to install and run multiple extensions simultaneously (if compatible), adding the new -exts option.
- Speaking of, massive changes to the TTYtter API. Extension authors should re-read the API documentation for compatibility notes. While many extensions will work with no or minimal changes, some may need to be updated.
- The old -lib and -olib options are now deprecated, and will be removed in the 1.1 releases.
- Synchronicity mode synchronizes updates with your keyboard activity (-synch), but has a price to pay. Mostly intended for input methods that are unhappy with background updates.
- -runcommand option for simple command-line queries.
- -hold is no longer infinite when used with -script.
- Tweet code temporary menus now occupy a three character menu code that always starts with z (so now /thread generates zz0 through zz9). This is to accommodate future menus that may be more than 20 entries.
- Initial support for the Retweet API and newRTs. NewRTs now appear in your timeline by default, are properly unwrapped so they are not truncated, and are canonicized to appear just like RTs used to. Retweets-of-me are displayed using the new /rtsofme command (/rtom). Note that because the API doesn't give you information about who retweeted you, neither does this command. Twitter acknowledges this deficiency and it will be supported in a later TTYtter when they fix it. If you want to disable NewRTs (such as for StatusNet, etc.), use -nonewrts. RTs made with /rt and friends are still the manual variety.
- /follow and /leave now handle following and leaving users (no more FOLLOW and LEAVE even though they are still supported).
- /dm who what replaces D who what (although the latter will still work), giving you your 140 characters all back, and is properly supported by -autosplit, -slowpost and -verify. /replying to a DM now internally uses /dm.
- /dump now supports the Geolocation API and Retweet API, giving you location information for tweets that encode it, plus the retweet metadata. More information is also in the tweet cache for later.
- A new versioning system recognizes when you are using a beta and checks the internal build number.
- Special logic to detect the Fail Whale for more bulletproof posting and more useful error messages.
- /again and /whois get confused by numeric Twitter user IDs (and treat them as user numbers). Patched to fix this so that numeric IDs are seen as true IDs. Although this also affects 0.9, it requires making an incompatible change, so it will not be fixed in that version.
- If -rc gives an absolute path, use that. (thanks @FunnelFiasco)
- All bug fixes from 0.9.10, 0.9.11 and 0.9.12.

##Changes in version 0.9.12 (bug fixes and critical improvements only; these fixes are also in 1.0.0):

- If you /troff on a keyword set that has quoted phrases, the quotes get lost off all of them. Fixed.
- Restoring from /set tquery 0 also fouls up quoted search terms. Fixed.
- Setting $tquery in an extension's initialization does not override $track. Fixed. (thanks @colindean)

##Changes in version 0.9.11 (bug fixes and critical improvements only; these fixes are also in 1.0.0):

- Warn the user if a notification framework was selected but no notifies were requested. This might be useful for an extension to dynamically control, so it is not a fatal error.
- Another try at properly handling GeoAPI information (thanks @chfrank\_cgn).
- Author breaks 50,000 tweets. A loud sobbing noise can be heard from Twitter corporate headquarters throughout most of the Bay Area.

##Changes in version 0.9.10 (bug fixes and critical improvements only; these fixes are also in 1.0.0):

- If the foreground process exits abnormally, it should still clean up the background process.
- -script and -verbose should work together better (a more effective fix is in the 1.0.0 beta).
- The -slowpost prompt lagged the signal switch ever so slightly, meaning you could hit ^C and kill the process even when it told you it was okay. The prompt is now delayed until after the signal handler change.
- -notifytype=0 should work fully now.
- -script and -status now correctly ignore -slowpost and -verify.
- /vreply format tweaked slightly.

##Changes in version 0.9.9 (bug fixes and critical improvements only):

- Tweets with geolocation information no longer cause the JSON parser to panic.
- If -autosplit=word fails, fall back on =char instead of completely destroying the tweet.
- /vre no longer threads the reply, as API changes have caused threaded tweets to be only visible to the one replied to.
- The planned conversion of 140 bytes to 140 characters as the tweet length could not be implemented in this version as the Twitter API does not correctly accept them yet.

##Changes in version 0.9.8 (bug fixes and critical improvements only):

- Identica fixes: base URL returned to friends\_timeline; fixed the "null list" warnings Identica users were getting; updated JSON parser to understand the new Identica fields.
- You can now say -notifytype=0 on the command line to disable a notifytype in your .ttytterrc.
- -hold can potentially loop forever even if you don't want it to. -hold=1 or -hold by itself keeps the old behaviour, but specifying an argument greater than 1 causes the script to stop after that many unsuccessful tries. In 1.0.0, this will be changed again.
- Auto-ratelimiting changed to use 50% instead of 60%. This slightly diminishes responsiveness, but seems to help people who were getting beaten up by other client usage. You can still use -pause with an argument, of course.
- /[ef]rt no longer thread retweets to the source tweet. Per Twitter, this won't work right any more and actually prevents retweets from being seen (by causing them to be treated as replies).
- /whois and /wagain now recognize the new default images Twitter is using for accounts without avatars.
- -curl now works correctly again (stupid typo regression).
- Error codes fixed for command line tools.

##Changes in version 0.9.7:

- 0.9 is now the stable branch and bug fixes only will occur on this branch until a stable 1.0.x becomes available, after which it will be deprecated. New development will now occur on unstable 1.0 and there will be compatibility changes. More on that when 1.0.0 is released.
- New notification framework with built-in support for Growl (via growlnotify) and experimental built-in support for libnotify (via modifications to notify-send; see Galago Project trac ticket #147) using -notifytype and -notifies. Expandable via the API.
- Revised API method for dynamic classification of tweets using the $tweettype method. (The old $choosecolour method is now deprecated and trying to call its handler will generate a fatal error. It will be completely removed in 1.0.0.)
- Favourites support with /favourites, /(un)fave and /frt.
- Tweets can be dumped and their status URLs grabbed with /dump (suggested by @augmentedfourth).
- /short and /url take %URL% as default, and /whois//wagain and /dump populate it, allowing you to grab URLs from status IDs or user profiles and open them or repost them (based on a suggestion from @vkoser). As a nice side effect, /url can now open arbitrary URLs as arguments.
- "Verified Account" support for /whois and /wagain.
- -slowpost mode for people needing something gentler than -verify (like me).
- Training-wheels mode intercepts common newbie tweets like quit and help (disabled by -slowpost and -verify; I assume that if you set those then you know what you're doing).
- -filter is now dynamic and can be recompiled on the fly with /set filter.
- /vreply forces publicly visible replies (with the de facto r @ttytter A public reply. notation).
- /eretweet populates %% as well to allow editing with the conventional substitution sequences (thanks @jasonwryan).
- To facilitate this behaviour, %-sequences are now generally interpreted at the end of a line as well, not just at the beginning.
- New reserved namespaces for API modules using the $store global reference in anticipation of multi-module support in 1.0.0.
- HTTPS URLs now accepted by /short and the TAB completer in -readline.
- -olib option for one-line libraries on the command line.
- UTF-8 characters can now be scanned for by /url, although your underlying browser may not like them (for example, Mac OS X /usr/bin/open thinks they are filenames).
- Default replies URL now set to mentions.json but remains the same command line option for backwards compatibility.
- Substitutions using %-x sequences would accept arguments that were too high and simply cut off until it couldn't anymore. This is now correctly flagged as an error.
- Another crash bug removed.
- Internal code consolidation.
- Better error messages for deletions, failed substitutions, etc.

##Changes in version 0.9.6:

- Direct message selection, analogous to tweet selection, which also supports /delete, /url and /reply for a nice almost-orthogonal interface.
- /retweet and /eretweet, previously undocumented in 0.9.5 due to inadequate testing, are now officially supported and properly thread in-reply-to fields.
- Large internal change to subprocess management for easier future expansion, along with more changes to $authenticate. This internal reworking will continue up until the OAuth-based TTYtter, so people hacking on the core should beware.
- $choosecolour is now unstable. API programmers who are using this method should contact me, as I am planning to change the interface as part of the future notification framework.
- /track should not throw pagination errors on common or popular search terms. I disagree with the way Twitter has implemented this warning, but this version includes a workaround (thanks @johndalton).
- /ruler once again lines up properly with the prompt (thanks @vkoser, @jazzychad and others of the Brotherhood of the Ruler).
- Search results now are properly coloured in anonymous mode.
- GNU screen printed bold characters as inverse text. ANSI sequence tweaked for wider compatibility (thanks @arsatiki).
- Unicode code point 0x2028 needed to be seen as a newline, and subject to -newline (or not). Fixed.
- -noratelimit does not work when it is changed dynamically, so it is simply made a startup-option only.
- -filter didn't handle quote-wrapped arguments (thanks @augmentedfourth). Fixed.
- -wrap sometimes overindented following lines (thanks again @augmentedfourth). Fixed.
- Not all legal characters for URLs were accepted by /url. Fixed.
- /search did not call $conclude, so -filter counts got out of sync. Fixed.
- Author breaks 40,000 tweets. Twitter calls him on the phone to please stop and use Plurk or something.

##Changes in version 0.9.5:

- Selection of individual tweets and threading with /thread, /reply, /delete and /url, along with @ markers on tweets that are part of a thread.
- -noratelimit and -notrack to disable rate limit checks and tracking keywords, respectively, on systems that don't support them (most notably Laconi.ca/Identi.ca).
- API addition with $choosecolour.
- UTF-8 characters are now allowed in tracking keywords.
- Faster and more reliable JSON fetch and parsing method.
- Expanded /help text.
- Bogus colour warnings when using -noansi are fixed.

##Changes in version 0.9.4:

- Twitter Search API integration, based on initial work by @kellyterryjones, @vielmetti and @br3nda (/search, -queryurl), with hashtag integration and keyword management (/tron, /troff, /track, /#, -notimeline, -track) and trends (/trends, -trendurl), suggested by a whole bunch of people including the most esteemed @adamcurry.
- Customizable colours (-colour{prompt,dm,me,reply,warn}), another common request.
- Base API URL can now be specified for Twitter clone APIs (-apibase).
- Official API support for libraries driving commands, or wishing to make JSON fetches from services.
- Whitelisted accounts bombed with autoratelimiting. Fixed to constant value.
- @ highlighting in direct messages tended to bleed. Fixed.
- -status probably shouldn't print version check warnings. Fixed.
- Not every overlong prompt was getting wordwrapped. Fixed.

##Changes in version 0.9.3:

- Automatically check that you're using the most current version, either with -vcheck at startup, or /vcheck within the client.
- New $authenticate API method makes it possible to store your credentials anywhere you darn well please, including nowhere. Now prompts for password when you don't specify. Based on code by @jcscoobyrs.
- Autosplit using the -autosplit option, suggested by @dogsbodyorg and @timtom.
- Correctly counts bytes in tweets, since Twitter counts in bytes, not characters (thanks @cyrixhero).
- Wordwrap for arbitrary screen sizes, based on a suggestion by @augmentedfourth.
- Verify individual tweets as you post them with -verify, along with simple Perl-expression-based filtering with -filter, based on suggestions by @cwage.
- Posting tweets did not show verbose information in -superverbose mode. Fixed.
- /setting superverbose should also set verbose. Fixed.

##Changes in version 0.9.2:

- Status changed to 'stable' fork; previously embryonic features now either fully enabled or made default.
- -rc=... option allows selection from multiple .ttytterrc files, based on a suggestion by @br3nda. Corresponding -norc option allowed to, conversely, completely disable any rc file present.
- API additions ($addaction/&defaultaddaction).
- Time ranges printed for /again user (when -timestamp is not enabled).
- /print ntabcomp to display newly added entries during this session, based on a suggestion by @augmentedfourth.
- TAB completion is now case-insensitive.
- Expanded control character filter from 0.8.6.
- All bug fixes and backouts from 0.8.6.

##Changes in version 0.8.6:

- Status changed to 'deprecated' fork.
- Control character filter added (backported from 0.9.x) and expanded to pre-interpret most common mistaken entries.
- Bug fixed with @ names framed with certain punctuation not getting highlighted.
- Backed out kludges for bowdlerized /whois and less efficient workaround JSON fetch.

##Changes in version 0.9.1:

- Large rewrite of the UTF-8 handling code, with hopefully better support on as wide a range of Perls as possible.
- /print tabcomp to display your optimized completer string in advance, based on a suggestion by @augmentedfourth.
- -newline to parse \n and \r, also suggested by @augmentedfourth.
- CTRL-C now correctly triggers the END subroutine, reported by @augmentedfourth. Yeah, he's been busy. ;-)

##Changes in version 0.9.0:

- Split into 'unstable' fork.
- Major retooling of program logic to eliminate redundant portions and streamline complex sections.
- Auto-ratelimit support with -pause=auto (EMBRYONIC). However, works well enough to be the default right now. If you don't want to use this, or don't trust it, you probably should be using 0.8.5.
- Support for Term::ReadLine::\* with -readline (EMBRYONIC), including cursor key history and TAB completion (with auto-learn), and API support with $autocompletion/&defaultautocompletion to define your own TAB completion routine.
- URL shortening (-shorturl and /short).
- Runtime changes to certain options now supported with /set and /print.
- Support for unusual client environments, using -leader and -noprompt, based on an idea submitted by @chfrank\_cgn.
- Easier SSL operations using -ssl instead of requiring changes to .ttytterrc.
- /again on a username reports the time of last update if you aren't using -timestamp.
- Friendship queries fixed.
- All bug fixes from 0.8.5.
- Author breaks 25,000 tweets. He is, truly, a nerd.

##Changes in version 0.8.5:

- Split into 'stable' fork.
- Bug fixed with UTF-8 handling, even on systems and Perls that don't understand UTF-8.
- Bug fixed with users with no DMs.

##Changes in version 0.8.4:

- Several temporary workarounds for glitches in the Twitter API, namely a kludge for eating invalid JSON generated by tweet deletes, disabling some fields in /whois that were pulled, and turning off friendship checks as they currently generate 500 errors. The tweaked JSON fetch is also marked as kludge. These temporary fixes will be backed out when they are fixed on Twitter's end.

##Changes in version 0.8.3:

- Tweaked fetch routine pending eventual format of null responses (i.e., much less spurious timeout or no data messages).

##Changes in version 0.8.2:

- Twitterer names, and @ names, are now boldface and underline respectively based on patches submitted by @smb.
- Expanded /whois with code for looking up friendships, and processing avatar images (-avatar, -frurl).
- API additions ($precommand, $prepost, $postpost).
- Certain HTTP status codes could cause the JSON parser to freak out. Fixed.
- -noansi didn't take precedence over -ansi like it was supposed to. Fixed.

##Changes in version 0.8.1:

- $lasttwit, and origination classes for $handle, both API enhancements suggested by @emilsit.
- -lynx and -curl can be told to run a specific binary, useful for PATH-deficient environments or version testing.
- -status correctly warns for tweets over 140 characters.
- Speaking of which, normal tweet activity also has better warning text for oversize tweets too.
- Additional debugging information for failed test logins available.

##Changes in version 0.8.0:

- Robust scripting support for simple command-line queries (/end and -script).
- -pause=0 is now valid.
- Popping words off the end of the line (%%--, etc.) works.
- API additions (&standardtweet, &standarddm, DUPSTDOUT).
- Null array references could escape from certain asynchronous commands and cause uncaught exceptions. Fixed.
- &prinput allegedly took arguments, but ignored them and just used $\_ like it used to. Kludged around.

##Changes in version 0.7.1:

- Null array references could leak from the JSON parser, which would throw an uncaught Perl error. Fixed.
- /ruler (suggested by @jspath55).

##Changes in version 0.7.0:

- Changes suggested and coded/adapted from code by @br3nda:
	- ANSI colour and highlighting (and -ansi/-noansi).
	- Timestamp support, including templates on supported installations (-timestamp).
- Replies support (/replies and -rurl).
- /again expanded to allow querying user timelines (and -uurl).
- API expanded with $prompt, &defaultprompt and -twarg.
- Anonymous mode (-anonymous).
- User query (/whois and /wagain, and -wurl).
- JSON parser upgrades to accomodate user queries.
- Error message reporting fixed.
- Proper detection of presence/absence of modules (particularly fixing problems with -seven) and streamlined BEGIN block.
- No need to pause with -silent.
- Several side effects have now been incorporated as virtues.
- Author breaks 10,000 tweets. What a dweeb he must be.

##Changes in version 0.6.1:

- Improved stability in JSON validator when using Lynx as the user-agent.

##Changes in version 0.6.0:

- Direct message support added to both interactive client and API, with -dmurl and -dmpause.
- -silent mode and exit statuses.
- Abstraction of console input processing to facilitate future expansion in both API and internal code.
- Recognizes new-format Twitter error messages. (Correspondingly, some API exception codes are now deprecated; see documentation.)
- Command abbreviations.
- Expanded command history support and -maxhist.
- Reworked error messages.
- Various custodial fixes and upgrades to JSON interpreter.

##Changes in version 0.5.1:

- Patched for various entities in the new Twitter JSON release. This version will correctly handle both ampersand-escaped and standard entities and quotes.

##Changes in version 0.5:

- Support for rate-limited API, in two ways: first, increasing default timeout to 120 seconds, and two, properly recognizing when rate-limiting has kicked in.
- Stability improvement in JSON validator.
- Additional API exception codes for the above features.
- select() loop tightened up to make timeline hits as minimal as possible.

##Changes in version 0.4:

- UTF-8 now works right (most of the time). Added -seven option for backwards compatibility.
- First support for the TTYtter API and the -lib option.
- Detached mode using -daemon, allowing bot building.
- Tweaks to defaults.
- Work-around for out-of-order tweets "stuttering" or getting stuck. This is technically a Twitter bug, but this version can now ignore the anomaly.

##Changes in version 0.3:

- Even bigger morer robuster JSON validator.
- Posting from the command line using -status.
- Can now configure update source using -update, allowing complete abstraction of TTYtter assuming the other side supports the Twitter API over JSON.
- -hold timeout tweaked.
- Messages tweaked for accuracy and semi-user-friendliness.

##Changes in version 0.2:

- Improved detection of Twitter HTML status messages and better tolerance of partially-transmitted data (which could sometimes cause ttytter's JSON validator to freak out).
- Added "re-tweet" facility for ... retweeting.
- Added -hold option.
- Another hal-fassed attempt at better UTF-8 handling.
- Exit statuses of curl/Lynx sessions are properly reported.
- Proper command line precedence over default options. 
