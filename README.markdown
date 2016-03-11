# oysttyer

The official fork and replacement for what was once [Floodgap's TTYtter](http://www.floodgap.com/software/ttytter/).

In order to get Cameron Kaiser's blessing, we've had to change the name, take out a new API key and keep the Floodgap Free Software License.

The master branch will be pretty much what I'm running, but that doesn't mean I've not managed to break it in someway. The mirror branch reflects all the historical official TTYtter updates.

See the [oysttyer User Guide](http://oysttyer.github.io/docs/userGuide.html) for usage information.

## Switching from TTYtter

1. You have to re-authorise (you can't use your `.ttytterkey`) as we have a new API key
2. Move/rename your `.ttytterc` file to `.oysttyerrc`
3. If you use the `ttytteristas` pref it is now called `oysttyeristas`
4. Read the Changelog to see what's new since TTYtter 2.1

I think that's it?

### Launching Oysttyer

Depending on how you obtain oysttyer the file could already be executable so you can launch it directly (`./oysttyer.pl`) as long as the shebang matches your path to Perl or you alter the shebang so it does. However, it's probably a lot easier just to do:

	perl oysttyer.pl

### Using your own oauthkey and oauthsecret

Since the transition from TTYtter, Twitter seem to be in the habit of muzzling us (their word for blocking write access). This is done at the oysttyer oauthkey/secret level so affects all users. As a (hopefully) temporary work-around until we can resolve this issue permanently with Twitter you can register our own app (You can call it whatever, but if you are stuck for a name call it "oysttyer-<your twitter handle>") and specify the `oauthkey` and `oauthsecret` in the `.oysttyerrc` file:

	oauthkey=xxXxxXxxXXXXXxXxxxXXXxxXX
	oauthsecret=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

Be sure to avoid trailing whitespace in your key/secret. You will, of course, have to re-authorise and get a new token. I suggest taking advantage of the existing keyfile functionality in oysttyer to do this. **Important**: If you are using you own oauthkey and oauthsecret to get a new token then that token will only work with your own oauthkey and oauthsecret. Tokens are not interchangeable between oauthkeys and oauthsecrets.

### New functionality since TTYtter 2.1

Until we catch up with the documentation, check out the changelog and commitlog, etc.

### Notes to extension developers

1. The `TTYtter_VERSION`, `TTYtter_PATCH_VERSION` and `TTYtter_RC_NUMBER` variables are now `oysttyer_VERSION`, `oysttyer_PATCH_VERSION` and `oysttyer_RC_NUMBER`.
2. User-agent string has changed to `oysttyer/$oysttyer_VERSION`.

## Recommendations

I strongly suggest, although it is by no means compulsory, tracking @oysttyer and #oysttyer as that way you become connected to a global support network.

Also, check out some available extensions:

* [oysttyer-profile](https://github.com/oysttyer/oysttyer-profile) update your profile information from within oysttyer
* [oysttyer-deshortify](https://github.com/oysttyer/oysttyer-deshortify) gets rid of shortlinks and displays final URLs
* [oysttyer-multigeo](https://github.com/oysttyer/oysttyer-multigeo) for all your geographical location needs

