#!/bin/bash
set -ex

if nvidia-smi nvlink --status | grep -qa inActive; then
    # Ensure Hyper-V PCI devices is ready
    retries=0
    while ! ls /sys/bus/vmbus/drivers/hv_pci/ | grep -q '[0-9a-f-]\{8\}-'; do
        error_code=$?
        if (( retries++ >= 5 )); then
            echo "Hyper-V PCI devices Inactive!"
            exit ${error_code}
        fi
        echo "Waiting for Hyper-V PCI devices..."
        sleep 1
    done

    # Ensure NVIDIA GPU PCI devices is ready
    retries=0
    while ! lspci | grep -qi nvidia; do
        error_code=$?
        if (( retries++ >= 5 )); then
            echo "NVIDIA GPU PCI Inactive!"
            exit ${error_code}
        fi
        echo "Waiting for NVIDIA GPU PCI devices..."
        sleep 1
    done

    echo "Reloading NVIDIA kernel modules..."
    sudo systemctl stop nvidia-dcgm.service
    remove_modules=(nvidia_drm nvidia_modeset)
    load_modules=(nvidia nvidia_modeset nvidia_uvm nvidia_peermem)
    if modinfo gdrdrv >/dev/null 2>&1; then
        remove_modules+=(gdrdrv)
        load_modules+=(gdrdrv)
    fi
    remove_modules+=(nvidia_peermem nvidia_uvm nvidia)
    load_modules+=(nvidia_drm)
    sudo modprobe -r "${remove_modules[@]}"
    sudo modprobe "${load_modules[@]}"
    sudo systemctl start nvidia-dcgm.service
fi

echo "Check NVLink status after reloading NVIDIA kernel modules..."
if nvidia-smi nvlink --status | grep -qa inActive; then
    echo "NVLink is still Inactive after reloading NVIDIA kernel modules!"
    exit 1
else
    echo "NVLink is Active."
fi
