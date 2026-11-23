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
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9'
bash "$validator" "$tmpdir/good" >/dev/null
positive_count=1
negative_count=0

write_fixture_from_stdin() {
  local name="$1"
  mkdir -p "$tmpdir/$name"
  cat > "$tmpdir/$name/workflow.yml"
}

expect_rejected() {
  local name="$1"
  if bash "$validator" "$tmpdir/$name" >/dev/null 2>&1; then
    echo "ERROR: security guard accepted invalid fixture: $name" >&2
    exit 1
  fi
  negative_count=$((negative_count + 1))
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
write_fixture local_action 'name: local action
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: ./.github/actions/unreviewed'
write_fixture flow_style_action 'name: flow style
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - { name: Checkout, uses: actions/checkout@v4 }'
write_fixture_from_stdin quoted_uses_action <<'EOF'
name: quoted uses
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - 'uses': actions/checkout@v4
EOF

write_fixture_from_stdin escaped_quoted_uses_action <<'EOF'
name: escaped quoted uses
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - "\u0075ses": actions/checkout@v4
EOF

write_fixture_from_stdin quoted_permissions_action <<'EOF'
name: quoted duplicate permissions
permissions:
  contents: read
"permissions": write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin spaced_uses_action <<'EOF'
name: whitespace before uses colon
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses : actions/checkout@v4
EOF

write_fixture_from_stdin spaced_permissions_action <<'EOF'
name: whitespace before permissions colon
permissions:
  contents: read
permissions : write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin explicit_uses_action <<'EOF'
name: explicit uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - ? uses
        : actions/checkout@v4
EOF

write_fixture_from_stdin tagged_uses_action <<'EOF'
name: tagged uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - !!str uses: actions/checkout@v4
EOF

write_fixture_from_stdin anchored_uses_action <<'EOF'
name: anchored uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - &uses_key uses: actions/checkout@v4
EOF

write_fixture_from_stdin alias_uses_action <<'EOF'
name: aliased uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses_key: &u uses
      - *u: actions/checkout@v4
EOF

write_fixture_from_stdin flow_spaced_uses_action <<'EOF'
name: flow style spaced uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - { uses : actions/checkout@v4 }
EOF

write_fixture_from_stdin flow_escaped_uses_action <<'EOF'
name: flow style escaped uses key
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - { "\u0075ses": actions/checkout@v4 }
EOF

write_fixture_from_stdin spaced_pull_request_target_action <<'EOF'
name: whitespace before dangerous trigger colon
permissions:
  contents: read
on:
  pull_request:
  pull_request_target : 
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin spaced_workflow_run_action <<'EOF'
name: whitespace before workflow_run colon
permissions:
  contents: read
on:
  pull_request:
  workflow_run : 
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin alias_permissions_action <<'EOF'
name: aliased permissions key
permissions:
  contents: read
permissions_key: &p permissions
*p: write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin explicit_permissions_action <<'EOF'
name: explicit permissions key
permissions:
  contents: read
? permissions
: write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin tagged_permissions_action <<'EOF'
name: tagged permissions key
permissions:
  contents: read
!!str permissions: write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin anchored_permissions_action <<'EOF'
name: anchored permissions key
permissions:
  contents: read
&permissions_key permissions: write-all
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF


write_fixture_from_stdin flow_on_pull_request_target_action <<'EOF'
name: flow on pull request target
permissions:
  contents: read
on: { pull_request_target: {} }
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin block_flow_pull_request_target_action <<'EOF'
name: block flow pull request target
permissions:
  contents: read
on:
  pull_request_target: {}
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin flow_on_workflow_run_action <<'EOF'
name: flow on workflow run
permissions:
  contents: read
on: { workflow_run: {} }
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

write_fixture_from_stdin flow_permissions_duplicate_action <<'EOF'
name: flow duplicate permissions
permissions:
  contents: read
permissions: { contents: read, issues: write }
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

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
  push:
    branches: [main]
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - 'systems/**'
      - 'scripts/**'
      - 'world/**'
      - 'tests/**'
      - 'daily_games/**'
      - 'prototypes/**'
      - 'assets/**'
      - 'project.godot'
      - '.gitignore'
      - 'README.md'
      - 'PROJECT_INDEX.md'
      - 'docs/**'
      - '**/README.md'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - name: Prepare candidate files from pinned commits
        run: |
          fetch_pinned_candidate() {
            local branch="$1"
            local expected_sha="$2"
            git fetch --no-tags origin "$branch"
            FETCHED_CANDIDATE_SHA="$(git rev-parse FETCH_HEAD)"
            if [[ "$FETCHED_CANDIDATE_SHA" != "$expected_sha" ]]; then
              exit 1
            fi
          }
          fetch_pinned_candidate "feature/daily-kroll-signal-sweep-2026-10-25" "e0953f6bcc58e764f172d85b96e2b66d73bdb859"
          git checkout "$FETCHED_CANDIDATE_SHA" -- daily_games/KROLL_Signal_Sweep
          fetch_pinned_candidate "fix/inventory-save-validation-2026-10-25" "2d39e18e8b90d9b90cd8a65ebfb6b76d375ae5cb"
          git checkout "$FETCHED_CANDIDATE_SHA" -- systems/SurvivalInventory.gd tests/inventory_save_validation.gd
          fetch_pinned_candidate "feature/m1-3-inventory-save-adapter-2026-10-25" "300d4cc826fc02423e365c8199460de9afa5ceb5"
          git checkout "$FETCHED_CANDIDATE_SHA" -- systems/SurvivalInventorySaveAdapter.gd tests/inventory_save_adapter.gd
          fetch_pinned_candidate "feature/kroll-orbital-convoy-backrooms-portals-2026-10-26" "c9833cafa00f6865c34752449cfe09ed17f04d65"
          git checkout "$FETCHED_CANDIDATE_SHA" -- daily_games/KROLL_Orbital_Convoy systems/BackroomsPortalDirector.gd tests/backrooms_portal_director_test.gd tests/backrooms_portal_scene_test.gd systems/BackroomsPortalVisual.gd systems/BackroomsPortalVisual.tscn docs/BACKROOMS_RANDOM_PORTAL_DIRECTOR_M0_1.md
EOF
bash "$validator" "$tmpdir/trigger_coverage" >/dev/null
positive_count=$((positive_count + 1))

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

mkdir -p "$tmpdir/trigger_missing_actions"
cat > "$tmpdir/trigger_missing_actions/godot-validation.yml" <<'EOF'
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


write_fixture scalar_workflow_run_event 'name: scalar workflow_run event
permissions:
  contents: read
on: workflow_run
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture scalar_pull_request_target_event 'name: scalar pull_request_target event
permissions:
  contents: read
on: pull_request_target
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture flow_sequence_workflow_run_event 'name: flow sequence workflow_run event
permissions:
  contents: read
on: [push, workflow_run]
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture flow_sequence_pull_request_target_event 'name: flow sequence pull_request_target event
permissions:
  contents: read
on: [pull_request_target]
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture block_sequence_workflow_run_event 'name: block sequence workflow_run event
permissions:
  contents: read
on:
  - workflow_run
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture block_sequence_pull_request_target_event 'name: block sequence pull_request_target event
permissions:
  contents: read
on:
  - pull_request_target
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture nonempty_pull_request_target_value 'name: nonempty pull_request_target value
permissions:
  contents: read
on:
  pull_request_target: [opened]
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture nonempty_workflow_run_value 'name: nonempty workflow_run value
permissions:
  contents: read
on:
  workflow_run: [completed]
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'

write_fixture duplicate_on_mapping 'name: duplicate on mapping
permissions:
  contents: read
on:
  pull_request:
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
on:
  push:
'

mkdir -p "$tmpdir/trigger_duplicate_pull_request"
cat > "$tmpdir/trigger_duplicate_pull_request/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
  pull_request:
    branches:
      - main
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_duplicate_paths"
cat > "$tmpdir/trigger_duplicate_paths/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
    paths:
      - 'systems/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_negative_all_paths"
cat > "$tmpdir/trigger_negative_all_paths/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - '!**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_negative_workflow_path"
cat > "$tmpdir/trigger_negative_workflow_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - '!.github/workflows/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_escaped_negative_workflow_path"
cat > "$tmpdir/trigger_escaped_negative_workflow_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - "\u0021.github/workflows/**"
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_anchored_negative_path"
cat > "$tmpdir/trigger_anchored_negative_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - &exclude_workflow_changes '!**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_aliased_negative_path"
cat > "$tmpdir/trigger_aliased_negative_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
env:
  excluded_path: &exclude_workflow_changes '!**'
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - *exclude_workflow_changes
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_tagged_negative_path"
cat > "$tmpdir/trigger_tagged_negative_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - !!str '!**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_block_scalar_negative_path"
cat > "$tmpdir/trigger_block_scalar_negative_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - >-
        !**
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_continued_escaped_negative_path"
cat > "$tmpdir/trigger_continued_escaped_negative_path/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
      - "\
        \u0021**"
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_branches_filter"
cat > "$tmpdir/trigger_pull_request_branches_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    branches: [main]
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_branches_ignore_filter"
cat > "$tmpdir/trigger_pull_request_branches_ignore_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    branches-ignore:
      - 'integration/**'
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_types_filter"
cat > "$tmpdir/trigger_pull_request_types_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    types: [opened]
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_paths_ignore_filter"
cat > "$tmpdir/trigger_pull_request_paths_ignore_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
    paths-ignore:
      - 'docs/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_merge_key_branch_filter"
cat > "$tmpdir/trigger_pull_request_merge_key_branch_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  push: &pr_config
    branches: [main]
  pull_request:
    <<: *pr_config
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

mkdir -p "$tmpdir/trigger_pull_request_padded_branches_filter"
cat > "$tmpdir/trigger_pull_request_padded_branches_filter/godot-validation.yml" <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    branches : [main]
    paths:
      - '.github/workflows/**'
      - '.github/scripts/**'
      - '.github/actions/**'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF

required_trigger_paths=(
  ".github/workflows/**"
  ".github/scripts/**"
  ".github/actions/**"
  "systems/**"
  "scripts/**"
  "world/**"
  "tests/**"
  "daily_games/**"
  "prototypes/**"
  "assets/**"
  "project.godot"
  ".gitignore"
  "README.md"
  "PROJECT_INDEX.md"
  "docs/**"
)
missing_path_index=0
for omitted_path in "${required_trigger_paths[@]}"; do
  missing_path_index=$((missing_path_index + 1))
  fixture_name="trigger_missing_required_path_${missing_path_index}"
  mkdir -p "$tmpdir/$fixture_name"
  {
    cat <<'EOF'
name: root gate
permissions:
  contents: read
on:
  pull_request:
    paths:
EOF
    for path in "${required_trigger_paths[@]}"; do
      if [[ "$path" == "$omitted_path" ]]; then
        continue
      fi
      printf "      - '%s'\n" "$path"
    done
    cat <<'EOF'
jobs:
  test:
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
EOF
  } > "$tmpdir/$fixture_name/godot-validation.yml"
  expect_rejected "$fixture_name"
done


mkdir -p "$tmpdir/candidate_fetch_pinned"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_pinned/godot-validation.yml"
bash "$validator" "$tmpdir/candidate_fetch_pinned" >/dev/null
positive_count=$((positive_count + 1))

mkdir -p "$tmpdir/candidate_fetch_unpinned"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_unpinned/godot-validation.yml"
sed -i 's|fetch_pinned_candidate "feature/daily-kroll-signal-sweep-2026-10-25" "e0953f6bcc58e764f172d85b96e2b66d73bdb859"|git fetch origin feature/daily-kroll-signal-sweep-2026-10-25|' "$tmpdir/candidate_fetch_unpinned/godot-validation.yml"

mkdir -p "$tmpdir/candidate_fetch_sha_mismatch"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_sha_mismatch/godot-validation.yml"
sed -i 's|e0953f6bcc58e764f172d85b96e2b66d73bdb859|0000000000000000000000000000000000000000|' "$tmpdir/candidate_fetch_sha_mismatch/godot-validation.yml"

mkdir -p "$tmpdir/candidate_fetch_missing_pin"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_missing_pin/godot-validation.yml"
sed -i '/fetch_pinned_candidate "feature\/daily-kroll-signal-sweep-2026-10-25"/d' "$tmpdir/candidate_fetch_missing_pin/godot-validation.yml"


mkdir -p "$tmpdir/candidate_fetch_commented_compare"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_commented_compare/godot-validation.yml"
sed -i 's|if \[\[ "$FETCHED_CANDIDATE_SHA" != "$expected_sha" \]\]; then|if false; then # if [[ "$FETCHED_CANDIDATE_SHA" != "$expected_sha" ]]; then|' "$tmpdir/candidate_fetch_commented_compare/godot-validation.yml"

mkdir -p "$tmpdir/candidate_fetch_pin_comment_decoy"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_pin_comment_decoy/godot-validation.yml"
sed -i 's|fetch_pinned_candidate "feature/daily-kroll-signal-sweep-2026-10-25" "e0953f6bcc58e764f172d85b96e2b66d73bdb859"|fetch_pinned_candidate "feature/daily-kroll-signal-sweep-2026-10-25" "0000000000000000000000000000000000000000"|' "$tmpdir/candidate_fetch_pin_comment_decoy/godot-validation.yml"
sed -i '/fetch_pinned_candidate "feature\/daily-kroll-signal-sweep-2026-10-25" "0000000000000000000000000000000000000000"/a\            # fetch_pinned_candidate "feature/daily-kroll-signal-sweep-2026-10-25" "e0953f6bcc58e764f172d85b96e2b66d73bdb859"' "$tmpdir/candidate_fetch_pin_comment_decoy/godot-validation.yml"

mkdir -p "$tmpdir/candidate_fetch_duplicate_helper"
cp .github/workflows/godot-validation.yml "$tmpdir/candidate_fetch_duplicate_helper/godot-validation.yml"
awk '
  { print }
  $0 == "          }" && !inserted {
    print "          fetch_pinned_candidate() {"
    print "            local branch=\"$1\""
    print "            local expected_sha=\"$2\""
    print "            FETCHED_CANDIDATE_SHA=\"$expected_sha\""
    print "          }"
    inserted=1
  }
  END { if (!inserted) exit 1 }
' "$tmpdir/candidate_fetch_duplicate_helper/godot-validation.yml" > "$tmpdir/candidate_fetch_duplicate_helper/workflow.tmp"
mv "$tmpdir/candidate_fetch_duplicate_helper/workflow.tmp" "$tmpdir/candidate_fetch_duplicate_helper/godot-validation.yml"

for fixture in candidate_fetch_unpinned candidate_fetch_sha_mismatch candidate_fetch_missing_pin candidate_fetch_commented_compare candidate_fetch_pin_comment_decoy candidate_fetch_duplicate_helper missing_permissions nested_permissions floating_action dangerous_trigger local_action flow_style_action quoted_uses_action escaped_quoted_uses_action quoted_permissions_action spaced_uses_action spaced_permissions_action explicit_uses_action tagged_uses_action anchored_uses_action alias_uses_action flow_spaced_uses_action flow_escaped_uses_action spaced_pull_request_target_action spaced_workflow_run_action alias_permissions_action explicit_permissions_action tagged_permissions_action anchored_permissions_action flow_on_pull_request_target_action block_flow_pull_request_target_action flow_on_workflow_run_action flow_permissions_duplicate_action extra_permission trigger_missing trigger_missing_actions trigger_push_only trigger_comment_only trigger_paths_ignore trigger_duplicate_pull_request trigger_duplicate_paths trigger_negative_all_paths trigger_negative_workflow_path trigger_escaped_negative_workflow_path trigger_anchored_negative_path trigger_aliased_negative_path trigger_tagged_negative_path trigger_block_scalar_negative_path trigger_continued_escaped_negative_path trigger_pull_request_branches_filter trigger_pull_request_branches_ignore_filter trigger_pull_request_types_filter trigger_pull_request_paths_ignore_filter trigger_pull_request_merge_key_branch_filter trigger_pull_request_padded_branches_filter scalar_workflow_run_event scalar_pull_request_target_event flow_sequence_workflow_run_event flow_sequence_pull_request_target_event block_sequence_workflow_run_event block_sequence_pull_request_target_event nonempty_pull_request_target_value nonempty_workflow_run_value duplicate_on_mapping; do
  expect_rejected "$fixture"
done

printf 'Workflow security guard self-tests passed: %d positive and %d negative fixtures.\n' "$positive_count" "$negative_count"
