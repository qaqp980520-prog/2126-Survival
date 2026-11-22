#!/usr/bin/env bash
set -euo pipefail

validator=".github/scripts/validate-workflow-security.sh"
if [[ ! -f "$validator" ]]; then
  echo "ERROR: validator file is missing: $validator" >&2
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
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9
      - uses: ./.github/actions/local'
bash "$validator" "$tmpdir/good" >/dev/null

expect_rejected() {
  local name="$1"
  if bash "$validator" "$tmpdir/$name" >/dev/null 2>&1; then
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

mkdir -p "$tmpdir/trigger_coverage"
cat > "$tmpdir/trigger_coverage/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF
bash "$validator" "$tmpdir/trigger_coverage" >/dev/null

mkdir -p "$tmpdir/trigger_missing"
cat > "$tmpdir/trigger_missing/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_push_only"
cat > "$tmpdir/trigger_push_only/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  push:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
  pull_request:
    paths:
      - 'systems/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_comment_only"
cat > "$tmpdir/trigger_comment_only/godot-validation.yml" <<'EOF'
name: root gate
# .github/workflows/**
# .github/scripts/**
permissions:
  contents: read
on:
  pull_request:
    paths:
      - 'systems/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_paths_ignore"
cat > "$tmpdir/trigger_paths_ignore/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths-ignore:
      - '.github/workflows/**'
      - '.github/scripts/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

for fixture in missing_permissions nested_permissions floating_action dangerous_trigger extra_permission trigger_missing trigger_push_only trigger_comment_only trigger_paths_ignore; do
  expect_rejected "$fixture"
done

printf 'Workflow security guard self-tests passed: 2 positive and 9 negative fixtures.\n'
