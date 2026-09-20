variable "vpc_id" {
  type        = string
  description = "ID of the VPC to place resources within"
}

variable "instance_ami" {
  type        = string
  description = "AMI to use when creating the instance"
  # Amazon Linux 2023 AMI 2023.10.20260105.0 arm64 HVM kernel-6.1
  default = "ami-0727d44a1158304d8"
}

variable "instance_type" {
  type        = string
  default     = "t4g.small"
  description = "Instance type to use for the EC2 instance"
}

variable "architecture" {
  type        = string
  description = "The architecture, should match the architecture of the instance_type, used to download the correct binary (arm64 or amd64)"
  default     = "arm64"
}

variable "instance_name" {
  type        = string
  default     = "docbox-api"
  description = "Name of the EC2 instance"
}

variable "instance_profile_name" {
  type        = string
  default     = "docbox-api-instance-profile"
  description = "Name of the EC2 instance profile"
}

variable "iam_role_name" {
  type        = string
  default     = "docbox-api-role"
  description = "Name of the EC2 instance role"
}

variable "security_group_name" {
  type        = string
  default     = "docbox-api-sg"
  description = "Name of the EC2 instance security group"
}

variable "s3_access_policy_name" {
  type        = string
  default     = "docbox_s3_access_policy"
  description = "Name to use for the default_s3_access_policy if enabled"
}

variable "secrets_access_policy_name" {
  type        = string
  default     = "docbox_secrets_access_policy"
  description = "Name of the secrets manager policy for the .env secret"
}

variable "default_s3_access_policy" {
  type        = bool
  default     = true
  description = "Whether to use the default docbox-* s3 access policy to access docbox-* prefixed buckets"
}

variable "env_secret_name" {
  type        = string
  default     = "docbox-env-file"
  description = "Name of the secret file to store the server secret within"
}

variable "additional_policy_arns" {
  type        = map(string)
  default     = {}
  description = "Extra IAM policy ARNs to attach to this Lambda's role (e.g., SQS execution)"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of CIDR blocks that are allowed to use the API server"
}

variable "full_access_security_groups" {
  type        = list(string)
  description = "List of security group IDs to allow full ingress access. Used for providing VPN access"
  default     = []
}

variable "proxy_url" {
  type        = string
  default     = ""
  description = "Proxy server host to use if proxying egress"
}

variable "ssh_key_name" {
  type        = string
  description = "Name of the SSH key to use for the instance"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet to store the instance within (private subnet preferred)"
}

variable "volume_type" {
  type        = string
  default     = "gp3"
  description = "Type of the API instance volume"
}

variable "volume_size" {
  type        = number
  default     = 8
  description = "Size of the API instance volume"
}

variable "swap_size_gb" {
  type        = number
  description = "Size of the server swap file in gigabytes to create"
  default     = 1
}

variable "credit_specification" {
  type    = string
  default = "standard"
}

variable "allow_ssm_management" {
  type        = bool
  default     = true
  description = "Whether to make the instance SSM managed by attaching the AmazonSSMManagedInstanceCore policy"
}

variable "instance_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to add to the EC2 instance"
}

variable "instance_timezone" {
  type        = string
  default     = "Pacific/Auckland"
  description = "Timezone to set the EC2 instance to (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones use the 'TZ identifier' value)"
}
