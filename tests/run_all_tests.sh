#!/bin/bash

# Ensure we're in the correct directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run individual tests using absolute paths
bash "$SCRIPT_DIR/health_check.sh"
bash "$SCRIPT_DIR/messaging_test.sh"

# Handle test failures
if [[ $? -ne 0 ]]; then
    echo "❌ Some tests failed! Check the logs."
    exit 1
fi

echo "✅ All tests executed successfully!"
exit 0
