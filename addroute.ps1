Set-ExecutionPolicy Unrestricted -Scope Process


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
        New-NetRoute -DestinationPrefix $network -NextHop $gateway -InterfaceAlias $interfaceAlias -ErrorAction Stop

    }
    catch {
        Write-Warning "�� ������� �������� ������� ��� $network ($_)"
    }
}

Write-Host "`n������� ��������. ��������� ����������� ��������:" -ForegroundColor Cyan
Get-NetRoute | Where-Object {$_.NextHop -eq $gateway} | Format-Table -AutoSize
Read-Host