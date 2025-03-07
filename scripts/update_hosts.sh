#!/bin/bash

# Script to update /etc/hosts file with test domains for mywebclass.org
echo "Adding mywebclass.org test domains to /etc/hosts..."

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (with sudo)"
  exit 1
fi

# Add hosts entries
cat << EOF >> /etc/hosts

# Agent Framework Test Domains
127.0.0.1 mywebclass.org www.mywebclass.org traefik.mywebclass.org registry.mywebclass.org agent.mywebclass.org tools.mywebclass.org
EOF

echo "Hosts file updated successfully!"
cat /etc/hosts | tail -3
