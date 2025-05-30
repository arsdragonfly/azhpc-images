# Below are the steps to use Packer to build an HPC test image on an Azure Linux 3.0 Gen2 marketplace image.
  * (Reference: https://github.com/Azure/azhpc-images)

1) Install Packer on your development machine. Packer uses credentials to the subscription to boot a marketplace image, SSH into it, customize it, and then save it as a managed image under the provided managed resource group. 
   You can find instructions on installing Packer here: * https://learn.hashicorp.com/tutorials/packer/get-started-install-cli.

2) Create a managed_image_resource_group_name in your subscription. Packer will use this managed_image_resource_group_name to save the customized managed image. This needs to be in the same region as the location specified in `azure-linux-hpc-image-vars-gen2.json`.

3) Use Azure CLI to create the service principal that Packer will use to authenticate with our subscription by running the following command:
   ```
   az ad sp create-for-rbac --name myServicePrincipalName --role roleName --scopes /subscriptions/mySubscriptionID/resourceGroups/myResourceGroupName --create-cert
   ```

4) Customize the `azure-linux-hpc-image-vars-gen2.json` file with the required details:
   ```
   "subscription_id":  "",
   "tenant_id":      "",
   "client_id": "",
   "client_cert_path": "",
   "location": "",
   "vm_size": "",
   "managed_image_resource_group_name": "",
   "managed_image_name": ""

   ```

5) Provide values in `azure-linux-hpc-image-vars-gen2.json` for subscription, client_id, client_cert_path, etc., which are needed for the Packer build. 
    **Do not check these in anywhere as they are credentials to our subscription. If you need to run Packer from a pipeline, use secure pipeline variables to store this information. If it leaks, we must delete it from our access control (IAM) tab on the subscription immediately.**

6) Run Packer with the `azure-linux-hpc-image-gen2.json` config filled with variables from your `azure-linux-hpc-image-vars-gen2.json`. This will take some time to complete the build. Use the following command:
   ```
   packer build -var-file ./.pipelines/azure-linux-hpc-image-vars-gen2.json ./.pipelines/azure-linux-hpc-image-gen2.json

   ```
   * An important aspect of this process is the custom_data_file named `sha1rsa_custom_data`, which allows sshd to accept SSH connections from Packer by reallowing less secure pubkey algorithms. Note that in the script.sh file, we remove these temporary configurations before the VHD is captured.

7) After Packer runs, the Azure Linux 3.0 HPC test Gen2 based managed image will be available in the specified managed resource group.


# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
