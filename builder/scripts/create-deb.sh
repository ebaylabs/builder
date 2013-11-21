#!/usr/bin/env bash

set -e

BASE_DIR=$1
LOG=$2

cd ${BASE_DIR}

# copy code
mkdir -p opt/${PACKAGE}
mv  ${BUILD_DIR}/${PACKAGE}/${VERSION} opt/${PACKAGE}/

#TODO DEPS go to a seperate file
FPM_COMMAND="fpm -s dir \
   -t deb  \
   -n ${PACKAGE} \
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

