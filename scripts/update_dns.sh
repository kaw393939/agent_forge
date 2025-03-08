#!/bin/bash

# DNS Update Script for DigitalOcean
# This script updates DNS records for a domain on DigitalOcean

set -e

# Color formatting for messages
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
function print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
function print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
function print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check dependencies
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first."
    print_status "On Ubuntu/Debian: sudo apt-get install jq"
    print_status "On macOS: brew install jq"
    exit 1
fi

# Check arguments
if [ "$#" -lt 3 ]; then
    print_error "Usage: $0 <domain> <ip_address> <do_token>"
    exit 1
fi

DOMAIN="$1"
IP_ADDRESS="$2"
DO_TOKEN="$3"

# Optional subdomains parameter (comma-separated list)
SUBDOMAINS=${4:-"www,registry,agent,tools,linkerd,traefik"}

# DigitalOcean API URL
DO_API_URL="https://api.digitalocean.com/v2"

# Function to update or create a DNS record
update_dns_record() {
    local domain="$1"
    local name="$2"
    local ip="$3"
    local token="$4"
    
    # Check if the domain exists in DigitalOcean
    domain_check=$(curl -s -X GET "$DO_API_URL/domains/$domain" \
        -H "Authorization: Bearer $token" | \
        jq -r ".domain.name // empty")
    
    if [ -z "$domain_check" ]; then
        print_warning "Domain $domain not found in DigitalOcean. Attempting to create it..."
        domain_create=$(curl -s -X POST "$DO_API_URL/domains" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$domain\",\"ip_address\":\"$ip\"}" | \
            jq -r ".domain.name // empty")
        
        if [ -z "$domain_create" ]; then
            print_error "Failed to create domain $domain. Please create it manually in DigitalOcean."
            return 1
        else
            print_success "Domain $domain created successfully in DigitalOcean."
        fi
    fi
    
    # Check if the record exists
    record_id=$(curl -s -X GET "$DO_API_URL/domains/$domain/records" \
        -H "Authorization: Bearer $token" | \
        jq -r ".domain_records[] | select(.name == \"$name\" and .type == \"A\") | .id")
    
    if [ -n "$record_id" ]; then
        # Update the existing record
        print_status "Updating DNS record for $name.$domain..."
        update_result=$(curl -s -X PUT "$DO_API_URL/domains/$domain/records/$record_id" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{\"data\":\"$ip\"}" | \
            jq -r ".domain_record.data // empty")
            
        if [ "$update_result" == "$ip" ]; then
            print_success "DNS record for $name.$domain updated successfully"
        else
            print_error "Failed to update DNS record for $name.$domain"
        fi
    else
        # Create a new record
        print_status "Creating DNS record for $name.$domain..."
        create_result=$(curl -s -X POST "$DO_API_URL/domains/$domain/records" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"$name\",\"data\":\"$ip\",\"ttl\":1800}" | \
            jq -r ".domain_record.data // empty")
            
        if [ "$create_result" == "$ip" ]; then
            print_success "DNS record for $name.$domain created successfully"
        else
            print_error "Failed to create DNS record for $name.$domain"
        fi
    fi
}

# Verify DigitalOcean API token
print_status "Verifying DigitalOcean API token..."
token_check=$(curl -s -X GET "$DO_API_URL/account" \
    -H "Authorization: Bearer $DO_TOKEN" | \
    jq -r ".account.status // empty")

if [ -z "$token_check" ]; then
    print_error "Invalid DigitalOcean API token. Please check your token and try again."
    exit 1
fi

print_success "DigitalOcean API token is valid."

# Update main domain (@ record)
print_status "Updating DNS records for $DOMAIN to point to $IP_ADDRESS..."
update_dns_record "$DOMAIN" "@" "$IP_ADDRESS" "$DO_TOKEN"

# Update each subdomain
IFS=',' read -ra SUBDOMAIN_ARRAY <<< "$SUBDOMAINS"
for subdomain in "${SUBDOMAIN_ARRAY[@]}"; do
    update_dns_record "$DOMAIN" "$subdomain" "$IP_ADDRESS" "$DO_TOKEN"
done

print_success "All DNS records have been updated successfully!"
print_status "DNS records now point to: $IP_ADDRESS"
print_status "Note: DNS changes may take some time to propagate globally (typically 5-30 minutes)"
print_status "You can verify DNS propagation with: dig +short $DOMAIN"
