#!/bin/bash

# AWS Infrastructure Deletion Script for Direct Marketing Portal
# This script deletes all AWS resources created for the staging environment
#
# Usage: ./delete-infrastructure.sh [environment] [region]
#   environment: Environment name (default: staging)
#   region: AWS region (default: eu-central-1)

# Don't use set -e as we want to continue even if some resources don't exist
# set -e

# Default values
ENV_NAME="${1:-staging}"
AWS_REGION="${2:-eu-central-1}"

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

# Function to get App Runner service ARN by name
get_apprunner_service_arn() {
    local service_name=$1
    aws apprunner list-services \
        --region "${AWS_REGION}" \
        --query "ServiceSummaryList[?ServiceName=='${service_name}'].ServiceArn" \
        --output text 2>/dev/null || echo ""
}

# Function to wait for App Runner service to be deleted
wait_for_apprunner_service_deleted() {
    local service_arn=$1
    local service_name=$2
    local max_attempts=40
    local attempt=1
    
    echo "  Waiting for ${service_name} to be deleted..."
    while [ $attempt -le $max_attempts ]; do
        # Check if service still exists
        STATUS=$(aws apprunner describe-service \
            --service-arn "${service_arn}" \
            --region "${AWS_REGION}" \
            --query 'Service.Status' \
            --output text 2>/dev/null || echo "DELETED")
        
        if [ "${STATUS}" = "DELETED" ] || [ -z "${STATUS}" ]; then
            echo "  ✓ ${service_name} has been deleted"
            return 0
        elif [ "${STATUS}" = "DELETE_FAILED" ]; then
            echo "  ✗ ${service_name} deletion failed"
            return 1
        fi
        
        echo "    Status: ${STATUS} (attempt ${attempt}/${max_attempts})"
        sleep 15
        attempt=$((attempt + 1))
    done
    
    echo "  ⚠ Timeout waiting for ${service_name} deletion, continuing..."
    return 0
}

# Function to delete App Runner services
delete_app_runner_services() {
    echo "Deleting App Runner services..."
    
    # Delete backend service
    BACKEND_SERVICE_ARN=$(get_apprunner_service_arn "${BACKEND_SERVICE_NAME}")
    
    if [ -n "${BACKEND_SERVICE_ARN}" ] && [ "${BACKEND_SERVICE_ARN}" != "None" ]; then
        aws apprunner delete-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" > /dev/null 2>&1 || true
        echo "  ✓ Backend service deletion initiated"
        
        wait_for_apprunner_service_deleted "${BACKEND_SERVICE_ARN}" "backend service"
    else
        echo "  Backend service not found (may already be deleted)"
    fi
    
    # Delete frontend service
    FRONTEND_SERVICE_ARN=$(get_apprunner_service_arn "${FRONTEND_SERVICE_NAME}")
    
    if [ -n "${FRONTEND_SERVICE_ARN}" ] && [ "${FRONTEND_SERVICE_ARN}" != "None" ]; then
        aws apprunner delete-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" > /dev/null 2>&1 || true
        echo "  ✓ Frontend service deletion initiated"
        
        wait_for_apprunner_service_deleted "${FRONTEND_SERVICE_ARN}" "frontend service"
    else
        echo "  Frontend service not found (may already be deleted)"
    fi
}

# Function to delete VPC connector
delete_vpc_connector() {
    echo ""
    echo "Deleting VPC connector..."
    
    VPC_CONNECTOR_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc-connector"
    
    # Get all VPC connectors with this name (there might be multiple versions)
    VPC_CONNECTOR_ARNS=$(aws apprunner list-vpc-connectors \
        --region "${AWS_REGION}" \
        --query "VpcConnectors[?VpcConnectorName=='${VPC_CONNECTOR_NAME}'].VpcConnectorArn" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${VPC_CONNECTOR_ARNS}" ] && [ "${VPC_CONNECTOR_ARNS}" != "None" ]; then
        for VPC_CONNECTOR_ARN in ${VPC_CONNECTOR_ARNS}; do
            aws apprunner delete-vpc-connector \
                --vpc-connector-arn "${VPC_CONNECTOR_ARN}" \
                --region "${AWS_REGION}" > /dev/null 2>&1 || true
            echo "  ✓ VPC connector deletion initiated: ${VPC_CONNECTOR_ARN}"
        done
        
        # Wait for deletion
        echo "  Waiting for VPC connector(s) to be deleted..."
        sleep 15
    else
        echo "  VPC connector not found (may already be deleted)"
    fi
}

# Function to delete RDS instance
delete_rds_instance() {
    echo ""
    echo "Deleting RDS instance..."
    
    DB_STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier "${DB_INSTANCE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")
    
    if [ "${DB_STATUS}" != "not-found" ]; then
        # Check if already being deleted
        if [ "${DB_STATUS}" = "deleting" ]; then
            echo "  RDS instance is already being deleted, waiting..."
        else
            aws rds delete-db-instance \
                --db-instance-identifier "${DB_INSTANCE_NAME}" \
                --skip-final-snapshot \
                --delete-automated-backups \
                --region "${AWS_REGION}" > /dev/null 2>&1 || true
            echo "  ✓ RDS instance deletion initiated"
        fi
        
        echo "  Waiting for RDS instance to be deleted (this may take several minutes)..."
        aws rds wait db-instance-deleted \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}" 2>/dev/null || true
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
            --region "${AWS_REGION}" 2>/dev/null || true
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
    
    if [ "${VPC_ID}" = "None" ] || [ -z "${VPC_ID}" ]; then
        echo "  VPC not found, skipping security group deletion"
        return
    fi
    
    # Get security group IDs
    RDS_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-rds-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    BACKEND_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-backend-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    # First, revoke ingress rules that reference other security groups
    if [ "${RDS_SG_ID}" != "None" ] && [ -n "${RDS_SG_ID}" ]; then
        # Revoke all ingress rules first
        aws ec2 revoke-security-group-ingress \
            --group-id "${RDS_SG_ID}" \
            --protocol tcp \
            --port 5432 \
            --source-group "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
    fi
    
    # Delete backend security group first (it's referenced by RDS SG)
    if [ "${BACKEND_SG_ID}" != "None" ] && [ -n "${BACKEND_SG_ID}" ]; then
        aws ec2 delete-security-group \
            --group-id "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Backend security group deleted"
    else
        echo "  Backend security group not found"
    fi
    
    # Then delete RDS security group
    if [ "${RDS_SG_ID}" != "None" ] && [ -n "${RDS_SG_ID}" ]; then
        aws ec2 delete-security-group \
            --group-id "${RDS_SG_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ RDS security group deleted"
    else
        echo "  RDS security group not found"
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
    
    if [ "${VPC_ID}" = "None" ] || [ -z "${VPC_ID}" ]; then
        echo "  VPC not found (may already be deleted)"
        return
    fi
    
    # First, disassociate and delete route table associations (except main)
    echo "  Cleaning up route tables..."
    ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text 2>/dev/null || echo "")
    
    for RT_ID in $ROUTE_TABLE_IDS; do
        # Get and delete associations first
        ASSOC_IDS=$(aws ec2 describe-route-tables \
            --route-table-ids "${RT_ID}" \
            --region "${AWS_REGION}" \
            --query 'RouteTables[0].Associations[?!Main].RouteTableAssociationId' \
            --output text 2>/dev/null || echo "")
        
        for ASSOC_ID in $ASSOC_IDS; do
            aws ec2 disassociate-route-table \
                --association-id "${ASSOC_ID}" \
                --region "${AWS_REGION}" 2>/dev/null || true
        done
        
        aws ec2 delete-route-table \
            --route-table-id "${RT_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Deleted route table: ${RT_ID}"
    done
    
    # Delete subnets
    echo "  Deleting subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null || echo "")
    
    for SUBNET_ID in $SUBNET_IDS; do
        aws ec2 delete-subnet \
            --subnet-id "${SUBNET_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Deleted subnet: ${SUBNET_ID}"
    done
    
    # Detach and delete internet gateway
    echo "  Deleting internet gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${IGW_ID}" != "None" ] && [ -n "${IGW_ID}" ]; then
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "${IGW_ID}" \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "${IGW_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Deleted internet gateway: ${IGW_ID}"
    fi
    
    # Delete VPC
    echo "  Deleting VPC..."
    aws ec2 delete-vpc \
        --vpc-id "${VPC_ID}" \
        --region "${AWS_REGION}" 2>/dev/null || true
    echo "  ✓ Deleted VPC: ${VPC_ID}"
}

# Function to delete IAM roles
delete_iam_roles() {
    echo ""
    echo "Deleting IAM roles..."
    
    ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-role"
    ECR_ACCESS_ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-ecr-access-role"
    
    # Delete App Runner instance role
    if aws iam get-role --role-name "${ROLE_NAME}" &> /dev/null 2>&1; then
        # Detach all policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "${ROLE_NAME}" \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        for POLICY_ARN in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "${ROLE_NAME}" \
                --policy-arn "${POLICY_ARN}" 2>/dev/null || true
        done
        
        aws iam delete-role --role-name "${ROLE_NAME}" 2>/dev/null || true
        echo "  ✓ Deleted IAM role: ${ROLE_NAME}"
    else
        echo "  IAM role not found: ${ROLE_NAME}"
    fi
    
    # Delete ECR access role
    if aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" &> /dev/null 2>&1; then
        # Detach all policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        for POLICY_ARN in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "${ECR_ACCESS_ROLE_NAME}" \
                --policy-arn "${POLICY_ARN}" 2>/dev/null || true
        done
        
        aws iam delete-role --role-name "${ECR_ACCESS_ROLE_NAME}" 2>/dev/null || true
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
            --region "${AWS_REGION}" > /dev/null 2>&1 || true
        echo "  ✓ Deleted backend ECR repository"
    else
        echo "  Backend ECR repository not found"
    fi
    
    # Delete frontend repository
    if aws ecr describe-repositories --repository-names "${ECR_FRONTEND_REPO}" --region "${AWS_REGION}" &> /dev/null; then
        aws ecr delete-repository \
            --repository-name "${ECR_FRONTEND_REPO}" \
            --force \
            --region "${AWS_REGION}" > /dev/null 2>&1 || true
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
