Function Get-SubscriptionName() {
    $name = (Get-AzureRmContext).Subscription.SubscriptionName
    if ($null -eq $name) { $name = (Get-AzureRmContext).Subscription.Name }
    return $name
}

$ErrorActionPreference = "Stop"
Write-Host "[INFO] Initializing Application Insights Connection ..."
Write-Host "[INFO] Loading AppInsights DLL from $PSScriptRoot\Microsoft.ApplicationInsights.dll"
$AI = "$PSScriptRoot\Microsoft.ApplicationInsights.dll"
[Reflection.Assembly]::LoadFile($AI)

# Use a custom function to derive the subscription name because of the inconsistencies detailed below:
# On Microsoft's VSTS agents, an older version of AzureRm is installed, whereby to get the subscription name, you have to use (Get-AzureRmContext).Subscription.SubscriptionName
# On the akuzhanself-hosted VSTS agents, to get the subscription name, you have to use (Get-AzureRmContext).Subscription.Name
if ((Get-SubscriptionName) -like "*-prd-*") {
	$InstrumentationKey = "xyz"
	Write-Host "[INFO] Application Insights set to log to [xyz]"
} else {
	$InstrumentationKey = "abc"
	Write-Host "[INFO] Application Insights set to log to [abc]"	
}

$global:TelClient = New-Object "Microsoft.ApplicationInsights.TelemetryClient"
$TelClient.InstrumentationKey = $InstrumentationKey
$TelClient.Context.Operation.Id = Get-Random -Maximum 9999999 -Minimum 1
$TelClient.Context.Operation.Name = "Akuzhan DevOps Agent Register Task"
$TelClient.TrackPageView("akuzhanDevOps Agent Register Task")

$DevOpsInstance = "$env:System_TeamFoundationCollectionUri"
$TelClient.TrackEvent("$DevOpsInstance") # e.g. "https://xyz.visualstudio.com/"

$sourceRepo = "$env:BUILD_PROJECTNAME" + "/" + "$env:BUILD_REPOSITORY_NAME"
$TelClient.TrackEvent("$sourceRepo") # e.g. "Project/XYZ" (concatenate Project Space with Repo Name for better context over which repo this release originated from)

$releasePipelineName = "$env:RELEASE_DEFINITIONNAME"
$TelClient.TrackEvent("$releasePipelineName") # e.g. "DevOps Agent Register-Release"

$releaseEnvName = "$env:Release_EnvironmentName"
$TelClient.TrackEvent("$releaseEnvName") # e.g. "dev"

$releaseDeployedBy = "$env:RELEASE_DEPLOYMENT_REQUESTEDFOREMAIL"
$TelClient.TrackEvent("$releaseDeployedBy") # e.g. "abc@xyz.com" (this is the email of the person who presses deploy, not the person who creates the release. For prod releases, this would typically be a release manager)

$TelClient.Flush()
Write-Host "[INFO] Application Insights Running Sucessfully."	