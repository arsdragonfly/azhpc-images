# =============================================================================
# HPC Image Builder - Source Definition
# =============================================================================
# Azure ARM builder configuration
# =============================================================================

packer {
  required_version = ">= 1.14.0"

  required_plugins {
    azure = {
      version = "~> 2.5.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

source "azure-arm" "hpc" {
  use_azure_cli_auth = true

  # base image from Marketplace
  image_publisher = local.image_publisher
  image_offer     = local.image_offer
  image_sku       = local.image_sku

  # base image from DSG
  direct_shared_gallery_image_id = local.direct_shared_gallery_image_id

  build_resource_group_name = local.resource_grp_name

  # These variables handle the intermediate "managed image".
  # The managed image (which is distinct from either the SIG image or the VHD) is of no particular use,
  # other than being, for historical reasons, a temporary artifact for SIG image creation.
  # It is now possible for a SIG image to be created directly from a generalized VM,
  # as opposed to having to first create a managed image, but the Packer Azure ARM builder
  # has not yet been updated to support that workflow.
  managed_image_resource_group_name = local.resource_grp_name
  managed_image_name                = "HPC-Image-${local.image_version}"

  os_type = "Linux"
  vm_size = local.gpu_size_option
  os_disk_size_gb = 64
  location = local.resource_grp_location

  # SSH Configuration
  communicator           = "ssh"
  ssh_username           = "hpcuser"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100
  ssh_pty                = true
}
