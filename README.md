# Terraform AWS Docbox API Instance

This repository contains the terraform infrastructure definitions to setup and configure a Docbox EC2 instance of AWS

This infrastructure includes

- Docbox EC2 Instance
    - The instance itself
    - IAM role for the instance
    - Instance profile for the instance
- Secret for .env file
- Security group for access
- IAM
    - Optional SSM policy attachment
    - Secrets access policy
    - S3 access for docbox-* buckets
    - SQS queue access for the s3 bucket events
- SQS queue for upload events
