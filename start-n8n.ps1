# start-n8n.ps1
# Launches n8n using the project-local .n8n folder

$env:N8N_USER_FOLDER = "$PSScriptRoot"
Write-Host "Starting n8n with data folder: $PSScriptRoot\.n8n" -ForegroundColor Cyan
n8n start