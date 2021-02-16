#!/bin/bash
echo "iso builder for LAIKA"
CURRENT_DIR=`pwd`

test -d laika_iso_tmp && echo "WARNING WARNING WARNING! It seems test.qcow2 is existing in laika_iso_tmp!"
test -d laika_iso_tmp && exit 1

mkdir laika_iso_tmp

test -f laika/test.qcow2 && mv laika/test.qcow2 laika_iso_tmp/test.qcow2
cp -r laika_boot/boot laika/boot
##cp laika_boot/efi.img laika/
grub-mkrescue --product-name="StellaOS" --product-version="Developer Preview" -o laika.iso laika/

rm -f laika/efi.img
rm -rf laika/boot
test -f laika_iso_tmp/test.qcow2 && mv laika_iso_tmp/test.qcow2 laika/test.qcow2

rm -rf laika_iso_tmp
echo "Done."
