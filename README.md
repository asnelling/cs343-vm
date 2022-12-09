# CS 343 Homeworks Virtual Machine

This Virtual Machine is built for running all homework assignments in [Risto
Miikkulainen][risto]'s [CS 343 Artificial Intelligence][cs343] course at the
University of Texas at Austin. It uses [QEMU][qemu], which students may be
familiar with from [Alison Norman][norman]'s [CS 439 Principles of Computer
Systems][cs439], and theoretically can run on Windows, macOS, and Linux at
near-native performance.

The VM may also run in VirtualBox, Hyper-V, and other virtualization front-ends
by importing the root disk image, `disk.img`.

## Requirements

-   [OVMF Firmware][ovmf] for UEFI booting

    The **Building the Virtual Machine** section shows how to download the
    required images from the Ubuntu package repository.

-   [QEMU][qemu]

-   Platform specific hardware virtualization enabled and configured

-   The VM boot disk: `disk.img`. Refer to **Building the Virtual Machine** for
    instructions to build this.

## Booting the Virtual Machine

Use the appropriate command below for your platform.

**Default User**: cs343

**Password**: aihacker

### Boot On Linux

```Shell
$ qemu-system-x86_64 \
      -machine accel=kvm,type=q35 \
      -cpu host -nographic \
      -m 4G -smp 2 \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::8000-:8000 \
      -drive if=virtio,format=qcow2,file=disk.img \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_CODE.fd \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_VARS.fd \
      -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0
```

Use `sudo poweroff` or `CTRL+a x` to shutdown the virtual machine.

### Boot on macOS

Special considerations for macOS:

-   Use the [Apple Hypervisor Framework][hvf] for near-native performance.
-   disable **Huge Pages**, which macOS does not support

```Shell
$ qemu-system-x86_64 \
      -machine accel=hvf,type=q35 \
      -cpu host,-pdpe1gb -nographic \
      -m 4G -smp 2 \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::8000-:8000 \
      -drive if=virtio,format=qcow2,file=disk.img \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_CODE.fd \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_VARS.fd \
      -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0
```

### Boot on Windows

Note: This configuration uses Intel HAXM for hardware accelerated graphics,
which I have been unsuccessful in booting on multiple CPU cores. Regardless, the
Windows Hypervisor Platform (WHPX) should yield better performance, but my
attempts to use it are unsuccessful.

See differences between
[HAXM and WHPX](https://learn.microsoft.com/en-us/xamarin/android/get-started/installation/android-emulator/hardware-acceleration).

Install Intel HAXM. Instructions at the bottom of
[this page](https://learn.microsoft.com/en-us/xamarin/android/get-started/installation/android-emulator/hardware-acceleration).

To try booting with `N` CPU cores allocated from the host, append the command
with `-smp N`.

To try with WHPX, replace `accel=hax` with `accel=whpx`.

```Shell
$ qemu-system-x86_64 \
      -machine accel=hax,type=q35 \
      -m 4G -nographic \
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::8022-:22,hostfwd=tcp::8000-:8000 \
      -drive if=virtio,format=qcow2,file=disk.img \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_CODE.fd \
      -drive if=pflash,format=raw,readonly=on,file=OVMF_VARS.fd \
      -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0
```

Use `sudo poweroff` or `CTRL+a x` to shutdown the virtual machine.

## Usage

To run OpenNERO, NERO 2.0, and other GUI apps, the host must forward an X
session to the VM for graphics rendering. Users on Linux hosts can simply use
the `-X` flag when connecting to the VM with SSH. Users on Windows and macOS
hosts should use [Xpra][]. Commands for both are provided for both OpenNERO and
NERO 2.0 below.

### Run OpenNERO

From a Linux host using X Forwarding:

```Shell
$ ssh -Y -p 8022 cs343@localhost
$ cd /opt/OpenNERO
$ ./OpenNERO
```

From a Windows or macOS host using [Xpra][]:

```Shell
$ xpra start ssh://cs343@localhost:8022 \
      --chdir=/opt/OpenNERO \
      --start=./OpenNERO
```

### Run NERO 2.0

From a Linux host using X Forwarding:

```Shell
$ ssh -Y -p 8022 cs343@localhost
$ cd /opt/nero2
$ ./nero.bin
```

From a Windows or macOS host using [Xpra][]:

```Shell
$ xpra start ssh://cs343@localhost:8022 \
      --chdir=/opt/nero2 \
      --start=./nero.bin
```

### Open a Jupyter Notebook

A JupyterHub server running in the VM is available from the host at
[http://localhost:8000](http://localhost:8000). Login using system user
credentials, such as the default **cs343** user account.mozil

## Building the Virtual Machine

1.  Download the latest Ubuntu cloud disk image.

    ```Shell
    $ wget -O disk.img https://cloud-images.ubuntu.com/releases/jammy/release/ubuntu-22.04-server-cloudimg-amd64.img
    ```

2.  Allocate free space to the image, which will expand up to the allocated size
    as needed.

    ```Shell
    $ qemu-img resize disk.img 20G
    ```

3.  Download virtual device firmware.

    ```Shell
    $ curl -sSfL https://mirrors.kernel.org/ubuntu/pool/main/e/edk2/ovmf_2022.05-4_all.deb \
          | bsdtar -Ox -f - data.tar.zst \
          | bsdtar --strip-components=4 -xf - usr/share/OVMF/OVMF_{CODE,VARS}.fd
    ```

4.  Review cloud-init configs and make changes a needed in the following YAML
    files:

    -   `meta-data`
    -   `user-data`

5.  Create the cloud-init seed image.

    ```Shell
    $ mkisofs -output cloud-init.seed.img -volid cidata -joliet -rock user-data meta-data
    ```

6.  Provision the virtual machine.

    On the first boot, we seed the VM using the [cloud-init][] configuration
    stored in cloud-init.seed.img. This will install all the necessary packages,
    create the initial user account, and enable an SSH daemone listening on host
    port 8022. This will take several minutes, and the virtual machine may
    reboot.

    Provisioning is complete when you see a line with:

    ```
    Cloud-init v. 22.3.4-0ubuntu1~22.04.1 finished at ...
    ```

    You may now power down the virtual machine with the `sudo poweroff` command
    or by pressing `CTRL+a x`. Subsequent boots do not need
    `cloud-init.seed.img`.

    Use the appropriate **Booting On** section above with the following argument
    appended to provision the virtual machine. Once provisioned, the argument
    may be omitted.

    ```Shell
    -drive if=virtio,format=raw,file=cloud-init.seed.img
    ```

[risto]: https://www.cs.utexas.edu/~risto/
[cs343]: https://www.cs.utexas.edu/~risto/cs343/
[qemu]: https://www.qemu.org/
[cloud-init]: https://github.com/canonical/cloud-init
[hvf]: https://developer.apple.com/documentation/hypervisor
[xpra]: https://xpra.org/
[norman]: https://www.cs.utexas.edu/~ans/
[cs439]: https://www.cs.utexas.edu/~ans/classes/cs439/
[ovmf]: https://www.tianocore.org/
