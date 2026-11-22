#!/usr/bin/env bash
set -euo pipefail

workflow_dir="${1:-.github/workflows}"
if [[ ! -d "$workflow_dir" ]]; then
  echo "ERROR: workflow directory not found: $workflow_dir" >&2
  exit 1
fi

mapfile -t workflow_files < <(find "$workflow_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort)
if [[ ${#workflow_files[@]} -eq 0 ]]; then
  echo "ERROR: no workflow YAML files found in $workflow_dir" >&2
  exit 1
fi

workflow_count=0
action_count=0
errors=0

fail() {
  printf 'ERROR: %s: %s\n' "$1" "$2" >&2
  errors=$((errors + 1))
}

has_pull_request_path() {
  local file="$1"
  local wanted_path="$2"
  awk -v wanted_path="$wanted_path" '
    /^on:[[:space:]]*(#.*)?$/ { in_on=1; in_pr=0; in_paths=0; next }
    /^[^[:space:]#]/ { in_on=0; in_pr=0; in_paths=0 }
    in_on && /^  pull_request:[[:space:]]*(#.*)?$/ { pr_blocks++; in_pr=1; in_paths=0; next }
    in_on && /^  [^[:space:]#][^:]*:/ { in_pr=0; in_paths=0 }
    in_pr && /^    paths:[[:space:]]*(#.*)?$/ { paths_blocks++; in_paths=1; next }
    in_pr && /^    [^[:space:]#][^:]*:/ { in_paths=0 }
    in_paths {
      line=$0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      if (line ~ /^[!&*]/ || line ~ /^[|>]/) unsafe_pattern=1
      if (line ~ /\\/) unsafe_pattern=1
      gsub(/^[\"\047]/, "", line)
      gsub(/[\"\047]$/, "", line)
      if (line ~ /^!/) unsafe_pattern=1
      if (line == wanted_path) found=1
    }
    END { exit !(pr_blocks == 1 && paths_blocks == 1 && found && !unsafe_pattern) }
  ' "$file"
}

has_pull_request_narrowing_filter() {
  local file="$1"
  awk '
    /^on:[[:space:]]*(#.*)?$/ { in_on=1; in_pr=0; next }
    /^[^[:space:]#]/ { in_on=0; in_pr=0 }
    in_on && /^  pull_request:[[:space:]]*(#.*)?$/ { in_pr=1; next }
    in_on && /^  [^[:space:]#][^:]*:/ { in_pr=0 }
    in_pr && /^    (branches|branches-ignore|types|paths-ignore):/ { found=1 }
    END { exit !found }
  ' "$file"
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

  if ! awk '
    /^on:[[:space:]]*(#.*)?$/ { blocks++; in_on=1; saw_child=0; next }
    /^[^[:space:]#]/ { in_on=0 }
    in_on && /^[[:space:]]*($|#)/ { next }
    in_on && !saw_child {
      saw_child=1
      if ($0 ~ /^[[:space:]]*-/) event_sequence=1
    }
    END { exit !(blocks == 1 && saw_child && !event_sequence) }
  ' "$file"; then
    fail "$file" "on must be exactly one non-empty block-style event mapping; scalar, flow-sequence, block-sequence, or duplicate forms are unsupported"
  fi

  if grep -Eq '^[[:space:]]*(-[[:space:]]*)?<<[[:space:]]*:' "$file" ||
     grep -Eq '[,{][[:space:]]*<<[[:space:]]*:' "$file"; then
    fail "$file" "YAML merge keys are unsupported; they can import unreviewed workflow event filters"
  fi

  if grep -Eq '^[[:space:]]*(pull_request_target|workflow_run)[[:space:]]*:' "$file"; then
    fail "$file" "high-risk trigger requires a separate security review, regardless of its value form"
  fi

  if grep -Eq '^[[:space:]]*(permissions|on|pull_request_target|workflow_run)[[:space:]]*:[[:space:]]*\{' "$file" ||
     grep -Eq '[,{][[:space:]]*(permissions|on|pull_request_target|workflow_run)[[:space:]]*:' "$file"; then
    fail "$file" "flow-style security-sensitive mappings are unsupported; use plain block-style mappings"
  fi

  if [[ "$file" == */godot-validation.yml ]]; then
    for required_path in \
      ".github/workflows/**" \
      ".github/scripts/**" \
      ".github/actions/**" \
      "systems/**" \
      "scripts/**" \
      "world/**" \
      "tests/**" \
      "daily_games/**" \
      "prototypes/**" \
      "assets/**" \
      "project.godot" \
      ".gitignore" \
      "README.md" \
      "PROJECT_INDEX.md" \
      "docs/**"; do
      if ! has_pull_request_path "$file" "$required_path"; then
        fail "$file" "Full Gate pull_request.paths must include $required_path without negative, tagged, anchored, aliased, or escaped patterns"
      fi
    done
    if has_pull_request_narrowing_filter "$file"; then
      fail "$file" "Full Gate pull_request must not narrow target branches or event activity types, or use paths-ignore"
    fi
  fi

  if grep -Eq '[,{][[:space:]]*uses:[[:space:]]*' "$file" ||
     grep -Eq "^[[:space:]]*(-[[:space:]]*)?['\"]uses['\"][[:space:]]*:" "$file" ||
     grep -Eq "[,{][[:space:]]*['\"]uses['\"][[:space:]]*:" "$file"; then
    fail "$file" "flow-style or quoted uses keys are unsupported; use block-style unquoted uses keys so action pinning can be audited"
  fi


  if awk '
    /^[[:space:]]*(-[[:space:]]*)?["\047][^"\047]+["\047][[:space:]]*:/ { found=1 }
    /[,{][[:space:]]*["\047][^"\047]+["\047][[:space:]]*:/ { found=1 }
    /^[[:space:]]*(-[[:space:]]*)?\?[[:space:]]*($|[^[:space:]#])/ { found=1 }
    /[,{][[:space:]]*\?[[:space:]]/ { found=1 }
    /^[[:space:]]*(-[[:space:]]*)?(uses|permissions|pull_request_target|workflow_run|on|pull_request|paths|paths-ignore|branches|branches-ignore|types)[[:space:]]+:/ { found=1 }
    /[,{][[:space:]]*(uses|permissions|pull_request_target|workflow_run|on|pull_request|paths|paths-ignore|branches|branches-ignore|types)[[:space:]]+:/ { found=1 }
    /^[[:space:]]*(-[[:space:]]*)?\*[[:alnum:]_-]+[[:space:]]*:/ { found=1 }
    /[,{][[:space:]]*\*[[:alnum:]_-]+[[:space:]]*:/ { found=1 }
    /^[[:space:]]*(-[[:space:]]*)?(&[^[:space:]]+|![^[:space:]]+)[[:space:]]+[^:]+:/ { found=1 }
    /[,{][[:space:]]*(&[^[:space:]]+|![^[:space:]]+)[[:space:]]+[^:]+:/ { found=1 }
    END { exit !found }
  ' "$file"; then
    fail "$file" "quoted, explicit, padded, tagged, anchored, or alias mapping keys are unsupported; use plain block-style keys so workflow security policy can be audited"
  fi

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    action_count=$((action_count + 1))
    case "$ref" in
      ./*)
        fail "$file" "local action reference is not allowed until composite action manifests are recursively audited: $ref"
        ;;
      *)
        if [[ ! "$ref" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*@[0-9a-f]{40}$ ]]; then
          fail "$file" "external action is not pinned to a full 40-character SHA: $ref"
        fi
        ;;
    esac
  done < <(sed -nE 's/^[[:space:]]*-[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\1/p; s/^[[:space:]]*uses:[[:space:]]*([^[:space:]#]+).*/\1/p' "$file")
done

if [[ $errors -ne 0 ]]; then
  printf 'Workflow security policy FAILED: %d workflows, %d action references, %d violations.\n' "$workflow_count" "$action_count" "$errors" >&2
  exit 1
fi

printf 'Workflow security policy PASSED: %d workflows, %d action references; all use contents: read, no job-level overrides, all external actions SHA-pinned, no pull_request_target/workflow_run triggers.\n' "$workflow_count" "$action_count"
