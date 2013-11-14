#!/usr/bin/env bash

set -e
#set -x

PACKAGE='keystone'
VERSION=`head -1 version.txt`

BASE_DIR=`pwd`
BUILD_DIR=$BASE_DIR/.build
LOG=$BASE_DIR/$PACKAGE.log

echo Build started at `date` | tee -a $LOG
echo Building $PACKAGE version $VERSION | tee -a  $LOG

echo Creating build directory $BUILD_DIR | tee -a  $LOG
if [ -d $BUILD_DIR ]; then
   rm -rf $BUILD_DIR
fi

mkdir -p $BUILD_DIR/dist
cd $BUILD_DIR

while read line ; do
   a=( $line )
   GIT_URL=${a[0]}
   GIT_TAG=${a[1]}
   REPO=`basename ${GIT_URL} .git`
   GIT_BASE_DIR=/tmp/${GIT_URL:8}
   mkdir -p ${GIT_BASE_DIR}
   cd ${GIT_BASE_DIR}
   T="$(date +%s)"
   if [ -d ${GIT_BASE_DIR}/${REPO} ]; then
        echo Found repo. Pulling the latest code from ${GIT_URL} | tee -a $LOG
        cd ${GIT_BASE_DIR}/${REPO}
        git checkout master &>> $LOG
        git reset --hard &>> $LOG 
        git pull &>> $LOG
   else
        echo "Cloning ${GIT_URL}" | tee -a $LOG
        git clone ${GIT_URL} &>> $LOG
        cd ${REPO}
   fi
   git checkout -f $GIT_TAG &>> $LOG
   T="$(($(date +%s)-T))"
   echo ${T}
   echo Time to get latest code for ${REPO}: ${T}secs | tee -a $LOG

   T="$(date +%s)"
   python setup.py build sdist &>> $LOG
   T="$(($(date +%s)-T))"
   echo Time to build ${REPO}: ${T}secs | tee -a $LOG

   if [ -d $BUILD_DIR/dist ]; then
       rm -rf $BUILD_DIR/dist/*
   fi
   cp dist/*.tar.gz $BUILD_DIR/dist/
   SETUP_VERSION=`ls dist | sed -e "s/$PACKAGE-\(.*\).tar.gz/\1/"`
done < <( cat ../git-repos.txt)

if [ -d $BUILD_DIR/$PACKAGE ]; then
    rm -rf $BUILD_DIR/$PACKAGE
fi
mkdir -p $BUILD_DIR/$PACKAGE
cd $BUILD_DIR/$PACKAGE

echo Creating virtualenv in `pwd`/$VERSION | tee -a  $LOG
virtualenv ${VERSION} &>> $LOG
cd ${VERSION}
. bin/activate
pip install -U pip &>> $LOG
pip install -U distribute &>> $LOG

while read package ; do
    echo Installing package ${package} | tee -a $LOG
    pip install $BUILD_DIR/dist/${package} &>> $LOG
done < <( ls $BUILD_DIR/dist )

echo Installing dependencies | tee -a $LOG
while read line ; do
  pip install  ${line} &>> $LOG
done < <( cat $BASE_DIR/pip-requires )

deactivate

echo Detailed log at $LOG | tee -a $LOG

cd $BASE_DIR
