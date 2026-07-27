#!/bin/bash
set -ex

# Place NDv6 customizations under /opt/microsoft/ndv6
mkdir -p /opt/microsoft/ndv6

if [[ -s /etc/modules-load.d/nvidia-peermem.conf ]]; then
    modprobe nvidia-peermem
fi