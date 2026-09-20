
# Secret to store the environment variables in
output "env_secret_name" {
  value = aws_secretsmanager_secret.env_secret.name
}

output "role_id" {
  value = aws_iam_role.role.id
}

output "role_arn" {
  value = aws_iam_role.role.arn
}

output "api_sg_id" {
  value = aws_security_group.security_group.id
}

output "api_instance_id" {
  value = aws_instance.instance.id
}

output "private_ip" {
  value = aws_instance.instance.private_ip
}
