# SimpleTimeService

A minimal "time service" microservice and Terraform infrastructure to deploy it on AWS Lambda. When you call the service's root URL, it returns a JSON payload with the current UTC timestamp and your IP address.

## Architecture

- **Serverless**: The application runs on AWS Lambda using container images
- **API Gateway**: Provides the HTTP endpoint with proper Lambda proxy integration
- **VPC**: Lambda runs in private subnets for security
- **ECR**: Container images are stored in Amazon Elastic Container Registry
- **No credentials committed**: Terraform reads your AWS credentials from `~/.aws/credentials` or environment variables
- **Local state**: Local state is used so that terraform init and apply are the only steps required to provision everything without extra manual setup

## Repository Layout

```
.
├── app
│   ├── main.py
│   ├── requirements.txt
│   └── Dockerfile
├── terraform
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── outputs.tf
│   └── modules
│       ├── lambda-service
│       │   ├── main.tf
│       │   ├── outputs.tf
│       │   ├── providers.tf
│       │   └── variables.tf
│       └── vpc
│           ├── main.tf
│           ├── outputs.tf
│           └── variables.tf
├── .github
│   └── workflows
│       └── ci-cd.yml
├── .gitignore
└── README.md
```

## Prerequisites

Before you begin, make sure the following tools are installed:

- **Git** - https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
- **Docker** - https://docs.docker.com/get-docker/
- **Terraform** (v1.4+) - https://learn.hashicorp.com/tutorials/terraform/install-cli
- **AWS CLI** - https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

Configure your credentials (IAM user with permissions for VPC, Lambda, API Gateway, ECR, CloudWatch, etc.) by running:

```bash
aws configure
```

or exporting environment variables:

```bash
export AWS_ACCESS_KEY_ID=YOUR_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=us-east-1
```

## Three Ways to Run This Application

This application can be deployed and tested in three different ways:

### Method 1: Local Docker Testing

1. **Clone the repository**
   ```bash
   git clone https://github.com/f1rmtea/simple-timeservice-serverless-iac.git
   cd simple-timeservice-serverless-iac/app
   ```

2. **Build the container**
   ```bash
   docker build -t simple-timeservice .
   ```

3. **Run the container**
   ```bash
   docker run -p 8080:8080 simple-timeservice
   ```

4. **Test locally**
   ```bash
   curl http://localhost:8080/
   ```
   
   Or simply visit http://localhost:8080/ in your browser.

**Alternative**: Test with the pre-built public image:
```bash
docker run -p 8080:8080 ghcr.io/f1rmtea/simple-timeservice:latest
curl http://localhost:8080/
```

**Screenshot - Local Docker Build and Test:** <br>
<br>
<img width="1273" alt="image" src="https://github.com/user-attachments/assets/3728175f-99fd-4624-9a32-7d5e257820c8" />


### Method 2: Cloud Deployment with Terraform

1. **Clone the repository** (if not already done)
   ```bash
   git clone https://github.com/f1rmtea/simple-timeservice-serverless-iac.git
   cd simple-timeservice-serverless-iac
   ```

2. **Switch to the Terraform directory**
   ```bash
   cd terraform
   ```

3. **Review and customize variables**
   - Open `variables.tf` to see available variables
   - Edit `terraform.tfvars` to override defaults (for example, AWS region or network CIDRs)

4. **Initialize Terraform**
   ```bash
   terraform init
   ```

5. **Preview the planned changes**
   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply --auto-approve
   ```

   This will:
   - Create a VPC with public/private subnets
   - Set up an ECR repository and push your container image
   - Deploy a Lambda function using the container image
   - Create an API Gateway with proper Lambda integration
   - Output the API endpoint URL

7. **Test the deployed service**
   ```bash
   # Method 1: Direct curl with the output URL
   curl "$(terraform output -raw api_url)/"
   
   # Method 2: If you have the URL manually
   curl "https://abcd1234.execute-api.us-east-1.amazonaws.com/prod/"
   ```
   
   Or visit the API Gateway URL directly in your browser using the output from `terraform output api_url`.

**Screenshot - Terraform Deployment:** <br>
<br>
<img width="521" alt="image" src="https://github.com/user-attachments/assets/1716ce61-2614-45fb-a65f-fd2f2713eb31" />


### Method 3: Automated CI/CD Deployment

1. **Fork this repository** to your GitHub account

2. **Set up GitHub Secrets**
   - Go to Settings > Secrets and variables > Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`

3. **Trigger deployment**
   - Trigger the workflow from the Actions tab
   - The GitHub Actions workflow will automatically run `terraform apply`

4. **Monitor deployment**
   - Check the Actions tab for deployment progress
   - Once complete, the API URL will be available in the workflow logs
   - Test the deployed API using curl or by visiting the URL in your browser

**Live Workflow Example:** <br>
[CI-CD Workflow Run](https://github.com/f1rmtea/simple-timeservice-serverless-iac/actions/runs/15820113860)

## Testing Your Deployment

For local development, you can run the Flask app directly:

```bash
cd app
pip install -r requirements.txt
python main.py
```

Then test with:
```bash
curl http://localhost:8080/
```

Or visit http://localhost:8080/ in your browser.

All Terraform files live in the `terraform/` directory. Local state (no remote backend) is used as an architectural decision to allow terraform init and apply to be the only steps required to provision everything.

Expected response from any deployment method:
```json
{
  "timestamp": "2025-06-21T12:34:56.789Z",
  "ip": "<your public IP>"
}
```

**Note**: You can test all deployment methods using either curl commands or by visiting the URLs directly in your web browser.

## Cleanup

Destroy AWS resources to avoid charges:

```bash
cd terraform
terraform destroy --auto-approve
```

Remove local state files if desired:
```bash
rm terraform.tfstate terraform.tfstate.backup
```
