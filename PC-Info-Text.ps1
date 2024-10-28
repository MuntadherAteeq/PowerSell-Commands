# Function to get a unique filename
function Get-UniqueFilename {
    $Count = 1
    do {
        $hostname = hostname
        $filename = "$hostname $Count.txt"
        $Count++
    } until (-not (Test-Path $filename))
    return $filename
}

# Fetch PC details
$PCInfo = @{
    'Serial Number' = (Get-CimInstance win32_bios).SerialNumber
    'Hostname'      = hostname
    'Username'      = $env:USERNAME
    'Product Name'  = (Get-CimInstance Win32_ComputerSystem).Model
    'CPU'           = (Get-CimInstance Win32_Processor).Name
    'Hard Drive'    = (Get-CimInstance Win32_DiskDrive).Model[0]
    'Password'      = 'YourPassword'  # Replace with actual password
}

# Exclude default Windows printers
$DefaultPrinters = @(
     "Microsoft Print to PDF", "Fax", "Microsoft XPS Document Writer",
    "OneNote", "Send To OneNote", "OneNote for Windows 10", "OneNote (Desktop)", "AnyDesk Printer","Send to Microsoft OneNote 16 Driver"
)

# Get non-default printers
$Printers = Get-Printer | Where-Object { $DefaultPrinters -notcontains $_.Name } |
    Select-Object Name, DriverName, PortName, PrinterStatus

# Status code to description mapping
$StatusDescriptions = @{
    "0" = "Other"
    "1" = "Unknown"
    "2" = "Idle"
    "3" = "Normal"
    "4" = "Warm-up"
    "5" = "Stopped Printing"
    "6" = "Offline"
}

# Determine maximum key length for formatting alignment
$maxKeyLength = ($PCInfo.Keys | Measure-Object -Maximum Length).Maximum

# Create formatted output for PC details
$Details = @"
 PC Details:
+------------------+------------------------------------------+
| Property         | Value                                    |
+------------------+------------------------------------------+
"@
foreach ($key in $PCInfo.Keys) {
    $Details += "`n| {0,-16} | {1,-40} |" -f $key, $PCInfo[$key]
    $Details += "`n+------------------+------------------------------------------+"
}

# Add Printer Details
$Details += @"
`n`n Printer Details:
+--------------------------------------------------------------+--------------------------------------------------------------+--------------------------------+-----------------------------+
| Name                                                         | Driver                                                       | Port                           | Status                      |
+--------------------------------------------------------------+--------------------------------------------------------------+--------------------------------+-----------------------------+
"@
if ($Printers) {
    foreach ($printer in $Printers) {
        $statusDescription = $StatusDescriptions[$printer.PrinterStatus] -or "Unknown Status"
        $Details += "`n| {0,-60} | {1,-60} | {2,-30} | {3,-27} |" -f $printer.Name, $printer.DriverName, $printer.PortName, $statusDescription
    }
} else {
    $Details += "`n| No printers found."
}
$Details += "`n+--------------------------------------------------------------+--------------------------------------------------------------+--------------------------------+-----------------------------+`n"

# Fetch installed programs and their versions
$uninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)

$Details += @"
`n`n Installed Programs:
+----------------------------------------------------------------------------------------+-----------------------------+
| Program Name                                                                           | Version                     |
+----------------------------------------------------------------------------------------+-----------------------------+
"@

foreach ($path in $uninstallPaths) {
    Get-ItemProperty -Path "$path\*" | ForEach-Object {
        if ($_.DisplayName) {
            $version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "N/A" }
            $Details += "`n| {0,-85}  | {1,-27} |" -f $_.DisplayName, $version
        }
    }
}

$Details += "`n+----------------------------------------------------------------------------------------+-----------------------------+`n"

# Save to file
$filename = Get-UniqueFilename
$Details | Out-File -FilePath $filename

# Open file in Notepad
Start-Process notepad.exe $filename