#!/usr/bin/env bash
set -euo pipefail

echo
echo '|=========================|'
echo '| Building normative tags |'
echo '|=========================|'
make build-tags

run_check() {
  local reference_path=$1
  local generated_path=$2

  if [[ "${UPDATE_REFERENCE:-}" == "1" ]]; then
    ruby scripts/detect_tag_changes.rb --update-reference \
      "${reference_path}" \
      "${generated_path}"
  else
    ruby scripts/detect_tag_changes.rb \
      "${reference_path}" \
      "${generated_path}"
  fi
}

echo
echo '|===================================|'
echo '| Checking unprivileged tag changes |'
echo '|===================================|'
run_check \
  ref/riscv-unprivileged-norm-tags.json \
  build/riscv-unprivileged-norm-tags.json

echo
echo '|=================================|'
echo '| Checking privileged tag changes |'
echo '|=================================|'
run_check \
  ref/riscv-privileged-norm-tags.json \
  build/riscv-privileged-norm-tags.json

echo "Tag change checks completed successfully."
