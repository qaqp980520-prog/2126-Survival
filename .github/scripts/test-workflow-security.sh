#!/usr/bin/env bash
set -euo pipefail

validator=".github/scripts/validate-workflow-security.sh"
if [[ ! -x "$validator" ]]; then
  echo "ERROR: validator is missing or not executable: $validator" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

write_fixture() {
  local name="$1"
  local body="$2"
  mkdir -p "$tmpdir/$name"
  printf '%s\n' "$body" > "$tmpdir/$name/workflow.yml"
}

write_fixture good 'name: good
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
      - uses: ./.github/actions/local'
"$validator" "$tmpdir/good" >/dev/null

expect_rejected() {
  local name="$1"
  if "$validator" "$tmpdir/$name" >/dev/null 2>&1; then
    echo "ERROR: security guard accepted invalid fixture: $name" >&2
    exit 1
  fi
}

write_fixture missing_permissions 'name: missing
on:
  pull_request:
jobs:
  test:
    steps:
      - run: echo ok'
write_fixture nested_permissions 'name: nested
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    permissions:
      contents: write
    steps:
      - run: echo ok'
write_fixture floating_action 'name: floating
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@v4'
write_fixture dangerous_trigger 'name: dangerous
permissions:
  contents: read
on:
  pull_request_target:
jobs:
  test:
    steps:
      - run: echo ok'
write_fixture extra_permission 'name: extra
permissions:
  contents: read
  issues: write
on:
  pull_request:
jobs:
  test:
    steps:
      - run: echo ok'

for fixture in missing_permissions nested_permissions floating_action dangerous_trigger extra_permission; do
  expect_rejected "$fixture"
done

printf 'Workflow security guard self-tests passed: 1 positive and 5 negative fixtures.\n'
