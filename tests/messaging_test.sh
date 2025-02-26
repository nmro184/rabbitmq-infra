#!/bin/bash

echo "=============================="
echo "🔍 Running RabbitMQ Messaging Test (via SSH Tunnel)..."
echo "=============================="

# Extract SSH Key Name from terraform.tfvars
SSH_KEY_NAME=$(grep 'ssh_key_name' terraform/terraform.tfvars | awk -F '"' '{print $2}')
SSH_KEY_PATH=$(grep 'ssh_key_path' terraform/terraform.tfvars | awk -F '"' '{print $2}')

# Ensure SSH key exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "❌ Error: SSH key not found at $SSH_KEY_PATH!"
    exit 1
fi

# Ensure RabbitMQ IPs file exists
if [[ ! -f tests/rabbitmq_ips.txt ]]; then
    echo "❌ Error: RabbitMQ IP list (tests/rabbitmq_ips.txt) is missing!"
    exit 1
fi

# Read RabbitMQ IPs from the file
RABBITMQ_IPS=($(cat tests/rabbitmq_ips.txt))
RABBITMQ_USER="guest"
RABBITMQ_PASS="guest"
QUEUE_NAME="test_queue"
EC2_USER="ec2-user"

# Pick the first node for SSH tunneling
TARGET_NODE=${RABBITMQ_IPS[0]}

echo "📡 Target RabbitMQ Node: $TARGET_NODE"
echo "=============================="

# 🔍 Step 1: Set Up SSH Tunnel (if not already running)
if ! nc -z localhost 15672; then
    echo "🔒 Setting up SSH tunnel to RabbitMQ on $TARGET_NODE..."
    ssh -i "$SSH_KEY_PATH" -L 15672:localhost:15672 -N -f "$EC2_USER@$TARGET_NODE"
    sleep 2  # Give it a second to establish
fi
echo "✅ SSH tunnel established!"

echo "=============================="

# 🔍 Step 2: Verify Connection to RabbitMQ API
echo "🔍 Checking if RabbitMQ is accessible via SSH tunnel..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -u "$RABBITMQ_USER:$RABBITMQ_PASS" "http://localhost:15672/api/overview")

if [[ "$API_STATUS" != "200" ]]; then
    echo "❌ Error: Unable to reach RabbitMQ API via SSH tunnel (HTTP Status: $API_STATUS)"
    exit 1
fi
echo "✅ RabbitMQ API is accessible!"

echo "=============================="

# 🔄 Step 3: Publish a Test Message
echo "📤 Sending message to RabbitMQ..."
PUBLISH_RESPONSE=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X POST "http://localhost:15672/api/exchanges/%2F/amq.default/publish" \
    -H "content-type: application/json" \
    -d '{
        "properties":{},
        "routing_key":"'"$QUEUE_NAME"'",
        "payload":"Test Message",
        "payload_encoding":"string"
    }')

# Debug: Print Response from RabbitMQ
echo "🔍 Publish Response: $PUBLISH_RESPONSE"

# ✅ Manually check if "routed":true exists (no jq)
if echo "$PUBLISH_RESPONSE" | grep -q '"routed":true'; then
    echo "✅ Message successfully published!"
else
    echo "❌ Error: Failed to publish message!"
    exit 1
fi

echo "=============================="

# 🔄 Step 4: Consume the Test Message
echo "📥 Checking if message was received..."
CONSUME_RESPONSE=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X POST "http://localhost:15672/api/queues/%2F/$QUEUE_NAME/get" \
    -H "content-type: application/json" \
    -d '{
        "count":1,
        "ackmode":"ack_requeue_false",
        "encoding":"auto"
    }')

# Debug: Print Response from RabbitMQ
echo "🔍 Consume Response: $CONSUME_RESPONSE"

# ✅ Manually extract the message payload
RECEIVED_MESSAGE=$(echo "$CONSUME_RESPONSE" | grep -o '"payload":"[^"]*' | awk -F ':"' '{print $2}')

if [[ "$RECEIVED_MESSAGE" == "Test Message" ]]; then
    echo "✅ Message successfully received!"
else
    echo "❌ Error: Message not received!"
    exit 1
fi

echo "=============================="
echo "✅ RabbitMQ Messaging Test Passed!"
exit 0
