resource "aws_instance" "rabbitmq_node" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  key_name                    = var.key_name
  subnet_id                   = var.subnet_ids[1]
  vpc_security_group_ids      = [aws_security_group.rabbitmq_sg.id]

  tags = {
    Name    = "rabbitmq-first-node"
    cluster = "first_node"  
  }


  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1  # Redirect output for debugging

    echo "===== Starting RabbitMQ Head Node Setup ====="

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
    sudo yum clean all
    sudo yum update -y
    check_success "System update failed."

    # Install dependencies
    echo "Installing dependencies..."
    sudo yum install -y wget curl epel-release
    check_success "Failed to install dependencies."

    # Import RabbitMQ and Erlang signing keys
    echo "Importing GPG keys..."
    sudo rpm --import https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
    sudo rpm --import https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/gpg.E495BB49CC4BBE5B.key
    check_success "Failed to import RabbitMQ and Erlang GPG keys."

    # Add Erlang repository
    echo "Adding Erlang repository..."
    sudo tee /etc/yum.repos.d/rabbitmq_erlang.repo > /dev/null <<EOL
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
    sudo tee /etc/yum.repos.d/rabbitmq.repo > /dev/null <<EOL
    [rabbitmq-server]
    name=RabbitMQ Server
    baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/7/\$basearch
    gpgcheck=1
    enabled=1
    gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
    EOL
    check_success "Failed to add RabbitMQ repository."

    # Install Erlang & RabbitMQ
    echo "Installing Erlang & RabbitMQ..."
    sudo yum install -y erlang rabbitmq-server
    check_success "Failed to install Erlang and RabbitMQ."

    # Enable and start RabbitMQ service
    echo "Starting RabbitMQ service..."
    sudo systemctl enable --now rabbitmq-server
    check_success "Failed to start RabbitMQ service."

    # Ensure RabbitMQ uses correct node name
    echo "Configuring RabbitMQ node name..."
    sudo bash -c 'echo "export RABBITMQ_NODENAME=rabbit@$(hostname -s)" >> /etc/profile'
    export RABBITMQ_NODENAME=rabbit@$(hostname -s)
    check_success "Failed to set RabbitMQ node name."

    # Enable RabbitMQ Management Plugin
    echo "Enabling RabbitMQ Management Plugin..."
    sudo rabbitmq-plugins enable rabbitmq_management
    check_success "Failed to enable RabbitMQ management plugin."

    # Create RabbitMQ Admin User
    echo "Creating RabbitMQ Admin User..."
    sudo rabbitmqctl add_user admin StrongPassword
    sudo rabbitmqctl set_user_tags admin administrator
    sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
    check_success "Failed to create RabbitMQ admin user."

    # Set up Erlang cookie (runs at the end with sudo)
    echo "Setting Erlang cookie for clustering..."
    sudo bash -c 'echo "FFVCEUJKPSYYKCGYQKDS" | tee /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie /home/ec2-user/.erlang.cookie'
    sudo chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
    sudo chown root:root /root/.erlang.cookie
    sudo chown ec2-user:ec2-user /home/ec2-user/.erlang.cookie
    sudo chmod 400 /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie /home/ec2-user/.erlang.cookie
    check_success "Failed to set Erlang cookie."

    # Restart RabbitMQ to Apply Changes
    echo "Restarting RabbitMQ to apply configurations..."
    sudo systemctl restart rabbitmq-server
    check_success "Failed to restart RabbitMQ."

    echo "===== RabbitMQ Head Node Setup Completed Successfully ====="
EOF

}
