#!/bin/bash

# AWS Docker Build and Push Script for Direct Marketing Portal
# This script builds and pushes Docker images to Amazon ECR
# Usage: ./deploy.sh [region] [tag] [auto-deploy]
#   region: AWS region (default: us-east-1)
#   tag: Image tag (default: latest)
#   auto-deploy: Auto-trigger App Runner deployments (default: false, set to 'true' to skip prompt)

set -e  # Exit on error

# Default values
AWS_REGION="${1:-us-east-1}"
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
echo "================================================"
echo ""

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed. Please install it first."
        exit 1
    fi
    echo "✓ AWS CLI is installed"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Error: Docker is not installed. Please install it first."
        exit 1
    fi
    echo "✓ Docker is installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials are not configured properly."
        exit 1
    fi
    echo "✓ AWS credentials are configured"
}

# Function to authenticate with ECR
authenticate_ecr() {
    echo ""
    echo "Authenticating with Amazon ECR..."
    
    aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login --username AWS --password-stdin \
        "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com"
    
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
    
    if [ -z "${BACKEND_REPO_URI}" ]; then
        echo "Error: Backend ECR repository not found: ${ECR_BACKEND_REPO}"
        echo "Please run create-infrastructure.sh first"
        exit 1
    fi
    
    FRONTEND_REPO_URI=$(aws ecr describe-repositories \
        --repository-names "${ECR_FRONTEND_REPO}" \
        --region "${AWS_REGION}" \
        --query 'repositories[0].repositoryUri' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${FRONTEND_REPO_URI}" ]; then
        echo "Error: Frontend ECR repository not found: ${ECR_FRONTEND_REPO}"
        echo "Please run create-infrastructure.sh first"
        exit 1
    fi
    
    echo "✓ Backend repository: ${BACKEND_REPO_URI}"
    echo "✓ Frontend repository: ${FRONTEND_REPO_URI}"
}

# Function to build and push backend image
build_and_push_backend() {
    echo ""
    echo "Building backend Docker image..."
    
    cd "${PROJECT_ROOT}/backend"
    
    docker build -t "${BACKEND_REPO_URI}:${TAG}" .
    
    echo "✓ Backend image built successfully"
    
    echo "Pushing backend image to ECR..."
    docker push "${BACKEND_REPO_URI}:${TAG}"
    
    echo "✓ Backend image pushed: ${BACKEND_REPO_URI}:${TAG}"
}

# Function to build and push frontend image
build_and_push_frontend() {
    echo ""
    echo "Building frontend Docker image..."
    
    cd "${PROJECT_ROOT}/frontend"
    
    docker build -t "${FRONTEND_REPO_URI}:${TAG}" .
    
    echo "✓ Frontend image built successfully"
    
    echo "Pushing frontend image to ECR..."
    docker push "${FRONTEND_REPO_URI}:${TAG}"
    
    echo "✓ Frontend image pushed: ${FRONTEND_REPO_URI}:${TAG}"
}

# Function to trigger App Runner deployments
trigger_deployments() {
    echo ""
    if [ "${AUTO_DEPLOY}" != "true" ]; then
        read -p "Do you want to trigger App Runner deployments? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            echo "Skipping deployment trigger"
            return
        fi
    fi
    
    echo "Triggering App Runner deployments..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ENV_NAME="staging"
    BACKEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-backend"
    FRONTEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-frontend"
    
    # Trigger backend deployment
    BACKEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${BACKEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${BACKEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null; then
        OPERATION_ID=$(aws apprunner start-deployment \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'OperationId' \
            --output text)
        echo "  ✓ Backend deployment triggered (Operation ID: ${OPERATION_ID})"
    else
        echo "  Backend service not found, skipping deployment trigger"
    fi
    
    # Trigger frontend deployment
    FRONTEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${FRONTEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${FRONTEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null; then
        OPERATION_ID=$(aws apprunner start-deployment \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'OperationId' \
            --output text)
        echo "  ✓ Frontend deployment triggered (Operation ID: ${OPERATION_ID})"
    else
        echo "  Frontend service not found, skipping deployment trigger"
    fi
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
    echo "================================================"
}

# Run main function
main
