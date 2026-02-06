build {
  name = "resource_group"
  sources = [
    "source.null.rg"
  ]

  provisioner "shell-local" {
    inline = [
      # check if the resource group already exists; if not, create it
      "az group show --name ${local.resource_grp_name} || az group create --name ${local.resource_grp_name} --location ${local.resource_grp_location} --tags ${local.merged_extra_tags_string}",
    ]
  }
}

build {
  name = "hpc_image_build"
  sources = ["source.azure-arm.hpc"]

  provisioner "shell" {
    name = "add SSH key"
    inline = [
      # add the public key to the VM
      "echo \"${local.public_key}\" >> /home/${local.username}/.ssh/authorized_keys",
    ]
  }

  provisioner "file" {
    source      = local.azhpc_local_path
    destination = "${local.azhpc_path}"
  }

  # TODO: find out if is_deprovision_eligible logic is applicable
  provisioner "shell" {
    name           = "clear history and deprovision"
    inline_shebang = local.inline_shebang
    skip_clean     = true  # waagent deprovision kills SSH, so Packer can't clean up
    inline = [
      "cd ${local.azhpc_path}/utils",
      "sudo ./clear_history.sh"
    ]
  }

  error-cleanup-provisioner "shell-local" {
    inline = [
      "if [ ${local.retain_vm_on_fail} = true ] || [ ${local.retain_vm_always} = true ] || [ ${local.externally_managed_resource_group} = true ]; then exit 0; else az group delete --name ${local.resource_grp_name} --yes; fi"
    ]
  }
}