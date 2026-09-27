$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root 'compose/.env.local'
if (Test-Path $destination) { Write-Host 'Existing .env.local preserved.'; return }
function New-LocalSecret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [Convert]::ToBase64String($bytes)
}
docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Start Docker Desktop before setup.' }
$names = @(docker ps -a --format '{{.Names}}')
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing containers.' }
$adminUser = 'postgres'
$adminPassword = New-LocalSecret
$iamPassword = New-LocalSecret
if ($names -contains 'siga-local-postgres-1') {
    $container = (docker inspect siga-local-postgres-1 | ConvertFrom-Json)[0]
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing PostgreSQL.' }
    foreach ($entry in $container.Config.Env) {
        if ($entry -match '^POSTGRES_USER=(.+)$') { $adminUser = $matches[1] }
        if ($entry -match '^POSTGRES_PASSWORD=(.+)$') { $adminPassword = $matches[1] }
        if ($entry -match '^SIGA_IAM_PASSWORD=(.+)$') { $iamPassword = $matches[1] }
    }
    if (-not ($container.Config.Env -match '^POSTGRES_PASSWORD=.+')) {
        throw 'Existing PostgreSQL has no password configuration; diagnose before provisioning.'
    }
    Write-Host 'Preserving existing Docker PostgreSQL administrator configuration and volume.'
} else {
    $volumes = @(docker volume ls --format '{{.Name}}')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing volumes.' }
    if ($volumes -contains 'siga-local_postgres-data') {
        throw 'An existing PostgreSQL volume has no container: diagnose its credentials before setup.'
    }
}
$rabbitUser = 'siga_mq'
$rabbitPassword = New-LocalSecret
if ($names -contains 'siga_rabbitmq') {
    $rabbit = (docker inspect siga_rabbitmq | ConvertFrom-Json)[0]
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect existing RabbitMQ.' }
    foreach ($entry in $rabbit.Config.Env) {
        if ($entry -match '^RABBITMQ_DEFAULT_USER=(.+)$') { $rabbitUser = $matches[1] }
        if ($entry -match '^RABBITMQ_DEFAULT_PASS=(.+)$') { $rabbitPassword = $matches[1] }
    }
    if (-not ($rabbit.Config.Env -match '^RABBITMQ_DEFAULT_PASS=.+')) {
        throw 'Existing RabbitMQ has no password configuration; diagnose before setup.'
    }
} else {
    $volumes = @(docker volume ls --format '{{.Name}}')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect RabbitMQ volumes.' }
    if ($volumes -contains 'siga-local_rabbitmq_data') {
        throw 'Existing RabbitMQ volume has no container: diagnose its credentials before setup.'
    }
}
$content = "LOCAL_POSTGRES_USER=$adminUser`nLOCAL_POSTGRES_PASSWORD=$adminPassword`nLOCAL_POSTGRES_PORT=15432`nSIGA_IAM_PASSWORD=$iamPassword`nLOCAL_RABBITMQ_USER=$rabbitUser`nLOCAL_RABBITMQ_PASSWORD=$rabbitPassword`n"
[IO.File]::WriteAllText($destination, $content, (New-Object Text.UTF8Encoding $false))
Write-Host 'Created ignored compose/.env.local; secrets were not printed.'
