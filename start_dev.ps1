$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $projectRoot 'backend'
$frontendDir = Join-Path $projectRoot 'frontend'
$apiBaseUrl = 'http://127.0.0.1:8000'

$shellCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if ($shellCommand) {
    $shellExe = $shellCommand.Source
} else {
    $shellExe = (Get-Command powershell -ErrorAction Stop).Source
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    $pythonCommand = 'py'
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCommand = 'python'
} else {
    throw 'Python launcher (py または python) が見つかりません。'
}

$backendCommand = "Set-Location '$backendDir'; $pythonCommand -m uvicorn main:app --reload --host 127.0.0.1 --port 8000"
$frontendCommand = "Set-Location '$frontendDir'; flutter run -d chrome --dart-define=API_BASE_URL=$apiBaseUrl"

Start-Process -FilePath $shellExe -ArgumentList '-NoExit', '-Command', $backendCommand
Start-Process -FilePath $shellExe -ArgumentList '-NoExit', '-Command', $frontendCommand

Write-Host 'Backend terminal started:' $backendDir
Write-Host 'Frontend terminal started:' $frontendDir
Write-Host 'API_BASE_URL:' $apiBaseUrl
