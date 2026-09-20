terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.54.0"
    }
  }

  required_version = ">= 1.2.0"
}

locals {
  binary_name = var.architecture == "arm64" ? "docbox-aarch64-linux-gnu" : "docbox-x86_64-linux-gnu"
  binary_url  = "https://github.com/docbox-nz/docbox/releases/latest/download/${local.binary_name}"

  docbox_service_config = file("${path.module}/resources/docbox.service")

  update_shell_script = templatefile("${path.module}/scripts/update.sh", {
    proxy_url  = var.proxy_url,
    binary_url = local.binary_url
  })

  update_env_shell_script = templatefile("${path.module}/scripts/update_env.sh", {
    secret_name = aws_secretsmanager_secret.env_secret.id
  })

  setup_shell_script = templatefile("${path.module}/scripts/setup.sh", {
    proxy_url  = var.proxy_url,
    binary_url = local.binary_url,

    docbox_service_config   = base64encode(local.docbox_service_config),
    update_script           = base64encode(local.update_shell_script),
    update_env_shell_script = base64encode(local.update_env_shell_script),

    swap_size_gb      = tostring(var.swap_size_gb),
    instance_timezone = var.instance_timezone
  })
}

resource "aws_instance" "instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type

  subnet_id = var.subnet_id

  key_name = var.ssh_key_name

  vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.name

  root_block_device {
    volume_type = var.volume_type
    volume_size = var.volume_size
  }

  credit_specification {
    cpu_credits = var.credit_specification
  }

  user_data = local.setup_shell_script

  # Prevent replacement due to user_data changes
  lifecycle {
    ignore_changes = [user_data]
  }

  tags = merge(var.instance_tags, {
    Name = var.instance_name
  })
}

resource "aws_iam_role" "role" {
  name = var.iam_role_name
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

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.instance_profile_name
  role = aws_iam_role.role.name
}

resource "aws_secretsmanager_secret" "env_secret" {
  name        = var.env_secret_name
  description = "Docbox instance .env file contents"
}

resource "aws_security_group" "security_group" {
  name        = var.security_group_name
  description = "Docbox API instance security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = var.full_access_security_groups
    description     = "Full trusted access to secure groups (VPN security groups, ..etc)"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "API access for allowed CIDR blocks"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Required port 443 ingress for AWS Secrets Manager, without this secrets manager will timeout"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound traffic from the API to other services"
  }

  tags = {
    Name = var.security_group_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  count      = var.allow_ssm_management ? 1 : 0
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "secrets_policy" {
  name        = var.secrets_access_policy_name
  description = "Secrets manager access for docbox to retrieve its .env file secret"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "secretsmanager:GetSecretValue",
      ],
      Resource = [aws_secretsmanager_secret.env_secret.arn]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = var.s3_access_policy_name
  description = "Default docbox S3 access policy for docbox prefixed bucket access by the API server"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Object level actions
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",        # Upload files
          "s3:PutObjectTagging", # Tag uploaded files (expiry tags)
          "s3:GetObject",        # Retrieve files
          "s3:DeleteObject"      # Delete files
        ]
        Resource = [
          "arn:aws:s3:::docbox-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.default_s3_access_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each   = var.additional_policy_arns
  role       = aws_iam_role.role.name
  policy_arn = each.value
}

# Queue for file upload messages
resource "aws_sqs_queue" "s3_queue" {
  name = var.s3_queue_name

  tags = {
    Name = var.s3_queue_tag_name
  }
}

# Policy on the docbox S3 notification SQS queue that permits AWS S3
# to push new messages onto the queue
resource "aws_sqs_queue_policy" "s3_sqs_policy" {
  queue_url = aws_sqs_queue.s3_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "docbox-queue-events"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.s3_queue.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:s3:::docbox-*"
          }
        }
      }
    ]
  })
}
