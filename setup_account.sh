#! /bin/bash

cd $(dirname $0)
CURRDIR=$(pwd)

echo "insert your twitter account name:"
read acct_name
export OYSTTYER_PROFILE=${acct_name}

test -d $HOME/.oysttyer || mkdir -p $HOME/.oysttyer
test -d $HOME/.oysttyer/default || mkdir -p $HOME/.oysttyer/default
test -d $HOME/.oysttyer/${OYSTTYER_PROFILE} || mkdir -p $HOME/.oysttyer/${OYSTTYER_PROFILE}

perl $CURRDIR/oysttyer.pl "$@"
