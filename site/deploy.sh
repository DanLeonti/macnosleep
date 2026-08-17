#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${MACNOSLEEP_PAGES_PROJECT:-macnosleep}"

echo "==> Deploying site/ to Cloudflare Pages project '${PROJECT}'"
npx --yes wrangler@4 pages deploy site \
  --project-name "${PROJECT}" \
  --branch main \
  --commit-dirty true
