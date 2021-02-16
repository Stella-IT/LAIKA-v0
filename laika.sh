#!/bin/bash
figlet LAIKA
echo "LAIKA: Automatic Initramfs Kit Aggregator"
echo
echo "[CONFIDENTIAL]"
echo "This software is part of Stella IT's StellaOS Building Architecture."
echo "Please refer to Stella IT NDA for more details"
echo
echo "Powered by Stella IT"
echo
echo

# location initialization
LAIKA_LOCATION=`pwd`
LAIKA_LATEST_VMLINUZ=`ls -t /artifact/ | head -1`

# show help
if [[ $1 == "help" ]]; then
echo "========[HELP]========"
echo
echo "LAIKA_INITRAMFS_DIR  = folder where initramfs structure exist"
echo "LAIKA_ROOTFS_DIR     = folder for rootfs for squashfs generation"
echo "                       (untar your rootfs.tar to create directory for it)"
echo "LAIKA_VMLINUZ        = the linux kernel file"
echo "                       (fallback: /artifact/$LAIKA_LATEST_VMLINUZ)"
echo "LAIKA_SKIP_QEMUIMAGE = set this 1 to skip qemu image building"
echo
exit 1
fi

# Temporary Folder Generation
echo -n "Creating Temporary folder for building... "
test -d laika && rm -rf laika > /dev/null
mkdir laika > /dev/null
echo "Done."

# check initramfs folder really exists
echo -n "Checking predefined initramfs directory exists... "

if [ ! -n "$LAIKA_INITRAMFS_DIR" ]; then
echo
echo
echo "System Detected that there is no predefined LAIKA_INITRAMFS_DIR"
read -p "Which directory does initramfs exist? : " LAIKA_INITRAMFS_DIR
test -n "$LAIKA_INITRAMFS_DIR" || echo "Invalid input! fallback to buildroot/output/staging/"
test -n "$LAIKA_INITRAMFS_DIR" || LAIKA_INITRAMFS_DIR="buildroot/output/staging"
echo
fi

test -d "$LAIKA_INITRAMFS_DIR" || echo "Invalid Directory!!"
test -d "$LAIKA_INITRAMFS_DIR" || exit 1
echo "Done."

# check squashfs
echo -n "Checking predefined rootfs directory exists... "
if [ ! -n "$LAIKA_ROOTFS_DIR" ]; then
echo
echo
echo "Could not find predefined LAIKA_ROOTFS_DIR variable"
read -p "Which directory does rootfs exist? : " LAIKA_ROOTFS_DIR
echo
fi

test -d "$LAIKA_ROOTFS_DIR" || echo "Invalid Directory!!"
test -d "$LAIKA_ROOTFS_DIR" || exit 1
echo "Done."

# copy squashfs
echo -n "Generating laika/rootfs.squashfs via $LAIKA_ROOTFS_DIR..."
cd $LAIKA_LOCATION
sudo mksquashfs $LAIKA_ROOTFS_DIR laika/rootfs.squashfs
echo "Done."

# signing rootfs.squashfs
echo -n "Signing laika/rootfs.squashfs..."
cd "$LAIKA_LOCATION/laika"
gpg -b rootfs.squashfs
echo "Done."

# copy rootfs.squshfs.sig to initramfs
echo -n "Copying laika/rootfs.squshfs.sig into initramfs structure..."
cd $LAIKA_LOCATION

sudo mksquashfs $LAIKA_ROOTFS_DIR laika/rootfs.squashfs
echo "Done."

# signing rootfs.squashfs
echo -n "Signing laika/rootfs.squashfs..."
cd "$LAIKA_LOCATION/laika"
gpg -b rootfs.squashfs
echo "Done."

# copy rootfs.squshfs.sig to initramfs
echo -n "Copying laika/rootfs.squshfs.sig into initramfs structure..."
cd $LAIKA_LOCATION
test -f $LAIKA_INITRAMFS_DIR/rootfs.squashfs.sig && rm $LAIKA_INITRAMFS_DIR/rootfs.squashfs.sig
mv laika/rootfs.squashfs.sig $LAIKA_INITRAMFS_DIR/
echo "Done."

# check vmlinuz
echo -n "Checking predefined vmlinuz exists... "

if [ ! -n "$LAIKA_VMLINUZ" ]; then
echo
echo
echo "Could not find predefined LAIKA_VMLINUZ variable"
echo "Automatically using latest available artifact."
echo " -> /artifact/$LAIKA_LATEST_VMLINUZ"
LAIKA_VMLINUZ="/artifact/$LAIKA_LATEST_VMLINUZ"
echo
fi

test -f "$LAIKA_VMLINUZ" || echo "vmlinuz file not found!!"
test -f "$LAIKA_VMLINUZ" || exit 1
echo "Done."

# copy vmlinuz and sign
echo -n "Copying vmlinuz to LAIKA workspace... "
cd $LAIKA_LOCATION
cp "$LAIKA_VMLINUZ" laika/vmlinuz
echo "Done."

# sign vmlinuz
echo -n "Signing vmlinuz... "
cd "$LAIKA_LOCATION/laika"
gpg -b vmlinuz

cd $LAIKA_LOCATION
test -f $LAIKA_INITRAMFS_DIR/vmlinuz.sig || rm $LAIKA_INITRAMFS_DIR/vmlinuz.sig
mv laika/vmlinuz.sig $LAIKA_INITRAMFS_DIR/
echo "Done."

# generate initramfs
echo -n "Generating initramfs..."
cd $LAIKA_LOCATION
cd $LAIKA_INITRAMFS_DIR
echo
find . -print0 | cpio --null --create --verbose --format=newc 2>/dev/null | gzip --best > $LAIKA_LOCATION/laika/initramfs
echo "Done."

# signing initramfs
echo -n "Signing initramfs..."
cd $LAIKA_LOCATION
cd laika/
gpg -b initramfs
cd ../
echo "Done."

if [ -n "$LAIKA_SKIP_QEMUIMAGE" ]; then
echo "Skipping QEMU build..."
exit 1
fi

## qcow2 마운트를 위한 커널 수정
echo -n "Tweaking Kernel for mounting qemu image..."
sudo modprobe nbd max_part=8
echo "Done."

## QEMU 이미지 생성
echo -n "Creating QEMU image..."
cd $LAIKA_LOCATION
cd laika/
qemu-img create -f qcow2 test.qcow2 10G
echo "Done."
# QEMU 이미지
echo -n "Mounting QEMU image to /dev/nbd0..."
cd $LAIKA_LOCATION
sudo qemu-nbd --connect=/dev/nbd0 laika/test.qcow2 > /dev/null
echo "Done"

## 파티셔닝 및 각각 ext3, ext4 포맷작업
echo -n "Partitioning /dev/nd0..."
sudo parted /dev/nbd0 mklabel msdos >/dev/null
sudo parted -a opt /dev/nbd0 mkpart primary ext3 0% 70% >/dev/null
sudo parted -a opt /dev/nbd0 mkpart primary ext4 70% 100% >/dev/null
echo "Done."

## 각각 파일 시스템 생성
echo "Creating Filesystem on /dev/nbd0p1..."
echo
sudo mkfs.ext3 /dev/nbd0p1
echo
echo "Done."

echo "Creating Filesystem on /dev/nbd0p2..."
echo
sudo mkfs.ext4 /dev/nbd0p2
echo
echo "Done."

## 부트 파티션 연동 작업
echo -n "Synchronizing Boot Partition of Image..."
test -d /tmp/nbdwork0 || mkdir /tmp/nbdwork0
sudo mount /dev/nbd0p1 /tmp/nbdwork0
sudo cp laika/* /tmp/nbdwork0/
echo "Done."

# 마무리 작업
echo "Unmounting Image..."
echo
sudo umount /tmp/nbdwork0
sudo rm -rf /tmp/nbdwork0
sudo qemu-nbd -d /dev/nbd0
echo
echo "Done."

# QEMU ON!!
echo "Starting StellaOS..."
cd laika
qemu-system-x86_64 -m 256 -kernel vmlinuz -initrd initramfs -append "quiet console=ttyS0" -display none -serial stdio -hda test.qcow2
cd ..
