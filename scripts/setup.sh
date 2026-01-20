#!/bin/bash
# Setup script for Purview Custom Connector Solution Accelerator
# This script helps you configure azd environment variables

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Purview Custom Connector - Deployment Setup Helper  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if azd is installed
if ! command -v azd &> /dev/null; then
    echo -e "${RED}Error: Azure Developer CLI (azd) is not installed.${NC}"
    echo -e "Install it from: ${BLUE}https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd${NC}"
    exit 1
fi

# Check if az is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI (az) is not installed.${NC}"
    echo -e "Install it from: ${BLUE}https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
    exit 1
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Logging in...${NC}"
    az login
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}\n"

# Initialize azd environment
echo -e "${CYAN}Step 1: Initialize azd environment${NC}"
read -p "Enter environment name (e.g., dev, test, prod) [default: dev]: " ENV_NAME
ENV_NAME=${ENV_NAME:-dev}

# Check if environment exists
if azd env list 2>/dev/null | grep -q "^${ENV_NAME}$"; then
    echo -e "${YELLOW}Environment '${ENV_NAME}' already exists.${NC}"
    read -p "Do you want to use it? (y/n) [default: y]: " USE_EXISTING
    USE_EXISTING=${USE_EXISTING:-y}
    if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
        azd env select "$ENV_NAME"
    else
        read -p "Enter new environment name: " ENV_NAME
        azd env new "$ENV_NAME"
    fi
else
    azd env new "$ENV_NAME"
fi

echo -e "${GREEN}✓ Environment '${ENV_NAME}' selected${NC}\n"

# Check for existing Purview accounts
echo -e "${CYAN}Step 2: Check for existing Purview accounts${NC}"
PURVIEW_ACCOUNTS=$(az purview account list --query "[].name" -o tsv 2>/dev/null || echo "")

if [ -z "$PURVIEW_ACCOUNTS" ]; then
    echo -e "${YELLOW}No existing Purview accounts found.${NC}"
    PURVIEW_ACCOUNT_NAME=""
    PURVIEW_RESOURCE_GROUP=""
else
    echo -e "${GREEN}Found existing Purview account(s):${NC}"
    echo "$PURVIEW_ACCOUNTS" | nl
    echo ""
    echo -e "${YELLOW}Note: You can only have ONE Purview account per Azure tenant.${NC}"
    read -p "Enter Purview account name to reuse (or press Enter to create new): " PURVIEW_ACCOUNT_NAME
    
    if [ -n "$PURVIEW_ACCOUNT_NAME" ]; then
        # Get the resource group of the existing Purview account
        echo -e "${YELLOW}Detecting Purview account resource group...${NC}"
        PURVIEW_RESOURCE_GROUP=$(az purview account show --name "$PURVIEW_ACCOUNT_NAME" --query "resourceGroup" -o tsv 2>/dev/null | grep -v '^WARNING:' | grep -v '^ERROR:' | tr -d '\r\n')
        
        if [ -n "$PURVIEW_RESOURCE_GROUP" ]; then
            echo -e "${GREEN}[OK] Detected resource group: ${PURVIEW_RESOURCE_GROUP}${NC}"
            read -p "Is this correct? (y/n) [default: y]: " CONFIRM_RG
            CONFIRM_RG=${CONFIRM_RG:-y}
            
            if [[ ! "$CONFIRM_RG" =~ ^[Yy]$ ]]; then
                read -p "Enter the resource group name for the Purview account: " PURVIEW_RESOURCE_GROUP
            fi
        else
            echo -e "${YELLOW}[WARNING] Could not auto-detect resource group${NC}"
            read -p "Enter the resource group name where Purview account '$PURVIEW_ACCOUNT_NAME' is located: " PURVIEW_RESOURCE_GROUP
        fi
    else
        PURVIEW_RESOURCE_GROUP=""
    fi
fi

echo ""

# Configure service principal
echo -e "${CYAN}Step 3: Configure Service Principal${NC}"
read -p "Do you want to create a new service principal? (y/n) [default: n]: " CREATE_SP
CREATE_SP=${CREATE_SP:-n}

if [[ "$CREATE_SP" =~ ^[Yy]$ ]]; then
    read -p "Enter service principal name [default: PurviewCustomConnectorSP]: " SP_NAME
    SP_NAME=${SP_NAME:-PurviewCustomConnectorSP}
    
    echo -e "${YELLOW}Creating service principal...${NC}"
    SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --role Contributor)
    
    CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
    CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
    TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenant')
    
    echo -e "${GREEN}✓ Service principal created${NC}"
    echo -e "Client ID: ${CYAN}${CLIENT_ID}${NC}"
    echo -e "${YELLOW}⚠ Save the client secret securely - it won't be shown again!${NC}"
else
    read -p "Enter service principal Client ID (appId): " CLIENT_ID
    read -sp "Enter service principal Client Secret (password): " CLIENT_SECRET
    echo ""
    read -p "Enter service principal name [default: PurviewCustomConnectorSP]: " SP_NAME
    SP_NAME=${SP_NAME:-PurviewCustomConnectorSP}
fi

echo ""

# Azure configuration
echo -e "${CYAN}Step 4: Configure Azure settings${NC}"
read -p "Enter Azure region [default: eastus]: " LOCATION
LOCATION=${LOCATION:-eastus}

read -p "Enter resource group name [default: pccsa-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-pccsa-rg}

read -p "Enter base name for resources (max 7 chars) [default: pccsa]: " BASE_NAME
BASE_NAME=${BASE_NAME:-pccsa}

echo ""

# Set all environment variables
echo -e "${CYAN}Step 5: Setting environment variables...${NC}"

azd env set AZURE_CLIENT_ID "$CLIENT_ID"
azd env set AZURE_CLIENT_SECRET "$CLIENT_SECRET" --secret
azd env set AZURE_CLIENT_NAME "$SP_NAME"
azd env set AZURE_LOCATION "$LOCATION"
azd env set AZURE_RESOURCE_GROUP "$RESOURCE_GROUP"
azd env set BASE_NAME "$BASE_NAME"

if [ -n "$PURVIEW_ACCOUNT_NAME" ]; then
    azd env set PURVIEW_ACCOUNT_NAME "$PURVIEW_ACCOUNT_NAME"
    azd env set PURVIEW_RESOURCE_GROUP "$PURVIEW_RESOURCE_GROUP"
    echo -e "${GREEN}✓ Will reuse existing Purview account: ${PURVIEW_ACCOUNT_NAME}${NC}"
else
    echo -e "${YELLOW}A new Purview account will be created${NC}"
fi

echo -e "${GREEN}✓ All environment variables set${NC}\n"

# Summary
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  Configuration Summary                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo -e "Environment:       ${GREEN}${ENV_NAME}${NC}"
echo -e "Service Principal: ${GREEN}${SP_NAME}${NC}"
echo -e "Resource Group:    ${GREEN}${RESOURCE_GROUP}${NC}"
echo -e "Location:          ${GREEN}${LOCATION}${NC}"
echo -e "Base Name:         ${GREEN}${BASE_NAME}${NC}"
if [ -n "$PURVIEW_ACCOUNT_NAME" ]; then
    echo -e "Purview Account:   ${GREEN}${PURVIEW_ACCOUNT_NAME} (existing)${NC}"
else
    echo -e "Purview Account:   ${YELLOW}Will be created${NC}"
fi
echo ""

# Deploy prompt
read -p "Do you want to deploy now? (y/n) [default: y]: " DEPLOY_NOW
DEPLOY_NOW=${DEPLOY_NOW:-y}

if [[ "$DEPLOY_NOW" =~ ^[Yy]$ ]]; then
    echo -e "\n${CYAN}Starting deployment...${NC}\n"
    azd up
else
    echo -e "\n${YELLOW}Deployment skipped.${NC}"
    echo -e "To deploy later, run: ${GREEN}azd up${NC}"
fi

echo -e "\n${GREEN}✓ Setup complete!${NC}"
echo -e "\nUseful commands:"
echo -e "  ${CYAN}azd up${NC}          - Deploy everything"
echo -e "  ${CYAN}azd provision${NC}   - Update infrastructure only"
echo -e "  ${CYAN}azd env get-values${NC} - View environment variables"
echo -e "  ${CYAN}azd down${NC}        - Delete all resources"
