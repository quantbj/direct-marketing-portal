# AWS Infrastructure for Direct Marketing Portal

This directory contains scripts and documentation for deploying the Direct Marketing Portal to AWS using App Runner, RDS PostgreSQL, and ECR.

## Architecture Overview

The AWS infrastructure consists of:

- **Amazon ECR**: Container registry for storing Docker images
- **Amazon VPC**: Virtual Private Cloud with public and private subnets
- **Amazon RDS**: PostgreSQL 16 database (db.t3.micro for staging)
- **AWS App Runner**: Managed container services for frontend and backend
- **VPC Connector**: Connects App Runner to RDS in private subnets
- **Security Groups**: Control network access between services
- **IAM Roles**: Provide necessary permissions for services

## Prerequisites

Before you begin, ensure you have:

1. **AWS CLI installed and configured**
   ```bash
   aws --version
   aws configure
   ```
   - You need AWS CLI version 2.x or higher
   - Configure with your AWS credentials: `aws configure`

2. **Docker installed**
   ```bash
   docker --version
   ```
   - Required for building and testing images locally

3. **Required IAM Permissions**
   
   Your AWS user/role needs permissions for:
   - ECR (create repositories, push images)
   - VPC (create VPC, subnets, security groups, internet gateways)
   - RDS (create databases, subnet groups)
   - App Runner (create services, VPC connectors)
   - IAM (create roles, attach policies)
   - EC2 (for VPC and networking resources)

4. **Bash shell**
   - Scripts are written for bash (Linux/macOS/WSL)

## Quick Start

### 1. Create Infrastructure

Run the infrastructure creation script:

```bash
cd infrastructure/aws
chmod +x *.sh
./create-infrastructure.sh [environment] [region] [db-password]
```

Parameters (all optional):
- `environment`: Environment name (default: `staging`)
- `region`: AWS region (default: `eu-central-1`)
- `db-password`: Database password (auto-generated if not provided)

Example:
```bash
./create-infrastructure.sh staging eu-central-1
```

This script will:
- Create ECR repositories for frontend and backend
- Set up VPC with public and private subnets (in 2 availability zones)
- Create security groups
- Launch RDS PostgreSQL instance (encrypted at rest)
- Create IAM roles for App Runner
- Create VPC connector
- Deploy App Runner services (if Docker images are available in ECR)

**Note**: The script is idempotent - it can be run multiple times safely.

**Important**: Save the database password displayed at the end!

### 2. Build and Push Docker Images

After infrastructure is created, build and push images:

```bash
./deploy.sh [region] [tag] [auto-deploy]
```

Parameters (all optional):
- `region`: AWS region (default: `eu-central-1`)
- `tag`: Image tag (default: `latest`)
- `auto-deploy`: Set to `true` to automatically trigger deployments without prompt (default: `false`)

Examples:
```bash
# Interactive mode (will prompt for deployment)
./deploy.sh eu-central-1 latest

# Auto-deploy mode (for CI/CD)
./deploy.sh eu-central-1 latest true
```

The script will:
- Authenticate with ECR
- Build backend Docker image (with `--platform linux/amd64` for App Runner compatibility)
- Build frontend Docker image
- Push both images to ECR
- Optionally trigger App Runner deployments

**Note**: If App Runner services don't exist yet, re-run `create-infrastructure.sh` after pushing images.

### 3. Access Your Application

After deployment completes, the script outputs the URLs:

```
Backend:  https://xxxxx.eu-central-1.awsapprunner.com
Frontend: https://yyyyy.eu-central-1.awsapprunner.com
```

Access the frontend URL in your browser to use the application.

## GitHub Actions CI/CD

The repository includes a GitHub Actions workflow for automated deployments.

### Setup GitHub Secrets

1. Go to your GitHub repository settings
2. Navigate to Secrets and Variables > Actions
3. Add the following secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key ID
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key

### Workflow Triggers

The workflow (`.github/workflows/deploy-staging.yml`) runs on:
- Push to `main` branch
- Manual trigger via workflow_dispatch

The workflow will:
1. Build Docker images for frontend and backend
2. Push images to ECR with commit SHA and `latest` tags
3. App Runner will automatically detect and deploy the new images

## Environment Variables

### Backend Environment Variables

Set in App Runner service configuration:

- `DATABASE_URL`: PostgreSQL connection string (automatically configured)
- `STORAGE_ROOT`: Path for file storage (default: `/app/storage`)
- `ESIGN_PROVIDER`: E-signature provider (default: `stub`)
- `ESIGN_WEBHOOK_SECRET`: Webhook secret for e-signature service

### Frontend Environment Variables

Set in App Runner service configuration:

- `NEXT_PUBLIC_API_BASE_URL`: Backend API URL (automatically configured)

## Cost Estimates

Approximate monthly costs for staging environment in eu-central-1:

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| RDS PostgreSQL | db.t3.micro, 20GB storage, encrypted | ~$15-25/month |
| App Runner (Backend) | 1 vCPU, 2GB RAM | ~$25-30/month (depends on usage) |
| App Runner (Frontend) | 1 vCPU, 2GB RAM | ~$25-30/month (depends on usage) |
| ECR Storage | Per GB stored | ~$0.10/GB/month |
| Data Transfer | Outbound data | Varies by usage |
| **Total Estimate** | | **~$70-100/month** |

**Notes**:
- App Runner charges for CPU/memory usage (prorated per second)
- Additional charges apply for data transfer out to the internet
- Costs may vary based on actual usage patterns
- eu-central-1 prices may be slightly higher than us-east-1

## Updating the Application

To deploy updates:

1. **Via GitHub Actions** (recommended):
   - Push changes to `main` branch
   - Workflow automatically builds and pushes images
   - App Runner detects new images and deploys

2. **Manually**:
   ```bash
   ./deploy.sh eu-central-1 v1.2.3
   ```
   - Then trigger deployment when prompted

## Deleting Infrastructure

To completely remove all AWS resources:

```bash
./delete-infrastructure.sh [environment] [region]
```

Example:
```bash
./delete-infrastructure.sh staging eu-central-1
```

**Warning**: This will delete all data including the database!

The deletion script will:
- Delete App Runner services (waits for completion)
- Delete VPC connector
- Delete RDS instance (skips final snapshot)
- Delete DB subnet group
- Delete security groups (revokes rules first)
- Delete VPC components (subnets, route tables, internet gateway)
- Delete IAM roles
- Optionally delete ECR repositories (prompts for confirmation)

## Troubleshooting

### Common Issues

1. **"App Runner services not created"**
   - This happens when ECR repositories are empty
   - Run `./deploy.sh` first to push images
   - Then re-run `./create-infrastructure.sh`

2. **ECR repository not found**
   - Run `./create-infrastructure.sh` first to create the repositories

3. **Docker build fails**
   - Ensure Docker is running: `docker info`
   - Check you have enough disk space
   - Try `docker system prune` to clean up old images

4. **RDS connection timeout**
   - Ensure VPC connector is properly configured
   - Check security group allows traffic from backend SG to RDS on port 5432
   - Verify RDS instance is in "available" state

5. **App Runner service CREATE_FAILED**
   - Check AWS Console for detailed error messages
   - Common causes: invalid Docker image, incorrect port configuration
   - Verify health check endpoint exists (`/health` for backend, `/` for frontend)

6. **Security group deletion fails**
   - Wait for App Runner services to fully delete first
   - The script handles this by deleting services before security groups

7. **VPC deletion fails**
   - Ensure all resources in the VPC are deleted first
   - Check for any ENIs (Elastic Network Interfaces) still attached

### Checking Service Logs

```bash
# Get App Runner service ARN
aws apprunner list-services --region eu-central-1

# View service details
aws apprunner describe-service --service-arn <service-arn> --region eu-central-1
```

For detailed logs, use the AWS Console:
1. Go to App Runner in the AWS Console
2. Select your service
3. Click on "Logs" tab

## Security Best Practices

For production environments, consider:

1. **Use AWS Secrets Manager** for database credentials instead of environment variables
2. **Enable VPC Flow Logs** for network monitoring
3. **Set up AWS WAF** for web application firewall protection
4. **Enable RDS automated backups** with longer retention
5. **Use larger RDS instance** (db.t3.small or larger) for production workloads
6. **Enable Multi-AZ** for RDS for high availability
7. **Set up CloudWatch alarms** for monitoring
8. **Implement proper IAM policies** with least privilege principle
9. **Enable AWS CloudTrail** for audit logging
10. **Consider using AWS Certificate Manager** for custom domain SSL
