# Create IAM Role for EC2
resource "aws_iam_role" "rabbitmq_role" {
  name = "rabbitmq-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach a policy to allow describing EC2 instances
resource "aws_iam_policy" "rabbitmq_ec2_policy" {
  name        = "rabbitmq-ec2-describe"
  description = "Allows EC2 instances to describe other instances"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances"
      ]
      Resource = "*"
    }]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "rabbitmq_policy_attachment" {
  role       = aws_iam_role.rabbitmq_role.name
  policy_arn = aws_iam_policy.rabbitmq_ec2_policy.arn
}

# Create an Instance Profile (required for EC2 IAM roles)
resource "aws_iam_instance_profile" "rabbitmq_profile" {
  name = "rabbitmq-instance-profile"
  role = aws_iam_role.rabbitmq_role.name
}
