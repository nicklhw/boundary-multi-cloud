#!/usr/bin/env bash

set -v

RDP_TARGET_ID=ttcp_UivblKzFt9

boundary authenticate oidc

# https://developer.hashicorp.com/boundary/docs/commands/connect/rdp
boundary connect rdp \
   -target-id $RDP_TARGET_ID \
   -exec bash \
   -- -c "open rdp://full%20address=s={{boundary.addr}} && sleep 600"

# Get Azure VM instance metadata
# Invoke-RestMethod -Uri http://169.254.169.254/metadata/instance?api-version=2021-02-01 -Headers @{Metadata="true"}

