param(
    [Parameter(Mandatory=$false)]
    [string]$Mode = "auto",
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentId = "6df27a14-a6c0-4d07-81c5-1c8e304bd06a", #Environment ID for Checkmarx One DAST scan
    [Parameter(Mandatory=$false)]
    [string]$ApiKey = $env:CX_APIKEY,
    [Parameter(Mandatory=$false)]
    [string]$ClientId = "b695463a-6a4c-4396-8add-5a8c7b10dc25", #AppID for Azure AD app registration (Checkmarx One)
    [Parameter(Mandatory=$false)]
    [string]$ClientSecret = $env:AZURE_CLIENT_SECRET, #Secret for Azure AD app registration (Checkmarx One) — set AZURE_CLIENT_SECRET env var
    [Parameter(Mandatory=$false)]
    [string]$Tenant = "fusion.co.th", #Tenant for Azure AD app registration (Checkmarx One)
    [Parameter(Mandatory=$false)]
    [string]$TargetUrl = "https://devsecops360.fusion.co.th", #endpoint URL for direct scan mode
    [Parameter(Mandatory=$false)]
    [string]$DastImage = "checkmarx/dast:latest",
    [Parameter(Mandatory=$false)]
    [string]$ZapConfigDir = "D:\ZAP Config" 
)

$ErrorActionPreference = "Stop"

# Ensure CX_APIKEY is set
if (-not $ApiKey) {
    throw "CX_APIKEY not set. Pass -ApiKey or set CX_APIKEY env var."
}

function Get-AzureToken {
    param($ClientId, $ClientSecret, $Tenant)
    $body = @{
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "$ClientId/.default"
        grant_type    = "client_credentials"
    }
    $response = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $body
    return $response.access_token
}

function New-ReportDirName {
    return "dast-output-$(Get-Random -Minimum 1000000000 -Maximum 9999999999)"
}

# === MODE: auto (recommended) ===
# Gets fresh Azure AD token, injects via httpsender script, runs scan
if ($Mode -eq "auto") {
    Write-Host "=== DAST Scan: Auto Mode (Bearer Token + Httpsender) ===" -ForegroundColor Cyan
    Write-Host "Getting Azure AD token..." -ForegroundColor Yellow
    $token = Get-AzureToken -ClientId $ClientId -ClientSecret $ClientSecret -Tenant $Tenant
    Write-Host "Token obtained: $($token.Substring(0,20))..." -ForegroundColor Green

    Write-Host "Starting scan (Zscaler CA injected, httpsender auth)..." -ForegroundColor Yellow

    docker run --user root `
        -e "CX_APIKEY=$ApiKey" `
        -e "AZURE_TOKEN=$token" `
        -v "${ZapConfigDir}:/dast" `
        --entrypoint /bin/sh `
        $DastImage `
        -c "cp /dast/zscaler-root-ca.crt /usr/local/share/ca-certificates/ && update-ca-certificates && /app/bin web --base-url https://sng.ast.checkmarx.net --environment-id $EnvironmentId --config /dast/test-auth.yaml --verbose"

    return
}

# === MODE: yaml (basic, no auth) ===
if ($Mode -eq "yaml") {
    Write-Host "=== Mode: ZAP Automation YAML (no auth) ===" -ForegroundColor Cyan

    docker run --user root `
        -e "CX_APIKEY=$ApiKey" `
        -v "${ZapConfigDir}:/dast" `
        --entrypoint /bin/sh `
        $DastImage `
        -c "cp /dast/zscaler-root-ca.crt /usr/local/share/ca-certificates/ && update-ca-certificates && /app/bin web --base-url https://sng.ast.checkmarx.net --environment-id $EnvironmentId --config /dast/test-checkmarx.yaml --verbose"

    return
}

# === MODE: direct ===
if ($Mode -eq "direct") {
    Write-Host "=== Mode: Get Token + Direct Scan ===" -ForegroundColor Cyan
    Write-Host "Getting Azure AD token..." -ForegroundColor Yellow

    $token = Get-AzureToken -ClientId $ClientId -ClientSecret $ClientSecret -Tenant $Tenant
    Write-Host "Token obtained: $($token.Substring(0,20))..." -ForegroundColor Green

    # The scan command requires env auth session configured in Checkmarx One UI
    # This mode works for simple URL scans without auth pre-config
    Write-Host "Starting direct scan" -ForegroundColor Yellow

    docker run --user root `
        -e "CX_APIKEY=$ApiKey" `
        -e "AZURE_TOKEN=$token" `
        -v "${ZapConfigDir}:/dast" `
        --entrypoint /bin/sh `
        $DastImage `
        -c "cp /dast/zscaler-root-ca.crt /usr/local/share/ca-certificates/ && update-ca-certificates && /app/bin scan --base-url https://sng.ast.checkmarx.net --environment-id $EnvironmentId --url $TargetUrl --custom-header 'Authorization: Bearer $AZURE_TOKEN' --verbose"

    return
}

# === MODE: help ===
Write-Host @"
Usage: .\Run-DastScan.ps1 -Mode <mode> [-EnvironmentId <id>] [-ApiKey <key>]

Modes:
  auto (default)  - Gets fresh Azure AD token, injects via httpsender script,
                    runs full DAST scan with Checkmarx wrapper. (Recommended)
  yaml            - Basic scan using YAML plan (no authentication).
  direct          - Gets token, passes via custom-header to scan command.

Examples:
  .\Run-DastScan.ps1                                          # auto mode
  .\Run-DastScan.ps1 -Mode yaml                               # basic scan
  .\Run-DastScan.ps1 -EnvironmentId <id> -ApiKey <key>        # custom env/key
"@ -ForegroundColor White
