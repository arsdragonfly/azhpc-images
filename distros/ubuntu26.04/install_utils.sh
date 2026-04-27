#!/bin/bash
set -ex

# Setup microsoft packages repository
# Best-effort: Microsoft may not yet publish a packages-microsoft-prod.deb for
# Ubuntu 26.04. If that's the case, fall back to the 24.04 (noble) repo configuration
# so that PMC-backed components (azcopy, slurm, amlfs, etc.) still resolve.
if curl -fsSL -o packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb; then
    dpkg -i packages-microsoft-prod.deb
elif curl -fsSL -o packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb; then
    echo "##[warning]Microsoft PMC repo not yet available for Ubuntu 26.04; falling back to 24.04 (noble) repo definition"
    dpkg -i packages-microsoft-prod.deb
else
    echo "##[warning]Could not install packages-microsoft-prod.deb; continuing without Microsoft PMC repo"
fi
rm -f packages-microsoft-prod.deb

apt-get update || true
apt-get -y install build-essential
apt-get -y install numactl \
                   rpm \
                   libnuma-dev \
                   libmpc-dev \
                   libmpfr-dev \
                   libxml2-dev \
                   m4 \
                   byacc \
                   tcl \
                   environment-modules \
                   tk \
                   texinfo \
                   libudev-dev \
                   binutils \
                   binutils-dev \
                   selinux-policy-dev \
                   flex \
                   libnl-3-dev \
                   libnl-route-3-dev \
                   libnl-3-200 \
                   libnl-genl-3-dev \
                   libnl-genl-3-200 \
                   bison \
                   libnl-route-3-200 \
                   gfortran \
                   cmake \
                   libnl-3-dev \
                   libnl-route-3-dev \
                   net-tools \
                   libsecret-1-0 \
                   python3 \
                   python3-pip \
                   python3-setuptools \
                   dkms \
                   jq \
                   curl \
                   libyaml-dev \
                   libreadline-dev \
                   libkeyutils1 \
                   libkeyutils-dev \
                   libmount-dev \
                   nfs-common \
                   pssh \
                   dos2unix

# azcopy comes from the Microsoft PMC repo; install best-effort so missing PMC support
# on a fresh distro doesn't break the rest of the build.
apt-get -y install azcopy || echo "##[warning]Failed to install azcopy (PMC may not yet have Ubuntu 26.04 support); continuing"

echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf
echo ib_umad | sudo tee /etc/modules-load.d/ib_umad.conf

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh

# Set default shell for newly created users (somehow bash is no longer the default in Canonical's Noble image for Azure)
sed -i 's|^SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd
