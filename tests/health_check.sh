#!/bin/bash

echo "=============================="
echo "🔍 Running RabbitMQ Node Health Check (Per Node via SSH)..."
echo "=============================="

# Extract SSH Key Name from terraform.tfvars
SSH_KEY_NAME=$(grep 'ssh_key_name' terraform/terraform.tfvars | awk -F '"' '{print $2}')
SSH_KEY_PATH=$(grep 'ssh_key_path' terraform/terraform.tfvars | awk -F '"' '{print $2}')

# Ensure RabbitMQ IPs file exists
if [[ ! -f tests/rabbitmq_ips.txt ]]; then
    echo "❌ Error: RabbitMQ IP list (tests/rabbitmq_ips.txt) is missing!"
    exit 1
fi

# Read RabbitMQ IPs from the file
RABBITMQ_IPS=($(cat tests/rabbitmq_ips.txt))

RABBITMQ_USER="guest"
RABBITMQ_PASS="guest"
EC2_USER="ec2-user"

ALL_HEALTHY=true

#!/bin/bash

echo "=============================="
echo "🔍 Running RabbitMQ Node Health Check (With Retry)..."
echo "=============================="

MAX_RETRIES=2
RETRY_DELAY=5  # Seconds to wait before retrying

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "🛠️ Health Check Attempt $i of $MAX_RETRIES..."
    
    ALL_HEALTHY=true  # Reset before each attempt

    for NODE_IP in "${RABBITMQ_IPS[@]}"; do
        echo "🔄 Checking Health of Node: $NODE_IP (via SSH)..."

        # Resolve hostname if needed
        if [[ "$NODE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            NODE_HOSTNAME=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$NODE_IP" \
                "curl -s http://169.254.169.254/latest/meta-data/public-hostname")
            if [[ -z "$NODE_HOSTNAME" ]]; then
                NODE_HOSTNAME="$NODE_IP"  # Use IP if hostname resolution fails
            fi
        else
            NODE_HOSTNAME="$NODE_IP"
        fi

        # Print the exact SSH command being executed
        echo "🛠️ Running Command: ssh -i \"$SSH_KEY_PATH\" \"$EC2_USER@$NODE_HOSTNAME\" \"curl -s -o /dev/null -w \"%{http_code}\" -u \"$RABBITMQ_USER:$RABBITMQ_PASS\" \"http://localhost:15672/api/healthchecks/node\"\""

        STATUS=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "$EC2_USER@$NODE_HOSTNAME" \
            "curl -s -o /dev/null -w \"%{http_code}\" -u \"$RABBITMQ_USER:$RABBITMQ_PASS\" \"http://localhost:15672/api/healthchecks/node\"")

        if [[ "$STATUS" == "200" ]]; then
            echo "✅ Node $NODE_HOSTNAME is Healthy!"
        else
            echo "❌ Node $NODE_HOSTNAME is NOT Healthy! (HTTP Status: $STATUS)"
            ALL_HEALTHY=false
        fi
    done

    # If all nodes are healthy, exit successfully
    if [[ "$ALL_HEALTHY" == true ]]; then
        echo "✅ All RabbitMQ Nodes are Healthy!"
        exit 0
    fi

    # If not the last attempt, wait before retrying
    if [[ "$i" -lt "$MAX_RETRIES" ]]; then
        echo "⏳ Waiting $RETRY_DELAY seconds before retrying..."
        sleep $RETRY_DELAY
    fi
done

# If we reach here, it means some nodes are still unhealthy after retries
echo "❌ Some nodes remain unhealthy after $MAX_RETRIES attempts!"
exit 1
