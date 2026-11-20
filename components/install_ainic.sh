#!/bin/bash
set -euo pipefail

source "${UTILS_DIR}/utilities.sh"

bundle="$TOP_DIR/internal_bits/mi455x"
filenames=$(jq -er '
    .ainic.packages
    | if type == "array" and length > 0 and all(.[]; test("^[A-Za-z0-9][A-Za-z0-9._+~-]*\\.deb$"))
      then .[]
      else error("Expected a non-empty list of AINIC DEB filenames")
      end
' "$bundle/manifest.json")
module_version=$(jq -er '.ainic.dkms_patch.module_version | select(test("^[0-9][A-Za-z0-9.+~-]*$"))' "$bundle/manifest.json")
patch=$(jq -er '.ainic.dkms_patch.filename | select(test("^[A-Za-z0-9][A-Za-z0-9._-]*\\.patch$"))' "$bundle/manifest.json")
packages=()
while IFS= read -r filename; do
    packages+=("$bundle/$filename")
done <<< "$filenames"
install -D -m 0644 "$bundle/$patch" "/etc/dkms/ionic/patches/$patch"
{
    printf '%s\n' 'PATCH_MATCH[${#PATCH[@]}]="^7\.0\."'
    printf 'PATCH+=("%s")\n' "$patch"
} > "/etc/dkms/ionic-${module_version}.conf"

if ! apt-get install -y "linux-headers-$(uname -r)" rdma-core libibverbs-dev librdmacm-dev "${packages[@]}"; then
    for build_log in /var/lib/dkms/ionic/*/build/make.log; do
        [[ ! -f "$build_log" ]] || tail -n 100 "$build_log" >&2
    done
    exit 1
fi
check_dkms_status ionic
modinfo -k "$(uname -r)" ionic_rdma >/dev/null
write_component_version AINIC "$(dpkg-query -W -f='${Version}' ionic-dkms)"
