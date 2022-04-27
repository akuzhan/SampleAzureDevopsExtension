param(
 [string]
 $InstanceName,
 
 [string]
 $AzureDevOpsInstanceURL,
 
 [string]
 $PatToken,
 
 [string]
 $AgentPoolName,
 
 [string]
 $UserEmailAddress,
 
 [string]
 $Password
)

function CopyAgentFilesOntoFolder([string]$folder, [string]$devOpsZip)
{
	$devOpsDestination = "C:\ProgramData\MicrosoftVSTSAgent\$folder" 
	if(!(test-path $devOpsDestination))
    {
          New-Item -ItemType Directory -Force -Path $devOpsDestination
    }
    Write-Host "[INFO] Expanding Package [$devOpsZip] to [$devOpsDestination]"
    $result = Expand-Zip -Source $devOpsZip -Destination $devOpsDestination
    Write-Host "[INFO] Agent instance [$folder] setup complete. Exit code=$result"
}

function Expand-Zip {
    [CmdletBinding()]
    param (
        [string]$Source,
        [string]$Destination
    )    
    try
    {
        #extract
        Add-Type -AssemblyName System.IO.Compression.FileSystem;[System.IO.Compression.ZipFile]::ExtractToDirectory($Source, "$Destination");
    }
    catch
    {
        Write-Error "Failed to extract $Source"
    }
}
function CheckNumberOfAgents()
{
    $files = get-childitem -Path "C:\ProgramData\MicrosoftVSTSAgent"
    $folders = $files | where-object { $_.PSIsContainer }
    return $folders.Count
}

$numberOfAgents = CheckNumberOfAgents
if($numberOfAgents -eq 4){
    throw "Number of agents registered on this vm is already 4."
}

$maxAgentCount = 8
$agentInstance = 1
while ($agentInstance -le $maxAgentCount){
    $result = Test-Path "C:\ProgramData\MicrosoftVSTSAgent\$InstanceName$agentInstance"
    if($result -eq $False)
    {
        break
    }
    $agentInstance++
}


$agentName= $env:COMPUTERNAME +"-"+ $InstanceName + $agentInstance
$folderName = $InstanceName + $agentInstance
$devOpsZip = "C:\ProgramData\MicrosoftVSTSAgent\devOpsAgent.zip"
CopyAgentFilesOntoFolder $folderName $devOpsZip

$agentPath = "C:\ProgramData\MicrosoftVSTSAgent\$InstanceName$agentInstance"
Set-Location $agentPath
./config.cmd --unattended --url $AzureDevOpsInstanceURL --auth pat --token $PatToken --pool $AgentPoolName --agent $agentName --acceptTeeEula --runAsService --windowsLogonAccount $UserEmailAddress --windowsLogonPassword $Password --work $agentPath