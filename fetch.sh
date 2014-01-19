#!/bin/sh

# Given a dist URL from floodgap, fetch all versions on that page, commit with right date and commit message from a changelog
# Ideally only do this if a more recent version 
# Changelog mostly here: http://www.floodgap.com/software/ttytter/dl.html
# (Had to manually put together the changelog in a markdown format)

DIST_URL=$@

get_lines_from_changelog() {
	changelog=$1
	version=$2
	#Find line number of change
	start=`sed -n "/^##Changes in version $version/=" $changelog`
	#Find line number of n ext change
	startnext=`expr $start + 1`
	endnext=`sed -n "$startnext,$ { /^##Changes/=; }" $changelog | head -n 1`
	end=`expr $endnext - 1`
	#Get those lines
	sed -n "$start,$end p" $changelog > commit.tmp
}

#What if version isn't found?
#i.e. 2.0.00 
#Also need to delete leading zero!!! 

curl $DIST_URL | grep bytes | sed 's/"/ /g' | awk '{print $4, $8, $9, $10, $11, $12}' > dist.txt
while read line; do
	URL=`echo $line | awk '{print dist_url $1}' dist_url=$DIST_URL`
	DATE=`echo $line | awk '{print $2",", $4, $3, $6, $5}'`
	TAG=`echo $line | awk '{print $1}' | sed 's/\.txt//g'`
	get_lines_from_changelog CHANGELOG.markdown $TAG
	curl $URL > ttytter.pl
	git add ttytter.pl
	git commit --file commit.tmp --date="$DATE" --author"=Cameron Kaiser <ckaiser@floodgap.com>"
	git tag $TAG 
done< dist.txt

#Clean up
rm dist.txt
rm commit.tmp
