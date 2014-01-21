#!/bin/sh

# Given a dist URL from floodgap, fetch all versions on that page, commit with right date and commit message from a changelog
# Ideally only do this if a more recent version - todo
# Changelog mostly here: http://www.floodgap.com/software/ttytter/dl.html
# (Had to manually put together the changelog in a markdown format)

# Needs an initial commit to exist

DIST_URL=$@

get_lines_from_changelog() {
	changelog=$1
	version=$2
	#Find line number of change
	start=`sed -n "/^##Changes in version $version/=" $changelog`
	if ! [ -z "$start" ]; then
		#Find line number of next change
		startnext=`expr $start + 1`
		endnext=`sed -n "$startnext,$ { /^##Changes/=; }" $changelog | head -n 1`
		if [ -z "$endnext" ]; then
			end=$
		else
			end=`expr $endnext - 1`
		fi
		#Get those lines
		sed -n "$start,$end p" $changelog > commit.tmp
	else
		echo "No Changelog entry available" > commit.tmp
	fi
}

# Hacky cludge to fix tags from Floodgap:
# 0.x versions are missing the decimals/periods
# 1.x or 2.x versions have leading zeroes on the last digit.
fixtag() {
	if [ `expr "$1" : '0'` -ne 0 ]; then
		if [ `expr length $1` -eq 2 ]; then
			fixedtag=`echo $1 | sed 's/\(0\)\([0-9]\)/\1\.\2/'`
		else
			fixedtag=`echo $1 | sed 's/\(0\)\([0-9]\)\([0-9]*\)/\1\.\2\.\3/'`
		fi
	elif [ `expr "$1" : '[1-2]'` -ne 0 ]; then
		fixedtag=`echo $1 | sed 's/\([0-9]\.[0-9]\.\)0\([0-9]\)/\1\2/'`
	fi
	echo $fixedtag
}

#Since listings aren't always in order, do need to check order they are committed!
ok_to_add() {
	#I'm sure there is a more succint way...
	this_major=`echo $1 | awk '{split($0,a,"."); print a[1]}'`
	this_minor=`echo $1 | awk '{split($0,a,"."); print a[2]}'`
	this_patch=`echo $1 | awk '{split($0,a,"."); print a[3]}'`
	last_major=`echo $2 | awk '{split($0,a,"."); print a[1]}'`
	last_minor=`echo $2 | awk '{split($0,a,"."); print a[2]}'`
	last_patch=`echo $2 | awk '{split($0,a,"."); print a[3]}'`
	if [ $this_major -gt $last_major ] || ( [ $this_major -eq $last_major ] && [ $this_minor -gt $last_minor ] ) || ( [ $this_major -eq $last_major ] && [ $this_minor -eq $last_minor ] && [ $this_patch -gt $last_patch ] ); then
		ok=1
	else
		ok=0
	fi
	echo $ok 
}

curl $DIST_URL | grep bytes | sed 's/"/ /g' | awk '{print $4, $8, $9, $10, $11, $12}' > dist.txt
while read line; do
	URL=`echo $line | awk '{print dist_url $1}' dist_url=$DIST_URL`
	DATE=`echo $line | awk '{print $2",", $4, $3, $6, $5}'`
	TAG=`echo $line | awk '{print $1}' | sed 's/\.txt//g'`
	TAG=`fixtag $TAG`
	#Ensure versions are added in order.
	LAST_TAG=`git tag --list | tail -n 1`
	if [ -z "$LAST_TAG" ]; then
		LAST_TAG="0.0"
	fi
	OK_TO_ADD=`ok_to_add $TAG $LAST_TAG` 
	if [ $OK_TO_ADD -eq 1 ]; then
		get_lines_from_changelog CHANGELOG.markdown $TAG
		curl $URL > ttytter.pl
		git add ttytter.pl
		git commit --file commit.tmp --date="$DATE" --author"=Cameron Kaiser <ckaiser@floodgap.com>"
		git tag $TAG 
	fi
done< dist.txt

#Clean up - this will error if actually didn't commit anything; that's fine
rm dist.txt
rm commit.tmp
