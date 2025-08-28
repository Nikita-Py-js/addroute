param (
    [ValidateSet("add", "del")]
    [string]$Mode,
    [string]$Debug
)

try {
  $Debubmode = [System.Convert]::ToBoolean($Debug) 
} catch [FormatException] {
  $Debubmode = $false
}

Write-Host  $Debubmode $Mode
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "���� ������ ������� ����� ��������������. ��������� PowerShell �� ����� ��������������."
    Read-Host
    exit 1
}


function Select-CfgFile {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }

    $cfgFiles = @(Get-ChildItem -Path $scriptDir -Filter "*.cfg" -File)
    
    if ($cfgFiles.Count -eq 0) {
        Write-Host "����� � ����������� .cfg �� �������� � ����������: $scriptDir" -ForegroundColor Red
        return $null
    }

    Write-Host "`n������� ��������� ����� .cfg:`n" -ForegroundColor Yellow
    $i = 0
    foreach ($cfgFile in $cfgFiles){
        Write-Host "$($i). $($cfgFile.Name)"
        $i++
    }

    do {
        $selectedIndex = Read-Host "`n������� ����� ����� (0-$($cfgFiles.Count-1))"
        $isValid = [int]::TryParse($selectedIndex, [ref]$null) -and $selectedIndex -ge 0 -and $selectedIndex -le $cfgFiles.Count-1
        if (-not $isValid) {
            Write-Host "������������ ����. ����������, ������� ����� �� 1 �� $($cfgFiles.Count-1)."
        }
    } while (-not $isValid)

    return $cfgFiles[$selectedIndex].FullName
}

$filePath = Select-CfgFile
if ($filePath) {
    Write-Host "��������� ����: $filePath"  -ForegroundColor Green
} else {
    Write-Host "���� �� ������." -ForegroundColor Red
    Read-Host
    exit 1
}
Write-Host "`n������� ����� ���� VPN: " -ForegroundColor Yellow
$gateway = Read-Host "`n"
if ($gateway) {
    Write-Host "��������� ����: $gateway"  -ForegroundColor Green
} else {
    Write-Host "���� �� ������."  -ForegroundColor Red
    Read-Host
    exit 1
}

$interfaces = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object InterfaceAlias, InterfaceDescription

Write-Host "`n��������� ������� ����������:" -ForegroundColor Yellow
$i = 0
foreach ($interface in $interfaces) {
    
    Write-Host "$($i). $($interface.InterfaceAlias) - $($interface.InterfaceDescription)"
    $i++
}

do {
    $selection = Read-Host "`n�������� ����� ���������� (0-$($interfaces.Count-1))"
    $selectedIndex = [int]$selection
} until ($selection -match "^\d+$")

$interfaceAlias = $interfaces[$selectedIndex].InterfaceAlias
Write-Host "������ ���������: $interfaceAlias" -ForegroundColor Green

if (-not (Test-Path $filePath)) {
    Write-Error "���� $filePath �� ������"
    exit 1
}

$routes = Get-Content $filePath
$progres=0
foreach ($route in $routes) {
    $route = $route.Trim()
    if (-not $route) { continue }

    # ���������� ����� ����
    if ($route -match '/') {
        $network = $route
    }
    else {
        $network = "$route/32"
    }

    try {
        $progres++
        Write-Progress -PercentComplete ($progres/$routes.Count*100) -Status "Processing Items" -Activity "Item $progres of $($routes.Count)"
        if($Mode -like "add"){
            $null = New-NetRoute -DestinationPrefix $network -NextHop $gateway -InterfaceAlias $interfaceAlias -ErrorAction Stop | Out-Null
        }else{
            $null = Remove-NetRoute -DestinationPrefix $network -NextHop 0.0.0.0 -InterfaceAlias $interfaceAlias -ErrorAction Stop -Confirm:$false | Out-Null
        }
        

    }
    catch {
        if($Debubmode -and $Mode -like "add"){Write-Warning "�� ������� �������� ������� ��� $network ($_)"}
        if($Debubmode -and $Mode -like "del"){Write-Warning "�� ������� �������� ������� ��� $network ($_)"}
    }
}
if($Mode -like "add"){
    Write-Host "`n������� ��������. ��������� ����������� ��������:" -ForegroundColor Cyan
}else{
    Write-Host "`n������� ��������. ��������� ��������:" -ForegroundColor Cyan
}

Get-NetRoute | Where-Object {$_.NextHop -eq $gateway} | Format-Table -AutoSize
Read-Host