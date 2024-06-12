#!/bin/bash

# Build software (Linux kernel + userspace initrd w. Busybox) for LiteX/Rocket
# (c) 2024 Gabriel L. Somlo <gsomlo@gmail.com>

# we do all this from the top-level user home directory:
cd ~/

# Linux kernel:
# (use resulting file ~/linux/arch/riscv/boot/Image)
pushd linux
make clean
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- litex_rocket_defconfig
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu-
popd

# Busybox userspace utility:
pushd busybox-1.36.1
cp ~/linux-on-litex-rocket/conf/busybox-1.36.1-rv64gc.config .config
make CROSS_COMPILE=riscv64-unknown-linux-gnu-
popd

# initial ramdisk image
# (use resulting file ~/initrd_bb)
mkdir initramfs; pushd initramfs
mkdir -p bin sbin lib etc dev home proc sys tmp mnt nfs root \
          usr/bin usr/sbin usr/lib
cp ~/busybox-1.36.1/busybox bin/
ln -s bin/busybox ./init
cat > etc/inittab <<- "EOT"
	::sysinit:/bin/busybox mount -t proc proc /proc
	::sysinit:/bin/busybox mount -t devtmpfs devtmpfs /dev
	::sysinit:/bin/busybox mount -t tmpfs tmpfs /tmp
	::sysinit:/bin/busybox mount -t sysfs sysfs /sys
	::sysinit:/bin/busybox --install -s
	/dev/console::sysinit:-/bin/ash
	EOT
fakeroot <<- "EOT"
	find . | cpio -H newc -o > ../initramfs.cpio
	EOT
popd
gzip initramfs.cpio
mv initramfs.cpio.gz initrd_bb
