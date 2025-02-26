#!/bin/bash

echo "=============================="
echo "🔍 AWS Configuration Setup"
echo "=============================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed! Please install it first: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if user has AWS CLI configured
AWS_PROFILES=$(aws configure list-profiles 2>/dev/null)

if [[ -z "$AWS_PROFILES" ]]; then
    echo "⚠️ No AWS profiles found! You need to configure AWS CLI first."
    echo "Run: aws configure"
    exit 1
fi

# Display available profiles
echo "✅ Available AWS profiles:"
i=1
declare -A PROFILE_MAP
for PROFILE in $AWS_PROFILES; do
    echo "$i) $PROFILE"
    PROFILE_MAP[$i]=$PROFILE
    ((i++))
done

# Ask user to select a profile
read -p "Select an AWS profile by number or enter name manually (default: 1): " PROFILE_CHOICE

if [[ -z "$PROFILE_CHOICE" ]]; then
    AWS_PROFILE=${PROFILE_MAP[1]}  # Default to first profile
elif [[ "$PROFILE_CHOICE" =~ ^[0-9]+$ ]] && [[ -n "${PROFILE_MAP[$PROFILE_CHOICE]}" ]]; then
    AWS_PROFILE=${PROFILE_MAP[$PROFILE_CHOICE]}
else
    AWS_PROFILE="$PROFILE_CHOICE"  # Use manually entered profile name
fi

echo "✅ Selected AWS Profile: $AWS_PROFILE"

# Set profile flag for AWS CLI
PROFILE_FLAG="--profile $AWS_PROFILE"

# Fetch AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text $PROFILE_FLAG 2>/dev/null)

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    echo "❌ Unable to retrieve AWS account details. Check your AWS credentials."
    exit 1
fi

# Prompt for region
read -p "Enter AWS Region (default: eu-west-2): " AWS_REGION
AWS_REGION=${AWS_REGION:-eu-west-2}

echo "✅ Using AWS Account: $AWS_ACCOUNT_ID"
echo "✅ Using AWS Profile: $AWS_PROFILE"
echo "✅ Using AWS Region: $AWS_REGION"

echo "=============================="
echo "🔍 Checking for Default VPC..."
echo "=============================="

# Check if a Default VPC exists using the "is-default" attribute
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text $PROFILE_FLAG --region "$AWS_REGION")

if [[ "$DEFAULT_VPC_ID" == "None" ]]; then
    echo "❌ No Default VPC found. Creating a new one..."
    
    # Create a Default VPC (AWS will automatically add subnets, IGW, and route tables)
    aws ec2 create-default-vpc $PROFILE_FLAG --region "$AWS_REGION"
    
    # Wait a few seconds for AWS to complete the creation
    sleep 5
    
    # Retrieve the new Default VPC ID
    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text $PROFILE_FLAG --region "$AWS_REGION")
    
    if [[ "$DEFAULT_VPC_ID" == "None" ]]; then
        echo "❌ Failed to create Default VPC!"
        exit 1
    else
        echo "✅ Created new Default VPC: $DEFAULT_VPC_ID"
    fi
else
    echo "✅ Default VPC found: $DEFAULT_VPC_ID"
fi

# Retrieve default subnets of the VPC
DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" --query "Subnets[*].SubnetId" --output text $PROFILE_FLAG --region "$AWS_REGION")

if [[ -z "$DEFAULT_SUBNET_IDS" ]]; then
    echo "❌ No default subnets found! Something went wrong."
    exit 1
else
    echo "✅ Found default subnets: $DEFAULT_SUBNET_IDS"
fi

echo "=============================="
echo "🔍 Checking for existing AWS SSH key pair..."
echo "=============================="

# Define a default key name
KEY_NAME="rabbitmq-key"
KEY_FILE="$HOME/.ssh/id_rsa_rabbitmq"

# Check if the key pair already exists in AWS
EXISTING_KEY=$(aws ec2 describe-key-pairs --query "KeyPairs[?KeyName=='$KEY_NAME'].KeyName" --output text $PROFILE_FLAG --region "$AWS_REGION")

if [[ -n "$EXISTING_KEY" ]]; then
    echo "✅ Existing SSH key pair found in AWS: $KEY_NAME"
else
    echo "❌ No existing key pair found. Creating a new one..."

    # Generate a new SSH key (without passphrase for automation)
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "rabbitmq-cluster"

    # Upload the public key to AWS
    aws ec2 import-key-pair --key-name "$KEY_NAME" --public-key-material fileb://"$KEY_FILE.pub" $PROFILE_FLAG --region "$AWS_REGION"

    echo "✅ New SSH key pair created: $KEY_NAME"
fi

# Ensure the SSH key file exists for local use
if [[ -f "$KEY_FILE" ]]; then
    echo "✅ SSH private key is available locally at: $KEY_FILE"
else
    echo "❌ Error: SSH key file not found!"
    exit 1
fi

echo "=============================="
echo "🔄 Updating terraform.tfvars with AWS and SSH Key Details"
echo "=============================="

cat <<EOF > terraform/terraform.tfvars
aws_region = "$AWS_REGION"
vpc_id = "$DEFAULT_VPC_ID"
subnet_ids = ["$(echo $DEFAULT_SUBNET_IDS | sed 's/ /", "/g')"]
ssh_key_name = "$KEY_NAME"
ssh_key_path = "$KEY_FILE"
EOF

echo "✅ Updated terraform.tfvars"

#!/bin/bash

echo "=============================="
echo "🚀 Running Terraform Deployment"
echo "=============================="

cd terraform
terraform init
terraform apply -auto-approve

# Check if Terraform succeeded
if [[ $? -ne 0 ]]; then
    echo "❌ Terraform deployment failed! Exiting."
    exit 1
fi

echo "✅ Terraform deployment completed successfully!"
sleep 5

cd ..

echo "=============================="
echo "🔍 Fetching RabbitMQ Cluster Public IPs..."
echo "=============================="

# ✅ Get all RabbitMQ nodes (head + workers) by name
RABBITMQ_IPS=($(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=rabbitmq-node,rabbitmq-first-node" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PublicIpAddress" \
    --output text --region "$AWS_REGION"))

if [[ ${#RABBITMQ_IPS[@]} -eq 0 ]]; then
    echo "❌ Failed to retrieve RabbitMQ instance IPs!"
    exit 1
fi

echo "✅ RabbitMQ Cluster Nodes: ${RABBITMQ_IPS[*]}"

# Save IPs for testing
echo "${RABBITMQ_IPS[*]}" > tests/rabbitmq_ips.txt

echo "✅ Deployment completed successfully!"
echo "⏳ Please wait a few minutes before running the tests, as it may take some time for all RabbitMQ nodes to fully initialize."
echo "✅ You can monitor the cluster status in your AWS Console."
echo "🚀 Once the nodes are ready, run: bash tests/run_all_tests.sh"

chmod +x tests/health_check.sh tests/messaging_test.sh
