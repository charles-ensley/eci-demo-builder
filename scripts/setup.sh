#!/bin/bash
set -e

ORG="${1:-}"
ORG_FLAG=""

if [ -n "$ORG" ]; then
    ORG_FLAG="--target-org $ORG"
fi

echo "=== Deploying ECI Demo Builder ==="
sf project deploy start $ORG_FLAG --wait 10

echo ""
echo "=== Assigning ECI_Demo_User permission set ==="
sf org assign permset --name ECI_Demo_User $ORG_FLAG

echo ""
echo "=== Done! ==="
echo "1. Open the App Launcher and search for 'ECI Demo Builder' to create your first demo call."
echo "2. After creating a call, navigate to the record, click the gear > Edit Page,"
echo "   and drag the 'eciDemoPlayback' component onto the page."
