#!/bin/bash

echo "Copying Linux Kernel Modules..."
find linux -name '*.ko' | cpio -pdm initramfs/trusted_live_initramfs/lib/modules/
