#!/bin/sh

#Too Change MMC mount directory
#export MMC=/dev/sdX1
#. install-me.sh

if [ -z $1 ] ; then
  echo "Please specify which kernel deb to install"
  exit 1
fi
KERNEL_DEB=$1
# Example  linux-image-3.1.0-x1_1.0natty_armel.deb
KERNEL_VERSION=`echo ${KERNEL_DEB} | awk -F- '{print $3 "-" $4 "-" $5 "-" $6 "-" $7}' | awk -F_ '{print $1}'`
#KERNEL_VERSION="3.1.0+"

if test "=$(uname -m)=" = "=armv7l=" ; then
  MKIMAGE=$(which mkimage 2> /dev/null)
  INITRAMFS=$(sudo which update-initramfs 2> /dev/null)

  if test "-$MMC-" = "--" ; then
    MMC=/dev/mmcblk0p1
  fi

  echo "Mounting Fat partition"
  mkdir -p /tmp/boot
  umount ${MMC} &> /dev/null
  mount ${MMC} /tmp/boot
  touch /tmp/boot/ro && sudo rm -f /tmp/boot/ro || sudo mount -o remount,rw /tmp/boot

  MMC_TEST=$(mount | grep $MMC | awk '{print $3}')
  if test "-$MMC_TEST-" = "-/tmp/boot-" ; then

    if test "-$MKIMAGE-" = "--" | test "-$INITRAMFS-" = "--" ; then
      echo "Installing Required Packages: uboot-mkimage initramfs-tools"
      apt-get install -y uboot-mkimage initramfs-tools
    fi

    echo "Installing linux-image"
    dpkg -i ${KERNEL_DEB}

    echo "Creating uImage from vmlinuz"
    mkimage -A arm -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n ${KERNEL_VERSION} -d /boot/vmlinuz-${KERNEL_VERSION} /tmp/boot/uImage-${KERNEL_VERSION}
    rm /tmp/boot/uImage
    cp /tmp/boot/uImage-${KERNEL_VERSION} /tmp/boot/uImage

    echo "Creating uInitrd"
    if [ ! -e /boot/initrd.img-${KERNEL_VERSION} ] ; then
      update-initramfs -c -k ${KERNEL_VERSION}
    fi
    mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n initramfs -d /boot/initrd.img-${KERNEL_VERSION} /tmp/boot/uInitrd-${KERNEL_VERSION}
    rm /tmp/boot/uInitrd
    cp /tmp/boot/uInitrd-${KERNEL_VERSION} /tmp/boot/uInitrd

    ls -lh /tmp/boot/uI*
    umount /tmp/boot

    echo "Please Reboot"
  else
    echo "Could Not mount MMC Directory"
  fi
else
  echo "Sorry Not Implemented yet"
fi

