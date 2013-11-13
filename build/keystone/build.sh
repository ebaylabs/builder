#! /bin/bash

set -e

CWD=`pwd`

mkdir .build-dir
cd .build-dir

cp ../fpm-command .

mkdir -p etc/keystone
mkdir -p etc/init

cp ../debian/keystone.conf etc/keystone/keystone.conf
cp ../debian/keystone.upstart etc/init/keystone.conf


TIMESTAMP=`date +%s`
BUILDDIR=$PACKAGE-$TIMESTAMP
while read line ; do
   REPO=`basename ${GIT_URL} .git`
   echo "cloning ${GIT_URL}"
   mkdir -p /tmp/$BUILDDIR
   cd /tmp/$BUILDDIR
   git clone ${GIT_URL}
   cd ${REPO};
   git checkout -f -B ${GIT_BRANCH} origin/${GIT_BRANCH}

   python setup.py build sdist

   SETUP_VERSION=`ls dist | sed -e "s/$PACKAGE-\(.*\).tar.gz/\1/"`
   # TODO read from file
   VERSION=$SETUP_VERSION

mkdir -p $PACKAGE
cd $PACKAGE
VENV=$VERSION
virtualenv --no-site-packages $VENV
cd $VENV
chmod +x ./bin/activate
. ./bin/activate
pip install -U distribute pip
pip install /tmp/$BUILDDIR/$REPO/dist/$PACKAGE-$SETUP_VERSION.tar.gz

while read line ; do
  pip install  $line
done < <( curl -k https://github.scm.corp.ebay.com/Openstratus/build/raw/master/dependencies/${PACKAGE}.txt )

# prepare for tar`ing
cd ..
deactivate
virtualenv --relocatable $VENV
cd ..
if [ $PACKAGE == 'trove' ]
then
  mv ../src $PACKAGE/$VENV/
fi
PKG_TAR="$PACKAGE-$VENV.tar.gz"
tar cfz $PKG_TAR $PACKAGE/$VENV

mv $PKG_TAR $CWD/

done < <( cat ../git-repos.txt)
