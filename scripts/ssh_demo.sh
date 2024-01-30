#!/usr/bin/env bash

set -v

SSH_TARGET_ID=tssh_YM6tq0S5dU

boundary authenticate oidc

boundary connect ssh -target-id $SSH_TARGET_ID

# Get instance ID in an EC2 instance
# curl http://169.254.169.254/latest/meta-data/instance-id
