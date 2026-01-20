# Setup script for Purview Custom Connector Solution Accelerator
# This script helps you configure azd environment variables

# Colors
function Write-Color {
    param($Text, $Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "========================================================" Cyan
Write-Color "  Purview Custom Connector - Deployment Setup Helper  " Cyan
Write-Color "========================================================" Cyan
Write-Host ""

# Check if azd is installed
if (-not (Get-Command azd -ErrorAction SilentlyContinue)) {
    Write-Color "Error: Azure Developer CLI (azd) is not installed." Red
    Write-Color "Install it from: https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd" Blue
    exit 1
}

# Check if az is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Color "Error: Azure CLI (az) is not installed." Red
    Write-Color "Install it from: https://docs.microsoft.com/cli/azure/install-azure-cli" Blue
    exit 1
}

# Check Azure login
try {
    $null = az account show 2>$null
} catch {
    Write-Color "Not logged in to Azure. Logging in..." Yellow
    az login
}

Write-Color "[OK] Prerequisites check passed" Green
Write-Host ""

# Initialize azd environment
Write-Color "Step 1: Initialize azd environment" Cyan
$ENV_NAME = Read-Host "Enter environment name (e.g., dev, test, prod) [default: dev]"
if ([string]::IsNullOrWhiteSpace($ENV_NAME)) { $ENV_NAME = "dev" }

# Check if environment exists
$existingEnvs = azd env list 2>$null | Out-String
if ($existingEnvs -match $ENV_NAME) {
    Write-Color "Environment '$ENV_NAME' already exists." Yellow
    $useExisting = Read-Host "Do you want to use it? (y/n) [default: y]"
    if ([string]::IsNullOrWhiteSpace($useExisting)) { $useExisting = "y" }
    
    if ($useExisting -match "^[Yy]") {
        azd env select $ENV_NAME
    } else {
        $ENV_NAME = Read-Host "Enter new environment name"
        azd env new $ENV_NAME
    }
} else {
    azd env new $ENV_NAME
}

Write-Color "[OK] Environment '$ENV_NAME' selected" Green
Write-Host ""

# Check for existing Purview accounts
Write-Color "Step 2: Check for existing Purview accounts" Cyan

# Suppress warnings and errors, get only the valid output
$ErrorActionPreference = 'SilentlyContinue'
$purviewAccountsRaw = az purview account list --query "[].name" -o tsv 2>&1 | Where-Object { $_ -notmatch '^WARNING:' -and $_ -notmatch '^ERROR:' }
$ErrorActionPreference = 'Continue'

$purviewAccounts = $purviewAccountsRaw -join "`n"

if ([string]::IsNullOrWhiteSpace($purviewAccounts)) {
    Write-Color "No existing Purview accounts found." Yellow
    $PURVIEW_ACCOUNT_NAME = ""
    $PURVIEW_RESOURCE_GROUP = ""
} else {
    Write-Color "Found existing Purview account(s):" Green
    $accountArray = $purviewAccounts -split "`n" | Where-Object { $_ -and $_.Trim() }
    $i = 1
    foreach ($account in $accountArray) {
        Write-Host "$i. $account"
        $i++
    }
    Write-Host ""
    Write-Color "Note: You can only have ONE Purview account per Azure tenant." Yellow
    $PURVIEW_ACCOUNT_NAME = Read-Host "Enter Purview account name to reuse (or press Enter to create new)"
    
    if (-not [string]::IsNullOrWhiteSpace($PURVIEW_ACCOUNT_NAME)) {
        # Get the resource group of the existing Purview account
        Write-Color "Detecting Purview account resource group..." Yellow
        $ErrorActionPreference = 'SilentlyContinue'
        $purviewRgRaw = az purview account show --name $PURVIEW_ACCOUNT_NAME --query "resourceGroup" -o tsv 2>&1 | Where-Object { $_ -notmatch '^WARNING:' -and $_ -notmatch '^ERROR:' }
        $ErrorActionPreference = 'Continue'
        
        if (-not [string]::IsNullOrWhiteSpace($purviewRgRaw)) {
            $PURVIEW_RESOURCE_GROUP = $purviewRgRaw.Trim()
            Write-Color "[OK] Detected resource group: $PURVIEW_RESOURCE_GROUP" Green
            $confirmRg = Read-Host "Is this correct? (y/n) [default: y]"
            if ([string]::IsNullOrWhiteSpace($confirmRg)) { $confirmRg = "y" }
            
            if ($confirmRg -notmatch "^[Yy]") {
                $PURVIEW_RESOURCE_GROUP = Read-Host "Enter the resource group name for the Purview account"
            }
        } else {
            Write-Color "[WARNING] Could not auto-detect resource group" Yellow
            $PURVIEW_RESOURCE_GROUP = Read-Host "Enter the resource group name where Purview account '$PURVIEW_ACCOUNT_NAME' is located"
        }
    } else {
        $PURVIEW_RESOURCE_GROUP = ""
    }
}

Write-Host ""

# Configure service principal
Write-Color "Step 3: Configure Service Principal" Cyan
$createSP = Read-Host "Do you want to create a new service principal? (y/n) [default: n]"
if ([string]::IsNullOrWhiteSpace($createSP)) { $createSP = "n" }

if ($createSP -match "^[Yy]") {
    $SP_NAME = Read-Host "Enter service principal name [default: PurviewCustomConnectorSP]"
    if ([string]::IsNullOrWhiteSpace($SP_NAME)) { $SP_NAME = "PurviewCustomConnectorSP" }
    
    Write-Color "Creating service principal..." Yellow
    $spOutput = az ad sp create-for-rbac --name $SP_NAME --role Contributor | ConvertFrom-Json
    
    $CLIENT_ID = $spOutput.appId
    $CLIENT_SECRET = $spOutput.password
    $TENANT_ID = $spOutput.tenant
    
    Write-Color "[OK] Service principal created" Green
    Write-Color "Client ID: $CLIENT_ID" Cyan
    Write-Color "[WARNING] Save the client secret securely - it won't be shown again!" Yellow
} else {
    $CLIENT_ID = Read-Host "Enter service principal Client ID (appId)"
    $CLIENT_SECRET = Read-Host "Enter service principal Client Secret (password)" -AsSecureString
    $CLIENT_SECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($CLIENT_SECRET))
    
    $SP_NAME = Read-Host "Enter service principal name [default: PurviewCustomConnectorSP]"
    if ([string]::IsNullOrWhiteSpace($SP_NAME)) { $SP_NAME = "PurviewCustomConnectorSP" }
}

Write-Host ""

# Azure configuration
Write-Color "Step 4: Configure Azure settings" Cyan
$LOCATION = Read-Host "Enter Azure region [default: eastus]"
if ([string]::IsNullOrWhiteSpace($LOCATION)) { $LOCATION = "eastus" }

$RESOURCE_GROUP = Read-Host "Enter resource group name [default: pccsa-rg]"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) { $RESOURCE_GROUP = "pccsa-rg" }

$BASE_NAME = Read-Host "Enter base name for resources (max 7 chars) [default: pccsa]"
if ([string]::IsNullOrWhiteSpace($BASE_NAME)) { $BASE_NAME = "pccsa" }

Write-Host ""

# Set all environment variables
Write-Color "Step 5: Setting environment variables..." Cyan

azd env set AZURE_CLIENT_ID $CLIENT_ID
azd env set AZURE_CLIENT_SECRET $CLIENT_SECRET
azd env set AZURE_CLIENT_NAME $SP_NAME
azd env set AZURE_LOCATION $LOCATION
azd env set AZURE_RESOURCE_GROUP $RESOURCE_GROUP
azd env set BASE_NAME $BASE_NAME

if (-not [string]::IsNullOrWhiteSpace($PURVIEW_ACCOUNT_NAME)) {
    azd env set PURVIEW_ACCOUNT_NAME $PURVIEW_ACCOUNT_NAME
    azd env set PURVIEW_RESOURCE_GROUP $PURVIEW_RESOURCE_GROUP
    Write-Color "[OK] Will reuse existing Purview account: $PURVIEW_ACCOUNT_NAME" Green
} else {
    Write-Color "A new Purview account will be created" Yellow
}

Write-Color "[OK] All environment variables set" Green
Write-Host ""

# Summary
Write-Color "========================================================" Cyan
Write-Color "                  Configuration Summary                 " Cyan
Write-Color "========================================================" Cyan
Write-Color "Environment:       $ENV_NAME" Green
Write-Color "Service Principal: $SP_NAME" Green
Write-Color "Resource Group:    $RESOURCE_GROUP" Green
Write-Color "Location:          $LOCATION" Green
Write-Color "Base Name:         $BASE_NAME" Green
if (-not [string]::IsNullOrWhiteSpace($PURVIEW_ACCOUNT_NAME)) {
    Write-Color "Purview Account:   $PURVIEW_ACCOUNT_NAME (existing)" Green
} else {
    Write-Color "Purview Account:   Will be created" Yellow
}
Write-Host ""

# Deploy prompt
$deployNow = Read-Host "Do you want to deploy now? (y/n) [default: y]"
if ([string]::IsNullOrWhiteSpace($deployNow)) { $deployNow = "y" }

if ($deployNow -match "^[Yy]") {
    Write-Host ""
    Write-Color "Starting deployment..." Cyan
    Write-Host ""
    azd up
} else {
    Write-Host ""
    Write-Color "Deployment skipped." Yellow
    Write-Color "To deploy later, run: azd up" Green
}

Write-Host ""
Write-Color "[OK] Setup complete!" Green
Write-Host ""
Write-Host "Useful commands:"
Write-Color "  azd up          - Deploy everything" Cyan
Write-Color "  azd provision   - Update infrastructure only" Cyan
Write-Color "  azd env get-values - View environment variables" Cyan
Write-Color "  azd down        - Delete all resources" Cyan
