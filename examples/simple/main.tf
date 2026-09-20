data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "docbox_ssh_key"
  public_key = file(var.ssh_public_key_path)

  tags = {
    Name = "docbox-ssh-key"
  }
}

module "docbox" {
  source = "../../"

  ssh_key_name = aws_key_pair.ssh_key.key_name

  vpc_id                      = data.aws_vpc.default.id
  subnet_id                   = data.aws_subnets.default.ids[0]
  allowed_cidr_blocks         = [data.aws_vpc.default.cidr_block]
  full_access_security_groups = []
  additional_policy_arns      = {}

  architecture = "amd64"
}
