#!/bin/bash

# GoDaddy Domain Manager Script
# This script helps manage domain settings and DNS records for a GoDaddy domain

set -e

# Load environment variables
if [ -f "$(dirname "$0")/../../.env" ]; then
    source "$(dirname "$0")/../../.env"
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$GODADDY_API_KEY" ] || [ -z "$GODADDY_API_SECRET" ] || [ -z "$GODADDY_DOMAIN" ]; then
    echo "Error: GoDaddy API credentials or domain not set in .env file"
    exit 1
fi

# Set API base URL
GODADDY_API_URL="https://api.godaddy.com/v1"

# Function to get domain information
get_domain_info() {
    echo "Getting information for domain: $GODADDY_DOMAIN"
    curl -s -X GET "$GODADDY_API_URL/domains/$GODADDY_DOMAIN" \
        -H "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" \
        -H "Content-Type: application/json"
}

# Function to get DNS records
get_dns_records() {
    local record_type=${1:-"A"}
    echo "Getting $record_type records for domain: $GODADDY_DOMAIN"
    curl -s -X GET "$GODADDY_API_URL/domains/$GODADDY_DOMAIN/records/$record_type" \
        -H "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" \
        -H "Content-Type: application/json"
}

# Function to update a DNS record
update_dns_record() {
    local record_type=$1
    local name=$2
    local value=$3
    local ttl=${4:-600}

    echo "Updating $record_type record '$name' to point to '$value'"
    curl -s -X PUT "$GODADDY_API_URL/domains/$GODADDY_DOMAIN/records/$record_type/$name" \
        -H "Authorization: sso-key $GODADDY_API_KEY:$GODADDY_API_SECRET" \
        -H "Content-Type: application/json" \
        -d "[{\"data\": \"$value\", \"ttl\": $ttl}]"
}

# Function to create subdomains pointing to DigitalOcean
setup_application_dns() {
    local ip_address=$1
    if [ -z "$ip_address" ]; then
        echo "Error: IP address not provided"
        exit 1
    fi

    # Create A records for the main domain and subdomains
    echo "Setting up DNS records for application..."
    
    # Main domain
    update_dns_record "A" "@" "$ip_address"
    
    # www subdomain
    update_dns_record "A" "www" "$ip_address"
    
    # Other application subdomains
    update_dns_record "A" "registry" "$ip_address"
    update_dns_record "A" "agent" "$ip_address"
    update_dns_record "A" "tools" "$ip_address"
    update_dns_record "A" "traefik" "$ip_address"
    
    echo "DNS records updated successfully!"
}

# Parse command line arguments
case "$1" in
    info)
        get_domain_info
        ;;
    records)
        record_type=${2:-"A"}
        get_dns_records "$record_type" | jq .
        ;;
    update)
        if [ $# -lt 4 ]; then
            echo "Usage: $0 update <record_type> <name> <value> [ttl]"
            exit 1
        fi
        update_dns_record "$2" "$3" "$4" "${5:-600}"
        ;;
    setup)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 setup <ip_address>"
            exit 1
        fi
        setup_application_dns "$2"
        ;;
    *)
        echo "Usage: $0 {info|records|update|setup}"
        echo ""
        echo "  info                     Get domain information"
        echo "  records [type]           Get DNS records (defaults to A records)"
        echo "  update <type> <name> <value> [ttl] Update a DNS record"
        echo "  setup <ip_address>       Setup all application DNS records"
        exit 1
        ;;
esac

exit 0
