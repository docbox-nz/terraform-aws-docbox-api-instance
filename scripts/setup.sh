#!/bin/bash

# ===
# This setup script is intended to be run on the EC2 instance
# that will be running the docbox API.
# ===

# Variables injected into the template
PROXY_URL="${proxy_url}"
BINARY_URL="${binary_url}"
SWAP_SIZE="${swap_size_gb}G"
INSTANCE_TIMEZONE="${instance_timezone}"

# IP address for instance metadata services (IMDS)
INSTANCE_METADATA_SERVICE_IP="169.254.169.254"

is_systemd_active() {
    command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1
}

# Make sudo run commands regularly if the system doesn't have sudo (docker containers)
if ! command -v sudo >/dev/null 2>&1; then
    sudo() {
        "$@"
    }
fi

# Configure dnf and system to use proxy if specified
configure_proxy() {
    # Skip proxy setup if PROXY_HOST or 1 is empty
    if [ -z "$PROXY_URL" ]; then
        echo "PROXY_URL is empty. Skipping proxy configuration."
        return 0
    fi

    if ! grep -q "^proxy=" /etc/dnf/dnf.conf 2>/dev/null; then
        echo "proxy=$PROXY_URL" >> /etc/dnf/dnf.conf
    else
        sed -i "s|^proxy=.*|proxy=$PROXY_URL|" /etc/dnf/dnf.conf
    fi

    # Set environment proxy variables for the session
    export http_proxy="$PROXY_URL"
    export https_proxy="$PROXY_URL"
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"

    # Ensure directory for override exists
    sudo mkdir -p /etc/systemd/system/amazon-ssm-agent.service.d

    # Create service override to proxy AWS SSM agent traffic through the proxy server
    # (https://docs.aws.amazon.com/systems-manager/latest/userguide/configure-proxy-ssm-agent.html#ssm-agent-proxy-upstart)
    echo "Setting up AWS SSM proxying"
    cat <<EOF | sudo tee /etc/systemd/system/amazon-ssm-agent.service.d/override.conf >/dev/null
[Service]
Environment="http_proxy=$PROXY_URL"
Environment="https_proxy=$PROXY_URL"
Environment="no_proxy=$INSTANCE_METADATA_SERVICE_IP"
EOF

    # Reload systemd daemon
    sudo systemctl daemon-reload

    # Restart SSM agent for the new configuration
    sudo systemctl restart amazon-ssm-agent
}

# Wait until the EC2 container has networking
# (When terraform is setting up this may not happen immediately)
wait_for_network() {
    # Wait until the network is up
    until curl -sSf https://www.google.com >/dev/null; do
        echo "Waiting for network..."
        sleep 5
    done
}

# Set the system timezone
set_timezone() {
    sudo timedatectl set-timezone "$INSTANCE_TIMEZONE"
}

# Install required dependencies
install_dependencies() {
    # Install updates
    echo "Installing updates"
    sudo dnf update -y

    # Install poppler
    echo "Installing dependencies"
    sudo dnf install -y poppler poppler-utils poppler-data
}

# Downloads and sets up the docbox server binary
download_docbox() {
    local TMP_SERVER_PATH="/tmp/docbox"
    local SERVER_PATH="/docbox/app"

    # Download docbox server binary
    echo "Downloading docbox server"
    curl -L -o $TMP_SERVER_PATH $BINARY_URL

    # Ensure the docbox directory exists
    sudo mkdir /docbox

    # Move docbox server binary
    sudo mv $TMP_SERVER_PATH $SERVER_PATH

    # Ensure the binary has execute permissions
    sudo chmod +x $SERVER_PATH
}

# Sets up and creates the docbox systemd service
setup_docbox_service() {
    # Create service for docbox
    echo "Creating docbox service"
    echo "${docbox_service_config}" | base64 -d | sudo tee /etc/systemd/system/docbox.service >/dev/null

    echo "Reloading systemd manager configuration..."

    # Reload the services
    sudo systemctl daemon-reload

    # Enable automatic startup of the services
    sudo systemctl enable docbox.service

    # Start the services
    sudo systemctl start docbox.service
}

# Runs docbox when within a containerized environment that has no systemd
run_docbox_no_systemd() {
    /docbox/app > /proc/1/fd/1 2>&1 &
}

# Sets up the updater script
setup_docbox_update_script() {
    # Create updater script
    echo "${update_script}" | base64 -d | sudo tee /docbox/update.sh >/dev/null
    # Make updater script executable
    sudo chmod +x /docbox/update.sh
}

# Setup the .env file downloader script
setup_env_script() {
    # Create .env retrieval script
    echo "${update_env_shell_script}" | base64 -d | sudo tee /docbox/update_env.sh >/dev/null

    # Make updater script executable
    sudo chmod +x /docbox/update_env.sh
}

# Setup a 1GB
setup_swap() {
    # Allocate 1GB swap file
    sudo fallocate -l "$SWAP_SIZE" /swapfile

    # Set swap file permissions
    sudo chmod 600 /swapfile

    # Set the swap area
    sudo mkswap /swapfile

    # Enable the swap file
    sudo swapon /swapfile

    # Persist the new swap file
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
}

configure_proxy
wait_for_network
set_timezone
install_dependencies
download_docbox

if is_systemd_active; then
    setup_docbox_service
else
    run_docbox_no_systemd
fi

setup_docbox_update_script
setup_swap
