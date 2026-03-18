#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <product_repo_path> <zap_runner_repo_path> [--move]" >&2
  exit 2
fi

product_repo="$(cd "$1" && pwd)"
zap_runner_repo="$(cd "$2" && pwd)"
mode="${3:---copy}"

src_files=(
  "cloud.gov billing api development.context"
  "cloud.gov billing api staging.context"
  "cloud.gov billing api production.context"
  "cloud.gov csb staging.context"
  "cloud.gov pages editor development.context"
  "cloud.gov-conmon-external.context"
  "cloud.gov-conmon-internal.context"
  "cloud.gov-conmon-pages.context"
)

dest_dir="${zap_runner_repo}/ci/zap-config/legacy-contexts/product"
mkdir -p "${dest_dir}"

for file in "${src_files[@]}"; do
  src="${product_repo}/${file}"
  dest="${dest_dir}/${file}"

  if [[ ! -f "${src}" ]]; then
    echo "missing source file: ${src}" >&2
    exit 1
  fi

  if [[ "${mode}" == "--move" ]]; then
    mv "${src}" "${dest}"
    echo "moved ${file}"
  else
    cp "${src}" "${dest}"
    echo "copied ${file}"
  fi
done

echo
echo "Legacy contexts are now under:"
echo "  ${dest_dir}"
echo
echo "Next step:"
echo "  python3 ${zap_runner_repo}/scripts/import-legacy-contexts.py ${dest_dir}"