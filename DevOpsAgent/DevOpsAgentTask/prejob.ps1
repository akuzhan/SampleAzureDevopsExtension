Write-Output "------------------ Start: Upgrade AzureRM on build host ------------------"

Write-Output "- - - - - Install package provider"
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser

Write-Output "- - - - - Remove all existing AzureRM Modules" 
Get-Module -ListAvailable | Where-Object {$_.Name -like '*AzureRM*'} | Remove-Module -Force 

Write-Output "- - - - - Install AzureRM 4.4.1"
Install-Module -Name AzureRM -RequiredVersion 4.4.1 -Force -Scope CurrentUser -AllowClobber

Write-Output "- - - - - Import AzureRM 4.4.1"
Import-Module AzureRM -Force -Verbose -Scope Local

Write-Output "------------------ End: Upgrade AzureRM on build host ------------------"