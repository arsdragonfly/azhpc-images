#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install the "Microsoft TLS RSA Root G2" trust anchor before any HTTPS
# calls to Microsoft endpoints.
$COMPONENT_DIR/install_microsoft_tls_root_g2.sh

# The legacy TDNF repo metadata plugin uses root's per-user GnuPG keyring,
# which is removed when the image is deprovisioned. Disable only this plugin;
# DNF and RPM package signature checks remain enabled.
tdnf_repogpgcheck_config=/etc/tdnf/pluginconf.d/tdnfrepogpgcheck.conf
if [[ -f "$tdnf_repogpgcheck_config" ]]; then
    sed -i 's/^enabled=.*/enabled=0/' "$tdnf_repogpgcheck_config"
fi

# Install Kernel dependencies
if [ "$ARCHITECTURE" = "aarch64" ]; then
    kernel_pkgs=(
        "kernel-hwe-devel-$(uname -r)"
        "kernel-headers"
    )
    if azl_uses_pmc_drivers; then
        kernel_pkgs+=("kernel-hwe-drivers-gpu-$(uname -r)")
    fi
    dnf install -y "${kernel_pkgs[@]}"
else
    kernel_pkgs=(
        "kernel-headers-$(uname -r)"
        "kernel-devel-$(uname -r)"
    )
    if azl_uses_pmc_drivers; then
        kernel_pkgs+=("kernel-drivers-gpu-$(uname -r)" "dkms")
    fi
    dnf install -y "${kernel_pkgs[@]}"
fi

# Install Python 3.12
dnf install -y python

# install pssh
dnf install -y pssh

# tk package is present in extended repo
dnf install -y azurelinux-repos-extended

dnf repolist --refresh

# Install pre-reqs and development tools
# dnf groupinstall -y "Development Tools"
dnf install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    python3-devel \
    python3-setuptools \
    python3-pip \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    glibc-devel \
    libudev-devel \
    binutils \
    binutils-devel \
    munge \
    pam-devel \
    ed \
    selinux-policy-devel \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    bison \
    libnl3-devel \
    libsecret \
    rpm-build \
    rpmdevtools \
    environment-modules \
    make \
    check \
    check-devel \
    lsof \
    azurelinux-rpm-macros \
    autoconf \
    automake \
    flex \
    gcc-c++ \
    libmnl-devel \
    mokutil \
    openssl-devel \
    pciutils-devel \
    tcsh \
    gcc-gfortran \
    perl \
    json-c-devel \
    pciutils \
    dnf-plugins-core \
    vim \
    nano \
    device-mapper-multipath \
    mdadm \
    ca-certificates-tools \
    git \
    gtest-devel \
    gmock-devel \
    hwloc-devel \
    rsyslog \
    dos2unix \
    azcopy

# Enable kernel log messages to file as per HPC requirement.
sed -i 's/^\#kern\.\*.*/kern\.\*                                \-\/var\/log\/kern.log/' /etc/rsyslog.conf
# Add kern.log from rsyslog to logrotate
sed -i 's#/var/log/maillog#/var/log/maillog\n/var/log/kern.log#' /etc/logrotate.d/rsyslog

## Install dkms
if is_azl_dkms_enabled; then
    if grep -q '\<lockdown=integrity\>' /etc/default/grub; then
        sed -i -E 's/\<lockdown=integrity\>[[:space:]]*//g' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
    $COMPONENT_DIR/install_cuda_repo_and_dkms.sh
    if sku_uses_ipoib; then
        echo ib_ipoib | tee /etc/modules-load.d/ib_ipoib.conf
    fi
    echo ib_umad | tee /etc/modules-load.d/ib_umad.conf
else
    dnf install -y dkms
fi

## Install subunit and subunit-devel
dnf install -y subunit
dnf install -y subunit-devel

## Install libmd and libmd-devel 
dnf install -y libmd
dnf install -y libmd-devel

# Install azure-vm-utils from source (upstream package for AZL3 is too outdated right now, see https://github.com/microsoft/azurelinux/issues/15661)
git clone --depth 1 https://github.com/Azure/azure-vm-utils.git /tmp/azure-vm-utils
pushd /tmp/azure-vm-utils
mkdir build && cd build
cmake -DENABLE_TESTS=0 ..
make
make install
popd
rm -rf /tmp/azure-vm-utils

# copy kvp client file
$COMPONENT_DIR/copy_kvp_client.sh

# copy torset tool
$COMPONENT_DIR/copy_torset_tool.sh

# Create alias for "ls -l"
echo "alias ll='ls -l'" | tee -a /etc/bash.bashrc

