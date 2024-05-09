####################################################################################################################################
#PS Ver	1 Matthew Brown (brownma@rcschools.net) with help from Brad Barnes and Chase Frazier
#PS Ver 2 removed diskpart and fully Powershell
#PS Ver 3 added PE drivers and loop for different autounattend files
#PS Ver 4 added option  text file naming driver files, and local copy options with code and help by Brad Barnes...also the CUSSD file round 1
#PS Ver 4a added option for Windows 11 deployment framework
#PS Ver 5 Rename to Intuninator then unveil my genius plan to a secret agent platypus
#PS Ver 6 more logic loops to reflect new network location
#pS Ver 6a fix logic issues. Add new powershell to remove built-in apps ...experimental
#PS ver 7 11 is the default - 180 triggers added to packages
#PS ver 8 fast refresh for just driver mode, packages and model check - idea inspired by Wilson and Will - Brad provided framwork for menu
#PS ver 9 rename to DriveBuilder - Create logic to have Domain Join packages PoC, code clean up, Progress Bar, and Stop the format popup
#PS ver 10 X for exit, Reading CUSSD words 
#PS Future - AutoPilot Only with scripts that will set the group tag or update the group with included logic to check and change
####################################################################################################################################

####################################################################################################################################
#Log File to see the magic
Start-Transcript -Append C:\Temp\IntuneDrive.log

####################################################################################################################################
#set variable for network location
$netLocation = "\\tech.rcs.k12.tn.us\intune$"
#set variable for local location
$localLocation = "C:\Intune"

####################################################################################################################################
#Check for Fresh file
If(Test-Path -Path $localLocation\zzFresh.txt){
 $packageDate = Get-Content $localLocation\zzFresh.txt 
 #Get the current date.
 $currentDate = Get-Date -format "yyyy-MM-dd"
 $packageDateObj = [DateTime]::ParseExact($packageDate, "yyyy-MM-dd", $null)
 $currentDateObj = [DateTime]::ParseExact($currentDate, "yyyy-MM-dd", $null)
 #Subtraction ...so much algebra? Is this algebra? 
 $freshOrExpired = $currentDateObj - $packageDateObj
 if(($freshOrExpired | Select -ExpandProperty Days) -lt 180){Write-Host "Local Intune Packages are valid" -ForegroundColor Green}
 else{Write-Host "Local Intune packages have expired. You Must REBUILD YOUR LOCAL STORE (C:\INTUNE). Choose Rebuild Local Store" -ForegroundColor red}
}

####################################################################################################################################
#Progress Bar function
function Show-ProgressBar {
    param(
        [int]$PercentComplete
    )
    $completedLength = [math]::Ceiling(($PercentComplete / 100) * $progressBarWidth)
    $remainingLength = $progressBarWidth - $completedLength
    $progressBar = "[" + "-" * $completedLength + (" " * $remainingLength) + "]"
    Write-Progress -Activity "RCS Drive Builder" -Status "$PercentComplete% Complete" -PercentComplete $PercentComplete 
}
# Copy folder function
function Copy-Folder {
param(
[string]$source,
[string]$destination
)
$files = Get-ChildItem $source -Recurse
$totalFiles = $files.Count
$copiedFiles = 0
foreach ($file in $files) {
$relativePath = $file.FullName.Substring($source.Length)
$destinationPath = Join-Path $destination $relativePath
Copy-Item $file.FullName -Destination $destinationPath -Force
$copiedFiles++
$percentComplete = ($copiedFiles / $totalFiles) * 100
Show-ProgressBar -PercentComplete $percentComplete
}
}
####################################################################################################################################
#Main Menu
do {
Write-Host "Are you running this as Administrator?  Please choose an option:" -ForegroundColor DarkCyan
Write-Host "1- Build New Drive"
Write-Host "2- Rebuild Local Store"
Write-Host "3- Add Drivers to Local Store"
Write-Host "4- Change School Package on USB Drive"
Write-Host "5- Change Drivers on USB Drive"
Write-Host "6- Check if the model is available"
Write-Host "7- Display Drive Information"
Write-Host "X- Exit" -ForegroundColor DarkRed
$choice = Read-Host "Enter your choice"

####################################################################################################################################
#Choice 1 Build New Drive
if ($choice -eq "1") {
#Input to get computer model for drivers or NA to get generic
$driverModel= Read-Host -Prompt 'Input your model for USB Drive (or NA if unknown)'

#Input to get site information 3 digit code
$site= Read-Host -Prompt 'Input your site (example WHS) or A for AutoPilot device'

#Input to get OS version or Automatic Windows 11 
#$OS= Read-Host -Prompt 'Input OS Choice (11 or 10)'
#Automatically 11 but will retain menu for future builds
$OS= 11

#stop hardware detection
Stop-Service -Name ShellHWDetection
#Format USB Drive. Make sure you do not have any other drives or partitions on this system beyond the 1 OS partition
Clear-Disk -Number 1 -RemoveData -Confirm:$false
Start-Sleep -s 1
New-Partition -DiskNumber 1 -Size 1.5GB -IsActive -DriveLetter G
Start-Sleep -s 1
Format-Volume -DriveLetter G -FileSystem FAT32 -NewFileSystemLabel OSFiles
Start-Sleep -s 1
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter Z
Start-Sleep -s 1
Format-Volume -DriveLetter Z -FileSystem NTFS -NewFileSystemLabel storage
Start-Sleep -s 1
#Start Hardware Detection
Start-Service -Name ShellHWDetection

#set USB drive variables
$StoragePath = "Z:"
$OSFilesPath = "G:"
if ($StoragePath) {
    Write-Host "OSFiles = $OSFilesPath and Storage = $StoragePath" -ForegroundColor Cyan

#Create Info File = Created, Updated, Site, System, Drivers
New-Item -Path $OSFilesPath\ -Name "CUSSD.txt" -Verbose
Add-Content $OSFilesPath\cussd.txt "Drive Created"
Add-Content $OSFilesPath\cussd.txt -Value (Get-Date)

#Create Directories Apps and Scripts on $StoragePath
New-Item -Path "$StoragePath\Apps" -ItemType Directory
New-Item -Path "$StoragePath\Scripts" -ItemType Directory

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$drivermodel"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the network store." -ForegroundColor Cyan}
$destinationDrivers = "$StoragePath\$driverModel"

#Copy Apps and OS
if(Test-Path -Path "$localLocation\$OS"){
# copy from local store
$sourceOSFiles = "$localLocation\$OS\OSFiles"
$sourceOSStorage = "$localLocation\$OS\Storage"
$sourceApps = "$localLocation\Apps"
Write-Host "The Operating System and Applications will be added from the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceOSFiles = "$netLocation\$OS\OSFiles"
$sourceOSStorage = "$netLocation\$OS\Storage"
$sourceApps = "$netLocation\Apps"
Write-Host "The Operating System and Applications will be added from the network store." -ForegroundColor Cyan }

#always copy scripts from Network Store
$sourceScripts = "$netLocation\Scripts"

$destinationApps = "$StoragePath\Apps"
$destinationOSFiles = "$OSFilesPath\"
$destinationOSStorage = "$StoragePath\"
$destinationScripts = "$StoragePath\Scripts"

Copy-Folder -source $sourceScripts  -destination $destinationScripts
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
Copy-Folder -source $sourceOSFiles  -destination $destinationOSFiles
Copy-Folder -source $sourceOSStorage  -destination $destinationOSStorage
Copy-Folder -source $sourceApps  -destination $destinationApps


#Handle AutoPilot To SKip this
if($site -eq "A"){Write-Host "Autopilot Deployment. No Package is Needed" -ForegroundColor Cyan
#Site - Display the AutoPilot
Add-Content $OSFilesPath\cussd.txt "Site :AutoPilot"}
else{

#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$site.cat"){
Copy-Item "$localLocation\Packages\$site.cat" -destination $StoragePath -recurse
Copy-Item "$localLocation\Packages\$site.ppkg" -destination $StoragePath -recurse
Write-Host "Package $site copied from the local store" -ForegroundColor Cyan }
else {
Copy-Item "$netLocation\Packages\$site.cat" -destination $StoragePath -recurse 
Copy-Item "$netLocation\Packages\$site.ppkg" -destination $StoragePath -recurse 
Write-Host "Package $site copied from the network store" -ForegroundColor Cyan }
#Site - Display the site name
Add-Content $OSFilesPath\cussd.txt "Site: $Site"
}
#Updated - read date on tech server
$packageCussed=Get-Content "$netLocation\packages\00Info.txt"
Add-Content G:\cussd.txt $packageCussed

#Add File so that you know what drivers these are
New-item -Path $StoragePath\$driverModel -Name "$driverModel.txt" -ItemType "file"

#System - Display OS Version and Build
$osVersionInfo=Get-Content "$OSFilesPath\$OS.txt"
Add-Content $OSFilesPath\cussd.txt $osVersionInfo

#Drivers - Display Driver information from tech server or local system
Add-Content $OSFilesPath\cussd.txt "Driver Model: $driverModel"

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $StoragePath\$driverModel){
Rename-Item "$StoragePath\$driverModel" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$StoragePath\Drivers\PE" -destination $StoragePath -Force -ErrorAction Ignore
Copy-Item "$StoragePath\Drivers\autounattend.xml" -destination $OSFilesPath -Force -ErrorAction Ignore
}
}
}
####################################################################################################################################
#Choice 2 Build a local store on C:\Intune
    elseif ($choice -eq "2") {
#Builds The Local Store specified in the variable aboe      
#Code for Yes or No menu with No as the default
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)
$title="Intune Drive Builder"
$localDirSetup = "Do you want to create a local Intune directory for faster creation? This will take some time to do!"
$result = $host.ui.PromptForChoice($title, $localDirSetup, $options, 1)
switch ($result) {
  0{
    Write-Host "Yes" -ForegroundColor Green
  }1{
    Write-Host "No" -ForegroundColor Red
  }2{
  Write-Host "Cancel" -ForegroundColor Red
  }
}

if($result -eq 0){
#Create $localLocation and also Delete Previous and Create a new Intune Directory
New-Item -Path "$localLocation" -ItemType Directory -ErrorAction Ignore
Remove-Item "$localLocation\Drivers" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\Apps" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\10" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\11" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\Packages" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\zzFresh.txt" -force -recurse -ErrorAction Ignore
Write-Host "Drivers, Apps, OS, and Packages have been cleared from the local store." -ForegroundColor DarkRed

#Input to get computer models for local directory
$localDriverModels= Read-Host -Prompt 'Input your models followed by commas (example 5330, 3120, NA)'

#Input your school sites followed by commas (3 digit code)
$localSites= Read-Host -Prompt 'Input your sites using commas (example RCV, CHM, SHS)'

#Copy listed drivers to $localLocation\Drivers
$localdriverarray= $localDriverModels.Replace(" ", "").Split(",")
foreach($localDriverModels in $localdriverarray){

$sourceDrivers = "$netLocation\Drivers\$localDriverModels"
Write-Host "$localDriverModels drivers will be added to your local store." -ForegroundColor Cyan

$destinationDrivers = "$localLocation\Drivers\$localDriverModels"
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
}
 
#Copies listed package files to $localLocation\Packages
New-Item -Path "$localLocation\Packages" -ItemType Directory
$sitearray= $localSites.Replace(" ", "").Split(",")
foreach ($localSites in $sitearray){
Copy-Item "$netLocation\Packages\$localSites.cat" -destination "$localLocation\Packages\$localSites.cat" -recurse
Copy-Item "$netLocation\Packages\$localSites.ppkg" -destination "$localLocation\Packages\$localSites.ppkg" -recurse
Write-Host "Site Package $LocalSites will be added local store" -ForegroundColor Cyan}
 
#Copy OS 10 to $localLocation\10
####################################################################################
#                                                                                  #
# Stop moving Windows 10 to local drive to increase creation speed                 #
#                                                                                  #
# If you need to use Windows to this can be added back by removing the comments    # 
#                                                                                  #
####################################################################################
#New-Item -Path "$localLocation\10" -ItemType Directory
#Copy-Item "$netLocation\10\*" -destination "$localLocation\10" -recurse -Container
#Write-Host "Windows 10 installation added to local store." -ForegroundColor Cyan

#Copy OS 11 to $localLocation\11
New-Item -Path "$localLocation\11" -ItemType Directory
$sourceOS = "$netLocation\11\"
Write-Host "Windows 11 will be added to local store." -ForegroundColor Cyan
$destinationOS = "$localLocation\11\"
Copy-Folder -source $sourceOS -destination $destinationOS

#Copy Apps to $localLocation\Apps
New-Item -Path "$localLocation\Apps" -ItemType Directory
$sourceApps = "$netLocation\Apps\"
Write-Host "Applications will be added to local store." -ForegroundColor Cyan
$destinationApps = "$localLocation\Apps\"
Copy-Folder -source $sourceApps -destination $destinationApps

#Create 180 File
Copy-Item -Path $netLocation\Packages\zzFresh.txt -destination $localLocation -recurse -force
Write-Host "Refresh file updated" -ForegroundColor Cyan
}
    }

####################################################################################################################################
#Choice 3 add additional drivers to  C:\Intune but NOT deleting the others.
  elseif ($choice -eq "3") {
#Code for Yes or No menu with No as the default
$yes3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no3 = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$cancel3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
$options3 = [System.Management.Automation.Host.ChoiceDescription[]]($yes3, $no3, $cancel3)
$title3="DriveBuilder Model Update"
$localDirSetup3 = "Do you want to add an additional model to your local store?"
$result3 = $host.ui.PromptForChoice($title3, $localDirSetup3, $options3, 1)
switch ($result3) {
  0{
    Write-Host "Yes" -ForegroundColor Green
  }1{
    Write-Host "No" -ForegroundColor Red
  }2{
  Write-Host "Cancel" -ForegroundColor Red
  }
}
if($result3 -eq 0){
#Add driver to local Intune location
#Input to get computer models for local directory
$localDriverModels3= Read-Host -Prompt 'Input your additional models followed by commas (example 3140, NA, 5000)'

#Copy listed drivers to $localLocation\Drivers
$localdriverarray3= $localDriverModels3.Replace(" ", "").Split(",")
foreach($localDriverModels3 in $localdriverarray3){

$sourceDrivers = "$netLocation\Drivers\$localDriverModels3"
Write-Host "$localDriverModels3 drivers will be added to your local store." -ForegroundColor Cyan

$destinationDrivers = "$localLocation\Drivers\$localDriverModels3"
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
} 
}
  }
####################################################################################################################################
#Choice 4 Replace site packages on the USB Drive
elseif ($choice -eq "4")
{
 $StoragePath = $null
$OSFilesPath = $null
#Find Storage Path
$Storage = "install.wim"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $Storage
    if (Test-Path $path) {
     $StoragePath = $drive
    }
}
#Find OSFiles Path
$OSFiles = "CUSSD.txt"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $OSFiles
    if (Test-Path $path) {
     $OSFilesPath = $drive
    }
}
# Check if $StoragePath was found
if ($StoragePath) {
    Write-Host "OSFiles = $OSFilesPath and Storage = $StoragePath" -ForegroundColor Cyan
   
#Code for Yes or No menu with No as the default
$yes4 = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no4 = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$cancel4 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
$options4 = [System.Management.Automation.Host.ChoiceDescription[]]($yes4, $no4, $cancel4)
$title4="Update the site packages on the USB"
$localDirSetup0 = "Do you just want to replace packages on your USB Drive?"
$result4 = $host.ui.PromptForChoice($title4, $localDirSetup4, $options4, 1)
switch ($result4)
 {
  0{
    Write-Host "Yes" -ForegroundColor Green
  }1{
    Write-Host "No" -ForegroundColor DarkRed
  }2{
  Write-Host "Cancel" -ForegroundColor DarkRed
  }
}
#Run a basic code to just copy package files
if($result4 -eq 0){
$stop= "$StoragePath\Apps\README.txt"
if(Test-Path $stop){
  Write-Host "You cannot perform this action on a domain joined drive. Please rebuild drive." -ForegroundColor Red
}else
{
#clear old drivers off USB Drive
Remove-Item "$StoragePath\*.ppkg" -force -recurse -ErrorAction Ignore
Remove-Item "$StoragePath\*.cat" -force -recurse -ErrorAction Ignore
Write-Host "Previous packages removed." -ForegroundColor Red

#Input to get site information 3 digit code
$site4= Read-Host -Prompt 'Input your Updated site (example WHS) or A for AutoPilot device' 

 #Handle AutoPilot To SKip this
if($site4 -eq "A"){Write-Host "Autopilot Deployment. No Package is Needed" -ForegroundColor Cyan
#Site - Display the AutoPilot
Add-Content $OSFilesPath\cussd.txt "Site (updated $(Get-Date)):AutoPilot"}
else{

#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$site4.cat"){
Copy-Item "$localLocation\Packages\$site4.cat" -destination $StoragePath -recurse
Copy-Item "$localLocation\Packages\$site4.ppkg" -destination $StoragePath -recurse
Write-Host "Package $site4 copied from the local store" -ForegroundColor Cyan }
else {
Copy-Item "$netLocation\Packages\$site4.cat" -destination $StoragePath -recurse 
Copy-Item "$netLocation\Packages\$site4.ppkg" -destination $StoragePath -recurse 
Write-Host "Package $site4 copied from the network store" -ForegroundColor Cyan }

#Site - Display the site name
Add-Content $OSFilesPath\cussd.txt "Site (updated $(Get-Date)): $Site4"
}
}
}
}
}

####################################################################################################################################
#Choice 5 replace drivers on USB Drive
 elseif ($choice -eq "5") {
$StoragePath = $null
$OSFilesPath = $null
#Find Storage Path
$Storage = "install.wim"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $Storage
    if (Test-Path $path) {
     $StoragePath = $drive
    }
}
#Find OSFiles Path
$OSFiles = "CUSSD.txt"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $OSFiles
    if (Test-Path $path) {
     $OSFilesPath = $drive
    }
}
# Check if $StoragePath was found
if ($StoragePath) {
    Write-Host "OSFiles = $OSFilesPath and Storage = $StoragePath" -ForegroundColor Cyan
#This will replace Drivers on the USB Drive.
#Code for Yes or No menu with No as the default
$yes5 = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no5 = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$cancel5 = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
$options5 = [System.Management.Automation.Host.ChoiceDescription[]]($yes5, $no5, $cancel5)
$title5="USB Driver Update"
$USBDirSetup5 = "Do you want to refresh Drivers on your USB Drive?"
$result5 = $host.ui.PromptForChoice($title5, $USBDirSetup5, $options5, 1)
switch ($result0)
 {
  0{
    Write-Host "Yes" -ForegroundColor Green
  }1{
    Write-Host "No" -ForegroundColor DarkRed
  }2{
  Write-Host "Cancel" -ForegroundColor DarkRed
  }
}
#Run a basic code to just copy drivers
if($result5 -eq 0){

#clear old drivers off USB Drive
Remove-Item "$StoragePath\Drivers" -force -recurse -ErrorAction Ignore
Remove-Item "$StoragePath\PE" -force -recurse -ErrorAction Ignore
Write-Host "Previous drivers have been removed." -ForegroundColor Red

#Input to get computer model for drivers or NA to get generic
$driverModel5= Read-Host -Prompt 'Input your new model for USB Drive (or NA if unknown)'

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$drivermodel5"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel5"
Write-Host "Drivers for the $driverModel5 will be added to your USB via the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel5"
Write-Host "Drivers for the $driverModel5 will be added to your USB via the network store." -ForegroundColor Cyan}

#set location of drivers on USB
$destinationDrivers = "$StoragePath\$driverModel5"

#copy using the progress bar
Copy-Folder -source $sourceDrivers -destination $destinationDrivers

#Add File so that you know what drivers these are
New-item -Path $StoragePath\$driverModel5 -Name "$driverModel5.txt" -ItemType "file"

#Drivers - Display New Driver information from tech server or local system
Add-Content $OSFilesPath\cussd.txt "Driver Model (updated $(Get-Date)): $driverModel5"}

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $StoragePath\$driverModel5){
Rename-Item "$StoragePath\$driverModel5" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$StoragePath\Drivers\PE" -destination $StoragePath -Force -ErrorAction Ignore
Copy-Item "$StoragePath\Drivers\autounattend.xml" -destination $OSFilesPath -Force -ErrorAction Ignore
}
}
}

####################################################################################################################################
#Choice 6 Check if the model is available
      elseif ($choice -eq "6") {
#Input to get computer models for local directory
$netDriverModels6= Read-Host -Prompt 'What model do you need'
If(Test-Path -Path $netLocation\Drivers\$netDriverModels6){
  Write-Host "Model is available" -ForegroundColor Cyan }
else{Write-Host "Model is not available" -ForegroundColor Red}
}

####################################################################################################################################
#Choice 7 Read CUSSD
      elseif ($choice -eq "7") {
      $StoragePath = $null
$OSFilesPath = $null
#Find Storage Path
$Storage = "install.wim"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $Storage
    if (Test-Path $path) {
     $StoragePath = $drive
    }
}
#Find OSFiles Path
$OSFiles = "CUSSD.txt"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $OSFiles
    if (Test-Path $path) {
     $OSFilesPath = $drive
    }
}
#Output OSFiles\Cussd.txt
Write-Host "Below is your CUSSD words" -ForegroundColor Yellow
Get-Content $OSFilesPath\cussd.txt
}

####################################################################################################################################
#Code A - This is nothing
elseif ($choice -eq "A") {
  Write-Host "A is also my favorite number" -ForegroundColor Cyan
}

####################################################################################################################################
#Choice D Use Domain Join package. This is seperated to give flexibitly that may be needed with 
# creating zero touch domain joined computers.
elseif ($choice -eq "D") {

Write-Host "This is an experimental feature. Please check before using this. 
If you create a drive using this you will need to completely rebuild the drive for any future use." -ForegroundColor Yellow

#Input to get computer model for drivers or NA to get generic
$driverModel= Read-Host -Prompt 'Input your model for USB Drive (or NA if unknown)'

#Set automatically to trigger domain package
$site= 'Domain'

#Input to get OS version or Automatic Windows 11 
#$OS= Read-Host -Prompt 'Input OS Choice (11 or 10)'
#Automatically 11 but will retain menu for future builds
$OS= 11

#stop hardware detection
Stop-Service -Name ShellHWDetection
#Format USB Drive. Make sure you do not have any other drives or partitions on this system beyond the 1 OS partition
Clear-Disk -Number 1 -RemoveData -Confirm:$false
Start-Sleep -s 1
New-Partition -DiskNumber 1 -Size 1.5GB -IsActive -DriveLetter G
Start-Sleep -s 1
Format-Volume -DriveLetter G -FileSystem FAT32 -NewFileSystemLabel OSFiles
Start-Sleep -s 1
New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter Z
Start-Sleep -s 1
Format-Volume -DriveLetter Z -FileSystem NTFS -NewFileSystemLabel storage
Start-Sleep -s 1
#Start Hardware Detection
Start-Service -Name ShellHWDetection

#set USB drive variables
$StoragePath = "Z:"
$OSFilesPath = "G:"
if ($StoragePath) {
    Write-Host "OSFiles = $OSFilesPath and Storage = $StoragePath" -ForegroundColor Cyan

#Create Info File = Created, Updated, Site, System, Drivers
New-Item -Path $OSFilesPath\ -Name "CUSSD.txt" -Verbose
Add-Content $OSFilesPath\cussd.txt "Drive Created"
Add-Content $OSFilesPath\cussd.txt -Value (Get-Date)

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$drivermodel"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the network store." -ForegroundColor Cyan}
$destinationDrivers = "$StoragePath\$driverModel"

#Copy Apps and OS
if(Test-Path -Path "$localLocation\$OS"){
# copy from local store
$sourceOSFiles = "$localLocation\$OS\OSFiles"
$sourceOSStorage = "$localLocation\$OS\Storage"
$sourceApps = "$localLocation\Apps"
Write-Host "The Operating System will be added from the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceOSFiles = "$netLocation\$OS\OSFiles"
$sourceOSStorage = "$netLocation\$OS\Storage"
$sourceApps = "$netLocation\Apps"
Write-Host "The Operating System will be added from the network store." -ForegroundColor Cyan }

$destinationApps = "$StoragePath\Apps"
$destinationOSFiles = "$OSFilesPath\"
$destinationOSStorage = "$StoragePath\"

Copy-Folder -source $sourceDrivers -destination $destinationDrivers
Copy-Folder -source $sourceOSFiles  -destination $destinationOSFiles
Copy-Folder -source $sourceOSStorage  -destination $destinationOSStorage

#Updated - read date on tech server
$packageCussed=Get-Content "$netLocation\packages\00Info.txt"
Add-Content $OSFilesPath\cussd.txt $packageCussed

#Add File so that you know what drivers these are
New-item -Path $StoragePath\$driverModel -Name "$driverModel.txt" -ItemType "file"

#Drivers - Display Driver information from tech server or local system
Add-Content $OSFilesPath\cussd.txt "Driver Model: $driverModel"

#Create Directory Apps on $StoragePath
New-Item -Path "$StoragePath\Apps" -ItemType Directory

#Copy Domain Joined Packages. Network Copy Only
Copy-Item "$netLocation\Domain\$site.cat" -destination $StoragePath -recurse 
Copy-Item "$netLocation\Domain\$site.ppkg" -destination $StoragePath -recurse
Write-Host "$site package copied from the network store" -ForegroundColor Cyan
#Site - Display the site name
Add-Content G:\cussd.txt "Site: $Site"

#create a READ ME No additional software at this time
New-Item -Path $StoragePath\Apps -Name "README.txt" -Verbose
Add-Content $StoragePath\Apps\README.txt "Domain Join package. There are no applications added."
Copy-Item "$netLocation\Apps\Remove-BuiltInApps.ps1" -destination $StoragePath\Apps -Force -ErrorAction Ignore

#System - Display OS Version and Build
$osVersionInfo=Get-Content "$OSFilesPath\$OS.txt"
Add-Content $OSFilesPath\cussd.txt $osVersionInfo

#Change name to Drivers and move PE Drivers to the root
If(Test-Path -Path $StoragePath\$driverModel){
Rename-Item "$StoragePath\$driverModel" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$StoragePath\Drivers\PE" -destination $StoragePath -Force -ErrorAction Ignore
Copy-Item "$StoragePath\Drivers\autounattend.xml" -destination $OSFilesPath -Force -ErrorAction Ignore
}
}
}
####################################################################################################################################
#Choice B for use by Intune Deployment Team 

### Better Option is in 1. This will probably be deleted####
elseif ($choice -eq "B")
{
 $StoragePath = $null
$OSFilesPath = $null
#Find Storage Path
$Storage = "install.wim"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $Storage
    if (Test-Path $path) {
     $StoragePath = $drive
    }
}
#Find OSFiles Path
$OSFiles = "CUSSD.txt"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $OSFiles
    if (Test-Path $path) {
     $OSFilesPath = $drive
    }
}
# Check if $StoragePath was found
if (Test-Path $StoragePath\Scripts) {
   Write-Host "Welcome Intune Deployment Team!" -ForegroundColor DarkRed
   Write-Host "OSFiles = $OSFilesPath and Storage = $StoragePath" -ForegroundColor Cyan
  #set location Scripts
$scripts = "$netLocation\Scripts"
#copy using the progress bar
Copy-Folder -source $scripts -destination $StoragePath\Scripts
Write-Host "Hardware Hash Scripts copied from the network store" -ForegroundColor Yellow
}
}
####################################################################################################################################
#Choice X Code the exit
 elseif ($choice -eq "X") {
        break; # Exit the loop and end the script
 }
   else {
 Write-Host "Not a valid choice. Try again." -ForegroundColor Red 
 }
} while ($true) # Loop back to the main menu after each task completes until option 7 selected

####################################################################################################################################
#the end for everything
Write-Host "Bye Bye!" -ForegroundColor Blue
Stop-Transcript