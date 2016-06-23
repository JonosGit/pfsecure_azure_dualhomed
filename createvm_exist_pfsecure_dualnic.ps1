## This script creates a PFSecure in an existing Subnets in an Azure Resource Group

## In order for this script to work properly the VNET and VNETResourceGroupName must already exist.
## Prior to running this script make sure the environment variables have been configured for Subscription ID, TenantID, ResourceGroup and VNETName
## Update the vmcount variable to increment the Deployed VM, i.e. 001 will result in a VM Deployed named PF001.
## To specify the local adminsitrator and Password Update the locadmin and locpassword
## The Public IP Address of the PFSecure VM will be shown when the script completes and can be used to SSH to the server.


## Global
$vmcount = "001"
$vmtype = "pfs"
$VMName = $vmtype + $vmcount
$ResourceGroupName = "<VMRESOURCEGROUPNAME>"
$vNetResourceGroupName = "<EXISTINGVNETRESOURCEGROUPNAME>"
$Location = "WestUs"
$SubscriptionID='<SUBID>'
$TenantID='<TENANTID>'
$StorageName = $VMName + "str"
$StorageType = "Standard_GRS"
$InterfaceName1 = $VMName + "nic1"
$InterfaceName2 = $VMName + "nic2"
$VNetName = "<EXISTINGVNETNAME>"
$ComputerName = $VMName
$VMSize = "Standard_A3"
$locadmin = 'localadmin'
$locpassword = 'PassW0rd!@1'

# Add-AzureRMAccount 
Login-AzureRmAccount
Set-AzureRmContext -tenantid $TenantID -subscriptionid $SubscriptionID

# Resource Group
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -force

# Storage
$StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Type $StorageType -Location $Location

# Network
$PIp = New-AzureRmPublicIpAddress -Name $InterfaceName1 -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod "Dynamic"
$VNet = Get-AzureRMVirtualNetwork -Name $VNetName -ResourceGroupName $vNetResourceGroupName | Set-AzureRmVirtualNetwork
$Interface1 = New-AzureRmNetworkInterface -Name $InterfaceName1 -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[1].Id -PublicIpAddressId $PIp.Id
$Interface2 = New-AzureRmNetworkInterface -Name $InterfaceName2 -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $VNet.Subnets[2].Id
$osDiskCaching = 'ReadWrite'

## Setup local VM object
$SecureLocPassword=Convertto-SecureString $locpassword –asplaintext -force
$Credential1 = New-Object System.Management.Automation.PSCredential ($locadmin,$SecureLocPassword)
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
$VirtualMachine = Set-AzureRmVMPlan -VM $VirtualMachine -Name pfsense-router-fw-vpn-225 -Publisher netgate -Product netgate-pfsense-appliance
$VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -linux -ComputerName $ComputerName -Credential $Credential1
$VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName netgate -Offer netgate-pfsense-appliance -Skus pfsense-router-fw-vpn-225 -Version "latest"
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface1.Id -Primary
$VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface2.Id
$OSDiskName = $VMName + "OSDisk"
$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
$VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption "FromImage" -Caching $osDiskCaching

## Create the VM in Azure
New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine -Verbose 

Get-AzureRmPublicIpAddress -Name $InterfaceName1 -ResourceGroupName $ResourceGroupName | ft "IpAddress"
