$ErrorActionPreference = "Stop"

Write-Host "=== Auto Setup Python + pip + venv ===" -ForegroundColor Cyan

# 1) Pastikan winget tersedia
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget tidak ditemukan." -ForegroundColor Red
    Write-Host "Install/update 'App Installer' dari Microsoft Store, lalu jalankan script ini lagi."
    exit 1
}

# 2) Cari Python 3.13 resmi Windows
$python = $null

$pyLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pyLauncher) {
    try {
        $candidate = (& py -3.13 -c "import sys; print(sys.executable)" 2>$null)
        if ($candidate -and (Test-Path $candidate)) {
            $python = $candidate.Trim()
        }
    } catch {}
}

if (-not $python) {
    $candidate = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
    if (Test-Path $candidate) {
        $python = $candidate
    }
}

# 3) Kalau belum ada, install Python 3.13 resmi
if (-not $python) {
    Write-Host "Python 3.13 belum ditemukan. Menginstall..." -ForegroundColor Yellow

    winget install -e --id Python.Python.3.13 --scope user `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    $candidate = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"

    if (Test-Path $candidate) {
        $python = $candidate
    } else {
        $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            try {
                $candidate = (& py -3.13 -c "import sys; print(sys.executable)" 2>$null)
                if ($candidate -and (Test-Path $candidate)) {
                    $python = $candidate.Trim()
                }
            } catch {}
        }
    }
}

if (-not $python -or -not (Test-Path $python)) {
    Write-Host "ERROR: Python selesai diinstall tetapi executable tidak ditemukan." -ForegroundColor Red
    Write-Host "Tutup lalu buka terminal/IDE, kemudian jalankan script ini lagi."
    exit 1
}

Write-Host "Python: $python" -ForegroundColor Green

# 4) Pastikan pip tersedia
Write-Host "Menyiapkan pip..." -ForegroundColor Yellow
& $python -m ensurepip --upgrade
& $python -m pip install --upgrade pip

# 5) Tambahkan Python resmi ke User PATH bila belum ada
$pythonDir = Split-Path $python
$scriptsDir = Join-Path $pythonDir "Scripts"

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @()
if ($userPath) {
    $parts = $userPath -split ";" | Where-Object { $_ -and $_.Trim() }
}

foreach ($p in @($pythonDir, $scriptsDir)) {
    if ($parts -notcontains $p) {
        $parts += $p
    }
}

[Environment]::SetEnvironmentVariable("Path", ($parts -join ";"), "User")

# Update PATH untuk proses PowerShell ini juga
if (($env:Path -split ";") -notcontains $pythonDir) {
    $env:Path = "$pythonDir;$scriptsDir;$env:Path"
}

# 6) Buat virtual environment di folder project saat ini
$venvPath = Join-Path (Get-Location) ".venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
    Write-Host "Membuat .venv..." -ForegroundColor Yellow
    & $python -m venv ".venv"
}

# 7) Upgrade pip di venv dan install MySQL Connector
Write-Host "Menginstall package project..." -ForegroundColor Yellow
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install mysql-connector-python

# 8) Konfigurasi interpreter untuk IDE yang kompatibel dengan VS Code settings
$vscodeDir = Join-Path (Get-Location) ".vscode"
$settingsFile = Join-Path $vscodeDir "settings.json"

New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

$settings = @{
    "python.defaultInterpreterPath" = '${workspaceFolder}\.venv\Scripts\python.exe'
}
$settings | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsFile

# 9) Tes
Write-Host ""
Write-Host "Mengetes Python, pip, dan MySQL Connector..." -ForegroundColor Cyan

& $venvPython -c "import sys; print('Python OK :', sys.version.split()[0]); import pip; print('pip OK    :', pip.__version__); import mysql.connector; print('MySQL OK  : mysql.connector berhasil di-import')"

Write-Host ""
Write-Host "=== SELESAI ===" -ForegroundColor Green
Write-Host "Interpreter project:"
Write-Host $venvPython
Write-Host ""
Write-Host "Kalau IDE masih terbuka, restart IDE agar PATH/interpreter terbaca."
