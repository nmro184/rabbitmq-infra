#!/bin/bash

echo "=============================="
echo "🚀 Running All RabbitMQ Tests..."
echo "=============================="

# Get absolute path of the current script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure RabbitMQ IPs file exists using absolute path
if [[ ! -f "$SCRIPT_DIR/rabbitmq_ips.txt" ]]; then
    echo "❌ Error: RabbitMQ IP list ($SCRIPT_DIR/rabbitmq_ips.txt) is missing!"
    exit 1
fi

# Move to the tests directory
cd "$SCRIPT_DIR" || exit 1

# Run individual tests using relative paths (since we're now in tests/)
bash health_check.sh
bash messaging_test.sh

# Handle test failures
if [[ $? -ne 0 ]]; then
    echo "❌ Some tests failed! Check the logs."
    exit 1
fi

echo "✅ All tests executed successfully!"
exit 0
