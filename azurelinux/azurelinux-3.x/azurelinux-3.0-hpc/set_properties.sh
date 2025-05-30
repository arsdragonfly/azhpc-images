#!/bin/bash

export TOP_DIR=../../..
export COMMON_DIR=../../../common
export TOOLS_DIR=../../../tools
export AZURE_LINUX_COMMON_DIR=../../common
export TEST_DIR=../../../tests
export DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)

# Component Versions
export COMPONENT_VERSIONS=$(jq -r . $TOP_DIR/versions.json)

# Environments
export MODULE_FILES_DIRECTORY=/usr/share/Modules/modulefiles

# Kernel
# export KERNEL=$(rpm -q kernel | sed 's/kernel\-//g')

# $COMMON_DIR/write_component_version.sh "distribution" $DISTRIBUTION