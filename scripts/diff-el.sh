#!/usr/bin/env bash
# diff-el.sh — Show .el file diffs for packages whose pinned revisions changed.
# Usage: bash scripts/diff-el.sh [BASE [FORMAT]]
#   BASE   defaults to HEAD.
#   FORMAT defaults to "md" (Markdown with ```diff fences).
#          Pass "raw" to emit bare unified diffs (pipe through bat --language=diff).
#
# GitHub/GitLab: fetched in parallel via the compare API (no local clone needed).
# Other git hosts: bare-cloned sequentially into a temp directory.

set -euo pipefail

BASE="${1:-HEAD}"
FORMAT="${2:-md}"
LOCK="lock/flake.lock"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

command -v jq >/dev/null 2>&1 || { printf 'Error: jq is required\n' >&2; exit 1; }

# Prefer gh api for GitHub (handles auth automatically); fall back to plain curl.
USE_GH_API=false
command -v gh >/dev/null 2>&1 && USE_GH_API=true

OLD_LOCK=$(git show "${BASE}:${LOCK}")
NEW_LOCK=$(cat "${LOCK}")

# Find packages with changed revisions; emit one TSV row per package.
CHANGED=$(jq -rn \
  --argjson old "$OLD_LOCK" \
  --argjson new "$NEW_LOCK" \
  '($old.nodes
    | to_entries
    | map(select(.value.locked != null))
    | map({key: .key, value: .value.locked})
    | from_entries) as $old_map |
   $new.nodes | to_entries[] |
   select(.value.locked != null) |
   .value.locked as $l |
   $old_map[.key] as $o |
   select(
     $o != null and
     ($l.rev // null) != null and
     ($o.rev // null) != null and
     $l.rev != $o.rev) |
   [.key,
    ($l.type  // "unknown"),
    ($l.owner // ""),
    ($l.repo  // ""),
    ($l.url   // ""),
    $o.rev,
    $l.rev] |
   @tsv') || true

if [[ -z "${CHANGED// }" ]]; then
  printf "No package revision changes vs %s.\n" "$BASE"
  exit 0
fi

declare -A PIDS=()

# Launch HTTP requests in parallel.
while IFS=$'\t' read -r name type owner repo url old_rev new_rev; do
  [[ -z "$name" ]] && continue
  pkgdir="${WORK}/${name}"
  mkdir -p "$pkgdir"

  case "$type" in
    github)
      if $USE_GH_API; then
        gh api "repos/${owner}/${repo}/compare/${old_rev}...${new_rev}" \
          > "${pkgdir}/response.json" 2>/dev/null &
      else
        curl -sf \
          -H "Accept: application/vnd.github.v3+json" \
          -H "User-Agent: diff-el/0.1" \
          "https://api.github.com/repos/${owner}/${repo}/compare/${old_rev}...${new_rev}" \
          -o "${pkgdir}/response.json" &
      fi
      PIDS["$name"]=$!
      ;;
    gitlab)
      project=$(python3 -c \
        "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1],safe=''))" \
        "${owner}/${repo}" 2>/dev/null \
        || printf '%s%%2F%s' "$owner" "$repo")
      curl -sf \
        -H "User-Agent: diff-el/0.1" \
        "https://gitlab.com/api/v4/projects/${project}/repository/compare?from=${old_rev}&to=${new_rev}" \
        -o "${pkgdir}/response.json" &
      PIDS["$name"]=$!
      ;;
  esac
done <<< "$CHANGED"

# Wait for all HTTP requests.
for name in "${!PIDS[@]}"; do
  wait "${PIDS[$name]}" 2>/dev/null || true
done

# Git-clone fallback for non-GitHub/GitLab hosts (rare; sequential).
while IFS=$'\t' read -r name type owner repo url old_rev new_rev; do
  [[ -z "$name" ]] && continue
  [[ "$type" == "github" || "$type" == "gitlab" ]] && continue
  pkgdir="${WORK}/${name}"
  mkdir -p "$pkgdir"
  if [[ "$url" == https://* ]]; then
    clonedir="${pkgdir}/clone"
    if git clone --bare --quiet "$url" "$clonedir" 2>/dev/null; then
      git -C "$clonedir" diff "${old_rev}" "${new_rev}" -- '*.el' \
        > "${pkgdir}/response.patch" 2>/dev/null || true
    else
      printf 'clone-error' > "${pkgdir}/error"
    fi
  else
    printf 'unsupported' > "${pkgdir}/error"
  fi
done <<< "$CHANGED"

# Choose jq templates based on FORMAT.
if [[ "$FORMAT" == "raw" ]]; then
  gh_tmpl='.files[] | select(.filename | endswith(".el")) | "### \(.filename)\n\(.patch // "")\n"'
  gl_tmpl='.diffs[] | select(.new_path | endswith(".el")) | "### \(.new_path)\n\(.diff // "")\n"'
else
  gh_tmpl='.files[] | select(.filename | endswith(".el")) | "### \(.filename)\n```diff\n\(.patch // "")\n```\n"'
  gl_tmpl='.diffs[] | select(.new_path | endswith(".el")) | "### \(.new_path)\n```diff\n\(.diff // "")\n```\n"'
fi

# Emit output in original lock-file order.
N=$(echo "$CHANGED" | wc -l | tr -d ' ')
printf "# .el diffs — %d packages changed vs %s\n" "$N" "$BASE"

while IFS=$'\t' read -r name type owner repo url old_rev new_rev; do
  [[ -z "$name" ]] && continue
  s_old="${old_rev:0:9}"
  s_new="${new_rev:0:9}"
  printf "\n## %s  (%s → %s)\n" "$name" "$s_old" "$s_new"

  pkgdir="${WORK}/${name}"

  if [[ -f "${pkgdir}/error" ]]; then
    err=$(cat "${pkgdir}/error")
    case "$err" in
      clone-error) printf "  [error: git clone failed]\n" ;;
      unsupported) printf "  [skipped: unsupported type %s]\n" "$type" ;;
      *)           printf "  [error: %s]\n" "$err" ;;
    esac
    continue
  fi

  patches=""
  case "$type" in
    github)
      if [[ ! -f "${pkgdir}/response.json" ]]; then
        printf "  [error: request failed (rate-limited?)]\n"; continue
      fi
      if ! jq -e '.files' "${pkgdir}/response.json" >/dev/null 2>&1; then
        msg=$(jq -r '.message // "unknown error"' "${pkgdir}/response.json" 2>/dev/null || true)
        printf "  [error: %s]\n" "${msg:-invalid response}"; continue
      fi
      patches=$(jq -r "$gh_tmpl" "${pkgdir}/response.json" 2>/dev/null || true)
      ;;
    gitlab)
      if [[ ! -f "${pkgdir}/response.json" ]]; then
        printf "  [error: request failed]\n"; continue
      fi
      patches=$(jq -r "$gl_tmpl" "${pkgdir}/response.json" 2>/dev/null || true)
      ;;
    *)
      if [[ -f "${pkgdir}/response.patch" ]]; then
        content=$(cat "${pkgdir}/response.patch")
        if [[ -n "$content" ]]; then
          if [[ "$FORMAT" == "raw" ]]; then
            patches=$(printf "### (all .el)\n%s\n" "$content")
          else
            patches=$(printf "### (all .el)\n\`\`\`diff\n%s\n\`\`\`\n" "$content")
          fi
        fi
      fi
      ;;
  esac

  if [[ -z "$patches" ]]; then
    printf "  (no .el file changes)\n"
  else
    printf "%s\n" "$patches"
  fi
done <<< "$CHANGED"
