#!/bin/bash
# Script to check for existing Purview accounts and configure deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Purview Account Detection ===${NC}"

# Check if user is logged in
if ! az account show &>/dev/null; then
    echo -e "${RED}Error: Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo -e "${GREEN}Current Subscription:${NC} $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Search for existing Purview accounts
echo -e "\n${YELLOW}Searching for Purview accounts in subscription...${NC}"
PURVIEW_ACCOUNTS=$(az purview account list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o json)

ACCOUNT_COUNT=$(echo "$PURVIEW_ACCOUNTS" | jq '. | length')

if [ "$ACCOUNT_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No existing Purview accounts found.${NC}"
    echo -e "${GREEN}You can create a new Purview account during deployment.${NC}"
    exit 0
fi

echo -e "${GREEN}Found $ACCOUNT_COUNT Purview account(s):${NC}\n"
echo "$PURVIEW_ACCOUNTS" | jq -r '.[] | "\(.Name) - \(.ResourceGroup) - \(.Location)"' | nl

echo -e "\n${CYAN}Note:${NC} You can only have one Purview account per Azure tenant."
echo -e "If you want to use an existing account, note its name for the deployment."
echo -e "\nTo use an existing account, set the environment variable:"
echo -e "${GREEN}azd env set PURVIEW_ACCOUNT_NAME <account-name>${NC}"
