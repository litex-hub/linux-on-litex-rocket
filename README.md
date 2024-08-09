# Linux on LiteX with a RV64GC RocketChip CPU

This repository demonstrates the capability to run 64-bit Linux on a
SoC built with [LiteX](https://github.com/enjoy-digital/litex) and
[RocketChip](https://github.com/chipsalliance/rocket-chip).

![](https://user-images.githubusercontent.com/1450143/102630245-9bac1c80-414c-11eb-92c9-311fd4e06bea.png)

## Prerequisites:

1. Miscellaneous supporting packages, including HDL compiler toolchains,
   most likely available from the repositories of your Linux distribution;
   e.g., on Fedora(40):

   ```text
   sudo dnf install openocd dtc expat-devel fakeroot perl-bignum json-c-devel \
        meson verilator python3-devel python3-setuptools python3-migen \
        python3-pyserial libevent-devel libmpc-devel mpfr-devel \
        yosys trellis nextpnr
   ```

   Some (non-Fedora) Linux distributions may not have packaged versions of
   some of the prerequisites (e.g., `python3-migen`, `yosys`, `trellis`, and
   `nextpnr`), so YMMV.

2. Unpackaged components, including the sources to LiteX and software items:

   **NOTE:** use the included
   [`download_components.sh`](scripts/download_components.sh)
   script to download and install all listed components.

   - [GCC cross-compiler toolchain for 64-bit RISC-V](https://github.com/riscv/riscv-gnu-toolchain).
     The script downloads a ***pre-built*** copy of the toolchain. To build it
     yourself from sources, follow these steps:

     ```text
     git clone --recursive https://github.com/riscv/riscv-gnu-toolchain
     pushd riscv-gnu-toolchain
     ./configure --prefix=$HOME/RISCV --enable-multilib
     make newlib linux
     popd
     ```

     Note that the above process may take several hours to complete.
     Be sure to add `$HOME/RISCV/bin` to your `$PATH` variable.

   - [LiteX](https://github.com/enjoy-digital/litex) (Python) repositories
   - [Linux](https://github.com/litex-hub/linux) kernel with LiteX specific
     out-of-tree drivers
   - [OpenSBI](https://github.com/riscv-software-src/opensbi) firmware
   - [Busybox](https://busybox.net) userspace software

   You may download a VirtualBox
   [pre-built VM](http://mirror.ini.cmu.edu/litex/litexdemo.ova)
   (username: `user`, password: `tartans`), containing all pre-installed
   components with versions (or git commits) tested to build correctly.

3. For Xilinx based FPGA boards, you should also install Vivado (2022.2 is
   known to work with this repository). Installing and configuring Vivado
   is out of scope for this document, but instructions should be readily
   available on the Internet.

## Pre-built Binaries: bitstream, boot images:

Pre-built binaries for the targets described below are available for download
[here](http://mirror.ini.cmu.edu/litex/litex_rocket_busybox_prebuilt.tar.xz)

## Building the Linux kernel and initrd userspace image:

**NOTE:** use the included
[`build_software.sh`](scripts/build_software.sh)
script to build the universal (kernel and userspace) software components.

Both the Linux kernel and initial ram disk image (which, in turn, is based
on the Busybox binary) are independent of the underlying "hardware"
(i.e., ***gateware***) configuration. They are the same whether we configure
a single or multiple RocketChip core(s), whether the FPGA board is using a
Lattice or Xilinx chip, or which peripherals (ethernet, sdcard, sata, etc.)
are present in the design.

## Building the Gateware (FPGA Bitstream):

### Building bitstream for [`lambdaconcept_ecpix5`](https://shop.lambdaconcept.com/home/46-2-ecpix-5.html#/2-ecpix_5_fpga-ecpix_5_85f) (Lattice ECP5 85k):

```text
cd ~/LITEX
litex-boards/litex_boards/targets/lambdaconcept_ecpix5.py --build \
    --cpu-type rocket --cpu-variant linux --cpu-num-cores 1 --cpu-mem-width 2 \
    --sys-clk-freq 50e6 --with-ethernet --with-sdcard \
    --yosys-flow3 --nextpnr-seed $RANDOM
```

The resulting bitstream can be sent to the board using the following command:

```text
openocd -f litex-boards/litex_boards/prog/openocd_ecpix5.cfg \
  -c 'transport select jtag; init; \
      svf build/lambdaconcept_ecpix5/gateware/lambdaconcept_ecpix5.svf; \
      exit'
```

### Building bitstream for `digilent_nexys_video` (Xilinx Artix-7 XC7A200T):

```text
cd ~/LITEX
litex-boards/litex_boards/targets/digilent_nexys_video.py --build \
    --cpu-type rocket --cpu-variant linux --cpu-num-cores 4 --cpu-mem-width 2 \
    --sys-clk-freq 50e6 --with-ethernet --with-sdcard --with-sata --sata-gen 1
```

The resulting bitstream can be sent to the board using the following command:

```text
openocd -f litex-boards/litex_boards/prog/openocd_nexys_video.cfg \
  -c 'transport select jtag; init; \
      pld load 0 build/digilent_nexys_video/gateware/digilent_nexys_video.bit; \
      exit'
```

### Building bitstream for `litex_acorn_baseboard_mini` (Xilinx Artix-7 XC7A200T):

```text
cd ~/LITEX
litex-boards/litex_boards/targets/litex_acorn_baseboard_mini.py --build \
    --cpu-type rocket --cpu-variant linux --cpu-num-cores 4 --cpu-mem-width 2 \
    --sys-clk-freq 75e6 --with-ethernet --with-sata
```

The resulting bitstream can be sent to the board using the following command:

```text
openocd -f litex-boards/litex_boards/prog/openocd_xc7_ft2232.cfg \
 -c 'transport select jtag; init; \
  pld load build/litex_acorn_baseboard_mini/gateware/litex_acorn_baseboard_mini.bit; \
  exit'
```

### A word on the `--cpu-mem-width` argument

Depending on each specific FPGA board, the LiteDRAM memory controller exposes
a port of a width (in bits) of either 64(1), 128(2), 256(4), or 512(8). In
order to avoid relying on LiteX to perform a width conversion between the
Rocket CPU and LiteDRAM, we need to select a pre-compiled Rocket model of
the appropriate width. When applying these instructions to a new (unlisted)
FPGA board, look for output that looks like this:

```text
...
Converting MemBus(...) data width to LiteDRAM(...)
...
```

and adjust the `--cpu-mem-width` value in your build command line accordingly.

## Building the OpenSBI Firmware:

### DT (Device Tree) file specific to your design/bitstream:

The included `*.dts` files (in the [`conf`](conf/) folder) were manually
assembled by combining core-specific parameters from the sample `*.dts`
files provided in `pythondata-cpu-rocket` with register address data
collected during bitstream generation, stored in the resulting `csr.csv`
and `csr.json` files found in `~/LITEX/build/<board-name>/`.

Note that interrupt numbers contained in `csr.*` must be incremented by 1
in the `*.dts` file in order to match the way RocketChip keeps track of
its external IRQ lines. Running `csr.json` through `litex_json2dts_linux.py`
might also help inform this process.

Additionally, information about the size of the initrd image (`initrd_bb`)
is also (loosely) captured in the `*.dts` file.

We use [`lambdaconcept_ecpix5.dts`](conf/lambdaconcept_ecpix5.dts) to
illustrate the process of building the OpenSBI firmware blob (`fw_jump.bin`):

```text
dtc -O dtb ~/linux-on-litex-rocket/conf/lambdaconcept_ecpix5.dts \
    -o /tmp/lambdaconcept_ecpix5.dtb
```

### Building the firmware blob:

We now build the OpenSBI firmware blob (`fw_jump.bin`) with a built-in
device tree binary blob (`*.dtb`) corresponding to our specific bitstream:

```text
cd ~/opensbi
make CROSS_COMPILE=riscv64-unknown-linux-gnu- PLATFORM=generic \
     FW_FDT_PATH=/tmp/lambdaconcept_ecpix5.dtb \
     FW_JUMP_FDT_ADDR=0x82400000
```

The resulting blob will become available as
`~/opensbi/build/platform/generic/firmware/fw_jump.bin`.

## Starting Linux on Litex+Rocket:

### Assembling the boot media:

On either the first, FAT16-formatted partition of an SD card, or in the
top-level directory of your TFTP server (typically `/var/lib/tftpboot`),
collect the following three files:

- `Image`: Linux kernel, from `~/linux/arch/riscv/boot/Image`
- `initrd_bb`: initial ram disk image, from `~/initrd_bb`
- `fw_jump.bin`: OpenSBI firmware with built-in bitstream-specific DT, from
  `~/opensbi/build/platform/generic/firmware/fw_jump.bin`

A fourth file, named `boot.json`, should be created with the following content:

```text
{
    "initrd_bb":   "0x82000000",
    "Image":       "0x80200000",
    "fw_jump.bin": "0x80000000"
}
```

### Booting Linux:

To connect to the system's console, use the `screen` utility to connect to
either `/dev/ttyUSB0` or `/dev/ttyUSB1` (might vary depending on the specific
FPGA board):

```
screen /dev/ttyUSB1 115200
```

Running the corresponding `openocd` command mentioned above (specific to the
bitstream/board being used) should result in the LiteX logo, followed by a
memory initialization and test, and finally a `litex>` boot prompt.

Depending on whether TFTP or a SD card is being used, type either `netboot`
or `sdcardboot` at the `litex>` prompt. This should result in a quick OpenSBI
splash screen, followed by the Linux kernel booting, and finally a shell
prompt from Busybox. Congratulations, you've booted Linux on a RV64GC CPU!

### Booting Fedora:

LiteX/Rocket is capable of running the
[RISC-V port of Fedora](https://fedoraproject.org/wiki/Architectures/RISC-V/Installing).
The process of "adapting" Fedora for booting on LiteX/Rocket is outlined in
the author's [FOSDEM23 talk](https://archive.fosdem.org/2023/schedule/event/rv_selfhosting_all_the_way_down/).

To replicate that process:

- Obtain a 32GB sized SD card
- Download and unpack the pre-made SD card image:

  ```text
  curl http://mirror.ini.cmu.edu/litex/litex_rocket_fedora_prebuilt.tar.xz \
       | tar xfJ -
  ```

- Write the disk image to the physical SD card (available as `/dev/sdX`):

  ```text
  dd if=litex_rocket_fedora_prebuilt/sdcard.bin of=/dev/sdX bs=8M oflag=direct
  ```

  This should be enough to boot Fedora on the ecpix5 board. For a different
  board (e.g., nexys-video), the following steps show how to replace the
  OpenSBI firmware blob.

- Replicate the process of building `fw_jump.bin` using one of the Fedora
  specific `*_fedora.dts` files shipped in the [conf](conf/) folder

- Eject and re-insert the SD card, then mount its first (FAT16) partition and
  copy the new OpenSBI firmware blob to it:

  ```text
  mount /dev/sdX /mnt
  cp ~/opensbi/build/platform/generic/firmware/fw_jump.bin /mnt/fw_jump.fed
  umount /mnt
  ```

- Insert the SD card into your ecpix5 or nexys-video board, program the board
  with your bitstream file (using `openocd` as shown above), then boot from
  the SD card:

  ```text
  litex> sdcardboot
  ```
