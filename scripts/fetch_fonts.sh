#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p assets/fonts
base='https://raw.githubusercontent.com/rastikerdar/vazirmatn/v33.003/fonts/ttf'
for weight in Regular Medium SemiBold Bold ExtraBold; do
  destination="assets/fonts/Vazirmatn-${weight}.ttf"
  if [[ ! -s "$destination" ]]; then
    echo "Downloading Vazirmatn-${weight} from its official upstream release ..."
    curl --fail --location --show-error --silent --retry 3 \
      "$base/Vazirmatn-${weight}.ttf" -o "$destination.tmp"
    mv "$destination.tmp" "$destination"
  fi
  test -s "$destination"
done
printf '%s\n' 'Official Vazirmatn fonts are ready in the local project.'
