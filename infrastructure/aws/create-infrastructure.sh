#!/bin/bash

# AWS Infrastructure Creation Script for Direct Marketing Portal
# This script creates all required AWS resources for the staging environment
#
# IMPORTANT: For production environments, consider using AWS Secrets Manager
# or Parameter Store for sensitive credentials instead of environment variables.
#
# Usage: ./create-infrastructure.sh [environment] [region] [db-password]
#   environment: Environment name (default: staging)
#   region: AWS region (default: eu-central-1)
#   db-password: Database password (auto-generated if not provided)

set -e  # Exit on error

# Default values
ENV_NAME="${1:-staging}"
AWS_REGION="${2:-eu-central-1}"
# Generate URL-safe password (no special characters that break URLs or JSON)
DB_PASSWORD="${3:-$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)}"

# Derived resource names
PROJECT_NAME="direct-marketing"
VPC_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc"
ECR_BACKEND_REPO="${PROJECT_NAME}-backend"
ECR_FRONTEND_REPO="${PROJECT_NAME}-frontend"
DB_INSTANCE_NAME="${PROJECT_NAME}-${ENV_NAME}-db"
BACKEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-backend"
FRONTEND_SERVICE_NAME="${PROJECT_NAME}-${ENV_NAME}-frontend"

echo "================================================"
echo "Direct Marketing Portal - Infrastructure Setup"
echo "================================================"
echo "Environment: ${ENV_NAME}"
echo "Region: ${AWS_REGION}"
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

# Function to check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "Error: AWS credentials are not configured properly."
        exit 1
    fi
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "✓ AWS credentials are configured (Account: ${ACCOUNT_ID})"
}

# Function to wait for App Runner service to be running
wait_for_apprunner_service() {
    local service_arn=$1
    local service_name=$2
    local max_attempts=60
    local attempt=1
    
    echo "  Waiting for ${service_name} to be running (this may take several minutes)..."
    while [ $attempt -le $max_attempts ]; do
        STATUS=$(aws apprunner describe-service \
            --service-arn "${service_arn}" \
            --region "${AWS_REGION}" \
            --query 'Service.Status' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "${STATUS}" = "RUNNING" ]; then
            echo "  ✓ ${service_name} is now running"
            return 0
        elif [ "${STATUS}" = "CREATE_FAILED" ] || [ "${STATUS}" = "DELETE_FAILED" ] || [ "${STATUS}" = "DELETED" ]; then
            echo "  ✗ ${service_name} failed with status: ${STATUS}"
            echo "  Check the AWS Console for more details about the failure."
            return 1
        fi
        
        echo "    Status: ${STATUS} (attempt ${attempt}/${max_attempts})"
        sleep 30
        attempt=$((attempt + 1))
    done
    
    echo "  ✗ Timeout waiting for ${service_name}"
    return 1
}

# Function to get App Runner service ARN by name
get_apprunner_service_arn() {
    local service_name=$1
    aws apprunner list-services \
        --region "${AWS_REGION}" \
        --query "ServiceSummaryList[?ServiceName=='${service_name}'].ServiceArn" \
        --output text 2>/dev/null || echo ""
}

# Function to create ECR repositories
create_ecr_repositories() {
    echo ""
    echo "Creating ECR repositories..."
    
    # Create backend repository
    if aws ecr describe-repositories --repository-names "${ECR_BACKEND_REPO}" --region "${AWS_REGION}" &> /dev/null; then
        echo "  Backend repository already exists"
        BACKEND_REPO_URI=$(aws ecr describe-repositories --repository-names "${ECR_BACKEND_REPO}" --region "${AWS_REGION}" --query 'repositories[0].repositoryUri' --output text)
    else
        BACKEND_REPO_URI=$(aws ecr create-repository \
            --repository-name "${ECR_BACKEND_REPO}" \
            --region "${AWS_REGION}" \
            --query 'repository.repositoryUri' \
            --output text)
        echo "  ✓ Created backend ECR repository: ${BACKEND_REPO_URI}"
    fi
    
    # Create frontend repository
    if aws ecr describe-repositories --repository-names "${ECR_FRONTEND_REPO}" --region "${AWS_REGION}" &> /dev/null; then
        echo "  Frontend repository already exists"
        FRONTEND_REPO_URI=$(aws ecr describe-repositories --repository-names "${ECR_FRONTEND_REPO}" --region "${AWS_REGION}" --query 'repositories[0].repositoryUri' --output text)
    else
        FRONTEND_REPO_URI=$(aws ecr create-repository \
            --repository-name "${ECR_FRONTEND_REPO}" \
            --region "${AWS_REGION}" \
            --query 'repository.repositoryUri' \
            --output text)
        echo "  ✓ Created frontend ECR repository: ${FRONTEND_REPO_URI}"
    fi
}

# Function to create VPC
create_vpc() {
    echo ""
    echo "Creating VPC and networking..."
    
    # Check if VPC already exists
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Name,Values=${VPC_NAME}" \
        --region "${AWS_REGION}" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${VPC_ID}" != "None" ] && [ -n "${VPC_ID}" ]; then
        echo "  VPC already exists: ${VPC_ID}"
    else
        # Create VPC
        VPC_ID=$(aws ec2 create-vpc \
            --cidr-block 10.0.0.0/16 \
            --region "${AWS_REGION}" \
            --query 'Vpc.VpcId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${VPC_ID}" \
            --tags "Key=Name,Value=${VPC_NAME}" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created VPC: ${VPC_ID}"
        
        # Enable DNS support (required for RDS)
        aws ec2 modify-vpc-attribute \
            --vpc-id "${VPC_ID}" \
            --enable-dns-support \
            --region "${AWS_REGION}"
        
        # Enable DNS hostnames (required for RDS)
        aws ec2 modify-vpc-attribute \
            --vpc-id "${VPC_ID}" \
            --enable-dns-hostnames \
            --region "${AWS_REGION}"
        
        echo "  ✓ Enabled DNS support and hostnames for VPC"
    fi
    
    # Create Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Name,Values=${VPC_NAME}-igw" \
        --region "${AWS_REGION}" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${IGW_ID}" != "None" ] && [ -n "${IGW_ID}" ]; then
        echo "  Internet Gateway already exists: ${IGW_ID}"
    else
        IGW_ID=$(aws ec2 create-internet-gateway \
            --region "${AWS_REGION}" \
            --query 'InternetGateway.InternetGatewayId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${IGW_ID}" \
            --tags "Key=Name,Value=${VPC_NAME}-igw" \
            --region "${AWS_REGION}"
        
        aws ec2 attach-internet-gateway \
            --vpc-id "${VPC_ID}" \
            --internet-gateway-id "${IGW_ID}" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created and attached Internet Gateway: ${IGW_ID}"
    fi
    
    # Get availability zones for the region
    AZ1=$(aws ec2 describe-availability-zones \
        --region "${AWS_REGION}" \
        --query 'AvailabilityZones[0].ZoneName' \
        --output text)
    AZ2=$(aws ec2 describe-availability-zones \
        --region "${AWS_REGION}" \
        --query 'AvailabilityZones[1].ZoneName' \
        --output text)
    
    echo "  Using availability zones: ${AZ1}, ${AZ2}"
    
    # Create public subnet 1
    PUBLIC_SUBNET_1=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-1" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PUBLIC_SUBNET_1}" != "None" ] && [ -n "${PUBLIC_SUBNET_1}" ]; then
        echo "  Public subnet 1 already exists: ${PUBLIC_SUBNET_1}"
    else
        PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
            --vpc-id "${VPC_ID}" \
            --cidr-block 10.0.1.0/24 \
            --availability-zone "${AZ1}" \
            --region "${AWS_REGION}" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${PUBLIC_SUBNET_1}" \
            --tags "Key=Name,Value=${VPC_NAME}-public-1" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created public subnet 1: ${PUBLIC_SUBNET_1}"
    fi
    
    # Create public subnet 2
    PUBLIC_SUBNET_2=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-2" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PUBLIC_SUBNET_2}" != "None" ] && [ -n "${PUBLIC_SUBNET_2}" ]; then
        echo "  Public subnet 2 already exists: ${PUBLIC_SUBNET_2}"
    else
        PUBLIC_SUBNET_2=$(aws ec2 create-subnet \
            --vpc-id "${VPC_ID}" \
            --cidr-block 10.0.2.0/24 \
            --availability-zone "${AZ2}" \
            --region "${AWS_REGION}" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${PUBLIC_SUBNET_2}" \
            --tags "Key=Name,Value=${VPC_NAME}-public-2" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created public subnet 2: ${PUBLIC_SUBNET_2}"
    fi
    
    # Create private subnet 1 (for RDS and VPC connector)
    PRIVATE_SUBNET_1=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-private-1" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PRIVATE_SUBNET_1}" != "None" ] && [ -n "${PRIVATE_SUBNET_1}" ]; then
        echo "  Private subnet 1 already exists: ${PRIVATE_SUBNET_1}"
    else
        PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
            --vpc-id "${VPC_ID}" \
            --cidr-block 10.0.11.0/24 \
            --availability-zone "${AZ1}" \
            --region "${AWS_REGION}" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${PRIVATE_SUBNET_1}" \
            --tags "Key=Name,Value=${VPC_NAME}-private-1" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created private subnet 1: ${PRIVATE_SUBNET_1}"
    fi
    
    # Create private subnet 2 (for RDS and VPC connector)
    PRIVATE_SUBNET_2=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-private-2" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PRIVATE_SUBNET_2}" != "None" ] && [ -n "${PRIVATE_SUBNET_2}" ]; then
        echo "  Private subnet 2 already exists: ${PRIVATE_SUBNET_2}"
    else
        PRIVATE_SUBNET_2=$(aws ec2 create-subnet \
            --vpc-id "${VPC_ID}" \
            --cidr-block 10.0.12.0/24 \
            --availability-zone "${AZ2}" \
            --region "${AWS_REGION}" \
            --query 'Subnet.SubnetId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${PRIVATE_SUBNET_2}" \
            --tags "Key=Name,Value=${VPC_NAME}-private-2" \
            --region "${AWS_REGION}"
        
        echo "  ✓ Created private subnet 2: ${PRIVATE_SUBNET_2}"
    fi
    
    # Create route table for public subnets
    ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-rt" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${ROUTE_TABLE_ID}" != "None" ] && [ -n "${ROUTE_TABLE_ID}" ]; then
        echo "  Route table already exists: ${ROUTE_TABLE_ID}"
    else
        ROUTE_TABLE_ID=$(aws ec2 create-route-table \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}" \
            --query 'RouteTable.RouteTableId' \
            --output text)
        
        aws ec2 create-tags \
            --resources "${ROUTE_TABLE_ID}" \
            --tags "Key=Name,Value=${VPC_NAME}-public-rt" \
            --region "${AWS_REGION}"
        
        aws ec2 create-route \
            --route-table-id "${ROUTE_TABLE_ID}" \
            --destination-cidr-block 0.0.0.0/0 \
            --gateway-id "${IGW_ID}" \
            --region "${AWS_REGION}" > /dev/null
        
        aws ec2 associate-route-table \
            --subnet-id "${PUBLIC_SUBNET_1}" \
            --route-table-id "${ROUTE_TABLE_ID}" \
            --region "${AWS_REGION}" > /dev/null
        
        aws ec2 associate-route-table \
            --subnet-id "${PUBLIC_SUBNET_2}" \
            --route-table-id "${ROUTE_TABLE_ID}" \
            --region "${AWS_REGION}" > /dev/null
        
        echo "  ✓ Created route table and associated with public subnets: ${ROUTE_TABLE_ID}"
    fi
}

# Function to create security groups
create_security_groups() {
    echo ""
    echo "Creating security groups..."
    
    # Security group for RDS
    RDS_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-rds-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${RDS_SG_ID}" != "None" ] && [ -n "${RDS_SG_ID}" ]; then
        echo "  RDS security group already exists: ${RDS_SG_ID}"
    else
        RDS_SG_ID=$(aws ec2 create-security-group \
            --group-name "${PROJECT_NAME}-${ENV_NAME}-rds-sg" \
            --description "Security group for RDS PostgreSQL" \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}" \
            --query 'GroupId' \
            --output text)
        
        echo "  ✓ Created RDS security group: ${RDS_SG_ID}"
    fi
    
    # Security group for App Runner VPC connector
    BACKEND_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-backend-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${BACKEND_SG_ID}" != "None" ] && [ -n "${BACKEND_SG_ID}" ]; then
        echo "  Backend security group already exists: ${BACKEND_SG_ID}"
    else
        BACKEND_SG_ID=$(aws ec2 create-security-group \
            --group-name "${PROJECT_NAME}-${ENV_NAME}-backend-sg" \
            --description "Security group for App Runner backend VPC connector" \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}" \
            --query 'GroupId' \
            --output text)
        
        echo "  ✓ Created backend security group: ${BACKEND_SG_ID}"
    fi
    
    # Allow backend security group to access RDS on port 5432
    EXISTING_RULES=$(aws ec2 describe-security-groups \
        --group-ids "${RDS_SG_ID}" \
        --region "${AWS_REGION}" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol=='tcp'].UserIdGroupPairs[?GroupId=='${BACKEND_SG_ID}'].GroupId" \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${EXISTING_RULES}" ] || [ "${EXISTING_RULES}" = "None" ]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "${RDS_SG_ID}" \
            --protocol tcp \
            --port 5432 \
            --source-group "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Added ingress rule: backend -> RDS on port 5432"
    else
        echo "  Ingress rule already exists: backend -> RDS on port 5432"
    fi
}

# Function to create RDS subnet group
create_db_subnet_group() {
    echo ""
    echo "Creating RDS subnet group..."
    
    DB_SUBNET_GROUP="${PROJECT_NAME}-${ENV_NAME}-db-subnet-group"
    
    if aws rds describe-db-subnet-groups --db-subnet-group-name "${DB_SUBNET_GROUP}" --region "${AWS_REGION}" &> /dev/null; then
        echo "  DB subnet group already exists"
    else
        aws rds create-db-subnet-group \
            --db-subnet-group-name "${DB_SUBNET_GROUP}" \
            --db-subnet-group-description "Subnet group for ${PROJECT_NAME} ${ENV_NAME} RDS" \
            --subnet-ids "${PRIVATE_SUBNET_1}" "${PRIVATE_SUBNET_2}" \
            --region "${AWS_REGION}" > /dev/null
        
        echo "  ✓ Created DB subnet group: ${DB_SUBNET_GROUP}"
    fi
}

# Function to create RDS instance
create_rds_instance() {
    echo ""
    echo "Creating RDS PostgreSQL instance..."
    
    # Check if RDS instance already exists
    DB_STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier "${DB_INSTANCE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "not-found")
    
    if [ "${DB_STATUS}" != "not-found" ]; then
        echo "  RDS instance already exists (status: ${DB_STATUS})"
        
        if [ "${DB_STATUS}" != "available" ]; then
            echo "  Waiting for RDS instance to be available..."
            aws rds wait db-instance-available \
                --db-instance-identifier "${DB_INSTANCE_NAME}" \
                --region "${AWS_REGION}"
        fi
        
        DB_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        echo "  ✓ RDS endpoint: ${DB_ENDPOINT}"
    else
        aws rds create-db-instance \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --db-instance-class db.t3.micro \
            --engine postgres \
            --engine-version "16.3" \
            --master-username dbadmin \
            --master-user-password "${DB_PASSWORD}" \
            --allocated-storage 20 \
            --db-subnet-group-name "${DB_SUBNET_GROUP}" \
            --vpc-security-group-ids "${RDS_SG_ID}" \
            --no-publicly-accessible \
            --backup-retention-period 7 \
            --storage-encrypted \
            --region "${AWS_REGION}" > /dev/null
        
        echo "  ✓ RDS instance creation initiated: ${DB_INSTANCE_NAME}"
        echo "  Waiting for RDS instance to be available (this may take 5-10 minutes)..."
        
        aws rds wait db-instance-available \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}"
        
        DB_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
        
        echo "  ✓ RDS instance is now available: ${DB_ENDPOINT}"
    fi
}

# Function to create IAM role for App Runner
create_app_runner_role() {
    echo ""
    echo "Creating IAM roles for App Runner..."
    
    ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-role"
    
    # Check if role already exists
    if aws iam get-role --role-name "${ROLE_NAME}" &> /dev/null 2>&1; then
        echo "  IAM instance role already exists: ${ROLE_NAME}"
        ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)
    else
        # Create trust policy for App Runner tasks
        echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"tasks.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' > /tmp/trust-policy.json
        
        ROLE_ARN=$(aws iam create-role \
            --role-name "${ROLE_NAME}" \
            --assume-role-policy-document file:///tmp/trust-policy.json \
            --query 'Role.Arn' \
            --output text)
        
        rm -f /tmp/trust-policy.json
        echo "  ✓ Created IAM instance role: ${ROLE_ARN}"
    fi
    
    # Create ECR access role for App Runner
    ECR_ACCESS_ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-ecr-access-role"
    
    if aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" &> /dev/null 2>&1; then
        echo "  ECR access role already exists: ${ECR_ACCESS_ROLE_NAME}"
        ECR_ACCESS_ROLE_ARN=$(aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" --query 'Role.Arn' --output text)
    else
        # Create trust policy for App Runner build service
        echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"build.apprunner.amazonaws.com"},"Action":"sts:AssumeRole"}]}' > /tmp/ecr-trust-policy.json
        
        ECR_ACCESS_ROLE_ARN=$(aws iam create-role \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --assume-role-policy-document file:///tmp/ecr-trust-policy.json \
            --query 'Role.Arn' \
            --output text)
        
        rm -f /tmp/ecr-trust-policy.json
        echo "  ✓ Created ECR access role: ${ECR_ACCESS_ROLE_ARN}"
        
        # Attach ECR access policy
        aws iam attach-role-policy \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
        
        echo "  ✓ Attached ECR access policy"
        
        # Wait for role to propagate (IAM is eventually consistent)
        echo "  Waiting for IAM role to propagate..."
        sleep 15
    fi
}

# Function to create VPC connector for App Runner
create_vpc_connector() {
    echo ""
    echo "Creating VPC connector for App Runner..."
    
    VPC_CONNECTOR_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc-connector"
    
    # Check if VPC connector already exists (and is active)
    VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors \
        --region "${AWS_REGION}" \
        --query "VpcConnectors[?VpcConnectorName=='${VPC_CONNECTOR_NAME}' && Status=='ACTIVE'].VpcConnectorArn | [0]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${VPC_CONNECTOR_ARN}" ] && [ "${VPC_CONNECTOR_ARN}" != "None" ] && [ "${VPC_CONNECTOR_ARN}" != "null" ]; then
        echo "  VPC connector already exists: ${VPC_CONNECTOR_ARN}"
    else
        VPC_CONNECTOR_ARN=$(aws apprunner create-vpc-connector \
            --vpc-connector-name "${VPC_CONNECTOR_NAME}" \
            --subnets "${PRIVATE_SUBNET_1}" "${PRIVATE_SUBNET_2}" \
            --security-groups "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}" \
            --query 'VpcConnector.VpcConnectorArn' \
            --output text)
        
        echo "  ✓ Created VPC connector: ${VPC_CONNECTOR_ARN}"
        
        # Wait for VPC connector to be active
        echo "  Waiting for VPC connector to be active..."
        local max_attempts=20
        local attempt=1
        while [ $attempt -le $max_attempts ]; do
            STATUS=$(aws apprunner describe-vpc-connector \
                --vpc-connector-arn "${VPC_CONNECTOR_ARN}" \
                --region "${AWS_REGION}" \
                --query 'VpcConnector.Status' \
                --output text 2>/dev/null || echo "UNKNOWN")
            
            if [ "${STATUS}" = "ACTIVE" ]; then
                echo "  ✓ VPC connector is active"
                break
            fi
            
            echo "    Status: ${STATUS} (attempt ${attempt}/${max_attempts})"
            sleep 5
            attempt=$((attempt + 1))
        done
    fi
}

# Function to check if ECR repository has images
check_ecr_image_exists() {
    local repo_name=$1
    local image_count=$(aws ecr list-images \
        --repository-name "${repo_name}" \
        --region "${AWS_REGION}" \
        --query 'length(imageIds)' \
        --output text 2>/dev/null || echo "0")
    
    if [ "${image_count}" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to create App Runner services
create_app_runner_services() {
    echo ""
    echo "Creating App Runner services..."
    
    # Check if Docker images exist in ECR
    if ! check_ecr_image_exists "${ECR_BACKEND_REPO}"; then
        echo ""
        echo "  ⚠ WARNING: No images found in backend ECR repository (${ECR_BACKEND_REPO})"
        echo "  App Runner services require Docker images to be pushed first."
        echo ""
        echo "  To push images, run:"
        echo "    cd infrastructure/aws"
        echo "    ./deploy.sh ${AWS_REGION}"
        echo ""
        echo "  Then re-run this script to create App Runner services."
        echo ""
        SKIP_APPRUNNER=true
        return 0
    fi
    
    if ! check_ecr_image_exists "${ECR_FRONTEND_REPO}"; then
        echo ""
        echo "  ⚠ WARNING: No images found in frontend ECR repository (${ECR_FRONTEND_REPO})"
        echo "  App Runner services require Docker images to be pushed first."
        echo ""
        echo "  To push images, run:"
        echo "    cd infrastructure/aws"
        echo "    ./deploy.sh ${AWS_REGION}"
        echo ""
        echo "  Then re-run this script to create App Runner services."
        echo ""
        SKIP_APPRUNNER=true
        return 0
    fi
    
    # Backend service
    BACKEND_SERVICE_ARN=$(get_apprunner_service_arn "${BACKEND_SERVICE_NAME}")
    
    if [ -n "${BACKEND_SERVICE_ARN}" ] && [ "${BACKEND_SERVICE_ARN}" != "None" ]; then
        echo "  Backend App Runner service already exists"
        BACKEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    else
        # Write backend service configuration to temp file
        cat > /tmp/backend-service.json << EOFBACKEND
{
  "ServiceName": "${BACKEND_SERVICE_NAME}",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "AccessRoleArn": "${ECR_ACCESS_ROLE_ARN}"
    },
    "ImageRepository": {
      "ImageIdentifier": "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_BACKEND_REPO}:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "DATABASE_URL": "postgresql+psycopg://dbadmin:${DB_PASSWORD}@${DB_ENDPOINT}:5432/postgres",
          "STORAGE_ROOT": "/app/storage",
          "ESIGN_PROVIDER": "stub",
          "ESIGN_WEBHOOK_SECRET": "staging-webhook-secret"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1 vCPU",
    "Memory": "2 GB",
    "InstanceRoleArn": "${ROLE_ARN}"
  },
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "${VPC_CONNECTOR_ARN}"
    }
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
EOFBACKEND
        
        BACKEND_SERVICE_ARN=$(aws apprunner create-service \
            --cli-input-json file:///tmp/backend-service.json \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceArn' \
            --output text)
        
        rm -f /tmp/backend-service.json
        echo "  ✓ Backend App Runner service created: ${BACKEND_SERVICE_ARN}"
        
        # Wait for service to be running using polling
        if ! wait_for_apprunner_service "${BACKEND_SERVICE_ARN}" "backend service"; then
            echo "  ✗ Backend service failed to start. Check AWS Console for details."
            return 1
        fi
        
        BACKEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    fi
    
    echo "  ✓ Backend service URL: https://${BACKEND_SERVICE_URL}"
    
    # Frontend service
    FRONTEND_SERVICE_ARN=$(get_apprunner_service_arn "${FRONTEND_SERVICE_NAME}")
    
    if [ -n "${FRONTEND_SERVICE_ARN}" ] && [ "${FRONTEND_SERVICE_ARN}" != "None" ]; then
        echo "  Frontend App Runner service already exists"
        FRONTEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    else
        # Write frontend service configuration to temp file
        cat > /tmp/frontend-service.json << EOFFRONTEND
{
  "ServiceName": "${FRONTEND_SERVICE_NAME}",
  "SourceConfiguration": {
    "AuthenticationConfiguration": {
      "AccessRoleArn": "${ECR_ACCESS_ROLE_ARN}"
    },
    "ImageRepository": {
      "ImageIdentifier": "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_FRONTEND_REPO}:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "3000",
        "RuntimeEnvironmentVariables": {
          "NEXT_PUBLIC_API_BASE_URL": "https://${BACKEND_SERVICE_URL}"
        }
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1 vCPU",
    "Memory": "2 GB",
    "InstanceRoleArn": "${ROLE_ARN}"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
EOFFRONTEND
        
        FRONTEND_SERVICE_ARN=$(aws apprunner create-service \
            --cli-input-json file:///tmp/frontend-service.json \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceArn' \
            --output text)
        
        rm -f /tmp/frontend-service.json
        echo "  ✓ Frontend App Runner service created: ${FRONTEND_SERVICE_ARN}"
        
        # Wait for service to be running using polling
        if ! wait_for_apprunner_service "${FRONTEND_SERVICE_ARN}" "frontend service"; then
            echo "  ✗ Frontend service failed to start. Check AWS Console for details."
            return 1
        fi
        
        FRONTEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    fi
    
    echo "  ✓ Frontend service URL: https://${FRONTEND_SERVICE_URL}"
}

# Main execution
main() {
    SKIP_APPRUNNER=false
    
    check_aws_cli
    check_aws_credentials
    create_ecr_repositories
    create_vpc
    create_security_groups
    create_db_subnet_group
    create_rds_instance
    create_app_runner_role
    create_vpc_connector
    create_app_runner_services
    
    echo ""
    echo "================================================"
    echo "Infrastructure Setup Complete!"
    echo "================================================"
    echo ""
    echo "IMPORTANT INFORMATION:"
    echo "----------------------"
    echo "Environment: ${ENV_NAME}"
    echo "Region: ${AWS_REGION}"
    echo ""
    echo "ECR Repositories:"
    echo "  Backend:  ${BACKEND_REPO_URI}"
    echo "  Frontend: ${FRONTEND_REPO_URI}"
    echo ""
    echo "Database:"
    echo "  Endpoint: ${DB_ENDPOINT}"
    echo "  Username: dbadmin"
    echo "  Password: ${DB_PASSWORD}"
    echo "  Database: postgres"
    echo "  Connection: postgresql://dbadmin:${DB_PASSWORD}@${DB_ENDPOINT}:5432/postgres"
    echo ""
    
    if [ "${SKIP_APPRUNNER}" = "true" ]; then
        echo "App Runner Services: NOT CREATED (images not yet pushed)"
        echo ""
        echo "NEXT STEPS:"
        echo "  1. Push Docker images: ./deploy.sh ${AWS_REGION}"
        echo "  2. Re-run this script to create App Runner services"
    else
        echo "App Runner Services:"
        echo "  Backend:  https://${BACKEND_SERVICE_URL}"
        echo "  Frontend: https://${FRONTEND_SERVICE_URL}"
    fi
    echo ""
    echo "⚠ SAVE THE DATABASE PASSWORD SECURELY!"
    echo "================================================"
}

# Run main function
main
