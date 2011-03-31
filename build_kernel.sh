#!/bin/bash -e

unset KERNEL_REL
unset KERNEL_PATCH
unset RC_KERNEL
unset RC_PATCH
unset BUILD
unset CC
unset GIT_MODE
unset NO_DEVTMPS

ARCH=$(uname -m)
CCACHE=ccache
DIR=$PWD

CORES=1
if test "-$ARCH-" = "-x86_64-" || test "-$ARCH-" = "-i686-"
then
 CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
 let CORES=$CORES+1
fi

mkdir -p ${DIR}/deploy/

DL_DIR=${DIR}/dl

mkdir -p ${DL_DIR}

function dl_kernel {
	wget -c --directory-prefix=${DL_DIR} http://www.kernel.org/pub/linux/kernel/v2.6/linux-${KERNEL_REL}.tar.bz2

if [ "${KERNEL_PATCH}" ] ; then
    if [ "${RC_PATCH}" ] ; then
		wget -c --directory-prefix=${DL_DIR} http://www.kernel.org/pub/linux/kernel/v2.6/testing/${DL_PATCH}.bz2
	else
		wget -c --directory-prefix=${DL_DIR} http://www.kernel.org/pub/linux/kernel/v2.6/${DL_PATCH}.bz2
    fi
fi
}

function extract_kernel {
	echo "Cleaning Up"
	rm -rfd ${DIR}/KERNEL || true
	echo "Extracting: ${KERNEL_REL} Kernel"
	tar xjf ${DL_DIR}/linux-${KERNEL_REL}.tar.bz2
	mv linux-${KERNEL_REL} KERNEL
	cd ${DIR}/KERNEL
if [ "${GIT_MODE}" ] ; then
	git init
	git add .
        git commit -a -m ''$KERNEL_REL' Kernel'
        git tag -a $KERNEL_REL -m $KERNEL_REL
fi
if [ "${KERNEL_PATCH}" ] ; then
	echo "Applying: ${KERNEL_PATCH} Patch"
	bzcat ${DL_DIR}/patch-${KERNEL_PATCH}.bz2 | patch -s -p1
if [ "${GIT_MODE}" ] ; then
	git add .
        git commit -a -m ''$KERNEL_PATCH' Kernel'
        git tag -a $KERNEL_PATCH -m $KERNEL_PATCH
fi
fi
	cd ${DIR}/
}

function patch_kernel {
	cd ${DIR}/KERNEL
	export DIR GIT_MODE
	/bin/bash -e ${DIR}/patch.sh

if [ "${GIT_MODE}" ] ; then
if [ "${KERNEL_PATCH}" ] ; then
        git add .
        git commit -a -m ''$KERNEL_PATCH'-'$BUILD' patchset'
        git tag -a $KERNEL_PATCH-$BUILD -m $KERNEL_PATCH-$BUILD
else
        git add .
        git commit -a -m ''$KERNEL_REL'-'$BUILD' patchset'
        git tag -a $KERNEL_REL-$BUILD -m $KERNEL_REL-$BUILD
fi
fi
#Test Patches:
#exit
	cd ${DIR}/
}

function copy_defconfig {
	cd ${DIR}/KERNEL/
	make ARCH=arm CROSS_COMPILE=${CC} distclean
if [ "${NO_DEVTMPS}" ] ; then
	cp ${DIR}/patches/no_devtmps-defconfig .config
else
	cp ${DIR}/patches/defconfig .config
fi
	cd ${DIR}/
}

function make_menuconfig {
	cd ${DIR}/KERNEL/
	make ARCH=arm CROSS_COMPILE=${CC} menuconfig
if [ "${NO_DEVTMPS}" ] ; then
	cp .config ${DIR}/patches/no_devtmps-defconfig
else
	cp .config ${DIR}/patches/defconfig
fi
	cd ${DIR}/
}

function make_uImage {
	cd ${DIR}/KERNEL/
	echo "make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE=\"${CCACHE} ${CC}\" CONFIG_DEBUG_SECTION_MISMATCH=y uImage"
	time make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y uImage
	KERNEL_UTS=$(cat ${DIR}/KERNEL/include/generated/utsrelease.h | awk '{print $3}' | sed 's/\"//g' )
	cp arch/arm/boot/uImage ${DIR}/deploy/${KERNEL_UTS}.uImage
	cd ${DIR}
}

function make_modules {
	cd ${DIR}/KERNEL/
	time make -j${CORES} ARCH=arm LOCALVERSION=-${BUILD} CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y modules

	echo ""
	echo "Building Module Archive"
	echo ""

	rm -rfd ${DIR}/deploy/mod &> /dev/null || true
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

	rm -rfd ${DIR}/deploy/headers &> /dev/null || true
	mkdir -p ${DIR}/deploy/headers/usr
	make ARCH=arm CROSS_COMPILE=${CC} headers_install INSTALL_HDR_PATH=${DIR}/deploy/headers/usr
	cd ${DIR}/deploy/headers
	echo "Building ${KERNEL_UTS}-headers.tar.gz"
	tar czf ../${KERNEL_UTS}-headers.tar.gz *
	cd ${DIR}
}


	/bin/bash -e ${DIR}/tools/host_det.sh || { exit 1 ; }
if [ -e ${DIR}/system.sh ]; then
	. system.sh
	. version.sh

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
	echo "Building for Debian Squeeze/Wheezy/Sid & Ubuntu 10.04/10.10/11.04"
	echo ""
fi

	dl_kernel
	extract_kernel
	patch_kernel
	copy_defconfig
	make_menuconfig
	make_uImage
	make_modules
	make_headers
else
	echo "Missing system.sh, please copy system.sh.sample to system.sh and edit as needed"
	echo "cp system.sh.sample system.sh"
	echo "gedit system.sh"
fi

