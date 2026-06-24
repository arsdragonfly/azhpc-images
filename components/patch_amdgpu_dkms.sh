#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PATCH_FILE=${SCRIPT_DIR}/amdgpu-dkms-mi300x-xgmi-legacy-fallback.patch
WORK_DIR=${AMDGPU_DKMS_PATCH_WORK_DIR:-/tmp/azhpc-amdgpu-dkms}
PATCH_SUFFIX=${AMDGPU_DKMS_PATCH_SUFFIX:-azhpc1}

if [[ ! -f "${PATCH_FILE}" ]]; then
    echo "Missing amdgpu-dkms patch: ${PATCH_FILE}" >&2
    exit 1
fi

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
pushd "${WORK_DIR}"

apt-get download amdgpu-dkms
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

patch --dry-run -d "${src_dir}" -p1 < "${PATCH_FILE}"
patch -d "${src_dir}" -p1 < "${PATCH_FILE}"

orig_version=$(dpkg-deb -f "${orig_deb}" Version)
new_version="${orig_version}+${PATCH_SUFFIX}"
sed -i "s/^Version: .*/Version: ${new_version}/" pkg/DEBIAN/control

if [[ -f pkg/DEBIAN/md5sums ]]; then
    pushd pkg
    find usr -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums
    popd
fi

patched_deb="${WORK_DIR}/amdgpu-dkms_${new_version#*:}_all.deb"
dpkg-deb -b pkg "${patched_deb}"

echo "Built patched amdgpu-dkms package: ${patched_deb}"
popd
