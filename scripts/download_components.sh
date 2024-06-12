#!/bin/bash

# Download Linux-on-LiteX-Rocket prerequisites that aren't distro-packaged
# (c) 2024 Gabriel L. Somlo <gsomlo@gmail.com>

# we do all this from the top-level user home directory:
cd ~/

# GCC cross-compiler toolchain:
# (pre-built, see https://github.com/linux-on-litex-rocket for details)
curl http://www.contrib.andrew.cmu.edu/~somlo/BTCP/RISCV-toolchain.tar.xz \
     | tar xfJ -
# this won't take effect until next login, or until `source ~/.bashrc`:
echo 'export PATH=$PATH:$HOME/RISCV/bin' >> ~/.bashrc

# LiteX repositories:
# (`git pull` in all repos and rebuild btstream to stay up to date)
mkdir LITEX; pushd LITEX
for i in litex litedram liteeth litesdcard litesata litescope; do
  git clone --recursive https://github.com/enjoy-digital/$i
  (cd $i; python setup.py develop --user)
done
for i in litex-boards pythondata-cpu-rocket pythondata-software-picolibc pythondata-software-compiler_rt; do
  git clone --recursive https://github.com/litex-hub/$i
  (cd $i; python setup.py develop --user)
done
popd

# Linux kernel:
# (tracks upstream Linus tree, keeps LiteX specific drivers rebased on top)
git clone https://github.com/litex-hub/linux -b litex-rebase

# OpenSBI:
git clone https://github.com/riscv-software-src/opensbi

# Busybox:
curl https://busybox.net/downloads/busybox-1.36.1.tar.bz2 | tar xfj -

