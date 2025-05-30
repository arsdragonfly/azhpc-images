#!/bin/bash

set -ex

source ${COMMON_DIR}/utilities.sh

aznhc_metadata=$(get_component_config "aznhc")
AZHC_VERSION=$(jq -r '.version' <<< $aznhc_metadata)

DEST_TEST_DIR=/opt/azurehpc/test

mkdir -p $DEST_TEST_DIR

pushd $DEST_TEST_DIR
GPU_PLAT=$1

git clone https://github.com/Azure/azurehpc-health-checks.git --branch v$AZHC_VERSION

pushd azurehpc-health-checks

chmod +x ./dockerfile/pull-image-mcr.sh
# Pull down docker container from MCR
if [ "${GPU_PLAT}" = "AMD" ]; then
   ./dockerfile/pull-image-mcr.sh rocm
else
   ./dockerfile/pull-image-mcr.sh cuda
fi

popd
popd

$COMMON_DIR/write_component_version.sh "AZ_HEALTH_CHECKS" ${AZHC_VERSION}
