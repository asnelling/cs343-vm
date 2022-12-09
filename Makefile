CLOUDIMG = ubuntu-22.04-server-cloudimg-amd64.img
FORWARD_PORTS = \
	hostfwd=tcp::8022-:22 \
	hostfwd=tcp::8000-:8000 \
	hostfwd=tcp::14500-:14500

.PHONY: all
all: build/cloud-init.seed.img build/OVMF_CODE.fd build/OVMF_VARS.fd build/disk.img

build/$(CLOUDIMG):
	wget -P build https://cloud-images.ubuntu.com/releases/jammy/release/$(CLOUDIMG)

build/disk.img: build/$(CLOUDIMG)
	qemu-img create -f qcow2 -F qcow2 -b $(CLOUDIMG) $@ 20G

build/disk.vhdx: build/$(CLOUDIMG)
	qemu-img convert -O vhdx build/$(CLOUDIMG) build/disk.vhdx

build/OVMF_CODE.fd build/OVMF_VARS.fd&:
	mkdir -p build
	curl -sSfL https://mirrors.kernel.org/ubuntu/pool/main/e/edk2/ovmf_2022.05-4_all.deb \
		| bsdtar -Ox -f - data.tar.zst \
		| bsdtar -C build --strip-components=4 -xf - usr/share/OVMF/OVMF_{CODE,VARS}.fd

build/cloud-init.seed.img: meta-data user-data
	mkdir -p build
	mkisofs -output build/cloud-init.seed.img -volid cidata -joliet -rock user-data meta-data

.PHONY: start
start: comma := ,
start: space := $  $ 
start: hostfwd = $(subst $(space),$(comma),$(FORWARD_PORTS))
start: build/cloud-init.seed.img build/OVMF_CODE.fd build/OVMF_VARS.fd build/disk.img
	qemu-system-x86_64 \
        -machine accel=kvm,type=q35 \
        -cpu host -nographic \
        -m 4G -smp 2 \
        -device virtio-net-pci,netdev=net0 \
        -netdev user,id=net0,$(hostfwd) \
        -drive if=virtio,format=qcow2,file=build/disk.img \
        -drive if=virtio,format=raw,file=build/cloud-init.seed.img \
        -drive if=pflash,format=raw,readonly=on,file=build/OVMF_CODE.fd \
        -drive if=pflash,format=raw,readonly=on,file=build/OVMF_VARS.fd \
        -object rng-random,id=rng0,filename=/dev/urandom -device virtio-rng-pci,rng=rng0

.PHONY: clean
clean:
	rm build/disk.img build/cloud-init.seed.img
