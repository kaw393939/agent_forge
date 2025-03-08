#!/usr/bin/env python3
"""
Deployment Testing Script for Agent Forge
This script tests the deployed services using Playwright
"""

import os
import sys
import time
import argparse
from playwright.sync_api import sync_playwright, expect

def test_service(page, url, name, expected_text=None, screenshot_path=None):
    """Test a specific service endpoint"""
    print(f"Testing {name} at {url}...")
    
    try:
        # Navigate to the URL
        response = page.goto(url, wait_until="networkidle", timeout=30000)
        
        # Check if the page loaded successfully
        if response is None or not response.ok:
            status = response.status if response else "Unknown"
            print(f"❌ Failed to load {name}. Status code: {status}")
            return False
        
        # Take a screenshot if path is provided
        if screenshot_path:
            os.makedirs(os.path.dirname(screenshot_path), exist_ok=True)
            page.screenshot(path=screenshot_path)
            print(f"📸 Screenshot saved to {screenshot_path}")
        
        # Check for expected text if provided
        if expected_text:
            content_found = page.content().find(expected_text) != -1
            if content_found:
                print(f"✅ Found expected text in {name}: '{expected_text}'")
            else:
                print(f"❌ Expected text not found in {name}: '{expected_text}'")
                return False
        
        print(f"✅ Successfully loaded {name}")
        return True
    
    except Exception as e:
        print(f"❌ Error testing {name}: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Test Agent Forge deployment")
    parser.add_argument("--base-domain", default="mywebclass.org", help="Base domain for testing")
    parser.add_argument("--ip", help="IP address for local testing (updates /etc/hosts)")
    parser.add_argument("--local", action="store_true", help="Test locally without HTTPS")
    parser.add_argument("--screenshots", action="store_true", help="Take screenshots of each service")
    
    args = parser.parse_args()
    
    # Determine protocol based on local or production testing
    protocol = "http" if args.local else "https"
    
    # Prepare test targets
    test_targets = [
        {
            "name": "Main Site",
            "path": "",
            "expected": "Agent Forge"
        },
        {
            "name": "Service Registry",
            "path": "registry",
            "expected": "Service Registry"
        },
        {
            "name": "Example Agent",
            "path": "agent",
            "expected": "Example Agent"
        },
        {
            "name": "Example Tool",
            "path": "tools",
            "expected": "Example Tool"
        },
        {
            "name": "Linkerd Dashboard",
            "path": "linkerd",
            "expected": "Linkerd"
        }
    ]
    
    # Initialize Playwright
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()
        
        # Test each target
        success_count = 0
        
        for target in test_targets:
            url = f"{protocol}://{target['path']}.{args.base_domain}" if target["path"] else f"{protocol}://{args.base_domain}"
            
            screenshot_path = None
            if args.screenshots:
                screenshot_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../test_results/screenshots")
                screenshot_path = f"{screenshot_dir}/{target['path'] or 'main'}.png"
            
            if test_service(page, url, target["name"], target["expected"], screenshot_path):
                success_count += 1
        
        # Close browser
        browser.close()
        
        # Report results
        print("\n=== Test Results ===")
        print(f"✅ {success_count}/{len(test_targets)} services tested successfully")
        
        if success_count == len(test_targets):
            print("\n🎉 All services are running correctly!")
            return 0
        else:
            print("\n⚠️ Some services have issues. Please check the logs above.")
            return 1

if __name__ == "__main__":
    sys.exit(main())
