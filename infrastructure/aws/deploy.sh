#!/bin/bash

# AWS Docker Build and Push Script for Direct Marketing Portal
# This script builds and pushes Docker images to Amazon ECR
#
# Usage: ./deploy.sh [region] [tag] [auto-deploy]
#   region: AWS region (default: eu-central-1)
#   tag: Image tag (default: latest)
#   auto-deploy: Auto-trigger App Runner deployments (default: false, set to 'true' to skip prompt)

set -e  # Exit on error

# Default values
AWS_REGION="${1:-eu-central-1}"
TAG="${2:-latest}"
AUTO_DEPLOY="${3:-false}"

# Derived resource names
PROJECT_NAME="direct-marketing"
ECR_BACKEND_REPO="${PROJECT_NAME}-backend"
ECR_FRONTEND_REPO="${PROJECT_NAME}-frontend"

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

echo "================================================"
echo "Direct Marketing Portal - Docker Build & Push"
echo "================================================"
echo "Region: ${AWS_REGION}"
echo "Tag: ${TAG}"
echo "Project Root: ${PROJECT_ROOT}"
echo "================================================"
echo ""

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed. Please install it first."
        echo "  See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    echo "✓ AWS CLI is installed"
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install it first."
        echo "  See: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Error: Docker daemon is not running. Please start Docker."
        exit 1
    fi
    
    echo "✓ Docker is installed and running"
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials are not configured properly."
        echo "  Run 'aws configure' to set up your credentials."
        exit 1
    fi
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✓ AWS credentials are configured (Account: ${ACCOUNT_ID})"
}

# Function to authenticate with ECR
authenticate_ecr() {
    echo ""
    echo "Authenticating with Amazon ECR..."
    
    ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    if ! aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login --username AWS --password-stdin "${ECR_REGISTRY}" 2>/dev/null; then
        echo "Error: Failed to authenticate with ECR"
        exit 1
    fi
    
    echo "✓ Successfully authenticated with ECR"
}

# Function to get ECR repository URIs
get_ecr_repositories() {
    echo ""
    echo "Getting ECR repository information..."
    
    BACKEND_REPO_URI=$(aws ecr describe-repositories \
        --repository-names "${ECR_BACKEND_REPO}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${BACKEND_REPO_URI}" ] || [ "${BACKEND_REPO_URI}" = "None" ]; then
        echo "Error: Backend ECR repository not found: ${ECR_BACKEND_REPO}"
        echo ""
        echo "Please run create-infrastructure.sh first to create the ECR repositories:"
        echo "  cd infrastructure/aws"
        echo "  ./create-infrastructure.sh staging ${AWS_REGION}"
        exit 1
    fi
    
    FRONTEND_REPO_URI=$(aws ecr describe-repositories \
        --repository-names "${ECR_FRONTEND_REPO}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${FRONTEND_REPO_URI}" ] || [ "${FRONTEND_REPO_URI}" = "None" ]; then
        echo "Error: Frontend ECR repository not found: ${ECR_FRONTEND_REPO}"
        echo ""
        echo "Please run create-infrastructure.sh first to create the ECR repositories:"
        echo "  cd infrastructure/aws"
        echo "  ./create-infrastructure.sh staging ${AWS_REGION}"
        exit 1
    fi
    
    echo "✓ Backend repository: ${BACKEND_REPO_URI}"
    echo "✓ Frontend repository: ${FRONTEND_REPO_URI}"
}

# Function to check if Dockerfile exists
check_dockerfile() {
    local dir=$1
    local name=$2
    
    if [ ! -f "${dir}/Dockerfile" ]; then
        echo "Error: Dockerfile not found in ${dir}"
        exit 1
    fi
}

# Function to build and push backend image
build_and_push_backend() {
    echo ""
    echo "Building backend Docker image..."
    
    check_dockerfile "${PROJECT_ROOT}/backend" "backend"
    
    cd "${PROJECT_ROOT}/backend"
    
    # Build with build output
    if ! docker build --platform linux/amd64 -t "${BACKEND_REPO_URI}:${TAG}" .; then
        echo "Error: Failed to build backend Docker image"
        exit 1
    fi
    
    echo "✓ Backend image built successfully"
    
    # Also tag as latest if we're using a different tag
    if [ "${TAG}" != "latest" ]; then
        docker tag "${BACKEND_REPO_URI}:${TAG}" "${BACKEND_REPO_URI}:latest"
    fi
    
    echo "Pushing backend image to ECR..."
    if ! docker push "${BACKEND_REPO_URI}:${TAG}"; then
        echo "Error: Failed to push backend image to ECR"
        exit 1
    fi
    
    # Push latest tag too if different
    if [ "${TAG}" != "latest" ]; then
        docker push "${BACKEND_REPO_URI}:latest"
    fi
    
    echo "✓ Backend image pushed: ${BACKEND_REPO_URI}:${TAG}"
}

# Function to build and push frontend image
build_and_push_frontend() {
    echo ""
    echo "Building frontend Docker image..."
    
    check_dockerfile "${PROJECT_ROOT}/frontend" "frontend"
    
    cd "${PROJECT_ROOT}/frontend"
    
    # Build with build output
    if ! docker build --platform linux/amd64 -t "${FRONTEND_REPO_URI}:${TAG}" .; then
        echo "Error: Failed to build frontend Docker image"
        exit 1
    fi
    
    echo "✓ Frontend image built successfully"
    
    # Also tag as latest if we're using a different tag
    if [ "${TAG}" != "latest" ]; then
        docker tag "${FRONTEND_REPO_URI}:${TAG}" "${FRONTEND_REPO_URI}:latest"
    fi
    
    echo "Pushing frontend image to ECR..."
    if ! docker push "${FRONTEND_REPO_URI}:${TAG}"; then
        echo "Error: Failed to push frontend image to ECR"
        exit 1
    fi
    
    # Push latest tag too if different
    if [ "${TAG}" != "latest" ]; then
        docker push "${FRONTEND_REPO_URI}:latest"
    fi
    
    echo "✓ Frontend image pushed: ${FRONTEND_REPO_URI}:${TAG}"
}

# Function to get App Runner service ARN by name
get_apprunner_service_arn() {
    local service_name=$1
    aws apprunner list-services \
        --region "${AWS_REGION}" \
        --query "ServiceSummaryList[?ServiceName=='${service_name}'].ServiceArn" \
        --output text 2>/dev/null || echo ""
}

# Function to trigger App Runner deployments
trigger_deployments() {
    echo ""
    
    ENV_NAME="staging"
    BACKEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-backend"
    FRONTEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-frontend"
    
    # Check if services exist first
    BACKEND_SERVICE_ARN=$(get_apprunner_service_arn "${BACKEND_SERVICE_NAME}")
    FRONTEND_SERVICE_ARN=$(get_apprunner_service_arn "${FRONTEND_SERVICE_NAME}")
    
    if [ -z "${BACKEND_SERVICE_ARN}" ] || [ "${BACKEND_SERVICE_ARN}" = "None" ]; then
        echo "App Runner services not yet created."
        echo ""
        echo "To create App Runner services, re-run create-infrastructure.sh:"
        echo "  ./create-infrastructure.sh staging ${AWS_REGION}"
        return 0
    fi
    
    if [ "${AUTO_DEPLOY}" != "true" ]; then
        read -p "Do you want to trigger App Runner deployments? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Skipping deployment trigger"
            return 0
        fi
    fi
    
    echo "Triggering App Runner deployments..."
    
    # Trigger backend deployment
    if [ -n "${BACKEND_SERVICE_ARN}" ] && [ "${BACKEND_SERVICE_ARN}" != "None" ]; then
        OPERATION_ID=$(aws apprunner start-deployment \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'OperationId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "${OPERATION_ID}" ]; then
            echo "  ✓ Backend deployment triggered (Operation ID: ${OPERATION_ID})"
        else
            echo "  ⚠ Failed to trigger backend deployment"
        fi
    fi
    
    # Trigger frontend deployment
    if [ -n "${FRONTEND_SERVICE_ARN}" ] && [ "${FRONTEND_SERVICE_ARN}" != "None" ]; then
        OPERATION_ID=$(aws apprunner start-deployment \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'OperationId' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "${OPERATION_ID}" ]; then
            echo "  ✓ Frontend deployment triggered (Operation ID: ${OPERATION_ID})"
        else
            echo "  ⚠ Failed to trigger frontend deployment"
        fi
    fi
    
    echo ""
    echo "Deployments triggered. You can monitor progress in the AWS Console:"
    echo "  https://${AWS_REGION}.console.aws.amazon.com/apprunner/home?region=${AWS_REGION}#/services"
}

# Main execution
main() {
    check_aws_cli
    check_docker
    check_aws_credentials
    get_ecr_repositories
    authenticate_ecr
    build_and_push_backend
    build_and_push_frontend
    trigger_deployments
    
    echo ""
    echo "================================================"
    echo "Build and Push Complete!"
    echo "================================================"
    echo ""
    echo "Images pushed:"
    echo "  Backend:  ${BACKEND_REPO_URI}:${TAG}"
    echo "  Frontend: ${FRONTEND_REPO_URI}:${TAG}"
    echo ""
    echo "Next steps:"
    echo "  1. If App Runner services exist, deployments have been triggered"
    echo "  2. If not, run: ./create-infrastructure.sh staging ${AWS_REGION}"
    echo "================================================"
}

# Run main function
main
