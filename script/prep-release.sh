#!/bin/bash
# prep release for upload to production container

set -e

# make ipxe directory to store ipxe disks
mkdir -p build/ipxe

# pull down upstream iPXE
git clone --depth 1 https://github.com/ipxe/ipxe.git ipxe_build

# copy iPXE config overrides into source tree
cp ipxe/local/* ipxe_build/src/config/local/

# copy certs into source tree
cp script/*.crt ipxe_build/src/

# build iPXE disks
cd ipxe_build/src

# get current iPXE hash
IPXE_HASH=`git log -n 1 --pretty=format:"%H"`

# generate d9pxe iPXE disks
make bin/ipxe.dsk bin/ipxe.iso bin/ipxe.lkrn bin/ipxe.usb bin/ipxe.kpxe bin/undionly.kpxe \
EMBED=../../ipxe/disks/d9pxe TRUST=ca-ipxe-org.crt
mv bin/ipxe.dsk ../../build/ipxe/d9pxe.dsk
mv bin/ipxe.iso ../../build/ipxe/d9pxe.iso
mv bin/ipxe.lkrn ../../build/ipxe/d9pxe.lkrn
mv bin/ipxe.usb ../../build/ipxe/d9pxe.usb
mv bin/ipxe.kpxe ../../build/ipxe/d9pxe.kpxe
mv bin/undionly.kpxe ../../build/ipxe/d9pxe-undionly.kpxe

# generate d9pxe iPXE disk for Google Compute Engine
make bin/ipxe.usb CONFIG=cloud EMBED=../../ipxe/disks/d9pxe-gce \
TRUST=ca-ipxe-org.crt
cp -f bin/ipxe.usb disk.raw
tar Sczvf d9pxe-gce.tar.gz disk.raw
mv d9pxe-gce.tar.gz ../../build/ipxe/d9pxe-gce.tar.gz

# generate d9pxe-packet iPXE disk
make bin/undionly.kpxe \
EMBED=../../ipxe/disks/d9pxe-packet TRUST=ca-ipxe-org.crt
mv bin/undionly.kpxe ../../build/ipxe/d9pxe-packet.kpxe

# generate EFI iPXE disks
cp config/local/general.h.efi config/local/general.h
make clean
make bin-x86_64-efi/ipxe.efi \
EMBED=../../ipxe/disks/d9pxe TRUST=ca-ipxe-org.crt
mkdir -p efi_tmp/EFI/BOOT/
cp bin-x86_64-efi/ipxe.efi efi_tmp/EFI/BOOT/bootx64.efi
genisoimage -o ipxe.eiso efi_tmp
mv bin-x86_64-efi/ipxe.efi ../../build/ipxe/d9pxe.efi
mv ipxe.eiso ../../build/ipxe/d9pxe-efi.iso

# generate EFI arm64 iPXE disk
make clean
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 \
EMBED=../../ipxe/disks/d9pxe TRUST=ca-ipxe-org.crt \
bin-arm64-efi/snp.efi
mv bin-arm64-efi/snp.efi ../../build/ipxe/d9pxe-arm64.efi

# generate d9pxe-packet-arm64 iPXE disk
make clean
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 \
EMBED=../../ipxe/disks/d9pxe-packet TRUST=ca-ipxe-org.crt \
bin-arm64-efi/snp.efi
mv bin-arm64-efi/snp.efi ../../build/ipxe/d9pxe-packet-arm64.efi

# generate arm64 experimental
cp config/local/nap.h.efi config/local/nap.h
cp config/local/usb.h.efi config/local/usb.h
make clean
make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 \
EMBED=../../ipxe/disks/d9pxe TRUST=ca-ipxe-org.crt \
bin-arm64-efi/snp.efi
mv bin-arm64-efi/snp.efi ../../build/ipxe/d9pxe-arm64-experimental.efi

# return to root
cd ../..

# generate header for sha256-checksums file
cd build/
CURRENT_TIME=`date`
cat > d9pxe-sha256-checksums.txt <<EOF
# d9pxe bootloaders generated at $CURRENT_TIME
# iPXE Commit: https://github.com/ipxe/ipxe/commit/$IPXE_HASH
# Travis-CI Job: https://travis-ci.org/antonym/d9pxe/builds/$TRAVIS_BUILD_ID

EOF

# generate sha256sums for iPXE disks
cd ipxe/
for ipxe_disk in `ls .`
do
  sha256sum $ipxe_disk >> ../d9pxe-sha256-checksums.txt
done
cat ../d9pxe-sha256-checksums.txt
mv ../d9pxe-sha256-checksums.txt .
cd ../..

# generate signatures for d9pxe source files
mkdir sigs
for src_file in `ls src`
do
  openssl cms -sign -binary -noattr -in src/$src_file \
  -signer script/codesign.crt -inkey script/codesign.key -certfile script/d9pxe.crt -outform DER \
  -out sigs/$src_file.sig
  echo Generated signature for $src_file...
done
mv sigs src/

# delete index.html so that we don't overwrite existing content type
rm src/index.html

# copy iPXE src code into build directory
cp -R src/* build/
