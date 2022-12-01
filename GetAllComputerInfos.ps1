[CmdletBinding()]
Param(
    [PSCredential]$creds,
    $NetRootFolder = "\\srv-file\mypath"
)

#Requires -Version 4.0
function Get-MrMonitorInfo {
    <#
    .SYNOPSIS
        Retrieves information about the monitors connected to the specified system.
    
    .DESCRIPTION
        Get-MrMonitorInfo is an advanced function that retrieves information about the monitors
        connected to the specified system.
    
    .PARAMETER CimSession
        Specifies the CIM session to use for this function. Enter a variable that contains the CIM session or a command that
        creates or gets the CIM session, such as the New-CimSession or Get-CimSession cmdlets. For more information, see
        about_CimSessions.
    
    .EXAMPLE
        Get-MrMonitorInfo
        
    .INPUTS
        None
    
    .OUTPUTS
        Mr.MonitorInfo
    
    .NOTES
        Author: Mike F Robbins
        Website: http://mikefrobbins.com
        Twitter: @mikefrobbins
        Modifications: Karsten Berg (removed all the PC stuff - just need the monitor information
    #>
    
        [CmdletBinding()]
        [OutputType('Mr.MonitorInfo')]
        param (
            [Microsoft.Management.Infrastructure.CimSession[]]$CimSession
        )
    
        $Params = @{
            ErrorAction = 'SilentlyContinue'
            ErrorVariable = 'Problem'
        }
    
        if ($PSBoundParameters.CimSession) {
            $Params.CimSession = $CimSession
        }
        
        $Monitors = Get-CimInstance @Params -ClassName WmiMonitorID -Namespace root/WMI -Property ManufacturerName, UserFriendlyName, ProductCodeID, SerialNumberID, WeekOfManufacture, YearOfManufacture
        
        $AllOfMyMonitors = @()
        foreach ($Monitor in $Monitors) {
            $AllOfMyMonitors += New-Object -TypeName PSObject -Property @{
                'MonitorManufacturer'    = -join $Monitor.ManufacturerName.ForEach({[char]$_})
                'MonitorModel'           = -join $Monitor.UserFriendlyName.ForEach({[char]$_})
                'ProductCode'            = -join $Monitor.ProductCodeID.ForEach({[char]$_})
                'MonitorSerial'          = -join $Monitor.SerialNumberID.ForEach({[char]$_})
                'MonitorManufactureWeek' =       $Monitor.WeekOfManufacture
                'MonitorManufactureYear' =       $Monitor.YearOfManufacture
            }
        }

        $AllOfMyMonitors
    }



# Mount the UNC-Share to B:\
New-PSDrive -Name "B" -PSProvider FileSystem -Root $NetRootFolder -Credential $creds
Set-Location -Path B:
$Date = Get-Date -Format yyyy-MM-dd--HH-mm

$ComputerInfos = Get-ComputerInfo
$PCSerial = ''
if ($($ComputerInfos.BiosSerialNumber)) {
    $PCSerial = $ComputerInfos.BiosSerialNumber
} elseif ($($ComputerInfos.BiosSeralNumber)) {
    $PCSerial = $ComputerInfos.BiosSeralNumber
}

$NetAdapter = Get-NetAdapter | Where-Object {
    ($_.Name -Match "Ethernet") -or
    ($_.Name -Match "LAN-Verbindung")
} | Where-Object {
    ($_.InterfaceDescription -NotMatch "Sophos") -and
    ($_.InterfaceDescription -NotMatch "TAP") -and
    ($_.InterfaceDescription -NotMatch "WLAN") -and
    ($_.InterfaceDescription -NotMatch "WiFi") -and
    ($_.InterfaceDescription -NotMatch "Wi-Fi")
}  | Select-Object MacAddress

$RAMs = Get-CimInstance -Class Win32_PhysicalMemory
$TotalRAM = 0
foreach ($RAM in $RAMs) {
    $TotalRAM += ($($RAM.Capacity) / (1024*1024))
}

$Discs = Get-PhysicalDisk | Select-Object -Property Model,MediaType,BusType,Size
$PhysicalDiscs = @()
foreach ($Disc in $Discs) {
    $PhysicalDiscs += New-Object -TypeName PSObject -Property @{
        'Model'     = $Disc.Model
        'MediaType' = $Disc.MediaType
        'BusType'   = $Disc.BusType
        'Size'      = [Math]::Round(($Disc.Size)/(1000000000),0)
    }
}

$MyMonitors = Get-MrMonitorInfo
$AllMonitors = @()
foreach ($MyMonitor in $MyMonitors) {
    $AllMonitors += New-Object -TypeName PSObject -Property @{
        'Manufacturer' = $MyMonitor.MonitorManufacturer
        'Model'        = $MyMonitor.MonitorModel
        'ProductCode'  = $MyMonitor.ProductCode
        'Serial'       = $MyMonitor.MonitorSerial
        'Manufactured' = "$($MyMonitor.MonitorManufactureWeek)\$($MyMonitor.MonitorManufactureYear)"
    }
}

$Result = New-Object -TypeName PSObject -Property @{
    'ComputerName'          = $ComputerInfos.CsDNSHostName
    'ComputerManufacturer'  = $ComputerInfos.CsManufacturer
    'ComputerModel'         = $ComputerInfos.CsSystemFamily
    'ComputerFirmwareType'  = $ComputerInfos.BiosFirmwareType
    'ComputerSerialNumber'  = $PCSerial
    'BiosVersion'           = $ComputerInfos.BiosVersion
    'BiosDate'              = $ComputerInfos.BiosReleaseDate
    'WinFeatureUpdate'      = $ComputerInfos.OsVersion
    'WinArchitecture'       = $ComputerInfos.OsArchitecture
    'LoggedInUser'          = $ComputerInfos.CsUsername
    'MacAddress'            = $NetAdapter.MacAddress
    'CPU'                   = $($ComputerInfos.CsProcessors)[0].Name
    'RAM'                   = $TotalRAM
    # We assume nobody has more than 3 physical discs
    'Disc1Model'            = $PhysicalDiscs[0].Model
    'Disc1MediaType'        = $PhysicalDiscs[0].MediaType
    'Disc1BusType'          = $PhysicalDiscs[0].BusType
    'Disc1Size'             = $PhysicalDiscs[0].Size
    'Disc2Model'            = $PhysicalDiscs[1].Model
    'Disc2MediaType'        = $PhysicalDiscs[1].MediaType
    'Disc2BusType'          = $PhysicalDiscs[1].BusType
    'Disc2Size'             = $PhysicalDiscs[1].Size
    'Disc3Model'            = $PhysicalDiscs[2].Model
    'Disc3MediaType'        = $PhysicalDiscs[2].MediaType
    'Disc3BusType'          = $PhysicalDiscs[2].BusType
    'Disc3Size'             = $PhysicalDiscs[2].Size
    # We assume nobody has more than 3 monitors
    'Monitor1Manufacturer'  = $AllMonitors[0].Manufacturer
    'Monitor1Model'         = $AllMonitors[0].Model
    'Monitor1Serial'        = $AllMonitors[0].Serial
    'Monitor1Manufactured'  = $AllMonitors[0].Manufactured
    'Monitor2Manufacturer'  = $AllMonitors[1].Manufacturer
    'Monitor2Model'         = $AllMonitors[1].Model
    'Monitor2Serial'        = $AllMonitors[1].Serial
    'Monitor2Manufactured'  = $AllMonitors[1].Manufactured
    'Monitor3Manufacturer'  = $AllMonitors[2].Manufacturer
    'Monitor3Model'         = $AllMonitors[2].Model
    'Monitor3Serial'        = $AllMonitors[2].Serial
    'Monitor3Manufactured'  = $AllMonitors[2].Manufactured
    'ReadDate'              = $Date
}

# Set CSV-path
$PCName = $Result.ComputerName
$FinalResult = "B:\Results\$PCName-$Date.csv"

# Export results
$OutputParams = (
    'ComputerName',
    'ComputerManufacturer',
    'ComputerModel',
    'ComputerFirmwareType',
    'ComputerSerialNumber',
    'CPU',
    'RAM',
    'BiosVersion',
    'BiosDate',
    'WinFeatureUpdate',
    'LoggedInUser',
    'MacAddress',
    'Disc1Model',
    'Disc1MediaType',
    'Disc1BusType',
    'Disc1Size',
    'Disc2Model',
    'Disc2MediaType',
    'Disc2BusType',
    'Disc2Size',
    'Disc3Model',
    'Disc3MediaType',
    'Disc3BusType',
    'Disc3Size',
    'Monitor1Manufacturer',
    'Monitor1Model',
    'Monitor1Serial',
    'Monitor1Manufactured',
    'Monitor2Manufacturer',
    'Monitor2Model',
    'Monitor2Serial',
    'Monitor2Manufactured',
    'Monitor3Manufacturer',
    'Monitor3Model',
    'Monitor3Serial',
    'Monitor3Manufactured',
    'ReadDate'
)
Write-Output $Result | Select-Object $OutputParams | Export-Csv $FinalResult -NoTypeInformation

# PSDrive wieder löschen
Set-Location -Path C:
Start-Sleep -Seconds 1
Remove-PSDrive -Name "B"
