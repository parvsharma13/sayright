#!/bin/bash
# Fills in the two placeholders left in the docs, so you do not have to hunt them down.
#   ./Scripts/set-repo.sh your-org/sayright you@example.com
set -euo pipefail

REPO="${1:-}"
CONTACT="${2:-}"

if [[ -z "$REPO" ]]; then
    echo "usage: $0 <owner/repo> [contact-email]" >&2
    exit 1
fi

OWNER="${REPO%%/*}"
files=$(grep -rl '<your-org>' --include='*.md' --include='*.yml' . || true)
for f in $files; do
    sed -i '' "s|<your-org>/sayright|$REPO|g; s|<your-org>|$OWNER|g" "$f"
    echo "updated $f"
done

if [[ -n "$CONTACT" ]]; then
    for f in $(grep -rl 'MAINTAINER' --include='*.md' . || true); do
        sed -i '' "s|\`<MAINTAINER EMAIL — replace before publishing>\`|\`$CONTACT\`|g; \
                   s|\`<MAINTAINER CONTACT — replace before publishing>\`|\`$CONTACT\`|g" "$f"
        echo "updated $f"
    done
else
    echo "note: no contact given; SECURITY.md and CODE_OF_CONDUCT.md still have a placeholder."
fi
