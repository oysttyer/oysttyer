#! /bin/bash

acct_name="INSERT_HERE_YOUR_ACCOUNT_NAME"
cd $(dirname $0)
CURRDIR=$(pwd)

export OYSTTYER_PROFILE=${acct_name}

test -d $HOME/.oysttyer || mkdir -p $HOME/.oysttyer
test -d $HOME/.oysttyer/default || mkdir -p $HOME/.oysttyer/default
test -d $HOME/.oysttyer/${OYSTTYER_PROFILE} || mkdir -p $HOME/.oysttyer/${OYSTTYER_PROFILE}

perl $CURRDIR/oysttyer.pl "$@"
