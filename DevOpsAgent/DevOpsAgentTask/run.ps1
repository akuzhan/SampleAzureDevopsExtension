$ConnectedServiceNameSelector = Get-VstsInput -Name ConnectedServiceNameSelector -Require
$ConnectedServiceNameARM = Get-VstsInput -Name ConnectedServiceNameARM -Require
$ResourceGroupName  = Get-VstsInput -Name ResourceGroupName -Require
$VirtualMachineName = Get-VstsInput -Name VirtualMachineName -Require

$InstanceName  = Get-VstsInput -Name InstanceName -Require
$AzureDevOpsInstanceURL  = Get-VstsInput -Name AzureDevOpsInstanceURL -Require
$PatToken  = Get-VstsInput -Name PatToken -Require
$AgentPoolName  = Get-VstsInput -Name AgentPoolName -Require
$UserEmailAddress  = Get-VstsInput -Name UserEmailAddress -Require
$Password  = Get-VstsInput -Name Password -Require

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Require
$serviceName = Get-VstsInput -Name ConnectedServiceNameARM -Require
$endPointRM = Get-VstsEndpoint -Name $serviceName -Require
 
$clientId = $endPointRM.Auth.Parameters.ServicePrincipalId
$clientSecret = $endPointRM.Auth.Parameters.ServicePrincipalKey
$tenantId = $endPointRM.Auth.Parameters.TenantId
 
 #Set the powershell credential object
$userPassword = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $clientId, $userPassword
 
#log On To Azure Account
 
Login-AzureRmAccount -ServicePrincipal -Credential $cred -TenantId $tenantId


# Importing and initliazing telemetry
Write-Host "##[command] Loading $PSScriptRoot\custom_modules\LoadTelemtry.ps1"
. $PSScriptRoot\custom_modules\LoadTelemetry.ps1


function Get-UniqueString ([string]$id, $length=8)
{
    $hashArray = (new-object System.Security.Cryptography.SHA512Managed).ComputeHash($id.ToCharArray())
    -join ($hashArray[1..$length] | ForEach-Object { [char]($_ % 26 + [byte][char]'a') })
}

$storageAccountContainerName = "scripts"
$StorageAccountName = Get-UniqueString($ResourceGroupName)
$ScriptBlobURL = "https://$StorageAccountName.blob.core.windows.net/$storageAccountContainerName/"
$ScriptName = "AgentInstall.ps1"
$ExtensionName = 'InstallDevOpsAgent'
$Version = '1.9'
$BlobName = "$ScriptName" 
$localFile = ".\$ScriptName"

Write-Host  "call Get-AzVM"
$vm= Get-AzureRMVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName
$VMLocation = $vm.location
Write-Host  "called Get-AzVM"
try
{
	$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -ErrorAction Stop
}
catch
{
	
	$storageAccount = New-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName -Location $VMLocation -SkuName "Standard_GRS" -EnableHttpsTrafficOnly $True 
}

try
{
	$storageAccountContainer = $storageAccount | Get-AzureStorageContainer -Name $storageAccountContainerName -ErrorAction Stop
}
catch
{
	$storageAccount | New-AzureStorageContainer -Name $storageAccountContainerName
}

$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -ErrorAction Stop

$storageAccount | Set-AzureStorageBlobContent -File $localFile -Container $storageAccountContainerName -Blob $BlobName

$keys = $storageAccount | Get-AzureRmStorageAccountKey
$key1 =$keys[0].Value

$Extensions = @( $vm.Extensions | Where {$_.VirtualMachineExtensionType -like 'CustomScriptExtension'} )
if($Extensions.count -gt 0)
{
	Try
	{
		Write-Warning "Removeing CustomScriptExtension '$($Extensions.Name)' on VM '$VM'"
		$Output = Remove-AzureRmVMCustomScriptExtension $ResourceGroupName -Name $Extensions.Name -vmname $VirtualMachineName -Force -ErrorAction Stop
		if($Output.StatusCode -notlike 'OK')
		{
			Throw "Remove-AzureRmVMCustomScriptExtension output seems off:`n$($Output | Format-List | Out-String)"
		}
	}
	Catch
	{
		Write-Error $_
		Write-Error "Failed to remove existing extension $($Extensions.Name) for VM '$VM' in ResourceGroup '$ResourceGroup'"
		continue
	}
}


Try
{
 
 Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName -Location $VMLocation  -Name $ExtensionName -TypeHandlerVersion $Version -StorageAccountName $StorageAccountName -StorageAccountKey $key1 -FileName $ScriptName -ContainerName $storageAccountContainerName -Run "$ScriptName" -ForceRerun $(New-Guid).Guid -Argument "$InstanceName $AzureDevOpsInstanceURL $PatToken $AgentPoolName $UserEmailAddress $Password" -SecureExecution
 
}
Catch
{
	$TelException = New-Object "Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry"
	$TelException.Exception = "$($PSItem.ToString())"
	$TelClient.TrackException($TelException)
	$TelClient.Flush()
    Throw $_
}
Finally
{
 $storageAccount | Remove-AzureRmStorageAccount -Force
}


$TelClient.TrackEvent("Datafactory IR Register Task completed successfully.")
$TelClient.Flush()



