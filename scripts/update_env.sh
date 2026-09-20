#!/bin/bash
# ===
# This script handles updating the docbox env file from secrets manager
# ===
SECRET_NAME="${secret_name}"

# Set the env file contents from the secret value
aws secretsmanager get-secret-value \
    --secret-id "$SECRET_NAME" \
    --query SecretString \
    --output text | sudo tee /docbox/.env >/dev/null
