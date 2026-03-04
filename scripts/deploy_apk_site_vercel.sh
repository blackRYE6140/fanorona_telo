#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE_DIR="$PROJECT_ROOT/apk_download_site"

if ! command -v vercel >/dev/null 2>&1; then
  echo "Vercel CLI not found. Install with: npm i -g vercel"
  exit 1
fi

"$PROJECT_ROOT/scripts/prepare_apk_site.sh"

cd "$SITE_DIR"

if [[ "$#" -eq 0 ]]; then
  vercel
else
  vercel "$@"
fi
