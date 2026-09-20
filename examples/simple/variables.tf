variable "aws_region" {
  description = "The AWS region to deploy the resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "aws_profile" {
  description = "The AWS cli profile to use"
  type        = string
}

variable "ssh_public_key_path" {
  description = "File path to the SSH public key to use for SSH"
  type        = string
}
