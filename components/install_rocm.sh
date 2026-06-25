#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

#move to rocm package
rocm_metadata=$(get_component_config "rocm")
rocm_version=$(jq -r '.version' <<< $rocm_metadata)
rocm_url=$(jq -r '.url' <<< $rocm_metadata)
rocm_sha256=$(jq -r '.sha256' <<< $rocm_metadata)
DEBPACKAGE=$(basename ${rocm_url})

patch_amdgpu_dkms(){
    local patch_file=${COMPONENT_DIR}/amdgpu-dkms-mi300x-xgmi-legacy-fallback.patch
    local work_dir=${AMDGPU_DKMS_PATCH_WORK_DIR:-/tmp/azhpc-amdgpu-dkms}
    local patch_suffix=${AMDGPU_DKMS_PATCH_SUFFIX:-azhpc1}
    local orig_deb src_dir orig_version new_version patched_deb

    if [[ ! -f "${patch_file}" ]]; then
        echo "Missing amdgpu-dkms patch: ${patch_file}" >&2
        exit 1
    fi

    rm -rf "${work_dir}"
    mkdir -p "${work_dir}"
    pushd "${work_dir}" >/dev/null

    apt-get download amdgpu-dkms >&2
    orig_deb=$(find . -maxdepth 1 -type f -name 'amdgpu-dkms_*.deb' | head -n 1)
    if [[ -z "${orig_deb}" ]]; then
        echo "Failed to download amdgpu-dkms package" >&2
        exit 1
    fi

    dpkg-deb -R "${orig_deb}" pkg
    src_dir=$(find pkg/usr/src -maxdepth 1 -type d -name 'amdgpu-*' | head -n 1)
    if [[ -z "${src_dir}" ]]; then
        echo "Unable to find amdgpu DKMS source tree in ${orig_deb}" >&2
        exit 1
    fi

    patch --dry-run -d "${src_dir}" -p1 < "${patch_file}" >&2
    patch -d "${src_dir}" -p1 < "${patch_file}" >&2

    orig_version=$(dpkg-deb -f "${orig_deb}" Version)
    new_version="${orig_version}+${patch_suffix}"
    sed -i "s/^Version: .*/Version: ${new_version}/" pkg/DEBIAN/control

    if [[ -f pkg/DEBIAN/md5sums ]]; then
        pushd pkg >/dev/null
        find usr -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums
        popd >/dev/null
    fi

    patched_deb="${work_dir}/amdgpu-dkms_${new_version#*:}_all.deb"
    dpkg-deb -b pkg "${patched_deb}" >&2
    ln -sf "$(basename "${patched_deb}")" "${work_dir}/amdgpu-dkms-patched.deb"

    echo "Built patched amdgpu-dkms package: ${patched_deb}" >&2
    popd >/dev/null
    echo "${work_dir}/amdgpu-dkms-patched.deb"
}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    if [[ $DISTRIBUTION == "ubuntu24.04" ]]; then
        # ROCm 6.4 depends on mivisionx-dev which depends on libopencv-dev which depends on libopenmpi3t64 which depends on libucx0, which is a Ubuntu upstream UCX that
        # is older than and conflicts with the ucx package installed by doca-ofed and has unknown IB support status.
        # We install this marker package to indicate to the package manager that ucx provides libucx0 so that ROCm can be installed.
        # TODO: make sure a UCX that actually has proper IB, GDR and ROCm support is being used
        # See https://askubuntu.com/a/218294/595565
        apt install -y equivs
        ucx_version=$(dpkg -s ucx | grep Version | awk '{print $2}')
        cat <<EOF > /tmp/ucx-provides-libucx0
Section: misc
Priority: optional
Homepage: https://github.com/Azure/azhpc-images
Standards-Version: 3.9.2

Package: ucx-provides-libucx0
Depends: ucx
Provides: libucx0 (= ${ucx_version})
Version: ${ucx_version}
Maintainer: Azure HPC Platform team <hpcplat@microsoft.com>
Description: marker package in Azure HPC Image to work around ROCm dependency issue
EOF
        equivs-build /tmp/ucx-provides-libucx0
        dpkg -i ucx-provides-libucx0_${ucx_version}_all.deb
        rm -f ucx-provides-libucx0_${ucx_version}_all.deb
        rm -f /tmp/ucx-provides-libucx0
    fi
    download_and_verify ${rocm_url} ${rocm_sha256}
    apt install -y ./${DEBPACKAGE}
    if [[ $DISTRIBUTION == "ubuntu24.04" ]]; then
        apt update
        apt install -y patch python3-setuptools python3-wheel
        patched_amdgpu_dkms_deb=$(patch_amdgpu_dkms)
        apt install -y "${patched_amdgpu_dkms_deb}" rocm
        apt-mark hold amdgpu-dkms
        # ROCm bundles RCCL
        write_component_version "RCCL" $(dpkg-query -W -f='${Version}' rccl)
    else
        amdgpu-install -y --usecase=graphics,rocm
    fi
    apt install -y rocm-bandwidth-test
    rm -f ./${DEBPACKAGE}
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    tdnf install -y azurelinux-repos-amd
    tdnf -y install kernel-drivers-gpu-$(uname -r)
    tdnf -y install amdgpu amdgpu-firmware amdgpu-headers

    # Add Azure Linux 3 ROCM repo file
    cat <<EOF >> /etc/yum.repos.d/amd_rocm.repo
[amd_rocm]
name="AMD ROCM packages repo for Azure Linux 3.0"
baseurl=https://repo.radeon.com/rocm/azurelinux3/${rocm_version}/main/
enabled=1
repo_gpgcheck=0
gpgcheck=0
sslverify=0
EOF

    tdnf repolist --refresh
    tdnf install -y rocm-dev rocm-validation-suite rocm-bandwidth-test
    tdnf install -y rocm-smi-lib rocm-core rocm-device-libs rocm-llvm rocm-validation-suite
    tdnf install -y rocm-bandwidth-test
fi

#Grant access to GPUs to all users via udev rules
cat <<'EOF' > /etc/udev/rules.d/99-amdgpu-permissive.rules
KERNEL=="kfd", MODE="0666"
SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0666"
EOF
udevadm control --reload-rules && sudo udevadm trigger

write_component_version "ROCM" ${rocm_version}

if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    echo blacklist amdgpu | tee -a /etc/modprobe.d/blacklist.conf
    update-initramfs -c -k $(uname -r)
fi

#1002:740c is Mi200
#1002:74b5 is Mi300x
#1002:74bd is Mi300HF
echo "Writing gpu mode probe in init.d"
cat <<'EOF' > /tmp/tempinit.sh
#!/bin/sh
at_count=0
while [ $at_count -le 90 ]
do
    if [ $(lspci -d 1002:74b5 | wc -l) -eq 8 -o $(lspci -d 1002:74bd | wc -l) -eq 8 -o $(lspci -d 1002:740c | wc -l) -eq 16 ]; then
       echo Required number of GPUs found
       at_count=91
       sleep 120s
       echo doing Modprobe for amdgpu
       if [ $(lspci -d 1002:740c | wc -l) -eq 16 ]; then
          sudo modprobe amdgpu
       else
          sudo modprobe -r hyperv_drm
          sudo modprobe amdgpu ip_block_mask=0x7f
       fi
    else
       sleep 10
       at_count=$(($at_count + 1))
    fi
done

exit 0
EOF
cp /tmp/tempinit.sh /etc/init.d/initamdgpu.sh
chmod +x /etc/init.d/initamdgpu.sh
rm /tmp/tempinit.sh

echo "Completed gpu mode probe in init.d"

echo -e '[Unit]\n\nDescription=Runs /etc/init.d/initamdgpu.sh\n\n' \
               | tee rocmstartup.service
echo -e '[Service]\n\nExecStart=/etc/init.d/initamdgpu.sh\n\n' \
               | tee -a rocmstartup.service
echo -e '[Install]\n\nWantedBy=multi-user.target' \
               | tee -a rocmstartup.service

mv rocmstartup.service /etc/systemd/system/rocmstartup.service
systemctl start rocmstartup
systemctl enable rocmstartup
