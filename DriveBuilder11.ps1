####################################################################################################################################
#PS Ver	1 Matthew Brown (brownma@rcschools.net) with help from Brad Barnes and Chase Frazier (built 2017)
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
#PS ver 11 Functions added to reduce code, Domain Join removed, New package coding to reflect new style packaging,CUSSD=CDIT
####################################################################################################################################
#PS CDIT = Custom Drive Information...Thingy
#PS Needed = Merge zzfresh and 00info - This will be used with auto-rebuild and CDIT. Code adjustments will have to be fixed in 1, 2, 4, and 5
####################################################################################################################################
#Log File to see the magic
Start-Transcript -Append C:\Temp\IntuneDrive.log
####################################################################################################################################
#set variable for network location
$netLocation = "\\tech.rcs.k12.tn.us\intune$"
#set variable for local location
$localLocation = "C:\Intune"
###################################################################################################################################
#Rebuild Local Store Function automatically
function Set-LocalStore {

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
$localDriverModels= Read-Host -Prompt 'Input your models followed by commas (example 5330,3120,NA)'
$localPackages= "Student,Staff,Support"

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
$packagearray= $localPackages.Replace(" ", "").Split(",")
foreach ($localPackages in $packagearray){
Copy-Item "$netLocation\Packages\$localPackages.cat" -destination "$localLocation\Packages\$localPackages.cat" -recurse
Copy-Item "$netLocation\Packages\$localPackages.ppkg" -destination "$localLocation\Packages\$localPackages.ppkg" -recurse
Write-Host "Package: $localPackages will be added local store" -ForegroundColor Cyan}
 
#Copy OS 10 to $localLocation\10
###This no longer happens but can be used for later OS Forks
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
Copy-Item -Path $netLocation\zzFresh.txt -destination $localLocation -recurse -force
Write-Host "Refresh file updated" -ForegroundColor Cyan
}

####################################################################################################################################
#storageDriveScan Function
function storageDriveScan {
  param(
  [string]$StoragePath
  )
 $StoragePath = $null

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
return $StoragePath
}

####################################################################################################################################
#USBDriveScan Function
function OSDriveScan {
  param(
  [string]$OSFilesPath
  )
 
$OSFilesPath = $null
#Find OSFiles Path
$OSFiles = "CDIT.txt"
# Get all drive letters
$driveLetters = Get-WmiObject Win32_LogicalDisk | Select-Object -ExpandProperty DeviceID
# Iterate through each drive letter
 foreach ($drive in $driveLetters) {
    $path = Join-Path -Path $drive -ChildPath $OSFiles
    if (Test-Path $path) {
     $OSFilesPath = $drive
    }
 }
return $OSFilesPath
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
#Yes or No Menu
function Yes-NoMenu {param(
        [string]$YesOption = "Yes",
        [string]$NoOption = "No"
    )
    Write-Host "Y - $YesOption" -ForegroundColor Green
    Write-Host "N - $NoOption" -ForegroundColor Red

    $choice = Read-Host "Enter your choice"
    switch ($choice) {
        'Y' { return 1 }
        'N' { return 2 }
        default { 2 }
    }
}

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

 if(($freshOrExpired | Select -ExpandProperty Days) -lt 180){Write-Host "LOCAL STORE is valid" -ForegroundColor Green}
  else{
  Write-Host "LOCAL STORE is out of date and will now be rebuilt (C:\INTUNE)" -ForegroundColor Yellow
  Set-LocalStore
  }
}

####################################################################################################################################
#Main Menu
do {
Write-Host "Are you running this as Administrator?  Please choose an option:" -ForegroundColor DarkCyan
Write-Host "1- Build New Drive"
Write-Host "2- Rebuild Local Store"
Write-Host "3- Add Drivers to Local Store"
Write-Host "4- Change Package Class on USB Drive"
Write-Host "5- Change Drivers on USB Drive"
Write-Host "6- Check if the model is available"
Write-Host "7- Display Drive Information"
Write-Host "X- Exit" -ForegroundColor DarkRed
$choice = Read-Host "Enter your choice"

####################################################################################################################################
#Choice 1 Build New Drive
if ($choice -eq "1") {

#Choose package class
$package= Read-Host -Prompt 'Please select package class: Staff, Student, Support, or ?'
#New for ? trigger and replace AutoPilot
if($package -eq "?"){
  Write-Host "Staff = School Staff, Staff Shared, Nurse Staff, Cafe Manager, It Staff" -ForegroundColor Green
  Write-Host "Student = ES Student, MS Student, HS Student, Drivers Ed, and Restricted Student" -ForegroundColor Green
  Write-Host "Support = FLW, Serving Line, Kiosk" -ForegroundColor Green
}
else{

#Input to get OS version or Automatic Windows 11 
#$OS= Read-Host -Prompt 'Input OS Choice (11 or 10)'
$OS= 11
#Input to get computer model for drivers or NA to get generic
$driverModel= Read-Host -Prompt 'Input your model for USB Drive (or NA if unknown)'  

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
$Storage = "Z:"
$OSFiles = "G:"
if ($Storage) {
    Write-Host "OSFiles = $OSFiles and Storage = $Storage" -ForegroundColor Cyan

#Create Info File
New-Item -Path $OSFiles\ -Name "CDIT.txt" -Verbose
Add-Content $OSFiles\CDIT.txt "Drive Created"
Add-Content $OSFiles\CDIT.txt -Value (Get-Date)   

#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$package.cat"){
Copy-Item "$localLocation\Packages\$package.cat" -destination $Storage -recurse
Copy-Item "$localLocation\Packages\$package.ppkg" -destination $Storage -recurse
Write-Host "Package $package copied from the local store" -ForegroundColor Cyan }
else {
Copy-Item "$netLocation\Packages\$package.cat" -destination $Storage -recurse 
Copy-Item "$netLocation\Packages\$package.ppkg" -destination $Storage -recurse 
Write-Host "Package $package copied from the network store" -ForegroundColor Cyan }
#Package - Display the Package name
Add-Content $OSFiles\CDIT.txt "Package: $package"

#Create Directories Apps and Scripts on $Storage
New-Item -Path "$Storage\Apps" -ItemType Directory
New-Item -Path "$Storage\Scripts" -ItemType Directory

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$drivermodel"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the local store." -ForegroundColor Cyan }
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the network store." -ForegroundColor Cyan}
$destinationDrivers = "$Storage\$driverModel"

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

$destinationApps = "$Storage\Apps"
$destinationOSFiles = "$OSFiles\"
$destinationOSStorage = "$Storage\"
$destinationScripts = "$Storage\Scripts"

Copy-Folder -source $sourceScripts  -destination $destinationScripts
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
Copy-Folder -source $sourceOSFiles  -destination $destinationOSFiles
Copy-Folder -source $sourceOSStorage  -destination $destinationOSStorage
Copy-Folder -source $sourceApps  -destination $destinationApps

#Updated - read date on tech server
$packageCDIT=Get-Content "$netLocation\00Info.txt"
Add-Content G:\CDIT.txt $packageCDIT

#Add File so that you know what drivers these are
New-item -Path $Storage\$driverModel -Name "$driverModel.txt" -ItemType "file"

#System - Display OS Version and Build
$osVersionInfo=Get-Content "$OSFiles\$OS.txt"
Add-Content $OSFiles\CDIT.txt $osVersionInfo
#Drivers - Display Driver information from tech server or local system
Add-Content $OSFiles\CDIT.txt "Driver Model: $driverModel"

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $Storage\$driverModel){
Rename-Item "$Storage\$driverModel" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$Storage\Drivers\PE" -destination $Storage -Force -ErrorAction Ignore
Copy-Item "$Storage\Drivers\autounattend.xml" -destination $OSFiles -Force -ErrorAction Ignore
    }
   }
  }
}

####################################################################################################################################
#Choice 2 Build a local store on C:\Intune
    elseif ($choice -eq "2") {
    #Builds The Local Store specified in the variable 
#Call Yes-NoMenu Function
Write-host "Confirm you want to rebuild your LOCAL STORE. This will take some time" -ForegroundColor Yellow
$result = Yes-NoMenu

#trigger rebuild
if($result -eq 1){Write-host "Updating Local Intune"
Set-LocalStore}
else{Write-host "Cancel" -ForegroundColor Red }
  }

####################################################################################################################################
#Choice 3 add additional drivers to  C:\Intune but NOT deleting the others.
  elseif ($choice -eq "3") {
#Call Yes-NoMenu Function
Write-host "Confirm you want to add an additional model to your local store" -ForegroundColor Yellow
$result = Yes-NoMenu

#trigger addition of files
if($result -eq 1){
#Add driver to local Intune location
#Input to get computer models for local directory
$localDriverModels3= Read-Host -Prompt 'Input your additional models followed by commas (example 3140,NA,5000)'

#Copy listed drivers to $localLocation\Drivers
$localdriverarray3= $localDriverModels3.Replace(" ", "").Split(",")
foreach($localDriverModels3 in $localdriverarray3){

$sourceDrivers = "$netLocation\Drivers\$localDriverModels3"
Write-Host "$localDriverModels3 drivers will be added to your local store." -ForegroundColor Cyan

$destinationDrivers = "$localLocation\Drivers\$localDriverModels3"
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
} 
}
else{Write-host "Cancel" -ForegroundColor Red }
  }

####################################################################################################################################
#Choice 4 Replace class package on the USB Drive
elseif ($choice -eq "4"){
#Trigger USB Drive Scan Function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -ForegroundColor Cyan
#This will replace Drivers on the USB Drive.
#Trigger Yes or No Menu
Write-Host "Confirm you want to replace packages on your USB Drive" -ForegroundColor Yellow
$result = Yes-NoMenu

#Run a basic code to just copy drivers
if($result -eq 1)
{
$stop= "$Storage\Apps\README.txt"
if(Test-Path $stop){
  Write-Host "You cannot perform this action on a domain joined drive. Please rebuild drive." -ForegroundColor Red
}else
{
#clear old drivers off USB Drive
Remove-Item "$Storage\*.ppkg" -force -recurse -ErrorAction Ignore
Remove-Item "$Storage\*.cat" -force -recurse -ErrorAction Ignore
Write-Host "Previous packages removed." -ForegroundColor Red

#Choose package class
$package= Read-Host -Prompt 'Please select package class: Staff, Student, Support, or ?'

#New for ? trigger and replace AutoPilot
if($package -eq "?"){
  Write-Host "Staff = School Staff, Staff Shared, Nurse Staff, Cafe Manager, It Staff" -ForegroundColor Green
  Write-Host "Student = ES Student, MS Student, HS Student, Drivers Ed, and Restricted Student" -ForegroundColor Green
  Write-Host "Support = FLW, Serving Line, Kiosk" -ForegroundColor Green
}
else{

#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$package.cat"){
Copy-Item "$localLocation\Packages\$package.cat" -destination $Storage -recurse
Copy-Item "$localLocation\Packages\$package.ppkg" -destination $Storage -recurse
Write-Host "Package $package copied from the local store" -ForegroundColor Cyan }
else {
Copy-Item "$netLocation\Packages\$package.cat" -destination $Storage -recurse 
Copy-Item "$netLocation\Packages\$package.ppkg" -destination $Storage -recurse 
Write-Host "Package $package copied from the network store" -ForegroundColor Cyan }

#Package - Display the Package name
$filePath = "$OSFiles\CDIT.txt"
$wordToMatch = "Package"
$content = Get-Content $filePath
# Filter out the lines that start with the specified word
$filteredContent = $content | Where-Object { -not ($_ -match "^$wordToMatch") }
# Write the filtered content back to the file
$filteredContent | Set-Content $filePath
Add-Content $filePath "Package Class: (updated $(Get-Date)):  $package"}
}
}
}

####################################################################################################################################
#Choice 5 replace drivers on USB Drive
 elseif ($choice -eq "5") {
#Trigger USB Drive Scan Function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -ForegroundColor Cyan
#This will replace Drivers on the USB Drive.
#Trigger Yes or No Menu
Write-host "Confirm you want to replace the drivers on USB Storage" -ForegroundColor Yellow
$result = Yes-NoMenu

#Run a basic code to just copy drivers
if($result -eq 1){

#clear old drivers off USB Drive
Remove-Item "$Storage\Drivers" -force -recurse -ErrorAction Ignore
Remove-Item "$Storage\PE" -force -recurse -ErrorAction Ignore
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
$destinationDrivers = "$Storage\$driverModel5"

#copy using the progress bar
Copy-Folder -source $sourceDrivers -destination $destinationDrivers

#Add File so that you know what drivers these are
New-item -Path $Storage\$driverModel5 -Name "$driverModel5.txt" -ItemType "file"

#Drivers - Display New Driver information from tech server or local system
$filePath = "$OSFiles\CDIT.txt"
$wordToMatch = "Driver"
$content = Get-Content $filePath
# Filter out the lines that start with the specified word
$filteredContent = $content | Where-Object { -not ($_ -match "^$wordToMatch") }
# Write the filtered content back to the file
$filteredContent | Set-Content $filePath
Add-Content $filePath "Driver Model (updated $(Get-Date)): $driverModel5"}

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $Storage\$driverModel5){
Rename-Item "$Storage\$driverModel5" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$Storage\Drivers\PE" -destination $Storage -Force -ErrorAction Ignore
Copy-Item "$Storage\Drivers\autounattend.xml" -destination $OSFiles -Force -ErrorAction Ignore
}
}

####################################################################################################################################
#Choice 6 Check if the model is available
   elseif ($choice -eq "6") {
#Input to get computer models for local directory
$netDriverModels= Read-Host -Prompt 'What model do you need'
If(Test-Path -Path $netLocation\Drivers\$netDriverModels){
  Write-Host "Model is available" -ForegroundColor Cyan }
else{Write-Host "Model is not available" -ForegroundColor Red}
}

####################################################################################################################################
#Choice 7 Read CDIT
      elseif ($choice -eq "7") {
#Trigger USB Drive Scan function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -ForegroundColor Cyan
#Output OSFiles\CDIT.txt
Write-Host "Behold! The CDIT File!" -ForegroundColor Magenta
Get-Content $OSFiles\CDIT.txt
}

####################################################################################################################################
#Code A - This is nothing
elseif ($choice -eq "A") {
  Write-Host "A is also my favorite number" -ForegroundColor Gray
}

####################################################################################################################################
#Choice X Code the exit
 elseif ($choice -eq "X"){ 
        break; # Exit the loop and end the script
   }
   else {
   Write-Host "Not a valid choice. Try again." -ForegroundColor Red 
   }
}while ($true) # Loop back to the main menu after each task completes until option 7 selected

####################################################################################################################################
#the end for everything
Write-Host "Bye Bye!" -ForegroundColor Blue
Stop-Transcript