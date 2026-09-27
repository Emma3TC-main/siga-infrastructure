param(
    [Parameter(Mandatory)][ValidateSet('Init','Start','Status','Stop','Config')][string]$Action,
    [ValidatePattern('^[a-z][a-z0-9-]{0,30}$')][string]$Instance = 'team',
    [ValidateRange(0,40000)][int]$PortOffset = 0,
    [switch]$WithMinio
)
$ErrorActionPreference = 'Stop'
if ($Instance -eq 'local') { throw 'Instance local is reserved for the existing environment.' }
$root = Split-Path $PSScriptRoot -Parent
$envPath = Join-Path $root "compose/.env.$Instance"
$composePath = Join-Path $root 'compose/compose.team.yml'
$project = "siga-$Instance"
function Assert-Native([string]$message) { if ($LASTEXITCODE -ne 0) { throw $message } }
function New-Secret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    [Convert]::ToBase64String($bytes)
}
docker info --format '{{.ServerVersion}}' | Out-Null
Assert-Native 'Start Docker Desktop with Linux containers first.'
if ($Action -eq 'Init') {
    if (Test-Path $envPath) { Write-Host "Existing configuration preserved: $envPath"; return }
    $containers = @(docker ps -a -q --filter "label=com.docker.compose.project=$project")
    Assert-Native 'Cannot inspect project containers.'
    $volumes = @(docker volume ls -q --filter "label=com.docker.compose.project=$project")
    Assert-Native 'Cannot inspect project volumes.'
    if ($containers.Count -or $volumes.Count) { throw 'Project data already exists without its env file. Restore matching credentials; do not initialize again.' }
    $ports = [ordered]@{
        LOCAL_POSTGRES_PORT=15432; LOCAL_REDIS_PORT=6379; LOCAL_RABBITMQ_PORT=5672
        LOCAL_RABBITMQ_UI_PORT=15672; LOCAL_MINIO_PORT=9000; LOCAL_MINIO_UI_PORT=9001
        LOCAL_IDENTITY_PORT=8081; LOCAL_MANAGEMENT_PORT=9081
    }
    $lines = @("COMPOSE_PROJECT_NAME=$project")
    foreach ($key in $ports.Keys) {
        $port = $ports[$key] + $PortOffset
        # Binding is a more reliable preflight than assuming an absent PostgreSQL installation.
        $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
        try { $listener.Start() } catch { throw "Port $port is unavailable. Choose another -PortOffset for the NEW instance." }
        finally { $listener.Stop() }
        $lines += "$key=$port"
    }
    foreach ($key in @('LOCAL_POSTGRES_PASSWORD','SIGA_IAM_PASSWORD','SIGA_TEST_PASSWORD','LOCAL_RABBITMQ_PASSWORD','LOCAL_MINIO_PASSWORD')) {
        $lines += "$key=$(New-Secret)"
    }
    [IO.File]::WriteAllText($envPath, ($lines -join "`n")+"`n", (New-Object Text.UTF8Encoding $false))
    Write-Host "Prepared $project; credentials are private in $envPath"
    return
}
if (-not (Test-Path $envPath)) { throw 'Run Init first.' }
$values = @{}
foreach ($line in Get-Content $envPath) {
    if ($line -match '^([A-Z_][A-Z_0-9]*)=(.*)$') { $values[$matches[1]]=$matches[2] }
}
if ($values['COMPOSE_PROJECT_NAME'] -ne $project) { throw 'Instance/project mismatch; refusing to select another environment.' }
$composeArgs = @('compose','--env-file',$envPath,'-f',$composePath,'-p',$project)
& docker @composeArgs config --quiet
Assert-Native 'Invalid Compose configuration.'
switch ($Action) {
    'Config' { Write-Host 'Compose configuration OK.' }
    'Status' { & docker @composeArgs --profile storage ps -a; Assert-Native 'Cannot read project status.' }
    'Stop' { & docker @composeArgs --profile storage stop; Assert-Native 'Could not stop project.' }
    'Start' {
        & docker @composeArgs up -d --wait --no-recreate postgres redis rabbitmq
        Assert-Native 'Dependencies failed. Check project logs; do not reset volumes.'
        if ($WithMinio) { & docker @composeArgs --profile storage up -d --no-recreate minio; Assert-Native 'MinIO failed.' }
        'SELECT current_user,current_database();' | & docker @composeArgs exec -T postgres sh -c 'PGPASSWORD=$SIGA_IAM_PASSWORD exec psql -h 127.0.0.1 -U siga_iam -d siga -v ON_ERROR_STOP=1'
        Assert-Native 'IAM connection failed. Preserve the volume and restore matching env.'
        'SELECT current_user,current_database();' | & docker @composeArgs exec -T postgres sh -c 'PGPASSWORD=$SIGA_TEST_PASSWORD exec psql -h 127.0.0.1 -U siga_iam_test -d siga_identity_local_test -v ON_ERROR_STOP=1'
        Assert-Native 'Dedicated test database/login unavailable. Inspect initialization logs.'
    }
}
