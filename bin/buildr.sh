#!/usr/bin/env bash

set -e
set -x

if [ -z $PACKAGE ]; then
    echo "PACKAGE env variable must be passed"
    exit -1
fi
CWD=`pwd`

if [ -z $BASE_DIR ]; then
    BASE_DIR=`pwd`
fi

BUILD_DIR=$BASE_DIR/.build
mkdir -p $CWD/logs
LOG=$CWD/logs/$PACKAGE.log

VERSION=`head -1 $BASE_DIR/version`
# clear log
if [ -f $LOG ]; then
    rm -f $LOG
fi

# trap for unexpected error
quit() {
    cd $BASE_DIR
    echo "[`date +'%Y-%m-%d %H:%M:%S'`] $1" | tee -a $LOG
    echo "[`date +'%Y-%m-%d %H:%M:%S'`] Failure." | tee -a $LOG
    echo "[`date +'%Y-%m-%d %H:%M:%S'`] Detailed log in $LOG"
    exit -1
}
trap "quit" ERR 

# start build
echo "[`date +'%Y-%m-%d %H:%M:%S'`] Build started." | tee -a $LOG
echo "[`date +'%Y-%m-%d %H:%M:%S'`] Building $PACKAGE version $VERSION" | tee -a  $LOG
echo "[`date +'%Y-%m-%d %H:%M:%S'`] Creating build directory $BUILD_DIR" | tee -a  $LOG

# clean build directory
if [ -d $BUILD_DIR ]; then
   rm -rf $BUILD_DIR
fi

if [ -d $BUILD_DIR/dist ]; then
    rm -rf $BUILD_DIR/dist/*
fi

mkdir -p $BUILD_DIR/dist
cd $BUILD_DIR

# run sdist for repos mentioned in git-repos
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
        echo "[`date +'%Y-%m-%d %H:%M:%S'`] Found repo. Pulling the latest code from ${GIT_URL}" | tee -a $LOG
        cd ${GIT_BASE_DIR}/${REPO}
        git checkout master &>> $LOG
        git reset --hard &>> $LOG 
        git pull &>> $LOG
   else
        echo "[`date +'%Y-%m-%d %H:%M:%S'`] Cloning ${GIT_URL}" | tee -a $LOG
        git clone ${GIT_URL} &>> $LOG
        cd ${REPO}
   fi
   git checkout -f $GIT_TAG &>> $LOG
   T="$(($(date +%s)-T))"
   echo "[`date +'%Y-%m-%d %H:%M:%S'`] Time to get latest code for ${REPO}: ${T} secs" | tee -a $LOG

   T="$(date +%s)"
   python setup.py build sdist &>> $LOG
   T="$(($(date +%s)-T))"
   echo "[`date +'%Y-%m-%d %H:%M:%S'`] Time to build ${REPO}: ${T} secs" | tee -a $LOG

   cp dist/*.tar.gz $BUILD_DIR/dist/
   SETUP_VERSION=`ls dist | sed -e "s/$PACKAGE-\(.*\).tar.gz/\1/"`
done < <( cat ${BASE_DIR}/git-repos)

# }}

# clean package directory. 
# this directory is the root for deb file {{
if [ -d ${BUILD_DIR}/$PACKAGE ]; then
    rm -rf ${BUILD_DIR}/$PACKAGE
fi

mkdir -p ${BUILD_DIR}/$PACKAGE
cd ${BUILD_DIR}/$PACKAGE
# }}

echo "[`date +'%Y-%m-%d %H:%M:%S'`] Creating virtualenv in `pwd`/$VERSION" | tee -a  $LOG
virtualenv ${VERSION} &>> $LOG
cd ${VERSION}
. bin/activate
echo "[`date +'%Y-%m-%d %H:%M:%S'`] Upgrading pip and distribute" 
pip install -U pip &>> $LOG
pip install -U distribute &>> $LOG

if [ -d $BUILD_DIR/dist ]; then
    while read package ; do
        echo "[`date +'%Y-%m-%d %H:%M:%S'`] Installing package ${package}" | tee -a $LOG
        T="$(date +%s)"
        pip install $BUILD_DIR/dist/${package} &>> $LOG
        T="$(($(date +%s)-T))"
        echo  -n "[`date +'%Y-%m-%d %H:%M:%S'`] "
        echo "Time to build ${PACKAGE} in venv: ${T} secs" | tee -a $LOG
    done < <( ls $BUILD_DIR/dist )
fi

echo "[`date +'%Y-%m-%d %H:%M:%S'`] Installing dependencies from pip-requires" | tee -a $LOG
while read line ; do
    echo "[`date +'%Y-%m-%d %H:%M:%S'`] * Installing $line"
    pip install  ${line} &>> $LOG
done < <( cat $BASE_DIR/pip-requires )

deactivate &>> $LOG

cd ${BUILD_DIR}/${PACKAGE}
virtualenv --relocatable ${VERSION} &>> $LOG

#### Copy the etc files.

cd ${BASE_DIR}/deb

wget `cat ${BASE_DIR}/deb-package-url` &>> $LOG
ar -x `ls *.deb`
mkdir -p data
tar zxf data.tar.gz -C data/
rsync -av --exclude=usr/share/pyshared --exclude=usr/lib/python2.7 data/ ${BUILD_DIR}/${PACKAGE}/ &>> $LOG

mkdir -p control
tar zxf control.tar.gz -C control/
    
cd ${BUILD_DIR}/${PACKAGE}

# copy code
mkdir -p opt/${PACKAGE}
mv  ${BUILD_DIR}/${PACKAGE}/${VERSION} opt/${PACKAGE}/

#TODO DEPS go to a seperate file
FPM_COMMAND="fpm -s dir \
   -t deb  \
   -n c3-keystone \
   -v 2013.2 \
   -a all \
   --vendor c3 \
   --maintainer prabhakhar@ebaysf.com \
   --description 'c3 venv-based ${PACKAGE} package'  "
   
if [ -f ${BASE_DIR}/deb/dependencies ]; then
    while read dep ; do
        FPM_COMMAND+="-d dep "
    done < <( cat ${BASE_DIR}/lib-dependencies )
fi

if [ -f  ${BASE_DIR}/deb/control/conffiles ]; then
    while read conffile ; do 
        FPM_COMMAND+="--config-files ${conffile} "
    done < <( cat ${BASE_DIR}/deb/control/conffiles )
fi

if [ -f ${BASE_DIR}/deb/control/preinst ]; then
    FPM_COMMAND+="--before-install $BASE_DIR/deb/control/preinst "
fi
if [ -f ${BASE_DIR}/deb/control/postinst ]; then
    FPM_COMMAND+="--after-install ${BASE_DIR}/deb/control/postinst "
fi
if [ -f ${BASE_DIR}/deb/control/prerm ]; then
    FPM_COMMAND+="--before-remove ${BASE_DIR}/deb/control/prerm "
fi
if [ -f ${BASE_DIR}/deb/control/postrm ]; then
    FPM_COMMAND+="--after remove ${BASE_DIR}/deb/control/postrm "
fi
   
FPM_COMMAND+="*"

echo $FPM_COMMAND &>> $LOG
echo -n "[`date +'%Y-%m-%d %H:%M:%S'`] "
eval $FPM_COMMAND

mv *.deb $BASE_DIR/
rm -rf ${BASE_DIR}/deb/*

echo "[`date +'%Y-%m-%d %H:%M:%S'`] Detailed log at $LOG" | tee -a $LOG

