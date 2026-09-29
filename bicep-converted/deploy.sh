#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deployment_name="az700-lab-v3-$(date +%Y%m%d%H%M%S)"

if ! command -v az >/dev/null 2>&1; then
  printf 'Azure CLI (az) is required.\n' >&2
  exit 1
fi

read -r -s -p 'VM admin password: ' admin_password
printf '\n'
read -r -s -p 'Confirm VM admin password: ' confirmed_password
printf '\n'

if [[ "$admin_password" != "$confirmed_password" ]]; then
  printf 'Passwords do not match.\n' >&2
  exit 1
fi

if (( ${#admin_password} < 12 || ${#admin_password} > 123 )); then
  printf 'Password must contain 12-123 characters.\n' >&2
  exit 1
fi

complexity=0
[[ "$admin_password" =~ [A-Z] ]] && ((complexity += 1))
[[ "$admin_password" =~ [a-z] ]] && ((complexity += 1))
[[ "$admin_password" =~ [0-9] ]] && ((complexity += 1))
[[ "$admin_password" =~ [^[:alnum:]] ]] && ((complexity += 1))

if (( complexity < 3 )); then
  printf 'Password must include at least three of: uppercase, lowercase, number, and special character.\n' >&2
  exit 1
fi

export AZURE_ADMIN_PASSWORD="$admin_password"
unset admin_password confirmed_password
trap 'unset AZURE_ADMIN_PASSWORD' EXIT

deployment_args=(
  az deployment sub create
  --name "$deployment_name"
  --location southafricanorth
  --parameters "$script_dir/main.bicepparam"
)

if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  deployment_args+=(--subscription "$AZURE_SUBSCRIPTION_ID")
fi

"${deployment_args[@]}"