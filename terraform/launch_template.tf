resource "aws_launch_template" "rabbitmq" {
  name_prefix   = "rabbitmq-cluster"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.rabbitmq_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.rabbitmq_profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1  # Redirect output for debugging

echo "===== Starting RabbitMQ Cluster Node Setup ====="

# Function to log errors and exit if a step fails
function check_success() {
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: $1" | tee -a /var/log/user-data.log
        exit 1
    fi
}

# Wait for YUM lock to be released
echo "Checking if YUM is locked..."
while sudo fuser /var/run/yum.pid >/dev/null 2>&1; do sleep 1; done

# Check Internet Connectivity
echo "Checking internet access..."
ping -c 3 google.com > /dev/null 2>&1
check_success "No internet access. Make sure your instance has outbound connectivity."

# Clean and update packages
echo "Updating system packages..."
yum clean all
yum update -y
check_success "System update failed."

# Install dependencies
echo "Installing dependencies..."
yum install -y wget curl nmap-ncat
check_success "Failed to install dependencies."

# Remove old repo files
echo "Cleaning up old RabbitMQ repo files..."
rm -f /etc/yum.repos.d/rabbitmq_erlang.repo
rm -f /etc/yum.repos.d/rabbitmq.repo

# Import correct RabbitMQ and Erlang signing keys
echo "Importing correct GPG keys..."
rpm --import https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
check_success "Failed to import RabbitMQ signing key."
rpm --import https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key
check_success "Failed to import Erlang signing key."

# Add Erlang repository
echo "Adding Erlang repository..."
cat > /etc/yum.repos.d/rabbitmq_erlang.repo <<EOL
[rabbitmq-erlang]
name=RabbitMQ Erlang
baseurl=https://packagecloud.io/rabbitmq/erlang/el/7/\$basearch
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/erlang/gpgkey
EOL
check_success "Failed to add Erlang repository."

# Add RabbitMQ repository
echo "Adding RabbitMQ repository..."
cat > /etc/yum.repos.d/rabbitmq.repo <<EOL
[rabbitmq-server]
name=RabbitMQ Server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/7/\$basearch
gpgcheck=1
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
EOL
check_success "Failed to add RabbitMQ repository."

# Verify that the repositories were added correctly
echo "Verifying repository list..."
yum repolist
check_success "Failed to list YUM repositories."

# Install Erlang
echo "Installing Erlang..."
yum install -y erlang
check_success "Erlang installation failed."

# Verify Erlang installation
erl -version > /dev/null 2>&1
check_success "Erlang command not found after installation."

# Install RabbitMQ
echo "Installing RabbitMQ..."
yum install -y rabbitmq-server
check_success "RabbitMQ installation failed."

# Enable and start RabbitMQ service
echo "Starting RabbitMQ service..."
systemctl enable --now rabbitmq-server
check_success "Failed to start RabbitMQ service."

# Set up Erlang cookie to match the cluster's cookie
echo "Configuring Erlang cookie..."
echo "FFVCEUJKPSYYKCGYQKDS" | sudo tee /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie /home/ec2-user/.erlang.cookie
sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
sudo chown root:root /root/.erlang.cookie
sudo chown ec2-user:ec2-user /home/ec2-user/.erlang.cookie
sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie /home/ec2-user/.erlang.cookie
check_success "Failed to set Erlang cookie."

# Restart RabbitMQ to apply changes
echo "Restarting RabbitMQ..."
systemctl restart rabbitmq-server
check_success "Failed to restart RabbitMQ service."

# Use Terraform output to get the first node IP
FIRST_NODE_IP="${aws_instance.rabbitmq_node.private_ip}"

if [[ -z "$FIRST_NODE_IP" || "$FIRST_NODE_IP" == "None" ]]; then
    echo "❌ ERROR: Could not fetch first node IP."
    exit 1
fi

echo "Joining RabbitMQ cluster at $FIRST_NODE_IP"

# Stop the RabbitMQ app before clustering
sudo rabbitmqctl stop_app
check_success "Failed to stop RabbitMQ app."

# Convert first node IP to RabbitMQ-compatible hostname format (ip-xxx-xxx-xxx-xxx)
RABBITMQ_CLUSTER_NODE="ip-$(echo "$FIRST_NODE_IP" | sed 's/\./-/g')"

echo "Joining RabbitMQ cluster at rabbit@$RABBITMQ_CLUSTER_NODE"

# Stop the RabbitMQ app before clustering
sudo rabbitmqctl stop_app
check_success "Failed to stop RabbitMQ app."

# Join the cluster using the converted hostname
sudo rabbitmqctl join_cluster rabbit@$RABBITMQ_CLUSTER_NODE
check_success "Failed to join RabbitMQ cluster."

# Start RabbitMQ app
sudo rabbitmqctl start_app
check_success "Failed to start RabbitMQ app after joining cluster."

echo "✅ Successfully joined RabbitMQ cluster at rabbit@$RABBITMQ_CLUSTER_NODE"

sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl restart rabbitmq-server

echo "===== RabbitMQ Cluster Node Setup Completed Successfully ====="

EOF
  )
}
