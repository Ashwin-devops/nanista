#Variables needs to be Updated

#https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/diagnostics-linux?toc=%2Fazure%2Fazure-monitor%2Ftoc.json&tabs=powershell
##############################
#
# Connect to Azure
#
############################

connect-AzAccount
$SubscriptionName="<Update me>"
Set-AzContext -Subscription $SubscriptionName

#apt-get install -y python2
#whereis python3

#Then we create a symlink to it: sudo ln -s /usr/bin/python3 /usr/bin/python
$storageAccountName = "<Update me>"
$storageAccountResourceGroup = "<Update me>"
$vmName = "<Update me>"
$VMresourceGroup = "d<Update me>"
$azureServiceRecoveryVault="<Update Vaultt Name>: myRecoveryServicesVault"
$policyName="< Update Policy Name From Recovery Valut:  DefaultPolicy>"

#Must complete the prerequisites
function enableDiagnostics{

    try{

    # Get the VM object
    $vm = Get-AzVM -Name $vmName -ResourceGroupName $VMresourceGroup

    # Enable system-assigned identity on an existing VM
    Update-AzVM -ResourceGroupName $VMresourceGroup -VM $vm -IdentityType SystemAssigned

    # Get the public settings template from GitHub and update the templated values for the storage account and resource ID
    $publicSettings = (Invoke-WebRequest -Uri https://raw.githubusercontent.com/Azure/azure-linux-extensions/master/Diagnostic/tests/lad_2_3_compatible_portal_pub_settings.json).Content
    $publicSettings = $publicSettings.Replace('__DIAGNOSTIC_STORAGE_ACCOUNT__', $storageAccountName)
    $publicSettings = $publicSettings.Replace('__VM_RESOURCE_ID__', $vm.Id)

    # If you have your own customized public settings, you can inline those rather than using the preceding template: $publicSettings = '{"ladCfg":  { ... },}'

    # Generate a SAS token for the agent to use to authenticate with the storage account
    $sasToken = New-AzStorageAccountSASToken -Service Blob,Table -ResourceType Service,Container,Object -Permission "racwdlup" -Context (Get-AzStorageAccount -ResourceGroupName $storageAccountResourceGroup -AccountName $storageAccountName).Context -ExpiryTime $([System.DateTime]::Now.AddYears(10))

    # Build the protected settings (storage account SAS token)
    $protectedSettings="{'storageAccountName': '$storageAccountName', 'storageAccountSasToken': '$sasToken'}"

    # Finally, install the extension with the settings you built
    Set-AzVMExtension -ResourceGroupName $VMresourceGroup -VMName $vmName -Location $vm.Location -ExtensionType LinuxDiagnostic -Publisher Microsoft.Azure.Diagnostics -Name LinuxDiagnostic -SettingString $publicSettings -ProtectedSettingString $protectedSettings -TypeHandlerVersion 4.0

    }
    catch{

        write-host "Exception during the Setup"
    }

}

function setvmSize{

    try{

    Get-AzVMSize -ResourceGroupName $VMresourceGroup -VMName $vmName
    $vm = Get-AzVM -ResourceGroupName $VMresourceGroup -VMName $vmName
    $vm.HardwareProfile.VmSize = "Standard_D2S_v3"
    Update-AzVM -VM $vm -ResourceGroupName $VMresourceGroup
    }
    catch{
        
        Write-Host "Exception during the Size Update"
    }

}

function SetupPolicy(){

    param(
		    $policy,
            [string] $vmName,
            [string] $vmRG
	    )

    try{

        Enable-AzRecoveryServicesBackupProtection `
            -ResourceGroupName $vmRG `
            -Name $myVM `
            -Policy $policy

        }
        catch{
    
            write-host "Exception During the Enablement "

        }

}
##############################
#
# Enable Boot Diagnostics
#
############################

enableDiagnostics

##############################
#
# Set VM Size
#
############################

setvmSize


##############################
#
# Enable Backup Policy
#
############################

# Get the Recovery Vault
Get-AzRecoveryServicesVault `
    -Name $azureServiceRecoveryVault | Set-AzRecoveryServicesVaultContext

$policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $policyName

SetupPolicy -policy $policy -vmName $myVM -vmRG $vmRG
