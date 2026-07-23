#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

nvidia_metadata=$(get_component_config "nvidia")

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Ubuntu 26.04 pins NVIDIA's generic package to the exact Canonical driver
    # version; other Ubuntu releases use the repository's selected version.
    NVIDIA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $nvidia_metadata)
    NVIDIA_DRIVER_MAJOR=$(echo $NVIDIA_DRIVER_VERSION | cut -d '.' -f1)

    if [[ $NVIDIA_DRIVER_MAJOR -ge 580 ]]; then
        PACKAGE_NAME="nvidia-fabricmanager"
    else
        PACKAGE_NAME="nvidia-fabricmanager-${NVIDIA_DRIVER_MAJOR}"
    fi

    if [[ "$DISTRIBUTION" == "ubuntu26.04" ]]; then
        NVIDIA_FABRICMANAGER_VERSION=$(apt-cache madison "$PACKAGE_NAME" \
            | awk -v version="$NVIDIA_DRIVER_VERSION" '$3 ~ ("^" version "-") {print $3; exit}')
        if [[ -z "$NVIDIA_FABRICMANAGER_VERSION" ]]; then
            echo "ERROR: no $PACKAGE_NAME package matches NVIDIA driver $NVIDIA_DRIVER_VERSION" >&2
            exit 1
        fi
        apt install -y "${PACKAGE_NAME}=${NVIDIA_FABRICMANAGER_VERSION}"
    else
        apt install -y ${PACKAGE_NAME}
    fi

    # Read back installed version for the component manifest
    NVIDIA_FABRICMANAGER_VERSION=$(dpkg-query -W -f='${Version}' ${PACKAGE_NAME})
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    # The NVIDIA CUDA repo (cuda-azl3) ships nvidia-fabricmanager and
    # libnvidia-nscq packages that Provide/Obsolete the identically-named PMC
    # packages, often at a newer version than the Microsoft 1P-signed driver
    # installed from PMC.  The driver kmod and fabric manager versions must
    # match exactly, so exclude the CUDA repo copies and let tdnf resolve to
    # the PMC-sourced packages whose versions track the 1P-signed driver.
    echo "exclude=nvidia-fabricmanager* nvidia-fabric-manager* libnvidia-nscq*" >> /etc/yum.repos.d/cuda-azl3.repo

    # tdnf does not respect exclude= directive of repo config
    dnf install -y nvidia-fabric-manager \
                   nvidia-fabric-manager-devel \
                   libnvidia-nscq
    NVIDIA_FABRICMANAGER_VERSION=$(sudo tdnf list installed | grep -i nvidia-fabric-manager.x86_64 | sed 's/.*[[:space:]]\([0-9.]*-[0-9]*\)\..*/\1/')
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    nvidia_fabricmanager_metadata=$(jq -r '.fabricmanager' <<< $nvidia_metadata)
    NVIDIA_FABRICMANAGER_DISTRIBUTION=$(jq -r '.distribution' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_VERSION=$(jq -r '.version' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_SHA256=$(jq -r '.sha256' <<< $nvidia_fabricmanager_metadata)
    NVIDIA_FABRICMANAGER_PREFIX=$(echo $NVIDIA_FABRICMANAGER_VERSION | cut -d '.' -f1)

    # For NVIDIA Fabric Manager major version 580, Nvidia dropped the hyphen between fabric and manager
    if [[ $NVIDIA_FABRICMANAGER_PREFIX -ge 580 ]]; then
        PACKAGE_NAME="nvidia-fabricmanager"
    else
        PACKAGE_NAME="nvidia-fabric-manager"
    fi
    NVIDIA_FABRIC_MNGR_PKG=https://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_FABRICMANAGER_DISTRIBUTION}/x86_64/${PACKAGE_NAME}-${NVIDIA_FABRICMANAGER_VERSION}.x86_64.rpm
    FILENAME=$(basename $NVIDIA_FABRIC_MNGR_PKG)
    download_and_verify ${NVIDIA_FABRIC_MNGR_PKG} ${NVIDIA_FABRICMANAGER_SHA256}
    
    yum install -y ./${FILENAME}

    # Prevent package from being updated after installation
    dnf_pin_packages "${PACKAGE_NAME}"
fi
write_component_version "NVIDIA_FABRIC_MANAGER" ${NVIDIA_FABRICMANAGER_VERSION}
