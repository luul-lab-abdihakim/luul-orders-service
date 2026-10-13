#!/usr/bin/env bash
# Simulated deploy. At Luul this would be: helm upgrade, or a GitOps PR that bumps the image tag.
set -euo pipefail
echo "==> Deploying $2 to $1"
echo "    settings: deploy/$1.env"; grep -v "^#" "deploy/$1.env" | sed "s/^/      /" || true
echo "    real life: helm upgrade --install luul-orders ./chart --set image=$2 -n $1 (env from deploy/$1.env)"
echo "==> $1 is now running $2"
