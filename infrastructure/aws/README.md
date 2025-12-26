# AWS Infrastructure for Direct Marketing Portal

This directory contains scripts and documentation for deploying the Direct Marketing Portal to AWS using App Runner, RDS PostgreSQL, and ECR.

## Architecture Overview

The AWS infrastructure consists of:

- **Amazon ECR**: Container registry for storing Docker images
- **Amazon VPC**: Virtual Private Cloud with public and private subnets
- **Amazon RDS**: PostgreSQL 17 database (db.t3.micro for staging)
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
- `region`: AWS region (default: `us-east-1`)
- `db-password`: Database password (auto-generated if not provided)

Example:
```bash
./create-infrastructure.sh staging us-east-1
```

This script will:
- Create ECR repositories for frontend and backend
- Set up VPC with public and private subnets
- Create security groups
- Launch RDS PostgreSQL instance
- Create IAM roles for App Runner
- Create VPC connector
- Deploy App Runner services

**Note**: The script is idempotent - it can be run multiple times safely.

**Important**: Save the database password displayed at the end!

### 2. Build and Push Docker Images

After infrastructure is created, build and push images:

```bash
./deploy.sh [region] [tag]
```

Parameters (all optional):
- `region`: AWS region (default: `us-east-1`)
- `tag`: Image tag (default: `latest`)

Example:
```bash
./deploy.sh us-east-1 latest
```

The script will:
- Authenticate with ECR
- Build backend Docker image
- Build frontend Docker image
- Push both images to ECR
- Optionally trigger App Runner deployments

### 3. Access Your Application

After deployment completes, the script outputs the URLs:

```
Backend:  https://xxxxx.us-east-1.awsapprunner.com
Frontend: https://yyyyy.us-east-1.awsapprunner.com
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

Approximate monthly costs for staging environment in us-east-1:

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| RDS PostgreSQL | db.t3.micro, 20GB storage | ~$15-20/month |
| App Runner (Backend) | 1 vCPU, 2GB RAM | ~$25-30/month (depends on usage) |
| App Runner (Frontend) | 1 vCPU, 2GB RAM | ~$25-30/month (depends on usage) |
| ECR Storage | Per GB stored | ~$0.10/GB/month |
| Data Transfer | Outbound data | Varies by usage |
| **Total Estimate** | | **~$70-90/month** |

**Notes**:
- App Runner charges for CPU/memory usage (prorated per second)
- Additional charges apply for data transfer out to the internet
- Costs may vary based on actual usage patterns

## Updating the Application

To deploy updates:

1. **Via GitHub Actions** (recommended):
   - Push changes to `main` branch
   - Workflow automatically builds and pushes images
   - App Runner detects new images and deploys

2. **Manually**:
   ```bash
   ./deploy.sh us-east-1 v1.2.3
   ```
   - Then trigger deployment when prompted

## Deleting Infrastructure

To completely remove all AWS resources:

```bash
./delete-infrastructure.sh [environment] [region]
```

Example:
```bash
./delete-infrastructure.sh staging us-east-1
```

**Warning**: This will:
- Delete all App Runner services
- Delete RDS database (**all data will be lost**)
- Delete VPC and networking
- Delete IAM roles
- Optionally delete ECR repositories

The script will prompt for confirmation before deleting.

## Troubleshooting

### Issue: "Error: AWS credentials are not configured properly"

**Solution**: Run `aws configure` and provide your AWS credentials.

### Issue: "Error: Backend ECR repository not found"

**Solution**: Run `./create-infrastructure.sh` first to create resources.

### Issue: App Runner service fails to start

**Solutions**:
1. Check App Runner service logs in AWS Console
2. Verify ECR images were pushed successfully:
   ```bash
   aws ecr describe-images --repository-name direct-marketing-backend --region us-east-1
   ```
3. Check that IAM roles have correct permissions
4. Verify VPC connector is active

### Issue: Backend cannot connect to database

**Solutions**:
1. Verify RDS instance is running:
   ```bash
   aws rds describe-db-instances --region us-east-1
   ```
2. Check security group rules allow backend to access RDS on port 5432
3. Verify `DATABASE_URL` environment variable is set correctly in App Runner
4. Check VPC connector is properly configured

### Issue: Frontend cannot connect to backend

**Solutions**:
1. Verify backend service is running and healthy
2. Check `NEXT_PUBLIC_API_BASE_URL` is set correctly in frontend App Runner config
3. Test backend API directly: `curl https://<backend-url>/health`

### Issue: Docker build fails

**Solutions**:
1. Ensure Docker is running: `docker ps`
2. Check Dockerfile syntax
3. Verify all required files are present in build context
4. Try building locally first: `docker build -t test ./backend`

### Viewing Logs

**App Runner logs**:
1. Go to AWS Console > App Runner
2. Select your service
3. Click on "Logs" tab

**RDS logs**:
1. Go to AWS Console > RDS
2. Select your database instance
3. Click on "Logs & events" tab

## Security Best Practices

1. **Database Access**:
   - RDS is in private subnets (not publicly accessible)
   - Only backend service can connect via security groups

2. **Secrets Management**:
   - Store database password securely (e.g., AWS Secrets Manager)
   - Rotate credentials regularly
   - Never commit secrets to source control

3. **HTTPS**:
   - App Runner provides automatic HTTPS with AWS-managed certificates
   - All external traffic is encrypted

4. **IAM Roles**:
   - Services use IAM roles with minimal required permissions
   - No long-lived credentials in containers

5. **Staging Access**:
   - Consider adding basic authentication middleware for staging environment
   - Restrict access via IP allowlists if needed
   - Use AWS WAF for additional protection

## Additional Resources

- [AWS App Runner Documentation](https://docs.aws.amazon.com/apprunner/)
- [Amazon RDS Documentation](https://docs.aws.amazon.com/rds/)
- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review AWS service logs
3. Consult AWS documentation
4. Open an issue in the project repository
