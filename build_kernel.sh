#!/bin/bash -e

unset KERNEL_REL
unset KERNEL_PATCH
unset RC_KERNEL
unset RC_PATCH
unset BUILD
unset CC
unset GIT_MODE
unset NO_DEVTMPS
unset FTP_KERNEL

ARCH=$(uname -m)

DIR=$PWD

CORES=1
if test "-$ARCH-" = "-x86_64-" || test "-$ARCH-" = "-i686-" ; then
 CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
 let CORES=$CORES+1
fi

if [ ! -e ${DIR}/deploy ] ; then
  mkdir -p ${DIR}/deploy
fi
rm -rf ${DIR}/deploy/*

function make_zImage {
  cd ${DIR}/KERNEL/
  echo "make -j${CORES} ARCH=arm CROSS_COMPILE=${CC} CONFIG_DEBUG_SECTION_MISMATCH=y zImage"
  time make -j${CORES} ARCH=arm CROSS_COMPILE=${CC} CONFIG_DEBUG_SECTION_MISMATCH=y zImage
  KERNEL_UTS=$(cat ${DIR}/KERNEL/include/generated/utsrelease.h | awk '{print $3}' | sed 's/\"//g' )
  cp arch/arm/boot/zImage ${DIR}/deploy/${KERNEL_UTS}.zImage
  cd ${DIR}
}

function make_modules {
  cd ${DIR}/KERNEL/
  time make -j${CORES} ARCH=arm CROSS_COMPILE=${CC} CONFIG_DEBUG_SECTION_MISMATCH=y modules

  echo ""
  echo "Building Module Archive"
  echo ""

  rm -rf ${DIR}/deploy/mod &> /dev/null || true
  mkdir -p ${DIR}/deploy/mod
  make ARCH=arm CROSS_COMPILE=${CC} modules_install INSTALL_MOD_PATH=${DIR}/deploy/mod
  echo "Building ${KERNEL_UTS}-modules.tar.gz"
  cd ${DIR}/deploy/mod
  tar czf ../${KERNEL_UTS}-modules.tar.gz *
  cd ${DIR}
}

function make_headers {
  cd ${DIR}/KERNEL/

  echo ""
  echo "Building Header Archive"
  echo ""

  rm -rf ${DIR}/deploy/headers &> /dev/null || true
  mkdir -p ${DIR}/deploy/headers/usr
  make ARCH=arm CROSS_COMPILE=${CC} headers_install INSTALL_HDR_PATH=${DIR}/deploy/headers/usr
  cd ${DIR}/deploy/headers
  echo "Building ${KERNEL_UTS}-headers.tar.gz"
  tar czf ../${KERNEL_UTS}-headers.tar.gz *
  cd ${DIR}
}

function make_deb {
  cd ${DIR}/KERNEL/
  echo "make -j${CORES} ARCH=arm KBUILD_DEBARCH=armel CROSS_COMPILE=\"${CC}\" KDEB_PKGVERSION=${BUILDREV}${DISTRO} deb-pkg"
  time fakeroot make -j${CORES} ARCH=arm KBUILD_DEBARCH=armel CROSS_COMPILE="${CC}" KDEB_PKGVERSION=${BUILDREV}${DISTRO} deb-pkg
  mv ${DIR}/dl/*.deb ${DIR}/deploy/ # cause KERNEL is a symlink to dl/<linux>
  cd ${DIR}
}

/bin/bash -e ${DIR}/tools/host_det.sh || { exit 1 ; }

if [ -e ${DIR}/system.sh ]; then
  . system.sh

  if [ "${IS_LUCID}" ] ; then
    echo ""
    echo "IS_LUCID setting in system.sh is Depreciated"
    echo ""
  fi

  if [ "${NO_DEVTMPS}" ] ; then
    echo ""
    echo "Building for Debian Lenny & Ubuntu 9.04/9.10"
    echo ""
  else
    echo ""
    echo "Building for Debian Squeeze/Wheezy/Sid & Ubuntu 10.04/10.10/11.04/11.10"
    echo ""
  fi

    make_zImage
    make_modules
    make_headers
    make_deb
else
  echo "Missing system.sh, please copy system.sh.sample to system.sh and edit as needed"
  echo "cp system.sh.sample system.sh"
  echo "gedit system.sh"
fi

