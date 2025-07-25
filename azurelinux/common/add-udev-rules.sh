#!/bin/bash
set -e

cat << EOF >> /etc/udev/rules.d/60-rdma-persistent-naming.rules
# SPDX-License-Identifier: (GPL-2.0 OR Linux-OpenIB)
# Copyright (c) 2019, Mellanox Technologies. All rights reserved. See COPYING file
#
# Rename modes:
# NAME_FALLBACK - Try to name devices in the following order:
#                 by-pci -> by-guid -> kernel
# NAME_KERNEL - leave name as kernel provided
# NAME_PCI - based on PCI/slot/function location
# NAME_GUID - based on system image GUID
#
# The stable names are combination of device type technology and rename mode.
# Infiniband - ib*
# RoCE - roce*
# iWARP - iw*
# OPA - opa*
# Default (unknown protocol) - rdma*
#
# Example:
# * NAME_PCI
#   pci = 0000:00:0c.4
#   Device type = IB
#   mlx5_0 -> ibp0s12f4
# * NAME_GUID
#   GUID = 5254:00c0:fe12:3455
#   Device type = RoCE
#   mlx5_0 -> rocex525400c0fe123455

# Suppressing/overwriting the udev rule rdma_core package. NAME_KERNEL leaves the IB devices names as provided by the kernel.
ACTION=="add", SUBSYSTEM=="infiniband", PROGRAM="rdma_rename %k NAME_KERNEL"
EOF

cat << EOF >> /etc/udev/rules.d/99-issm.rules
KERNEL=="issm*", NAME="infiniband/%k"
EOF

udevadm control --reload-rules
udevadm trigger