#!/bin/bash

# AWS Infrastructure Creation Script for Direct Marketing Portal
# This script creates all required AWS resources for the staging environment
#
# IMPORTANT: For production environments, consider using AWS Secrets Manager
# or Parameter Store for sensitive credentials instead of environment variables.

set -e  # Exit on error

# Default values
ENV_NAME="${1:-staging}"
AWS_REGION="${2:-eu-central-1}"
DB_PASSWORD="${3:-$(openssl rand -base64 32)}"

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
    echo "✓ AWS credentials are configured"
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
        elif [ "${STATUS}" = "CREATE_FAILED" ] || [ "${STATUS}" = "DELETE_FAILED" ]; then
            echo "  ✗ ${service_name} failed with status: ${STATUS}"
            return 1
        fi
        
        echo "    Status: ${STATUS} (attempt ${attempt}/${max_attempts})"
        sleep 30
        attempt=$((attempt + 1))
    done
    
    echo "  ✗ Timeout waiting for ${service_name}"
    return 1
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
    
    if [ "${VPC_ID}" != "None" ] && [ "${VPC_ID}" != "" ]; then
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
        
        # Enable DNS hostnames
        aws ec2 modify-vpc-attribute \
            --vpc-id "${VPC_ID}" \
            --enable-dns-hostnames \
            --region "${AWS_REGION}"
    fi
    
    # Create Internet Gateway
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=tag:Name,Values=${VPC_NAME}-igw" \
        --region "${AWS_REGION}" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${IGW_ID}" != "None" ] && [ "${IGW_ID}" != "" ]; then
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
    
    # Create public subnets in two availability zones
    AZ1="${AWS_REGION}a"
    AZ2="${AWS_REGION}b"
    
    PUBLIC_SUBNET_1=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-1" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PUBLIC_SUBNET_1}" != "None" ] && [ "${PUBLIC_SUBNET_1}" != "" ]; then
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
    
    PUBLIC_SUBNET_2=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-2" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PUBLIC_SUBNET_2}" != "None" ] && [ "${PUBLIC_SUBNET_2}" != "" ]; then
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
    
    # Create private subnets for RDS
    PRIVATE_SUBNET_1=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-private-1" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PRIVATE_SUBNET_1}" != "None" ] && [ "${PRIVATE_SUBNET_1}" != "" ]; then
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
    
    PRIVATE_SUBNET_2=$(aws ec2 describe-subnets \
        --filters "Name=tag:Name,Values=${VPC_NAME}-private-2" \
        --region "${AWS_REGION}" \
        --query 'Subnets[0].SubnetId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${PRIVATE_SUBNET_2}" != "None" ] && [ "${PRIVATE_SUBNET_2}" != "" ]; then
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
        --filters "Name=tag:Name,Values=${VPC_NAME}-public-rt" \
        --region "${AWS_REGION}" \
        --query 'RouteTables[0].RouteTableId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${ROUTE_TABLE_ID}" != "None" ] && [ "${ROUTE_TABLE_ID}" != "" ]; then
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
            --region "${AWS_REGION}"
        
        aws ec2 associate-route-table \
            --subnet-id "${PUBLIC_SUBNET_1}" \
            --route-table-id "${ROUTE_TABLE_ID}" \
            --region "${AWS_REGION}"
        
        aws ec2 associate-route-table \
            --subnet-id "${PUBLIC_SUBNET_2}" \
            --route-table-id "${ROUTE_TABLE_ID}" \
            --region "${AWS_REGION}"
        
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
    
    if [ "${RDS_SG_ID}" != "None" ] && [ "${RDS_SG_ID}" != "" ]; then
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
    
    # Security group for App Runner (backend)
    BACKEND_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${PROJECT_NAME}-${ENV_NAME}-backend-sg" "Name=vpc-id,Values=${VPC_ID}" \
        --region "${AWS_REGION}" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "${BACKEND_SG_ID}" != "None" ] && [ "${BACKEND_SG_ID}" != "" ]; then
        echo "  Backend security group already exists: ${BACKEND_SG_ID}"
    else
        BACKEND_SG_ID=$(aws ec2 create-security-group \
            --group-name "${PROJECT_NAME}-${ENV_NAME}-backend-sg" \
            --description "Security group for App Runner backend" \
            --vpc-id "${VPC_ID}" \
            --region "${AWS_REGION}" \
            --query 'GroupId' \
            --output text)
        
        echo "  ✓ Created backend security group: ${BACKEND_SG_ID}"
    fi
    
    # Allow backend to access RDS - check using describe-security-groups instead
    EXISTING_RULE=$(aws ec2 describe-security-groups \
        --group-ids "${RDS_SG_ID}" \
        --region "${AWS_REGION}" \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\`].UserIdGroupPairs[?GroupId=='${BACKEND_SG_ID}'].GroupId" \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${EXISTING_RULE}" ]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "${RDS_SG_ID}" \
            --protocol tcp \
            --port 5432 \
            --source-group "${BACKEND_SG_ID}" \
            --region "${AWS_REGION}" 2>/dev/null || true
        echo "  ✓ Allowed backend to access RDS on port 5432"
    else
        echo "  Backend already has access to RDS"
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
            --region "${AWS_REGION}"
        
        echo "  ✓ Created DB subnet group: ${DB_SUBNET_GROUP}"
    fi
}

# Function to create RDS instance
create_rds_instance() {
    echo ""
    echo "Creating RDS PostgreSQL instance..."
    
    # Check if RDS instance already exists
    if aws rds describe-db-instances --db-instance-identifier "${DB_INSTANCE_NAME}" --region "${AWS_REGION}" &> /dev/null; then
        echo "  RDS instance already exists"
        DB_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --region "${AWS_REGION}" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text)
    else
        aws rds create-db-instance \
            --db-instance-identifier "${DB_INSTANCE_NAME}" \
            --db-instance-class db.t3.micro \
            --engine postgres \
            --engine-version 17.2 \
            --master-username dbadmin \
            --master-user-password "${DB_PASSWORD}" \
            --allocated-storage 20 \
            --db-subnet-group-name "${DB_SUBNET_GROUP}" \
            --vpc-security-group-ids "${RDS_SG_ID}" \
            --no-publicly-accessible \
            --backup-retention-period 7 \
            --region "${AWS_REGION}"
        
        echo "  ✓ RDS instance creation initiated: ${DB_INSTANCE_NAME}"
        echo "  Waiting for RDS instance to be available (this may take several minutes)..."
        
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
        echo "  IAM role already exists: ${ROLE_NAME}"
        ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query 'Role.Arn' --output text)
    else
        # Create trust policy
        cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "tasks.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        ROLE_ARN=$(aws iam create-role \
            --role-name "${ROLE_NAME}" \
            --assume-role-policy-document file:///tmp/trust-policy.json \
            --query 'Role.Arn' \
            --output text)
        
        echo "  ✓ Created IAM role: ${ROLE_ARN}"
        
        # Attach policies for ECR access
        aws iam attach-role-policy \
            --role-name "${ROLE_NAME}" \
            --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        
        echo "  ✓ Attached ECR read policy to role"
    fi
    
    # Create ECR access role for App Runner
    ECR_ACCESS_ROLE_NAME="${PROJECT_NAME}-${ENV_NAME}-apprunner-ecr-access-role"
    
    if aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" &> /dev/null 2>&1; then
        echo "  ECR access role already exists: ${ECR_ACCESS_ROLE_NAME}"
        ECR_ACCESS_ROLE_ARN=$(aws iam get-role --role-name "${ECR_ACCESS_ROLE_NAME}" --query 'Role.Arn' --output text)
    else
        # Create trust policy for App Runner build service
        cat > /tmp/ecr-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        ECR_ACCESS_ROLE_ARN=$(aws iam create-role \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --assume-role-policy-document file:///tmp/ecr-trust-policy.json \
            --query 'Role.Arn' \
            --output text)
        
        echo "  ✓ Created ECR access role: ${ECR_ACCESS_ROLE_ARN}"
        
        # Attach ECR read policy
        aws iam attach-role-policy \
            --role-name "${ECR_ACCESS_ROLE_NAME}" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
        
        echo "  ✓ Attached ECR access policy"
        
        # Wait for role to propagate
        echo "  Waiting for IAM role to propagate..."
        sleep 10
    fi
}

# Function to create VPC connector for App Runner
create_vpc_connector() {
    echo ""
    echo "Creating VPC connector for App Runner..."
    
    VPC_CONNECTOR_NAME="${PROJECT_NAME}-${ENV_NAME}-vpc-connector"
    
    # Check if VPC connector already exists
    VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors \
        --region "${AWS_REGION}" \
        --query "VpcConnectors[?VpcConnectorName=='${VPC_CONNECTOR_NAME}'].VpcConnectorArn" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${VPC_CONNECTOR_ARN}" ] && [ "${VPC_CONNECTOR_ARN}" != "None" ]; then
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
        echo "  Waiting for VPC connector to be active..."
        
        # Wait for VPC connector to be active
        sleep 15
    fi
}

# Function to create App Runner services
create_app_runner_services() {
    echo ""
    echo "Creating App Runner services..."
    
    # Get AWS account ID
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Backend service
    BACKEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${BACKEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${BACKEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null 2>&1; then
        echo "  Backend App Runner service already exists"
        BACKEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    else
        # Create backend service configuration
        cat > /tmp/backend-service.json <<EOF
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
    "Path": "/health"
  }
}
EOF
        
        BACKEND_SERVICE_ARN=$(aws apprunner create-service \
            --cli-input-json file:///tmp/backend-service.json \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceArn' \
            --output text)
        
        echo "  ✓ Backend App Runner service created: ${BACKEND_SERVICE_ARN}"
        
        # Wait for service to be running using polling
        wait_for_apprunner_service "${BACKEND_SERVICE_ARN}" "backend service"
        
        BACKEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${BACKEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
        
        echo "  ✓ Backend service URL: https://${BACKEND_SERVICE_URL}"
    fi
    
    # Frontend service
    FRONTEND_SERVICE_ARN="arn:aws:apprunner:${AWS_REGION}:${ACCOUNT_ID}:service/${FRONTEND_SERVICE_NAME}"
    if aws apprunner describe-service --service-arn "${FRONTEND_SERVICE_ARN}" --region "${AWS_REGION}" &> /dev/null 2>&1; then
        echo "  Frontend App Runner service already exists"
        FRONTEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
    else
        # Create frontend service configuration
        cat > /tmp/frontend-service.json <<EOF
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
    "Path": "/"
  }
}
EOF
        
        FRONTEND_SERVICE_ARN=$(aws apprunner create-service \
            --cli-input-json file:///tmp/frontend-service.json \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceArn' \
            --output text)
        
        echo "  ✓ Frontend App Runner service created: ${FRONTEND_SERVICE_ARN}"
        
        # Wait for service to be running using polling
        wait_for_apprunner_service "${FRONTEND_SERVICE_ARN}" "frontend service"
        
        FRONTEND_SERVICE_URL=$(aws apprunner describe-service \
            --service-arn "${FRONTEND_SERVICE_ARN}" \
            --region "${AWS_REGION}" \
            --query 'Service.ServiceUrl' \
            --output text)
        
        echo "  ✓ Frontend service URL: https://${FRONTEND_SERVICE_URL}"
    fi
}

# Main execution
main() {
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
    echo ""
    echo "App Runner Services:"
    echo "  Backend:  https://${BACKEND_SERVICE_URL}"
    echo "  Frontend: https://${FRONTEND_SERVICE_URL}"
    echo ""
    echo "SAVE THE DATABASE PASSWORD SECURELY!"
    echo "================================================"
}

# Run main function
main
