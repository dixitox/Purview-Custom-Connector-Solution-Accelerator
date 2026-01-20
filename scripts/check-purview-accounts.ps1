# Script to check for existing Purview accounts and configure deployment

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$CYAN = "Cyan"

Write-Host "=== Purview Account Detection ===" -ForegroundColor $CYAN

# Check if user is logged in
try {
    $null = az account show 2>$null
} catch {
    Write-Host "Error: Not logged in to Azure. Please run 'az login' first." -ForegroundColor $RED
    exit 1
}

# Get current subscription
$SUBSCRIPTION_ID = az account show --query id -o tsv
$SUBSCRIPTION_NAME = az account show --query name -o tsv

Write-Host "Current Subscription: " -NoNewline
Write-Host "$SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)" -ForegroundColor $GREEN

# Search for existing Purview accounts
Write-Host "`nSearching for Purview accounts in subscription..." -ForegroundColor $YELLOW

# Suppress warnings and errors, get only the valid JSON output
$ErrorActionPreference = 'SilentlyContinue'
$purviewAccountsRaw = az purview account list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o json 2>&1 | Where-Object { $_ -notmatch '^WARNING:' -and $_ -notmatch '^ERROR:' }
$ErrorActionPreference = 'Continue'

try {
    $PURVIEW_ACCOUNTS = ($purviewAccountsRaw -join "`n") | ConvertFrom-Json
    $ACCOUNT_COUNT = @($PURVIEW_ACCOUNTS).Count
} catch {
    Write-Host "Unable to query Purview accounts. The Purview CLI extension may not be installed." -ForegroundColor $YELLOW
    Write-Host "You can create a new Purview account during deployment." -ForegroundColor $GREEN
    exit 0
}

if ($ACCOUNT_COUNT -eq 0) {
    Write-Host "No existing Purview accounts found." -ForegroundColor $YELLOW
    Write-Host "You can create a new Purview account during deployment." -ForegroundColor $GREEN
    exit 0
}

Write-Host "Found $ACCOUNT_COUNT Purview account(s):`n" -ForegroundColor $GREEN

$i = 1
foreach ($account in $PURVIEW_ACCOUNTS) {
    Write-Host "$i. $($account.Name) - $($account.ResourceGroup) - $($account.Location)"
    $i++
}

Write-Host "`nNote: " -ForegroundColor $CYAN -NoNewline
Write-Host "You can only have one Purview account per Azure tenant."
Write-Host "If you want to use an existing account, note its name for the deployment."
Write-Host "`nTo use an existing account, set the environment variable:"
Write-Host "azd env set PURVIEW_ACCOUNT_NAME <account-name>" -ForegroundColor $GREEN
