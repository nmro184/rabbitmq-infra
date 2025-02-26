# 🐇 Terraform RabbitMQ Cluster Deployment

## 📌 Overview
This project automates the deployment of a **RabbitMQ cluster** in AWS using Terraform. It simplifies the setup process, ensuring a fully functional and tested RabbitMQ cluster with minimal effort.

## 🚀 Features
- **Fully Automated Deployment** – Deploys a RabbitMQ cluster in AWS using Terraform.
- **Secure Access** – Uses an SSH tunnel for secure connections instead of exposing RabbitMQ publicly.
- **Automated Testing** – Validates cluster health and messaging functionality after deployment.
- **Easy Cleanup** – Tear down the entire infrastructure with a single command.

## 🔧 Prerequisites
Before running this project, make sure you have the following installed and configured:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) – Infrastructure as Code tool.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) – Required for authentication with AWS.
- An AWS account with appropriate permissions to create EC2 instances and security groups.
- **AWS CLI must be configured for the root user** since the setup script runs with `sudo`. Run the following command to configure AWS credentials for root:
  ```bash
  sudo aws configure

## ⚙️ Installation & Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/nmro184/rabbitmq-infra
   cd rabbitmq-infra
   ```

2. **Set execute permissions** for the setup script:
   ```bash
   sudo chmod +x setup.sh
   ```

3. **Run the setup script** to deploy everything:
   ```bash
   sudo ./setup.sh
   ```

## 🛠 Running Tests
Once the setup is complete and RabbitMQ nodes are fully initialized:

```bash
bash tests/run_all_tests.sh
```

This will execute the test suite to verify:
- **Cluster health** (`tests/health_check.sh`)
- **Messaging functionality** (`tests/messaging_test.sh`)

## 🔥 Cleanup
To **destroy** the infrastructure and remove all deployed resources, run:

```bash
cd terraform
terraform destroy --auto-approve
```

## ❗ Troubleshooting
- **Terraform fails to apply**: Ensure AWS CLI is configured (`aws configure`).
- **Tests failing**: Check if all RabbitMQ nodes have fully initialized before running tests.
