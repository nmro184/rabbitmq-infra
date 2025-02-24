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
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text $PROFILE_FLAG --region $AWS_REGION)

if [[ "$DEFAULT_VPC_ID" == "None" ]]; then
    echo "❌ No Default VPC found. Creating a new one..."
    
    # Create a Default VPC (AWS will automatically add subnets, IGW, and route tables)
    aws ec2 create-default-vpc $PROFILE_FLAG --region $AWS_REGION
    
    # Wait a few seconds for AWS to complete the creation
    sleep 5
    
    # Retrieve the new Default VPC ID
    DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text $PROFILE_FLAG --region $AWS_REGION)
    
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
DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" --query "Subnets[*].SubnetId" --output text $PROFILE_FLAG --region $AWS_REGION)

if [[ -z "$DEFAULT_SUBNET_IDS" ]]; then
    echo "❌ No default subnets found! Something went wrong."
    exit 1
else
    echo "✅ Found default subnets: $DEFAULT_SUBNET_IDS"
fi

# Save the VPC ID and Subnet IDs for Terraform
echo "VPC_ID=$DEFAULT_VPC_ID" > vpc_output.txt
echo "SUBNET_IDS=$DEFAULT_SUBNET_IDS" >> vpc_output.txt

echo "✅ Default VPC setup completed!"
echo "📄 Saved details to vpc_output.txt"
