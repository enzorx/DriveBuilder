####################################################################################################################################
#PS Ver	1 Matthew Brown with help from Brad Barnes and Chase Frazier
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
#PS ver 12 New Fresh file, Fixed USB Scan, added repeat on option 1. New Option 2 for automatic patching
#PS ver Next - CK to create Check files
####################################################################################################################################
#Log File to see the magic
Start-Transcript -Append C:\Temp\DriveBuilder.log
####################################################################################################################################
#set variable for network location
$netLocation = 
#set variable for local location
$localLocation = 

###################################################################################################################################
#Rebuild Local Store Function automatically
function Set-LocalStore {

#Create $localLocation and also Delete Previous and Create a new Intune Directory
New-Item -Path "$localLocation" -ItemType Directory -ErrorAction Ignore
Remove-Item "$localLocation\Drivers" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\Apps" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\11" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\Packages" -force -recurse -ErrorAction Ignore
Remove-Item "$localLocation\Fresh.txt" -force -recurse -ErrorAction Ignore
Write-Host "Drivers, Apps, OS, and Packages have been cleared from the local store." -ForegroundColor Blue

do {
#Input to get computer models for local directory
$localDriverModels= Read-Host -Prompt 'Input your models followed by commas (example 5330, 3120, NA)'
# blank input 
    if ([string]::IsNullOrEmpty($localDriverModels)) {
        Write-Host "You forgot to enter any models. Try again" -ForegroundColor Yellow
    }
} until (-not [string]::IsNullOrEmpty($localDriverModels))

$localPackages= "Student,Staff,Support"
#Copy listed drivers to $localLocation\Drivers
$localdriverarray= $localDriverModels.Replace(" ", "").Split(",")
foreach($localDriverModels in $localdriverarray){

if(Test-Path -Path "$netLocation\Drivers\$localDriverModels"){

$sourceDrivers = "$netLocation\Drivers\$localDriverModels"
Write-Host "$localDriverModels drivers will be added to your local store." -Foreground Green

$destinationDrivers = "$localLocation\Drivers\$localDriverModels"
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
 }
else{Write-Host "$localDriverModels Not a valid model"}
}
 
#Copies listed package files to $localLocation\Packages
New-Item -Path "$localLocation\Packages" -ItemType Directory
$packagearray= $localPackages.Replace(" ", "").Split(",")
foreach ($localPackages in $packagearray){
Copy-Item "$netLocation\Packages\$localPackages.cat" -destination "$localLocation\Packages\$localPackages.cat" -recurse
Copy-Item "$netLocation\Packages\$localPackages.ppkg" -destination "$localLocation\Packages\$localPackages.ppkg" -recurse
Write-Host "Package: $localPackages will be added local store" -Foreground Green}
 
#Copy OS 11 to $localLocation\11
New-Item -Path "$localLocation\11" -ItemType Directory
$sourceOS = "$netLocation\11\"
Write-Host "Windows 11 will be added to local store." -Foreground Green
$destinationOS = "$localLocation\11\"
Copy-Folder -source $sourceOS -destination $destinationOS

#Copy Apps to $localLocation\Apps
New-Item -Path "$localLocation\Apps" -ItemType Directory
$sourceApps = "$netLocation\Apps\"
Write-Host "Applications will be added to local store." -Foreground Green
$destinationApps = "$localLocation\Apps\"
Copy-Folder -source $sourceApps -destination $destinationApps

#Create Fresh File
$Freshfile = "$localLocation\Fresh.txt"
# Get the current date
$currentDate = Get-Date -Format "yyyy-MM-dd"
# Write the date to the file
$currentDate | Out-File -FilePath $Freshfile -Encoding UTF8

Write-Host "Fresh File Created"
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
#OSDriveScan Function
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
        [int]$PercentComplete,
        [int]$Width = 50 
    )
    $completedLength = [math]::Ceiling(($PercentComplete / 100) * $Width)
    $remainingLength = $Width - $completedLength
    #dots progress bar...this can be changed
$progressBar = "[" + ("|" * $completedLength) + (" " * $remainingLength) + "]"
#new progress bar
   Write-Host "`r$progressBar $PercentComplete% Complete" -NoNewline

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
#Yes or No Menu Function
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
#Choose Package Function
function Choose-Package { 
  param(
    [string]$PackagePath
  )
  #add your package names here
  Write-Host "example 1"
  Write-Host "example 2" 

  # Loop until a valid input is provided
  do {
    $input = Read-Host -Prompt 'Please select a package'
    if ([string]::IsNullOrEmpty($input)) {
      Write-Host "You forgot to enter a package. Try again" -ForegroundColor Yellow
    } else {
      $PackagePath = $input  # Set the parameter only if input is valid
    }
  } until (-not [string]::IsNullOrEmpty($input))
  # Optional: Return the selected package path if desired
  return $PackagePath
}

####################################################################################################################################
#Choose Driver Function
function Choose-Driver { 
  param(
    [string]$driverPath
  )
#Input to get computer model for drivers
## Loop until a valid input is provided
do
{
$driverinput= Read-Host -Prompt 'Input your model'

if ([string]::IsNullOrEmpty($driverinput)) {
        Write-Host "You forgot to enter a model. Try again." -ForegroundColor Yellow
    }
} until (-not [string]::IsNullOrEmpty($driverinput))
$driverPath = $driverinput
return $driverPath
}

####################################################################################################################################
#used to build drive and control the format plus the drive letters
function FormatUSB {
    Start-Sleep -Seconds 2 
    #rescan hardware
    echo rescan | diskpart

    # Stop hardware detection
    Stop-Service -Name ShellHWDetection

    # Format USB Drive
    Clear-Disk -Number 1 -RemoveData -Confirm:$false
    Start-Sleep -Seconds 1
    New-Partition -DiskNumber 1 -Size 1.5GB -IsActive -DriveLetter G
    Start-Sleep -Seconds 1
    Format-Volume -DriveLetter G -FileSystem FAT32 -NewFileSystemLabel OSFiles
    Start-Sleep -Seconds 1
    New-Partition -DiskNumber 1 -UseMaximumSize -DriveLetter Z
    Start-Sleep -Seconds 1
    Format-Volume -DriveLetter Z -FileSystem NTFS -NewFileSystemLabel storage
    Start-Sleep -Seconds 1

    # Start hardware detection
    Start-Service -Name ShellHWDetection
}

####################################################################################################################################
#Check for Fresh file
If(Test-Path -Path $localLocation\Fresh.txt){
 $packageDate = Get-Content $localLocation\Fresh.txt 
 #Get the current date.
 $currentDate = Get-Date -format "yyyy-MM-dd"
 $packageDateObj = [DateTime]::ParseExact($packageDate, "yyyy-MM-dd", $null)
 $currentDateObj = [DateTime]::ParseExact($currentDate, "yyyy-MM-dd", $null)
 #Subtraction ...so much algebra? Is this algebra? 
 $freshOrExpired = $currentDateObj - $packageDateObj

 if(($freshOrExpired | Select -ExpandProperty Days) -lt 364){Write-Host "LOCAL STORE is valid" -ForegroundColor Green}
  else{
  Write-Host "LOCAL STORE has not been rebuilt in the last year. Rebuilding Now." -ForegroundColor Red
  Set-LocalStore
  } 
}

####################################################################################################################################
#Main Menu
do {
Write-Host ""
Write-Host "Are you running this as Administrator?" -ForegroundColor Yellow
Write-Host "Please choose an option:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1- Build New Drive"
Write-Host "2- Patch Local Store"
Write-Host "3- Create Local Store"
Write-Host "4- Add Drivers to Local Store"
Write-Host "5- Change Package on USB Drive"
Write-Host "6- Change Drivers on USB Drive"
Write-Host "7- Check if the Drivers for a Model are available"
Write-Host "8- Display Drive Information"
Write-Host "X- Exit" -ForegroundColor Red
$choice = Read-Host "Enter your choice"

####################################################################################################################################
#Choice 1 Build New Drive
if ($choice -eq "1") {

#Trigger Package Class function
$Package = Choose-Package $PackagePath
Write-Host "$Package package selected" -ForegroundColor Blue

#$OS= Read-Host -Prompt 'Input OS Choice (11 or 10)'
$OS= 11

#Trigger Choose Driver function
$driverModel = Choose-Driver $driverPath
if(Test-Path -Path "$netLocation\Drivers\$driverModel"){
Write-Host "$driverModel model selected" -ForegroundColor Blue

$loop = "1"
#loop code to repeat 
while ($loop -eq 1) 
{

#Call FormatUSB Function
FormatUSB

#Catch Break for Format
if(Test-Path -Path G:\){

#set USB drive variables
$Storage = "Z:"
$OSFiles = "G:"
if ($Storage) {
    Write-Host "OSFiles = $OSFiles and Storage = $Storage" -Foreground Blue

#Create Info File
New-Item -Path $OSFiles\ -Name "CDIT.txt" -Verbose
$CDITFile = "$OSFiles\CDIT.txt"
$currentDateTime = Get-Date
$formattedCurrentDateTime = $currentDateTime.ToString("yyyy-MM-dd HH:mm")
Add-Content -Path $CDITFile -Value "Drive Created: $formattedCurrentDateTime"
   
#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$package.cat"){
Copy-Item "$localLocation\Packages\$package.cat" -destination $Storage -recurse
Copy-Item "$localLocation\Packages\$package.ppkg" -destination $Storage -recurse
Write-Host "Package $package copied from the local store" -Foreground Green }
else {
Copy-Item "$netLocation\Packages\$package.cat" -destination $Storage -recurse 
Copy-Item "$netLocation\Packages\$package.ppkg" -destination $Storage -recurse 
Write-Host "Package $package copied from the network store" -Foreground Green }
#Package - Display the Package name
Add-Content -Path $CDITFile -Value "Package: $package"

#Create Directories Apps and Scripts on $Storage
New-Item -Path "$Storage\Apps" -ItemType Directory
New-Item -Path "$Storage\Scripts" -ItemType Directory

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$drivermodel"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the local store." -Foreground Green }
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel"
Write-Host "Drivers for the $driverModel will be added to your USB via the network store." -Foreground Green}
$destinationDrivers = "$Storage\$driverModel"

#Copy Apps and OS
if(Test-Path -Path "$localLocation\$OS"){
# copy from local store
$sourceOSFiles = "$localLocation\$OS\OSFiles"
$sourceOSStorage = "$localLocation\$OS\Storage"
$sourceApps = "$localLocation\Apps"
Write-Host "The Operating System and Applications will be added from the local store." -Foreground Green }
# copy from network store
else { 
$sourceOSFiles = "$netLocation\$OS\OSFiles"
$sourceOSStorage = "$netLocation\$OS\Storage"
$sourceApps = "$netLocation\Apps"
Write-Host "The Operating System and Applications will be added from the network store." -Foreground Green }

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

$wimFile = "Z:\install.wim"
$packageCheckFile = "$netLocation\Packages\chk.id12"

#Packages - Get the last modified date of chkid file for package
if (Test-Path $packageCheckFile) {
$modifiedDate0 = (Get-Item $packageCheckFile).LastWriteTime
$formattedDate0 = $modifiedDate0.ToString("yyyy-MM-dd")
$expiryDate = $modifiedDate0.AddDays(179)
$formattedExpiryDate = $expiryDate.ToString("yyyy-MM-dd")
Add-Content -Path $CDITFile -Value "Packages Created: $formattedDate0 /Expire: $formattedExpiryDate"
}

#Add File so that you know what drivers these are
New-item -Path $Storage\$driverModel -Name "$driverModel.txt" -ItemType "file"

#System - Get the last modified date of the install.wim file
if (Test-Path $wimFile) {
$modifiedDate = (Get-Item $wimFile).LastWriteTime
$formattedDate = $modifiedDate.ToString("yyyy-MM-dd")
Add-Content $CDITFile "OS Patched: $formattedDate"
}
#Drivers - Display Driver information from file server or local system
Add-Content $CDITFile "Model $driverModel"

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $Storage\$driverModel){
Rename-Item "$Storage\$driverModel" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$Storage\Drivers\PE" -destination $Storage -Force -ErrorAction Ignore
Copy-Item "$Storage\Drivers\autounattend.xml" -destination $OSFiles -Force -ErrorAction Ignore
    }
  }
#end of test path G: loop
}
  #prompt to loop again
write-Host "Would you like to build another with the same values?" -ForegroundColor Yellow
$loop = Yes-NoMenu
#end of loop
}
#end of driver check
 } 
 else{Write-Host "$driverModel is not a valid model" -ForegroundColor Red}

#end of choice 1
}

####################################################################################################################################
#Choice 2 Patch My Drive
  elseif ($choice -eq "2") {

#Call Yes-NoMenu Function to update local store
Write-Host "Do you want to check\update OS and Apps found on your local store?" -ForegroundColor Yellow
$result = Yes-NoMenu

#trigger chkid scan on local store
if($result -eq 1){Write-host "Updating local store"
# Define paths to chk.id12
$chkFileAppNet = "$netLocation\Apps\chk.id12"
$chkFileAppLocal = "$localLocation\Apps\chk.id12"
$chkFileOSNet = "$netLocation\11\Storage\chk.id12"
$chkFileOSLocal = "$localLocation\11\Storage\chk.id12"

# Check and update Apps
if (Test-Path $chkFileAppLocal) {
    $hashAppNet = Get-FileHash $chkFileAppNet -Algorithm SHA256
    $hashAppLocal = Get-FileHash $chkFileAppLocal -Algorithm SHA256

    if ($hashAppNet.Hash -ne $hashAppLocal.Hash) {
        Write-Host "Updating local Apps folder" -ForegroundColor Green
        # Remove old local Apps folder
        Remove-Item "$localLocation\Apps" -Recurse -Force -ErrorAction Ignore
        # Recreate and copy from network
        New-Item -Path "$localLocation\Apps" -ItemType Directory -Force
        Copy-Item "$netLocation\Apps\*" -Destination "$localLocation\Apps" -Recurse -Force
        Write-Host "Local Apps folder updated from network." -ForegroundColor Blue
    } else {
        Write-Host "No App updates available." -ForegroundColor Blue
    }
} else {
    Write-Host "App chk.id12 file is missing. Skipping comparison." -ForegroundColor Red
}
# Check and update OS
if (Test-Path $chkFileOSLocal) {
    $hashOSNet = Get-FileHash $chkFileOSNet -Algorithm SHA256
    $hashOSLocal = Get-FileHash $chkFileOSLocal -Algorithm SHA256

    if ($hashOSNet.Hash -ne $hashOSLocal.Hash) {
        Write-Host "Updating local OS install file" -ForegroundColor Green
        # Remove old local OS folder
        Remove-Item "$localLocation\11\Storage" -Recurse -Force -ErrorAction Ignore
        # Recreate and copy from network
        New-Item -Path "$localLocation\11\Storage" -ItemType Directory -Force
        Copy-Item "$netLocation\11\Storage\*" -Destination "$localLocation\11\Storage" -Recurse -Force
        Write-Host "OS file updated from network." -ForegroundColor Blue
    } else {
        Write-Host "No OS updates available." -ForegroundColor Blue
    }
} else {
    Write-Host "App chk.id12 file is missing. Skipping comparison." -ForegroundColor Red
}

}
else{Write-host "Cancel" -ForegroundColor Red }

#Call Yes-NoMenu Function to Drivers
Write-Host "Do you want to check for updated Drivers for your local store?" -ForegroundColor Yellow
$result = Yes-NoMenu

#trigger chkid on local Drivers
if($result -eq 1){
$netDriversPath = "$netLocation\Drivers"
$localDriversPath = "$localLocation\Drivers"

# Get all folders in the local Drivers directory
$localDriverFolders = Get-ChildItem -Path $localDriversPath -Directory

foreach ($folder in $localDriverFolders) {
    $folderName = $folder.Name
    $localChk = Join-Path $folder.FullName "chk.id12"
    $netChk = Join-Path (Join-Path $netDriversPath $folderName) "chk.id12"

    # Check if the same folder exists in the network location and both chk.id12 files exist
    if (Test-Path $localChk) {
        $localHash = Get-FileHash $localChk -Algorithm SHA256
        $netHash = Get-FileHash $netChk -Algorithm SHA256

        if ($localHash.Hash -ne $netHash.Hash) {
            Write-Host "Updating $folderName - chk.id12 files differ." -ForegroundColor DarkBlue

            # Remove the local folder
            Remove-Item -Path $folder.FullName -Recurse -Force

            # Copy the folder from the network
            Copy-Item -Path (Join-Path $netDriversPath $folderName) -Destination $localDriversPath -Recurse -Force

            Write-Host "$folderName updated from network." -ForegroundColor Green
        } else {
            Write-Host "$folderName is up to date." -ForegroundColor Green
        }
    } else {
        Write-Host "$folderName skipped - chk.id12 missing" -ForegroundColor Red
    }
}

}
else{Write-host "Cancel" -ForegroundColor Red }

 }

####################################################################################################################################
#Choice 3 Build a local store on C:\DriveBuilder (or where you make your local store)
    elseif ($choice -eq "3") {
    #Builds The Local Store specified in the variable 
#Call Yes-NoMenu Function
Write-host "Confirm you want to rebuild your LOCAL STORE. This will take some time" -ForegroundColor Yellow
$result = Yes-NoMenu

#trigger rebuild
if($result -eq 1){Write-host "Building local store"
Set-LocalStore}
else{Write-host "Cancel" -ForegroundColor Red }
  }

####################################################################################################################################
#Choice 4 add additional drivers to  C:\DriveBuilder but NOT deleting the others.
  elseif ($choice -eq "4") {
#Call Yes-NoMenu Function
Write-host "Confirm you want to add additional models to your local store."
$result = Yes-NoMenu

#trigger addition of files
if($result -eq 1){
#Add driver to local Intune location
#Input to get computer models for local directory
Write-Host "Add a comma between models you plan to add (ex: 5000,5330,3140)"

#Trigger Choose Driver function
$localDriverModels4 = Choose-Driver $driverPath 
Write-Host "$localDriverModels4 model(s) selected" -ForegroundColor Blue


#Copy listed drivers to $localLocation\Drivers
$localdriverarray4= $localDriverModels4.Replace(" ", "").Split(",")
foreach($localDriverModels4 in $localdriverarray4){
if(Test-Path -Path "$netLocation\Drivers\$localDriverModels4"){
$sourceDrivers = "$netLocation\Drivers\$localDriverModels4"
Write-Host "$localDriverModels4 drivers will be added to your local store."

$destinationDrivers = "$localLocation\Drivers\$localDriverModels4"
Copy-Folder -source $sourceDrivers -destination $destinationDrivers
} 
else{Write-Host "$localDriverModels4 Not a valid model" -ForegroundColor Red}
}
}
else{Write-host "Cancel" -ForegroundColor Red }
  }

####################################################################################################################################
#Choice 5 Replace package on the USB Drive
elseif ($choice -eq "5"){
#Trigger USB Drive Scan Function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -Foreground Blue
#This will replace Drivers on the USB Drive.
#Trigger Yes or No Menu
Write-Host "Confirm you want to replace the package on your USB Drive" -ForegroundColor Yellow
$result = Yes-NoMenu

#Run a basic code to just copy drivers
if($result -eq 1)
{
#clear old drivers off USB Drive
Remove-Item "$Storage\*.ppkg" -force -recurse -ErrorAction Ignore
Remove-Item "$Storage\*.cat" -force -recurse -ErrorAction Ignore
Write-Host "Previous packages removed." -ForegroundColor Red

#Trigger Package function
$Package = Choose-Package $PackagePath

#Copy Intune Packages. This includes logic for local package copy
if(Test-Path -Path "$localLocation\Packages\$package.cat"){
Copy-Item "$localLocation\Packages\$package.cat" -destination $Storage -recurse
Copy-Item "$localLocation\Packages\$package.ppkg" -destination $Storage -recurse
Write-Host "$package package copied from the local store" -ForegroundColor Blue}
else {
Copy-Item "$netLocation\Packages\$package.cat" -destination $Storage -recurse 
Copy-Item "$netLocation\Packages\$package.ppkg" -destination $Storage -recurse 
Write-Host "$package package copied from the network store" -ForegroundColor Blue}

#Package - Display the Package name and list variables
$CDITFile = "$OSFiles\CDIT.txt"
$content = Get-Content $CDITFile
#$wordToMatch1 = "Package"
$packageCheckFile = "$netLocation\Packages\chk.id12"
# Filter out the lines that start with the specified word
#$filteredContent1 = $content | Where-Object { -not ($_ -match "^$wordToMatch1") }
# Write the filtered content back to the file
#$filteredContent1 | Set-Content $CDITFile
$currentDateTime = Get-Date
$formattedCurrentDateTime = $currentDateTime.ToString("yyyy-MM-dd HH:mm")
#Add-Content -Path $CDITFile -Value "Package $package updated $formattedCurrentDateTime"

#Update Check file - Get the last modified date of chkid file for package
# Filter out the lines that start with the specified word
$wordToMatch0 = "Package"
$filteredContent0 = $content | Where-Object { -not ($_ -match "^$wordToMatch0") }
# Write the filtered content back to the file
$filteredContent0 | Set-Content $CDITFile
$modifiedDate0 = (Get-Item $packageCheckFile).LastWriteTime
$formattedDate0 = $modifiedDate0.ToString("yyyy-MM-dd")
$expiryDate = $modifiedDate0.AddDays(179)
$formattedExpiryDate = $expiryDate.ToString("yyyy-MM-dd")
Add-Content -Path $CDITFile -Value "Package $package added $formattedCurrentDateTime"
Add-Content -Path $CDITFile -Value "Packages Created: $formattedDate0 /Expire: $formattedExpiryDate"
}
}

####################################################################################################################################
#Choice 6 replace drivers on USB Drive
 elseif ($choice -eq "6") {
#Trigger USB Drive Scan Function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -Foreground Blue
#Trigger Choose Driver function
$driverModel6= Choose-Driver $driverPath
if(Test-Path -Path "$netLocation\Drivers\$driverModel6"){
#This will replace Drivers on the USB Drive.
#Trigger Yes or No Menu
Write-host "Confirm you want to replace the drivers on USB Storage" -ForegroundColor Yellow
Write-host ""
$result = Yes-NoMenu

#Run a basic code to just copy drivers
if($result -eq 1){

#clear old drivers off USB Drive
Remove-Item "$Storage\Drivers" -force -recurse -ErrorAction Ignore
Remove-Item "$Storage\PE" -force -recurse -ErrorAction Ignore
Write-Host "Previous drivers have been removed." -ForegroundColor Red
Write-Host ""

#Copying Drivers and set PE folder if needed. This includes logic for local driver copy
if(Test-Path -Path "$localLocation\Drivers\$driverModel6"){
# copy from local store
$sourceDrivers = "$localLocation\Drivers\$driverModel6"
Write-Host "Drivers for the $driverModel6 will be added to your USB via the local store."}
# copy from network store
else { 
$sourceDrivers = "$netLocation\Drivers\$driverModel6"
Write-Host "Drivers for the $driverModel6 will be added to your USB via the network store."}

#set location of drivers on USB
$destinationDrivers = "$Storage\$driverModel6"

#copy using the progress bar
Copy-Folder -source $sourceDrivers -destination $destinationDrivers

#Add File so that you know what drivers these are
New-item -Path $Storage\$driverModel6 -Name "$driverModel6.txt" -ItemType "file"

#Drivers - Display New Driver information from tech server or local system
$CDITFile = "$OSFiles\CDIT.txt"
$wordToMatch = "Model"
$content = Get-Content $CDITFile
# Filter out the lines that start with the specified word
$filteredContent = $content | Where-Object { -not ($_ -match "^$wordToMatch") }
# Write the filtered content back to the file
$filteredContent | Set-Content $CDITFile
$currentDateTime = Get-Date
$formattedCurrentDateTime = $currentDateTime.ToString("yyyy-MM-dd HH:mm")
Add-Content -Path $CDITFile -Value "Model $driverModel6 added $formattedCurrentDateTime"

#Change name to drivers and move PE drivers and set autounattend.xml
If(Test-Path -Path $Storage\$driverModel6){
Rename-Item "$Storage\$driverModel6" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$Storage\Drivers\PE" -destination $Storage -Force -ErrorAction Ignore
Copy-Item "$Storage\Drivers\autounattend.xml" -destination $OSFiles -Force -ErrorAction Ignore
}
#Second Attempt at renaming and moving PE
If(-NOt(Test-Path -Path $Storage\drivers)){
Rename-Item "$Storage\$driverModel6" -NewName "Drivers" -force -ErrorAction Ignore
Move-Item "$Storage\Drivers\PE" -destination $Storage -Force -ErrorAction Ignore
Copy-Item "$Storage\Drivers\autounattend.xml" -destination $OSFiles -Force -ErrorAction Ignore
}
}
}
else{Write-Host "$driverModel6 is not a valid model" -ForegroundColor Red}
}

####################################################################################################################################
#Choice 7 Check if the model is available
   elseif ($choice -eq "7") {
#Input to get computer models for local directory
$netDriverModels= Read-Host -Prompt 'What model do you need?'
If(Test-Path -Path $netLocation\Drivers\$netDriverModels){
  Write-Host "Model is available" -ForegroundColor Green}
else{Write-Host "Model is not available" -ForegroundColor Red}
}

####################################################################################################################################
#Choice 8 Read CDIT
      elseif ($choice -eq "8") {
#Trigger USB Drive Scan function
$OSFiles = OSDriveScan -$OSFilesPath
$Storage = storageDriveScan -$StoragePath
$CDITFile = "$OSFiles\CDIT.txt"
If(Test-Path -Path $CDITFile){
Write-Host "OSFiles = $OSFiles and Storage = $Storage" -Foregroundcolor Blue
Write-Host "Behold! The CDIT File!"
Write-Host ""
Get-Content $CDITFile
}
else{Write-Host "Drive does not have a custom drive information thingy! Please rebuild the drive." -ForegroundColor Red}
}

####################################################################################################################################
#Choice X Code the exit
 elseif ($choice -eq "X"){ 
        break; # Exit the loop and end the script
   }
   else {
   Write-Host "Not a valid choice. Try again." -ForegroundColor Red 
   }
}while ($true) # Loop back to the main menu after each task completes until option X selected

####################################################################################################################################
#I hear that X is going to give it to you. 
Write-Host "Bye Bye!" -ForegroundColor Blue
Stop-Transcript