#!/bin/bash
unset LAIKA_ROOTFS_DIR
echo "rootfs dir generator for LAIKA"
test -n "$LAIKA_ROOTFS_TAR" || read -p "where is your rootfs.tar file: " LAIKA_ROOTFS_TAR

if [ -f "$LAIKA_ROOTFS_TAR" ]; then
  test -d "rootfs" && rm -rf rootfs
  mkdir rootfs

  tar -C rootfs/ -xvf $LAIKA_ROOTFS_TAR
  echo "Complete. Setting your LAIKA_ROOTFS_DIR for you."
  
  CURRENT_DIR=`pwd`
  export LAIKA_ROOTFS_DIR="$CURRENT_DIR/rootfs/"
  echo "set LAIKA_ROOTFS_DIR to $LAIKA_ROOTFS_DIR."
  echo "use command unset LAIKA_ROOTFS_DIR or rerun this program to unset it."
else
  echo "Invalid File!!"
fi
