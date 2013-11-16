#!/usr/bin/env bash

set -e
#set -x


PACKAGE='keystone'
VERSION=`head -1 version.txt`

BASE_DIR=`pwd`
BUILD_DIR=$BASE_DIR/.build
LOG=$BASE_DIR/$PACKAGE.log

# clear log
if [ -f $LOG ]; then
    rm -f $LOG
fi

# trap for unexpected error
quit() {
    cd $BASE_DIR
    echo "[`date`] $1" | tee -a $LOG
    echo "[`date`] Failure." | tee -a $LOG
    echo "[`date`] Detailed log in $LOG"
    exit -1
}
trap "quit" ERR 

# start build
echo "[`date`] Build started." | tee -a $LOG
echo "[`date`] Building $PACKAGE version $VERSION" | tee -a  $LOG

echo "[`date`] Creating build directory $BUILD_DIR" | tee -a  $LOG
# clean build directory
if [ -d $BUILD_DIR ]; then
   rm -rf $BUILD_DIR
fi

mkdir -p $BUILD_DIR/dist
cd $BUILD_DIR

# run sdist for repos mentioned in git-repos.txt
# collect all tars in $BUILD_DIR/dist {{
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
        echo "[`date`] Found repo. Pulling the latest code from ${GIT_URL}" | tee -a $LOG
        cd ${GIT_BASE_DIR}/${REPO}
        git checkout master &>> $LOG
        git reset --hard &>> $LOG 
        git pull &>> $LOG
   else
        echo "[`date`] Cloning ${GIT_URL}" | tee -a $LOG
        git clone ${GIT_URL} &>> $LOG
        cd ${REPO}
   fi
   git checkout -f $GIT_TAG &>> $LOG
   T="$(($(date +%s)-T))"
   echo "[`date`] Time to get latest code for ${REPO}: ${T} secs" | tee -a $LOG

   T="$(date +%s)"
   python setup.py build sdist &>> $LOG
   T="$(($(date +%s)-T))"
   echo "[`date`] Time to build ${REPO}: ${T} secs" | tee -a $LOG

   if [ -d $BUILD_DIR/dist ]; then
       rm -rf $BUILD_DIR/dist/*
   fi
   cp dist/*.tar.gz $BUILD_DIR/dist/
   SETUP_VERSION=`ls dist | sed -e "s/$PACKAGE-\(.*\).tar.gz/\1/"`
done < <( cat ../git-repos.txt)

# }}

# clean package directory. 
# this directory is the root for deb file {{
if [ -d $BUILD_DIR/$PACKAGE ]; then
    rm -rf $BUILD_DIR/$PACKAGE
fi
mkdir -p $BUILD_DIR/$PACKAGE
cd $BUILD_DIR/$PACKAGE
# }}

echo "[`date`] Creating virtualenv in `pwd`/$VERSION" | tee -a  $LOG
virtualenv ${VERSION} &>> $LOG
cd ${VERSION}
. bin/activate
echo "[`date`] Upgrading pip and distribute" 
pip install -U pip &>> $LOG
pip install -U distribute &>> $LOG

while read package ; do
    echo "[`date`] Installing package ${package}" | tee -a $LOG
    T="$(date +%s)"
	pip install $BUILD_DIR/dist/${package} &>> $LOG
    T="$(($(date +%s)-T))"
    echo "[`date`] Time to build ${PACKAGE} in venv: ${T} secs" | tee -a $LOG
done < <( ls $BUILD_DIR/dist )

echo "[`date`] Installing dependencies from pip-requires" | tee -a $LOG
while read line ; do
  pip install  ${line} &>> $LOG
done < <( cat $BASE_DIR/pip-requires )

deactivate &>> $LOG

#### Copy the etc files.
cd $BUILD_DIR/$PACKAGE

mkdir -p etc/init
mkdir -p etc/${PACKAGE}
mkdir -p etc/logrotate.d

cp $BASE_DIR/debian/${PACKAGE}.upstart etc/init/ 
cp $BASE_DIR/debian/${PACKAGE}.conf etc/keystone/
cp $BASE_DIR/debian/logging.conf etc/keystone/
cp $BASE_DIR/debian/policy.json etc/keystone/
cp $BASE_DIR/debian/${PACKAGE}.logrotate etc/logrotate.d/keystone

#TODO logrotate

fpm -s dir \
   -t deb  \
   -n c3-keystone \
   -v 2013.2 \
   -d python2.7 \
   -d 'python >= 2.7.1-0ubuntu2' \
   -d 'python << 2.8' \
   -d dbconfig-common \
   -d 'debconf (>= 0.5) | debconf-2.0' \
   -d 'upstart-job' \
   -d 'adduser' \
   -d 'ssl-cert (>= 1.0.12)' \
   -d 'dbconfig-common' \
   -d libxml2-dev \
   -d libxslt-dev \
   -d libmysqlclient-dev \
   -a all \
   --vendor c3 \
   --description 'c3 venv-based ${PACKAGE} package' \
   --config-files /etc/logrotate.d/${PACKAGE} \
   --config-files /etc/init/${PACKAGE}.conf \
   --config-files /etc/keystone/policy.json \
   --config-files /etc/keystone/${PACKAGE}.conf \
   --config-files /etc/keystone/logging.conf  \
   --maintainer prabhakhar@ebaysf.com \
   --before-install ${BASE_DIR}/debian/${PACKAGE}.preinst \
   --after-install ${BASE_DIR}/debian/${PACKAGE}.postinst \
   --after-remove ${BASE_DIR}/debian/${PACKAGE}.postrm \
   *

cp *.deb $BASE_DIR/
echo "[`date`] Detailed log at $LOG" | tee -a $LOG
cd $BASE_DIR
