#!/bin/bash

# AWS Infrastructure Deletion Script for Direct Marketing Portal
# This script deletes all AWS resources created for the staging environment

set -e  # Exit on error

# Default values
ENV_NAME="${1:-staging}"
AWS_REGION="${2:-us-east-1}"

# Derived resource names
PROJECT_NAME="direct-marketing"
VPC_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc"
ECR_BACKEND_REPO="${PROJECT_NAME}-backend"
ECR_FRONTEND_REPO="${PROJECT_NAME}-frontend"
DB_INSTANCE_NAME="${PROJECT_NAME}-${ENV_NAME}-db"
BACKEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-backend"
FRONTEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-frontend"

echo "================================================"
echo "Direct Marketing Portal - Infrastructure Deletion"
echo "================================================"
echo "Environment: ${ENV_NAME}"
echo "Region: ${AWS_REGION}"
echo "================================================"
echo ""
echo "WARNING: This will delete ALL infrastructure for ${ENV_NAME} environment!"
echo "This includes:"
echo "  - App Runner services"
echo "  - RDS database (all data will be lost)"
echo "  - VPC and networking components"
echo "  - IAM roles"
echo "  - VPC connector"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deletion cancelled."
    exit 0
fi
echo ""

# Function to delete App Runner services
delete_app_runner_services() {
    echo "Deleting App Runner services..."
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Delete backend service
    BACKEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${BACKEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${BACKEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null; then
        aws apprunner delete-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --output text
        echo "  ✓ Backend service deletion initiated"
        
        # Wait for service to be deleted
        echo "  Waiting for backend service to be deleted..."
        aws apprunner wait service-deleted \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" || true
    else
        echo "  Backend service not found (may already be deleted)"
    fi
    
    # Delete frontend service
    FRONTEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${FRONTEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${FRONTEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null; then
        aws apprunner delete-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --output text
        echo "  ✓ Frontend service deletion initiated"
        
        # Wait for service to be deleted
        echo "  Waiting for frontend service to be deleted..."
        aws apprunner wait service-deleted \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" || true
    else
        echo "  Frontend service not found (may already be deleted)"
    fi
}

# Function to delete VPC connector
delete_vpc_connector() {
    echo ""
    echo "Deleting VPC connector..."
    
    VPC_CONNECTOR_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc-connector"
    
    VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors \
        --region "${AWS_REGION}" \
        --query "VpcConnectors[?VpcConnectorName=='${VPC_CONNECTOR_NAME}'].VpcConnectorArn" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${VPC_CONNECTOR_ARN}" ]; then
        aws apprunner delete-vpc-connector \
            --vpc-connector-arn "${VPC_CONNECTOR_ARN}" \
            --region "${AWS_REGION}"
        echo "  ✓ VPC connector deletion initiated"
        
        # Wait a bit for deletion to process
        sleep 5
    else
        echo "  VPC connector not found (may already be deleted)"
    fi
}

# Function to delete RDS instance
delete_rds_instance() {
    echo ""
    echo "Deleting RDS instance..."
    
    if aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_NAME}" --region "${AWS_REGION}" &> /dev/null; then
        aws rds delete-db-instance \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --skip-final-snapshot \
            --region "${AWS_REGION}"
        echo "  ✓ RDS instance deletion initiated"
        
        echo "  Waiting for RDS instance to be deleted (this may take several minutes)..."
        aws rds wait db-instance-deleted \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}"
        echo "  ✓ RDS instance deleted"
    else
        echo "  RDS instance not found (may already be deleted)"
    fi
}

# Function to delete RDS subnet group
delete_db_subnet_group() {
    echo ""
    echo "Deleting RDS subnet group..."
    
    DB_SUBNET_GROUP="${PROJECT_NAME}-${ENV_NAME}-db-subnet-group"
    
    if aws rds describe-db-subnet-groups --db-subnet-group-name "${DB_SUBNET_GROUP}" --region "${AWS_REGION}" &> /dev/null; then
        aws rds delete-db-subnet-group \
            --db-subnet-group-name "${DB_SUBNET_GROUP}" \
            --region "${AWS_REGION}"
        echo "  ✓ DB subnet group deleted"
    else
        echo "  DB subnet group not found (may already be deleted)"
    fi
}

# Function to delete security groups
delete_security_groups() {
    echo ""
    echo "Deleting security groups..."
    
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${VPC_NAME}" \
        --region "${AWS_REGION}" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${VPC_ID}" = "None" ]; then
        echo "  VPC not found, skipping security group deletion"
        return
    fi
    
    # Delete RDS security group
    RDS_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-rds-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${RDS_SG_ID}" != "None" ]; then
        aws ec2 delete-security-group \
            --group-id "${RDS_SG_ID}" \
            --region "${AWS_REGION}"
        echo "  ✓ RDS security group deleted"
    else
        echo "  RDS security group not found"
    fi
    
    # Delete backend security group
    BACKEND_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-backend-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${BACKEND_SG_ID}" != "None" ]; then
        aws ec2 delete-security-group \
            --group-id "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}"
        echo "  ✓ Backend security group deleted"
    else
        echo "  Backend security group not found"
    fi
}

# Function to delete VPC components
delete_vpc() {
    echo ""
    echo "Deleting VPC and networking components..."
    
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${VPC_NAME}" \
        --region "${AWS_REGION}" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${VPC_ID}" = "None" ]; then
        echo "  VPC not found (may already be deleted)"
        return
    fi
    
    # Delete subnets
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[].SubnetId' \
        --output text)
    
    for SUBNET_ID in $SUBNET_IDS; do
        aws ec2 delete-subnet \
            --subnet-id "${SUBNET_ID}" \
            --region "${AWS_REGION}"
        echo "  ✓ Deleted subnet: ${SUBNET_ID}"
    done
    
    # Delete route tables (except main)
    ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
        --output text)
    
    for RT_ID in $ROUTE_TABLE_IDS; do
        aws ec2 delete-route-table \
            --route-table-id "${RT_ID}" \
            --region "${AWS_REGION}"
        echo "  ✓ Deleted route table: ${RT_ID}"
    done
    
    # Detach and delete internet gateway
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${IGW_ID}" != "None" ]; then
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "${IGW_ID}" \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}"
        
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "${IGW_ID}" \
            --region "${AWS_REGION}"
        echo "  ✓ Deleted internet gateway: ${IGW_ID}"
    fi
    
    # Delete VPC
    aws ec2 delete-vpc \
        --vpc-id "${VPC_ID}" \
        --region "${AWS_REGION}"
    echo "  ✓ Deleted VPC: ${VPC_ID}"
}

# Function to delete IAM roles
delete_iam_roles() {
    echo ""
    echo "Deleting IAM roles..."
    
    ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-role"
    ECR_ACCESS_ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-ecr-access-role"
    
    # Delete App Runner role
    if aws iam get-role --role-name "${ROLE_NAME}" &> /dev/null 2>&1; then
        # Detach policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text)
        
        for POLICY_ARN in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "${ROLE_NAME}" \
                --policy-arn "${POLICY_ARN}"
        done
        
        aws iam delete-role --role-name "${ROLE_NAME}"
        echo "  ✓ Deleted IAM role: ${ROLE_NAME}"
    else
        echo "  IAM role not found: ${ROLE_NAME}"
    fi
    
    # Delete ECR access role
    if aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" &> /dev/null 2>&1; then
        # Detach policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text)
        
        for POLICY_ARN in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "${ECR_ACCESS_ROLE_NAME}" \
                --policy-arn "${POLICY_ARN}"
        done
        
        aws iam delete-role --role-name "${ECR_ACCESS_ROLE_NAME}"
        echo "  ✓ Deleted IAM role: ${ECR_ACCESS_ROLE_NAME}"
    else
        echo "  IAM role not found: ${ECR_ACCESS_ROLE_NAME}"
    fi
}

# Function to optionally delete ECR repositories
delete_ecr_repositories() {
    echo ""
    read -p "Do you want to delete ECR repositories (and all images)? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "  Skipping ECR repository deletion"
        return
    fi
    
    echo "Deleting ECR repositories..."
    
    # Delete backend repository
    if aws ecr describe-repositories --repository-names "${ECR_BACKEND_REPO}" --region "${AWS_REGION}" &> /dev/null; then
        aws ecr delete-repository \
            --repository-name "${ECR_BACKEND_REPO}" \
            --force \
            --region "${AWS_REGION}"
        echo "  ✓ Deleted backend ECR repository"
    else
        echo "  Backend ECR repository not found"
    fi
    
    # Delete frontend repository
    if aws ecr describe-repositories --repository-names "${ECR_FRONTEND_REPO}" --region "${AWS_REGION}" &> /dev/null; then
        aws ecr delete-repository \
            --repository-name "${ECR_FRONTEND_REPO}" \
            --force \
            --region "${AWS_REGION}"
        echo "  ✓ Deleted frontend ECR repository"
    else
        echo "  Frontend ECR repository not found"
    fi
}

# Main execution
main() {
    delete_app_runner_services
    delete_vpc_connector
    delete_rds_instance
    delete_db_subnet_group
    delete_security_groups
    delete_vpc
    delete_iam_roles
    delete_ecr_repositories
    
    echo ""
    echo "================================================"
    echo "Infrastructure Deletion Complete!"
    echo "================================================"
}

# Run main function
main
