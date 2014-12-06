#!/bin/sh

my_echo() {
  echo "`date`: $*"
}

tmpdir=/tmp/neutron-split-tmp
rm -fr $tmpdir
mkdir -p $tmpdir
logfile=$tmpdir/output.log
my_echo "Logging to $logfile"

basedir=`dirname $0`

src_repo="$1"

if [ ! -d "$src_repo" ]; then
    echo "usage: `basename $0` <source-repo-dir>"
    exit 1
elif [ -d x-n -o -d x-l -o -d x-f -o -d x-v ]; then
    echo "ERROR: one of the dest repos already exists"
    exit 1
fi

my_echo "Starting neutron split into x-n..."
$basedir/neutron-split.sh $src_repo x-n > $logfile.n 2>&1

my_echo "Starting LBaaS split into x-l..."
$basedir/service-split.sh $src_repo x-l lbaas neutron-lbaas neutron_lbaas > $logfile.l 2>&1


my_echo "Done"
