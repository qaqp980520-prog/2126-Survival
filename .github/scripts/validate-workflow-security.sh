#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${1:-.github/workflows}"
if [[ ! -d "$workflow_dir" ]]; then
  echo "ERROR: workflow directory not found: $workflow_dir" >&2
  exit 1
fi

mapfile -t workflow_files < <(find "$workflow_dir" -maxdepth 1 -type f \\( -name '*.yml' -o -name '*.yaml' \\) -print | sort)
if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo "ERROR: no workflow YAML files found in $workflow_dir" >&2
  exit 1
fi

workflow_count=0
action_count=0
errors=0

fail() {
  printf 'ERROR: %s: %s\\n' "$1" "$2" >&2
  errors=$((errors + 1))
}

for file in "${workflow_files[@]}"; do
  workflow_count=$((workflow_count + 1))

  if ! grep -Eq '^permissions:[[:space:]]*$' "$file"; then
    fail "$file" "missing top-level permissions block"
  fi
  if grep -Eq '^ {2,}permissions:[[:space:]]*$' "$file"; then
    fail "$file" "job-level permissions override detected; review explicitly"
  fi

  if ! awk '
    /^permissions:[[:space:]]*$/ { blocks++; in_block=1; next }
    in_block && /^[^[:space:]#]/ { in_block=0 }
    in_block && /^[[:space:]]*$/ { next }
    in_block && /^[[:space:]]*#/ { next }
    in_block {
      if ($0 ~ /^  contents:[[:space:]]*read([[:space:]]*#.*)?$/) { contents++; next }
      bad=1
    }
    END { exit !(blocks == 1 && contents == 1 && !bad) }
  ' "$file"; then
    fail "$file" "permissions must contain only contents: read"
  fi

  if grep -Eq '^[[:space:]]*(pull_request_target|workflow_run):[[:space:]]*$' "$file"; then
    fail "$file" "high-risk trigger requires a separate security review"
  fi

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    action_count=$((action_count + 1))
    case "$ref" in
      ./*) ;;
      *)
        if [[ ! "$ref" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*@[0-9a-f]{40}$ ]]; then
          fail "$file" "external action is not pinned to a full 40-character SHA: $ref"
        fi
        ;;
    esac
  done < <(sed -nE 's/^[[:space:]]*-[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\\1/p; s/^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\\1/p' "$file")
done

if [[ $errors -ne 0 ]]; then
  printf 'Workflow security policy FAILED: %d workflows, %d action references, %d violations.\\n' "$workflow_count" "$action_count" "$errors" >&2
  exit 1
fi

printf 'Workflow security policy PASSED: %d workflows, %d action references; all use contents: read, no job-level overrides, all external actions SHA-pinned, no pull_request_target/workflow_run triggers.\\n' "$workflow_count" "$action_count"
