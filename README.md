# Linux on LiteX with a 64-bit RocketChip CPU

This repository demonstrates the capability to run 64-bit Linux on a
SoC built with [LiteX](https://github.com/enjoy-digital/litex) and
[RocketChip](https://github.com/chipsalliance/rocket-chip).

![](https://user-images.githubusercontent.com/1450143/102630245-9bac1c80-414c-11eb-92c9-311fd4e06bea.png)

## Prerequisites:

1. Miscellaneous supporting packages, most likely available from the
   repositories of your Linux distribution; e.g., on Fedora(32):

   ```
   sudo dnf install openocd dtc fakeroot perl-bignum json-c-devel verilator \
                    python3-devel python3-setuptools libevent-devel \
                    libmpc-devel mpfr-devel
   ```

   Some Linux distributions (e.g, Fedora) also provide packaged versions of
   some of the additional prerequisites listed below (e.g., `python3-migen`,
   `yosys`, `trellis`, and `nextpnr`).

2. The full LiteX development environment (including pre-built Verilog
   "intermediate" sources for Rocket, and the underlying Migen meta-HDL):

   ```
   wget https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
   python3 ./litex_setup.py init install --user
   ```

3. A GCC cross-compiler toolchain for 64-bit RISC-V. One might simply add
   `gcc` as an additional argument on the `litex_setup.py` installation
   command line from above, but that may or may not work when building
   BusyBox, and, more importantly, BBL. Therefore, for a fully functional
   toolchain, the following is strongly recommended:

   ```
   git clone --recursive https://github.com/riscv/riscv-gnu-toolchain
   pushd riscv-gnu-toolchain
   ./configure --prefix=$HOME/RISCV --enable-multilib
   make newlib linux
   popd
   ```

   Note that building the whole gcc cross-compiler toolchain from source may
   take several hours to complete. A pre-built binary tarball of the toolchain
   described above may be downloaded
   [here](http://www.contrib.andrew.cmu.edu/~somlo/BTCP/RISCV-20201216git7553f35.tar.xz).

   Be sure to add `$HOME/RISCV/bin` to your `$PATH`, e.g.:

   ```
   echo 'export PATH=$PATH:$HOME/RISCV/bin' >> ~/.bashrc
   ```

4. One or more HDL toolchains, as appropriate for your specific FPGA board:
   - Vivado (e.g., 2018.2) for Xilinx boards (e.g., `digilent_nexys4ddr`)
   - [yosys](https://github.com/YosysHQ/yosys),
     [trellis](https://github.com/YosysHQ/prjtrellis), and
     [nextpnr](https://github.com/YosysHQ/nextpnr)
     for Lattice ECP5 boards (e.g., `lattice_versa_ecp5`, `trellisboard`,
     `lambdaconcept_ecpix5`, etc.)<br>
     You may be able to install these as distro-packages on e.g. Fedora
     (`sudo dnf install yosys trellis nextpnr`), or you may want to download
     and build their latest upstream sources, as they are being developed
     at a rapid pace and changes (for better or worse) will outpace whatever
     is currently offered as a package with Fedora.

## Pre-built Binaries: bitstream, boot images, intermediate targets:

Pre-built binaries for most of the targets described below are available for
download [here](https://github.com/litex-hub/linux-on-litex-rocket/issues/1).

## Building the Gateware (FPGA Bitstream):

The five boards currently tested are `digilent_nexys4ddr`, `trellisboard`,
`lambdaconcept_ecpix5`, `lattice_versa_ecp5`, and `digilent_arty`. Once all
prerequisites are in place, building bitstream for each one is a relatively
straightforward process.

***NOTE 1***: The difference between the `linux`, `linuxd`, and `linuxq`
variants of the Rocket cpu-type is in the bit width of the point-to-point
AXI link connecting the CPU and LiteDRAM controller specific to each particular
board model. On `digilent_nexys4ddr`, LiteDRAM has a native port width of
64 bits; on the `trellisboard`, the native LiteDRAM width is 256 bits; finally,
on both `lambdaconcept_ecpix5`, `lattice_versa_ecp5` and `digilent_arty`,
LiteDRAM is 128 bit wide.

How to tell what the appropriate port width is on a ***new*** board?
Right after starting the bitstream build process, watch for output that looks
like this:

```
INFO:SoCBusHandler:main_ram Region added at Origin: 0x80000000,
     Size: 0xXXXXXXX, Mode: RW, Cached: True Linker: False.
```

followed by either:

```
INFO:SoC:Matching AXI MEM data width (XXX)
```

or

```
INFO:SoC:Converting MEM data width: XXX to YYY via Wishbone
```

In the second case, `XXX` is the LiteDRAM port width, and `YYY` is the CPU's
AXI memory port width. It is highly recommended to use a CPU variant whose
AXI memory port width matches that of LiteDRAM!


***NOTE 2***: The `--load` option on the command line examples below will
have the builder invoke `openocd` to push the bitstream to the board,
assuming the board is connected to a USB port and powered on.

1. LiteX+Rocket on the `digilent_nexys4ddr`:

   ```
   litex-boards/litex_boards/targets/digilent_nexys4ddr.py --build [--load] \
      --cpu-type rocket --cpu-variant linux --sys-clk-freq 50e6 \
      --with-ethernet --with-sdcard
   ```

   This is currently the most well-supported option, with the only "drawback"
   that it relies on a proprietary non-FOSS HDL toolchain (Vivado). The design
   passes timing at 50MHz, and both Ethernet and SDCard booting (and operation
   under Linux) works (with the occasional LiteSDCard read data transfer
   timeout).

   To program the board with a pre-built bitstream file, run:

   ```
   openocd -f litex-boards/litex_boards/prog/openocd_xc7_ft2232.cfg \
           -c 'transport select jtag; init;
               pld load 0 build/digilent_nexys4ddr/gateware/digilent_nexys4ddr.bit; exit'
   ```

2. LiteX+Rocket on the `trellisboard`:

   ```
   litex-boards/litex_boards/targets/trellisboard.py --build [--load] \
      --cpu-type rocket --cpu-variant linuxq --sys-clk-freq 50e6 \
      --with-ethernet --with-sdcard
   ```

   Unlike the `digilent_nexys4ddr`, the built-in SDCard reader on this board
   does not have a card-detect pin, so the SDCard must be inserted when the
   kernel boots, and can't be ejected while the kernel runs.<br>
   There's an option to use an external pmod SDCard reader, which *does* offer
   a card-detect pin. Testing in that configuration is pending.<br>

   To program the board with a pre-built bitstream file, run:

   ```
   openocd -f litex-boards/litex_boards/prog/openocd_trellisboard.cfg \
           -c 'transport select jtag; init;
               svf build/trellisboard/gateware/trellisboard.svf; exit'
   ```

3. Litex+Rocket on the `lambdaconcept_ecpix5`:

   ```
   litex-boards/litex_boards/targets/lambdaconcept_ecpix5.py --build [--load] \
      --cpu-type rocket --cpu-variant linuxd --sys-clk-freq 50e6 \
      --with-ethernet --with-sdcard
   ```

   To program the board with a pre-built bitstream file, run:

   ```
   openocd -f litex-boards/litex_boards/prog/openocd_ecpix5.cfg \
           -c 'transport select jtag; init;
               svf build/lambdaconcept_ecpix5/gateware/lambdaconcept_ecpix5.svf; exit'
   ```

4. LiteX+Rocket on `lattice_versa_ecp5`:

   ```
   litex-boards/litex_boards/targets/lattice_versa_ecp5.py --build [--load] \
      --cpu-type rocket --cpu-variant linuxd --sys-clk-freq 50e6 \
      --with-ethernet [--yosys-nowidelut]
   ```

   Adding the `--yosys-nowidelut` option to the build command line *might*
   result in a slightly tighter packing, possibly at the expense of some of
   the timing budget.

   There is no SDCard reader available on this board. Which is OK, given that
   the 45k sized ECP5 FPGA doesn't have the capacity to support it anyway:
   utilization approaches 99% for the design built using the above command.

   To program the board with a pre-built bitstream file, run:

   ```
   openocd -f litex-boards/litex_boards/prog/openocd_versa_ecp5.cfg \
           -c 'transport select jtag; init;
               svf build/lattice_versa_ecp5/gateware/lattice_versa_ecp5.svf; exit'
   ```

5. LiteX+Rocket on the `digilent_arty`:

   ```
   litex-boards/litex_boards/targets/digilent_arty.py --build [--load] \
      --cpu-type rocket --cpu-variant linuxd --sys-clk-freq 50e6 \
      --with-ethernet --variant=a7-100
   ```

   Relies on a proprietary non-FOSS HDL toolchain (Vivado). The design
   passes timing at 50MHz and Ethernet (and operation under Linux) works.
   The `a7-35` variant is probably too small to fit Rocket.

   To program the board with a pre-built bitstream file use the `--load` option.

## Building the Software (`boot.bin`: BusyBox, Linux, and BBL)

To keep things simple, we embed a BusyBox based initial RAM filesystem
into the Linux kernel, as a cpio archive provided during kernel compilation.
The kernel is subsequently embedded as a payload into BBL, which is then
loaded into RAM by the bare-metal (BIOS) bootloader. BBL also provides FPU
emulation at the machine layer, since none of our FPGAs are large enough
to fit a RocketChip version with a "real" FPU (implemented in gateware).

1. Building BusyBox:

   Using the included [config](conf/busybox-1.31.0-rv64gc.config) file, we
   cross-compile BusyBox as a static binary for the `rv64gc` architecture:

   ```
   curl https://busybox.net/downloads/busybox-1.31.0.tar.bz2 | tar xfj -
   cp conf/busybox-1.31.0-rv64gc.config busybox-1.31.0/.config
   (cd busybox-1.31.0; make CROSS_COMPILE=riscv64-unknown-linux-gnu-)
   ```

2. Creating the `initramfs.cpio` (kernel root RAM filesystem) archive:

   We build a rudimentary root file system layout for Linux, relying
   on `fakeroot` to create device nodes, before packaging it as a `.cpio`
   archive:

   ```
   mkdir initramfs
   pushd initramfs
   mkdir -p bin sbin lib etc dev home proc sys tmp mnt nfs root \
             usr/bin usr/sbin usr/lib
   cp ../busybox-1.31.0/busybox bin/
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
   ```

3. Building the Kernel:

   Using the `initramfs.cpio` root image from earlier, we cross-compile a
   64-bit (RV64GC) kernel with device drivers for our LiteX specific gateware
   devices (N.B., the kernel is unmodified w.r.t. upstream, except for the
   added LiteX gateware drivers):

   ```
   git clone https://github.com/litex-hub/linux.git
   cp initramfs.cpio linux/
   pushd linux
   git checkout litex-rebase
   make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- \
        litex_rocket_defconfig litex_rocket_initramfs.config
   make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu-
   popd
   ```

4. Building BBL (a.k.a. `boot.bin`, a.k.a. the Litex boot image):

   BBL (the somewhat improperly named "Berkely Boot Loader") is in reality a
   machine (M) mode "hypervisor" of sorts, providing trap handlers for things
   like the kernel's hvc/sbi console driver, and FPU emulation. Running in
   supervisor (S) mode, the kernel will trap into the underlying M mode when
   attempting to execute an FP opcode (which is an *illegal* opcode given that
   the actual Rocket CPU lacks a FP unit, which would be too large to fit on
   any of the FPGAs we used up to this point). BBL is configured to emulate
   said FP opcodes, and to restart the kernel once the computation is complete.

   Normally, the Device Tree data structure should be embedded into the BIOS
   built into the bitstream. However, since `litex/tools/litex_json2dts.py`
   doesn't yet know how to dynamically generate a proper Litex+Rocket `.dts`
   file, we provide pre-generated source files that can be embedded into BBL
   during compilation.

   For now, we provide Device Tree source configurations matching all four
   FPGA development boards for which we know how to build a bitsream:
   `digilent_nexys4ddr`, `trellisboard`, `lambdaconcept_ecpix5`,
   `lattice_versa_ecp5` and `digilent_arty`. The example below uses
   [`nexys4ddr.dts`](conf/nexys4ddr.dts), but feel free
   to replace that with [`trellisboard.dts`](conf/trellisboard.dts),
   [`ecpix5.dts`](conf/ecpix5.dts), [`versa_ecp5.dts`](conf/versa_ecp5.dts),
   or [`arty.dts`](conf/arty.dts) as needed:

   ```
   git clone https://github.com/riscv/riscv-pk
   mkdir riscv-pk/build
   pushd riscv-pk/build
   # NOTE: "--with-arch=rv64imac" is what enables BBL's FPU emulation!
   ../configure --host=riscv64-unknown-linux-gnu \
                --with-arch=rv64imac \
                --with-payload=../../linux/vmlinux \
                --with-dts=../../conf/nexys4ddr.dts \
                --enable-logo
   make bbl
   riscv64-unknown-linux-gnu-objcopy -O binary bbl ../../boot.bin
   popd
   ```

   The resulting file `boot.bin` will be the "binary blob" loaded into RAM
   by the bare-metal firmware (BIOS) included with each board's bitstream.

## Starting Linux on Litex+Rocket

To connect to the system's console, use the `screen` utility (assuming
`/dev/ttyUSB1` is used, below):

```
screen /dev/ttyUSB1 115200
```

Each time a board is programmed (directly from the builder if the `--load`
option is given, or directly using `openocd`), and each time a programmed
board is reset, the bare-metal firmware (BIOS) included in the bitstream
will initialize the CPU, RAM, and peripherals, and attempt to load `boot.bin`,
first from the SDCard (first partition, expected to be formatted as msdos/fat),
then via TFTP over the network (expecting a `192.168.1.0/24` network, with
the LiteX+Rocket system using IP address `192.168.1.50`, and attempting to
download `boot.bin` via TFTP from a server at `192.168.1.100`).

1. Booting from microSD card:

   Using any partitioning tool, create a dos partition table and a FAT
   partition on your microSD card, which should look something like this:

   ```
   # fdisk /dev/sdX

   Welcome to fdisk (util-linux 2.35.2).
   Changes will remain in memory only, until you decide to write them.
   Be careful before using the write command.

   Command (m for help): p
   Disk /dev/sdX: 29.74 GiB, 31914983424 bytes, 62333952 sectors
   Disk model: SD/MMC
   Units: sectors of 1 * 512 = 512 bytes
   Sector size (logical/physical): 512 bytes / 512 bytes
   I/O size (minimum/optimal): 512 bytes / 512 bytes
   Disklabel type: dos
   Disk identifier: 0x67f480f9

   Device     Boot   Start      End  Sectors  Size Id Type
   /dev/sdX1          2048  2099199  2097152    1G  6 FAT16
   ...
   ```

   Format the partition, mount it, and copy `boot.bin` to it:

   ```
   mkdosfs /dev/sdX1
   mount /dev/sdX1 /mnt
   cp boot.bin /mnt
   umount /mnt
   ```

   With the microSD card inserted, reset (or program) the board, and
   BBL, then Linux, and, finally, a BusyBox shell should appear on the
   console.

2. Booting from the network:

   Connect the board's Ethernet port to a switch/router port that places it
   into the same Layer-2 broadcast domain (i.e., on the same LAN) as the
   machine acting as your TFTP server. Ensure that `boot.bin` is available
   in the TFTP directory, and that the TFTP server (or socket, if using
   systemd) is started:

   ```
   sudo cp boot.bin /var/lib/tftpboot/
   sudo systemctl start tftp.socket
   ```

   Also make sure your TFTP server responds to requests sent to the IP
   address `192.168.1.100`, by adding that address as a secondary IP to
   your network interface:

   ```
   sudo ip addr add 192.168.1.100/24 scope global dev <interface>
   ```

   (replacing `<interface>` with whatever your relevant network interface is
   actually named).

   Ensure the microSD slot is empty (as it takes precedence over Ethernet
   in the hardcoded BIOS boot order), and program or reset the board. The
   `boot.bin` blob will be copied in over TFTP, and BBL, Linux, and BusyBox's
   shell will be started on the console, in that order.

## Simulation (using Verilator)

   The RocketChip equipped LiteX SoC can be tested using Verilator. However,
   simulation will be (painfully) slow when compared to simulating a 32-bit
   CPU option (e.g., VexRiscV). To avoid waiting (for hours) for `boot.bin`
   to be loaded via TFTP, use `--ram-init boot.bin` to "side-load" the image
   directly into the simulated RAM memory:

   ```
   litex/litex/tools/litex_sim.py --threads 4 --opt-level Ofast \
      --cpu-type rocket --cpu-variant linux \
      --with-ethernet [--ram-init boot.bin]
   ```

   Once the simulation starts, it will attempt its usual boot sequence,
   which includes booting over the serial link, then netbooting over TFTP.
   The latter takes *very* long to time out, so you might want to preempt
   the entire sequence by hitting `Q` or `Esc` when prompted by the bios.

   At the moment, I'm not aware of a good way to tell the firmware/BIOS to
   simply jump to the first RAM address and start executing the side-loaded
   `boot.bin` which is now located there. Although that should be an easy fix.

## Future Work (TODO List)

- Improve LiteSDCard performance
  - LiteSDCard data transfer glitches
  - gpio-based card-detect and/or PMOD (external) SDCard reader for
    `trellisboard`
- update `json2dts.py` to automatically generate device tree source files
  for LiteX+Rocket SoCs.
- port to more FPGA dev. boards (e.g., `digilent_genesys2`,
  `digilent_nexys_video`, etc.)
- improve Linux drivers for LiteX gateware, upstream 64- and 32-bit capable
  drivers into mainline Linux
- ... and much more!

## Paper & Presentation Links

G. L. Somlo, "[Toward a Trustable, Self-Hosting Computer System](https://ieeexplore.ieee.org/document/9283874)", 2020 IEEE Security and Privacy Workshops (SPW), San Francisco, CA, 2020, pp. 136-143

- [Paper PDF](http://www.contrib.andrew.cmu.edu/~somlo/BTCP/glsomlo_cresct_2020.pdf)
- [Slides](http://www.contrib.andrew.cmu.edu/~somlo/BTCP/glsomlo_cresct_2020_slides.pdf)
- [Video](https://youtu.be/5IhujGl_-K0)
