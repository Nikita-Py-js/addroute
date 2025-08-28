Set-ExecutionPolicy Unrestricted -Scope Process


if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Этот скрипт требует права администратора. Запустите PowerShell от имени администратора."
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
        Write-Host "Файлы с расширением .cfg не найднены в директории: $scriptDir" -ForegroundColor Red
        return $null
    }

    Write-Host "`nНайдены следующие файлы .cfg:`n" -ForegroundColor Yellow
    $i = 0
    foreach ($cfgFile in $cfgFiles){
        Write-Host "$($i). $($cfgFile.Name)"
        $i++
    }

    do {
        $selectedIndex = Read-Host "`nВведите номер файла (0-$($cfgFiles.Count-1))"
        $isValid = [int]::TryParse($selectedIndex, [ref]$null) -and $selectedIndex -ge 0 -and $selectedIndex -le $cfgFiles.Count-1
        if (-not $isValid) {
            Write-Host "Некорректный ввод. Пожалуйста, введите число от 1 до $($cfgFiles.Count-1)."
        }
    } while (-not $isValid)

    return $cfgFiles[$selectedIndex].FullName
}

$filePath = Select-CfgFile
if ($filePath) {
    Write-Host "Выбранный файл: $filePath"  -ForegroundColor Green
} else {
    Write-Host "Файл не выбран." -ForegroundColor Red
    Read-Host
    exit 1
}
Write-Host "`nВведите адрес шюза VPN: " -ForegroundColor Yellow
$gateway = Read-Host "`n"
if ($gateway) {
    Write-Host "Указанный шлюз: $gateway"  -ForegroundColor Green
} else {
    Write-Host "Шлюз не указан."  -ForegroundColor Red
    Read-Host
    exit 1
}

$interfaces = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object InterfaceAlias, InterfaceDescription

Write-Host "`nДоступные сетевые интерфейсы:" -ForegroundColor Yellow
$i = 0
foreach ($interface in $interfaces) {
    
    Write-Host "$($i). $($interface.InterfaceAlias) - $($interface.InterfaceDescription)"
    $i++
}

do {
    $selection = Read-Host "`nВыберите номер интерфейса (0-$($interfaces.Count-1))"
    $selectedIndex = [int]$selection
} until ($selection -match "^\d+$")

$interfaceAlias = $interfaces[$selectedIndex].InterfaceAlias
Write-Host "Выбран интерфейс: $interfaceAlias" -ForegroundColor Green

if (-not (Test-Path $filePath)) {
    Write-Error "Файл $filePath не найден"
    exit 1
}

$routes = Get-Content $filePath

foreach ($route in $routes) {
    $route = $route.Trim()
    if (-not $route) { continue }

    # Определяем маску сети
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
        Write-Warning "Не удалось добавить маршрут для $network ($_)"
    }
}

Write-Host "`nПроцесс завершен. Проверьте добавленные маршруты:" -ForegroundColor Cyan
Get-NetRoute | Where-Object {$_.NextHop -eq $gateway} | Format-Table -AutoSize
Read-Host