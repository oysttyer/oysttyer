#!/bin/sh

#Given a dist URL from floodgap, fetch all versions on that page and commit, tag with right date. Only if version more recent. etc

#Changelog mostly here: http://www.floodgap.com/software/ttytter/dl.html
DIST_URL=http://www.floodgap.com/software/ttytter/dist2/
curl $DIST_URL | grep bytes | sed 's/"/ /g' | awk '{print $4, $8, $9, $10, $11, $12}' > dist.txt
while read line; do
	URL=`echo $line | awk '{print dist_url $1}' dist_url=$DIST_URL`
	DATE=`echo $line | awk '{print $2",", $4, $3, $6, $5}'`
	TAG=`echo $line | awk '{print $1}' | sed 's/\.txt//g'`
	echo $URL
	echo $DATE
	echo $TAG
	curl $URL > ttytter.pl
	git add ttytter.pl
	git commit -m "commit" --date="$DATE" --author"=Cameron Kaiser <ckaiser@floodgap.com>"
	git tag $TAG 
done< dist.txt
