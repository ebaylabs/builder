#!/usr/bin/env bash

set -e
set -x

PACKAGE='keystone'
VERSION=`head -1 version.txt`
LOG=$PACKAGE.log

echo Building $PACKAGE version $VERSION

BASE_DIR=`pwd`
BUILD_DIR=$BASE_DIR/build

echo Creating build directory $BUILD_DIR
mkdir -p $BUILD_DIR/dist
cd $BUILD_DIR

while read line ; do
   a=( $line )
   GIT_URL=${a[0]}
   GIT_TAG=${a[1]}
   REPO=`basename ${GIT_URL} .git`
   echo "Cloning ${GIT_URL}"
   GIT_BASE_DIR=/tmp/${GIT_URL:8}
   mkdir -p ${GIT_BASE_DIR}
   cd ${GIT_BASE_DIR}
   git clone ${GIT_URL} >> $LOG
   cd ${REPO};
   git checkout -f $GIT_TAG >> $LOG
   python setup.py build sdist >> $LOG
   cp dist/*.tar.gz $BUILD_DIR/dist/
   SETUP_VERSION=`ls dist | sed -e "s/$PACKAGE-\(.*\).tar.gz/\1/"`
done < <( cat ../git-repos.txt)


mkdir $BUILD_DIR/$PACKAGE
cd $BUILD_DIR/$PACKAGE

echo Creating virtualenv in `pwd`/$VERSION
virtualenv --no-site-packages $VERSION
cd $VERSION
. bin/activate
pip install -U pip >> $LOG
pip install -U distribute $LOG

while read package ; do
    echo Installing package $package
    pip install $BUILD_DIR/dist/$package >> $LOG
done < <( ls $BUILD_DIR/dist )

echo Installing dependencies
while read line ; do
  pip install  $line >> $LOG
done < <( cat $BASE_DIR/pip-requires )

deactivate

echo Detailed log at $LOG

