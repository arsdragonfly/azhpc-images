# TODO: add variables for auth other than Az CLI

variable "username" {
  type    = string
  default = env("USERNAME")
}
locals {
  username = coalesce(var.username, "hpcuser")
}

variable "resource_grp_name" {
  type        = string
  description = "Location of the resource group"
  default     = env("RESOURCE_GRP_NAME")
}
locals {
  resource_grp_name = coalesce(var.resource_grp_name, "hpc-image-build-${substr(replace(lower(uuidv4()), "-", ""), 0, 6)}-rg")
}

variable "resource_grp_location" {
  type        = string
  description = "Location of the resource group"
  default     = env("RESOURCE_GRP_LOCATION")
}
locals {
  resource_grp_location = coalesce(var.resource_grp_location, "southcentralus")
}

variable "owner_alias" {
  type        = string
  description = "Your alias for Azure resource tagging (required by policy)"
  default     = "mogaurab"
}

variable "images_repo_url" {
  type        = string
  description = "GitHub repository URL for azhpc-images"
  default     = env("IMAGES_REPO_URL")
}
locals {
  images_repo_url = coalesce(var.images_repo_url, "https://github.com/Azure/azhpc-images")
}

variable "target_branch" {
  type        = string
  description = "Branch to use from the repo"
  default     = env("TARGET_BRANCH")
}
locals {
  target_branch = coalesce(var.target_branch, "master")
}

variable "os_version" {
  type        = string
  description = "OS version to use for the image"
  default     = env("OS_VERSION")
}
locals {
  os_version = coalesce(var.os_version, "ubuntu_22.04")
}

variable "gpu_size_option" {
  type        = string
  description = "VM SKU to use for image building"
  default     = env("GPU_SIZE_OPTION")
}
locals {
  gpu_size_option = coalesce(var.gpu_size_option, "Standard_ND96asr_v4")
}

# TODO: derive gpu_platform, gpu_sku and architecture from gpu_size_option

variable "create_image" {
  type        = string
  description = "whether to create a compute gallery image or not"
  default     = env("CREATE_IMAGE")
}
locals {
  create_image = coalesce(var.create_image, false)
}

variable "create_vhd" {
  type        = string
  description = "whether to create a VHD or not"
  default     = env("CREATE_VHD")
}
locals {
  create_vhd = coalesce(var.create_vhd, false)
}

variable "is_experimental_image" {
  type        = string
  description = "whether the image is experimental or not"
  default     = env("IS_EXPERIMENTAL_IMAGE")
}
locals {
  is_experimental_image = coalesce(var.is_experimental_image, false)
}

variable "sig_subscription" {
  type        = string
  description = "Subscription ID for the Shared Image Gallery"
  default     = env("SIG_SUBSCRIPTION")
}
locals {
  sig_subscription = var.sig_subscription
}

variable "sig_resource_grp_name" {
  type        = string
  description = "Resource group name for the Shared Image Gallery"
  default     = env("SIG_RESOURCE_GRP_NAME")
}
locals {
  sig_resource_grp_name = coalesce(var.sig_resource_grp_name, "azhpc-images-rg")
}

variable "sig_gallery_name" {
  type        = string
  description = "Shared Image Gallery name"
  default     = env("SIG_GALLERY_NAME")
}
locals {
  sig_gallery_name = coalesce(var.sig_gallery_name, "AzHPCImageReleaseCandidates")
}

variable "sig_image_version" {
  type        = string
  description = "Shared Image Gallery image version"
  default     = env("SIG_IMAGE_VERSION")
}
locals {
  sig_image_version = coalesce(var.sig_image_version, "0.0.1")
}

variable "sig_image_definition" {
  type        = string
  description = "Shared Image Gallery image definition name"
  default     = env("SIG_IMAGE_DEFINITION")
}

locals {
  sig_image_definition = coalesce(var.sig_image_definition, "hpc-${replace(local.os_version, "_", "-")}-${var.gpu_size_option}")
}

variable "sig_use_shallow_replication" {
  type        = string
  description = "Use shallow replication for the Shared Image Gallery image. Useful for testing for faster builds."
  default     = env("SIG_USE_SHALLOW_REPLICATION")
}
locals {
  sig_use_shallow_replication = coalesce(var.sig_use_shallow_replication, true)
}

variable "sig_target_regions" {
  type        = string
  description = "Space-separated list of target regions for the Shared Image Gallery image."
  default     = env("SIG_TARGET_REGIONS")
}

locals {
  sig_target_regions = var.sig_target_regions == null ? [local.resource_grp_location] : split(" ", var.sig_target_regions)
}

variable "vhd_resource_grp_name" {
  type        = string
  description = "Resource group name for the VHD storage account"
  default     = env("VHD_RESOURCE_GRP_NAME")
}
locals {
  vhd_resource_grp_name = coalesce(var.vhd_resource_grp_name, "azhpc-images-rg")
}

variable "vhd_storage_account_name" {
  type        = string
  description = "Storage account name for the VHD"
  default     = env("VHD_STORAGE_ACCOUNT_NAME")
}
locals {
  vhd_storage_account_name = coalesce(var.vhd_storage_account_name, "azhpcstor")
}

variable "vhd_container_name" {
  type        = string
  description = "Container name for the VHD blob"
  default     = env("VHD_CONTAINER_NAME")
}
locals {
  vhd_container_name = coalesce(var.vhd_container_name, "azhpc-vhd-store")
}

# TODO: determine VHD name prefix

variable "skip_hpc" {
  type       = string
  description = "Skip any HPC-specific tasks. Useful for testing."
  default     = env("SKIP_HPC")
}
locals {
  skip_hpc = coalesce(var.skip_hpc, false)
}

variable "public_key" {
  type        = string
  description = "Public key to use for SSH access for debugging purposes"
  default     = env("PUBLIC_KEY")
}
locals {
  public_key = var.public_key
}

variable "retain_vm_on_fail" {
  type        = string
  description = "Retain the VM (and the resource group) if the build fails"
  default     = env("RETAIN_VM_ON_FAIL")
}
locals {
  retain_vm_on_fail = coalesce(var.retain_vm_on_fail, false)
}

variable "retain_vm_always" {
  type        = string
  description = "Retain the VM (and the resource group) unconditionally. Injects an error to Packer to prevent deletion."
  default     = env("RETAIN_VM_ALWAYS")
}
locals {
  retain_vm_always = coalesce(var.retain_vm_always, false)
}

variable "private_virtual_network_with_public_ip" {
  type        = string
  description = "Also use a public IP when using a private virtual network."
  default     = env("PRIVATE_VIRTUAL_NETWORK_WITH_PUBLIC_IP")
}
locals {
  # existing setup defaults to having Public IP, presumably for debugging
  private_virtual_network_with_public_ip = coalesce(var.private_virtual_network_with_public_ip, true)
}

variable "virtual_network_subnet_name" {
  type        = string
  description = "Use a pre-existing subnet for the VM."
  default     = env("VIRTUAL_NETWORK_SUBNET_NAME")
}
locals {
  virtual_network_subnet_name = var.virtual_network_subnet_name
}

variable "virtual_network_resource_group_name" {
  type        = string
  description = "Resource group for the existing virtual network."
  default     = env("VIRTUAL_NETWORK_RESOURCE_GROUP_NAME")
}
locals {
  virtual_network_resource_group_name = var.virtual_network_resource_group_name
}

variable "externally_managed_resource_group" {
  type        = string
  description = "Whether the resource group is externally managed by e.g. Azure Pipelines, in which case the pipeline itself is responsible for cleanup."
  default     = env("EXTERNALLY_MANAGED_RESOURCE_GROUP")
}
locals {
  externally_managed_resource_group = coalesce(var.externally_managed_resource_group, false)
}

# TODO: add injection point for 1P-specific scripts


# =============================================================================
# Azure Linux Specific Variables
# =============================================================================

variable "base_image" {
  type        = string
  description = "base image type: Marketplace-FIPS, Marketplace-Non-FIPS, 1P-FIPS, 1P-Non-FIPS"
  default     = env("BASE_IMAGE")
}
locals {
  base_image = coalesce(var.base_image, "Marketplace")
}

variable "azl3_prebuilt_version" {
  type        = string
  description = "Version for Azure Linux prebuilt artifacts (e.g., 0.0.17)"
  default     = env("AZL3_PREBUILT_VERSION")
}
locals {
  azl3_prebuilt_version = coalesce(var.azl3_prebuilt_version, "0.0.17")
}

variable "azl3_prebuilt_storage_account" {
  type        = string
  description = "Storage account for Azure Linux prebuilt artifacts"
  default     = "azhpcstoralt"
}

variable "azl_prebuilt_container" {
  type        = string
  description = "Container for Azure Linux prebuilt artifacts"
  default     = "azurelinux-prebuilt"
}

variable "u24gb200_internalbits_version" {
  type        = string
  description = "Version for Ubuntu 24.04 GB200 internal bits"
  default     = env("U24GB200_INTERNALBITS_VERSION")
}

# TODO: TiP session stuff

# TODO: PartUUID

variable "major_version" {
  type        = string
  description = "Major version for the image"
  default     = env("MAJOR_VERSION")
}
locals {
  major_version = coalesce(var.major_version, "0")
}

variable "minor_version" {
  type        = string
  description = "Minor version for the image"
  default     = env("MINOR_VERSION")
}
locals {
  minor_version = coalesce(var.minor_version, "0")
}

variable "patch_version" {
  type        = string
  description = "Patch version for the image"
  default     = env("PATCH_VERSION")
}
locals {
  patch_version = coalesce(var.patch_version, "1")
}

variable "image_version" {
  type        = string
  description = "Image version in format Major.Minor.Patch"
  default     = env("IMAGE_VERSION")
}
locals {
  image_version = coalesce(var.image_version, "${local.major_version}.${local.minor_version}.${local.patch_version}")
}

variable "iso_format_start_time" {
  type        = string
  description = "ISO format pipeline start time"
  default     = env("ISO_FORMAT_START_TIME")
}
locals {
  iso_format_start_time = coalesce(var.iso_format_start_time, timestamp())
}

variable "aks_host_image" {
  type        = bool
  description = "Whether to produce an AKS host image"
  default     = env("AKS_HOST_IMAGE")
}
locals {
  aks_host_image = coalesce(var.aks_host_image, false)
}

variable "accl_nw" {
  type        = bool
  description = "Whether to enable Acccelerated Networking on the build VM"
  default     = env("ACCL_NW")
}
locals {
  accl_nw = coalesce(var.accl_nw, false)
}

variable "use_spot_instances" {
  type        = bool
  description = "Whether to use Spot Instances for the build VM"
  default     = env("USE_SPOT_INSTANCES")
}
locals {
  use_spot_instances = coalesce(var.use_spot_instances, false)
}