#!/bin/bash

echo "=============================="
echo "🔍 Running RabbitMQ Messaging Test..."
echo "=============================="

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

# Pick the first node for testing
TARGET_NODE=${RABBITMQ_IPS[0]}

echo "📤 Sending message to RabbitMQ on $TARGET_NODE..."

# Publish message
curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X POST "http://$TARGET_NODE:15672/api/exchanges/%2F/amq.default/publish" \
    -H "content-type: application/json" \
    -d '{
        "properties":{},
        "routing_key":"'"$QUEUE_NAME"'",
        "payload":"Test Message",
        "payload_encoding":"string"
    }' | jq .

echo "✅ Message sent!"

# Consume message
echo "📥 Checking if message was received..."
RECEIVED_MESSAGE=$(curl -s -u "$RABBITMQ_USER:$RABBITMQ_PASS" \
    -X GET "http://$TARGET_NODE:15672/api/queues/%2F/$QUEUE_NAME/get" \
    -H "content-type: application/json" \
    -d '{
        "count":1,
        "ackmode":"ack_requeue_false",
        "encoding":"auto"
    }' | jq -r '.[0].payload')

if [[ "$RECEIVED_MESSAGE" == "Test Message" ]]; then
    echo "✅ Message successfully received!"
else
    echo "❌ Message not received!"
    exit 1
fi

echo "✅ RabbitMQ Messaging Test Passed!"
exit 0
