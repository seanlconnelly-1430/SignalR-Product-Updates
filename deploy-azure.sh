#!/bin/bash

# Azure Container Apps Deployment Script
# This script automates the deployment of SignalR Product Updates to Azure

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="signalr-rg"
LOCATION="eastus"
ACR_NAME="signalracr"
ENVIRONMENT_NAME="signalr-env"
SERVER_APP_NAME="signalr-server"
CLIENT_APP_NAME="signalr-client"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Azure Container Apps Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Azure CLI is not installed. Please install it first.${NC}"
    echo "macOS: brew install azure-cli"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure login status...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Logging in...${NC}"
    az login
fi

echo -e "${GREEN}✓ Azure CLI is configured${NC}"
echo ""

# Show current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${YELLOW}Current subscription: ${SUBSCRIPTION}${NC}"
read -p "Continue with this subscription? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please set the correct subscription with: az account set --subscription '<subscription-id>'"
    exit 1
fi

# Step 1: Create Resource Group
echo -e "${YELLOW}Creating resource group...${NC}"
if az group show --name $RESOURCE_GROUP &> /dev/null; then
    echo -e "${GREEN}✓ Resource group already exists${NC}"
else
    az group create --name $RESOURCE_GROUP --location $LOCATION
    echo -e "${GREEN}✓ Resource group created${NC}"
fi
echo ""

# Step 2: Create Container Registry
echo -e "${YELLOW}Creating Azure Container Registry...${NC}"
if az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo -e "${GREEN}✓ ACR already exists${NC}"
else
    az acr create \
        --resource-group $RESOURCE_GROUP \
        --name $ACR_NAME \
        --sku Basic \
        --location $LOCATION \
        --admin-enabled true
    echo -e "${GREEN}✓ ACR created${NC}"
fi
echo ""

# Get ACR credentials
echo -e "${YELLOW}Getting ACR credentials...${NC}"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)
echo -e "${GREEN}✓ ACR credentials retrieved${NC}"
echo ""

# Step 3: Login to ACR
echo -e "${YELLOW}Logging in to ACR...${NC}"
az acr login --name $ACR_NAME
echo -e "${GREEN}✓ Logged in to ACR${NC}"
echo ""

# Step 4: Build and push server image
echo -e "${YELLOW}Building server image...${NC}"
cd ProductUpdatesServer
docker build -f Dockerfile.azure -t ${ACR_NAME}.azurecr.io/signalr-server:latest .
echo -e "${GREEN}✓ Server image built${NC}"
echo ""

echo -e "${YELLOW}Pushing server image to ACR...${NC}"
docker push ${ACR_NAME}.azurecr.io/signalr-server:latest
echo -e "${GREEN}✓ Server image pushed${NC}"
cd ..
echo ""

# Step 5: Create Container Apps Environment
echo -e "${YELLOW}Creating Container Apps environment...${NC}"
if az containerapp env show --name $ENVIRONMENT_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo -e "${GREEN}✓ Environment already exists${NC}"
else
    az containerapp env create \
        --name $ENVIRONMENT_NAME \
        --resource-group $RESOURCE_GROUP \
        --location $LOCATION
    echo -e "${GREEN}✓ Environment created${NC}"
fi
echo ""

# Step 6: Deploy server container
echo -e "${YELLOW}Deploying server container...${NC}"
if az containerapp show --name $SERVER_APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo -e "${YELLOW}Server app exists, updating...${NC}"
    az containerapp update \
        --name $SERVER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --image ${ACR_NAME}.azurecr.io/signalr-server:latest
else
    az containerapp create \
        --name $SERVER_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment $ENVIRONMENT_NAME \
        --image ${ACR_NAME}.azurecr.io/signalr-server:latest \
        --registry-server ${ACR_NAME}.azurecr.io \
        --registry-username $ACR_USERNAME \
        --registry-password $ACR_PASSWORD \
        --target-port 5170 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 3 \
        --cpu 0.5 \
        --memory 1Gi \
        --env-vars ASPNETCORE_ENVIRONMENT=Production
fi
echo -e "${GREEN}✓ Server deployed${NC}"
echo ""

# Get server URL
SERVER_URL=$(az containerapp show \
    --name $SERVER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Server URL: https://${SERVER_URL}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 7: Update client environment file
echo -e "${YELLOW}Updating client environment configuration...${NC}"
cat > product-updates-client/src/environments/environment.azure.ts << EOF
export const environment = {
  production: true,
  apiUrl: 'https://${SERVER_URL}',
  signalRUrl: 'https://${SERVER_URL}/productHub'
};
EOF
echo -e "${GREEN}✓ Client environment updated with server URL${NC}"
echo ""

# Step 8: Build and push client image
echo -e "${YELLOW}Building client image...${NC}"
cd product-updates-client
docker build -f Dockerfile.azure -t ${ACR_NAME}.azurecr.io/signalr-client:latest --build-arg BUILD_CONFIGURATION=azure .
echo -e "${GREEN}✓ Client image built${NC}"
echo ""

echo -e "${YELLOW}Pushing client image to ACR...${NC}"
docker push ${ACR_NAME}.azurecr.io/signalr-client:latest
echo -e "${GREEN}✓ Client image pushed${NC}"
cd ..
echo ""

# Step 9: Deploy client container
echo -e "${YELLOW}Deploying client container...${NC}"
if az containerapp show --name $CLIENT_APP_NAME --resource-group $RESOURCE_GROUP &> /dev/null; then
    echo -e "${YELLOW}Client app exists, updating...${NC}"
    az containerapp update \
        --name $CLIENT_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --image ${ACR_NAME}.azurecr.io/signalr-client:latest
else
    az containerapp create \
        --name $CLIENT_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --environment $ENVIRONMENT_NAME \
        --image ${ACR_NAME}.azurecr.io/signalr-client:latest \
        --registry-server ${ACR_NAME}.azurecr.io \
        --registry-username $ACR_USERNAME \
        --registry-password $ACR_PASSWORD \
        --target-port 80 \
        --ingress external \
        --min-replicas 1 \
        --max-replicas 3 \
        --cpu 0.25 \
        --memory 0.5Gi
fi
echo -e "${GREEN}✓ Client deployed${NC}"
echo ""

# Get client URL
CLIENT_URL=$(az containerapp show \
    --name $CLIENT_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}Server URL: https://${SERVER_URL}${NC}"
echo -e "${GREEN}Client URL: https://${CLIENT_URL}${NC}"
echo ""
echo -e "${GREEN}Health Checks:${NC}"
echo -e "  Server: https://${SERVER_URL}/health"
echo -e "  Client: https://${CLIENT_URL}/health"
echo ""
echo -e "${YELLOW}Open the client URL in your browser to test the application!${NC}"
echo ""
echo -e "${YELLOW}To view logs:${NC}"
echo -e "  Server: az containerapp logs show --name $SERVER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo -e "  Client: az containerapp logs show --name $CLIENT_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo ""
