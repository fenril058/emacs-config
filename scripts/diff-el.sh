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

# SOH (\x01) as field separator: bash IFS treats tab/space as whitespace and
# collapses consecutive separators, swallowing empty fields (e.g. absent URLs).
FS=$'\x01'

command -v jq >/dev/null 2>&1 || { printf 'Error: jq is required\n' >&2; exit 1; }

# Prefer gh api for GitHub (handles auth automatically); fall back to plain curl.
USE_GH_API=false
command -v gh >/dev/null 2>&1 && USE_GH_API=true

# Wrap a command in `timeout` when available so a dead host can't hang forever.
TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout"
run_to() {
  if [[ -n "$TIMEOUT_BIN" ]]; then "$TIMEOUT_BIN" "$@"; else shift; "$@"; fi
}

OLD_LOCK=$(git show "${BASE}:${LOCK}")
NEW_LOCK=$(cat "${LOCK}")

# Find packages with changed revisions.
# Output fields (SOH-separated):
#   name, new_type, new_owner, new_repo, new_url,
#   old_rev, new_rev, old_type, old_owner, old_repo, old_url, new_ref
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
    $l.rev,
    ($o.type  // "unknown"),
    ($o.owner // ""),
    ($o.repo  // ""),
    ($o.url   // ""),
    ($l.ref   // "")] |
   join("")') || true

if [[ -z "${CHANGED// }" ]]; then
  printf "No package revision changes vs %s.\n" "$BASE"
  exit 0
fi

# Returns true when the source repository changed between old and new lock.
source_changed() {
  local type="$1" owner="$2" repo="$3" url="$4"
  local old_type="$5" old_owner="$6" old_repo="$7" old_url="$8"
  [[ "$old_type" != "$type" ]] && return 0
  case "$type" in
    github|gitlab) [[ "$old_owner" != "$owner" || "$old_repo" != "$repo" ]] ;;
    *)             [[ "$old_url"   != "$url"   ]] ;;
  esac
}

# Fetch the .el diff for a generic git host (no compare API) into response.patch.
# Tries a shallow single-branch fetch first, deepening until both revs are
# present; only falls back to a full bare clone if that fails. This avoids
# cloning entire multi-decade histories (e.g. Maxima on SourceForge) just to
# diff a handful of files. Runs in the background, so it must not rely on `exit`.
clone_generic() {
  local url="$1" old_rev="$2" new_rev="$3" ref="$4" pkgdir="$5"
  local dir="${pkgdir}/clone"
  if [[ "$url" != https://* ]]; then
    printf 'unsupported' > "${pkgdir}/error"; return 0
  fi
  local have_both=false
  if [[ -n "$ref" ]] && git init --bare --quiet "$dir" 2>/dev/null \
     && run_to 300 git -C "$dir" fetch --quiet --depth=16 --no-tags "$url" "$ref" 2>/dev/null; then
    local i=0
    while ! { git -C "$dir" cat-file -e "${old_rev}^{commit}" 2>/dev/null \
              && git -C "$dir" cat-file -e "${new_rev}^{commit}" 2>/dev/null; }; do
      (( i++ >= 6 )) && break
      run_to 300 git -C "$dir" fetch --quiet --deepen=128 --no-tags "$url" "$ref" 2>/dev/null || break
    done
    if git -C "$dir" cat-file -e "${old_rev}^{commit}" 2>/dev/null \
       && git -C "$dir" cat-file -e "${new_rev}^{commit}" 2>/dev/null; then
      have_both=true
    fi
  fi
  if ! $have_both; then
    rm -rf "$dir"
    if ! run_to 600 git clone --bare --quiet "$url" "$dir" 2>/dev/null; then
      printf 'clone-error' > "${pkgdir}/error"; return 0
    fi
  fi
  git -C "$dir" diff "$old_rev" "$new_rev" -- '*.el' \
    > "${pkgdir}/response.patch" 2>/dev/null || true
}

declare -A PIDS=()

# Launch every fetch (compare-API requests and generic shallow clones) in
# parallel. The method per package is recorded so the output phase knows how to
# render the result.
while IFS="$FS" read -r name type owner repo url old_rev new_rev \
                        old_type old_owner old_repo old_url new_ref; do
  [[ -z "$name" ]] && continue
  pkgdir="${WORK}/${name}"
  mkdir -p "$pkgdir"

  if source_changed "$type" "$owner" "$repo" "$url" \
                    "$old_type" "$old_owner" "$old_repo" "$old_url"; then
    printf '%s/%s\x01%s/%s' \
      "${old_owner:-${old_url}}" "${old_repo}" \
      "${owner:-${url}}" "${repo}" > "${pkgdir}/source-changed"
    continue
  fi

  # Resolve the fetch method. Self-hosted GitLab (a URL whose host contains
  # "gitlab", e.g. gitlab.kitware.com) uses the same compare API as gitlab.com,
  # which avoids cloning huge repos like the entire CMake tree.
  method="$type"
  gl_host="" gl_project=""
  case "$type" in
    github) method="github" ;;
    gitlab) method="gitlab"; gl_host="gitlab.com"; gl_project="${owner}/${repo}" ;;
    *)
      host="${url#*://}"; host="${host%%/*}"
      path="${url#*://*/}"; path="${path%.git}"
      if [[ "$host" == *gitlab* && "$path" == */* ]]; then
        method="gitlab"; gl_host="$host"; gl_project="$path"
      else
        method="generic"
      fi
      ;;
  esac
  printf '%s' "$method" > "${pkgdir}/method"

  case "$method" in
    github)
      if $USE_GH_API; then
        gh api "repos/${owner}/${repo}/compare/${old_rev}...${new_rev}" \
          > "${pkgdir}/response.json" 2>/dev/null &
      else
        curl -sf --connect-timeout 10 --max-time 120 \
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
        "$gl_project" 2>/dev/null \
        || printf '%s' "${gl_project//\//%2F}")
      curl -sf --connect-timeout 10 --max-time 120 \
        -H "User-Agent: diff-el/0.1" \
        "https://${gl_host}/api/v4/projects/${project}/repository/compare?from=${old_rev}&to=${new_rev}" \
        -o "${pkgdir}/response.json" &
      PIDS["$name"]=$!
      ;;
    generic)
      clone_generic "$url" "$old_rev" "$new_rev" "$new_ref" "$pkgdir" &
      PIDS["$name"]=$!
      ;;
  esac
done <<< "$CHANGED"

# Wait for all fetches.
for name in "${!PIDS[@]}"; do
  wait "${PIDS[$name]}" 2>/dev/null || true
done

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

while IFS="$FS" read -r name type owner repo url old_rev new_rev \
                        old_type old_owner old_repo old_url new_ref; do
  [[ -z "$name" ]] && continue
  s_old="${old_rev:0:9}"
  s_new="${new_rev:0:9}"
  printf "\n## %s  (%s → %s)\n" "$name" "$s_old" "$s_new"

  pkgdir="${WORK}/${name}"

  if [[ -f "${pkgdir}/source-changed" ]]; then
    IFS=$'\x01' read -r from to < "${pkgdir}/source-changed"
    printf "  [source changed: %s → %s]\n" "$from" "$to"
    continue
  fi

  if [[ -f "${pkgdir}/error" ]]; then
    err=$(cat "${pkgdir}/error")
    case "$err" in
      clone-error) printf "  [error: git clone failed]\n" ;;
      unsupported) printf "  [skipped: unsupported type %s]\n" "$type" ;;
      *)           printf "  [error: %s]\n" "$err" ;;
    esac
    continue
  fi

  method=$(cat "${pkgdir}/method" 2>/dev/null || printf '%s' "$type")
  patches=""
  case "$method" in
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
