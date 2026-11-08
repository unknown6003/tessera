#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
research_dir=${1:-$script_dir}
issue_page=${2:-1}
run_id=${3:-github-followup-2026-08-31}
output_suffix=${4:-followup}
api_root=https://api.github.com
user_agent=Tessera-Disk-Rescue-Research
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/tessera-github-followup.XXXXXX")
trap 'rm -rf -- "$tmp_dir"' EXIT

declare -a repos=(
  game:Lutris/lutris
  game:ValveSoftware/Proton
  game:PrismLauncher/PrismLauncher
  package:python-poetry/poetry
  package:pypa/pip
  package:microsoft/vcpkg
  profile:signalapp/Signal-Desktop
  profile:element-hq/element-desktop
  profile:mattermost/desktop
  communication:telegramdesktop/tdesktop
  communication:jitsi/jitsi-meet-electron
)

mapfile -t current_files < <(
  rg --files "$research_dir" |
    rg 'tessera-disk-rescue-(.+-ledger|market-scan)\.jsonl$' |
    sort
)

if ((${#current_files[@]} == 0)); then
  printf 'No existing corpus files found in %s\n' "$research_dir" >&2
  exit 1
fi

current_urls="$tmp_dir/current-urls.json"
jq -r '.url' "${current_files[@]}" |
  jq -R -s 'split("\n") | map(select(length > 0))' >"$current_urls"

keyword_re='storage|cache|disk|profile|save|cloud|offline|data|space|restore|backup|delete|move|library|volume|path|state|attachment|message|draft|session|credential|password|encryption|workspace|mod|prefix|install|uninstall|reclaim|download|upload|sync|database|local|persistent'

fetch_repo() {
  local lane=$1
  local repo=$2
  local safe_repo=${repo//\//-}
  local raw_response="$tmp_dir/${lane}-${safe_repo}-raw.json"
  local response="$tmp_dir/${lane}-${safe_repo}.json"
  local url="$api_root/repos/$repo/issues?state=all&sort=updated&direction=desc&per_page=100&page=$issue_page"
  local api_path="repos/$repo/issues?state=all&sort=updated&direction=desc&per_page=100&page=$issue_page"

  if command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1; then
    if ! GH_PAGER=cat gh api --hostname github.com \
      -H "Accept: application/vnd.github+json" \
      "$api_path" >"$raw_response"; then
      printf 'Authenticated GitHub request failed: %s\n' "$repo" >&2
      return 1
    fi
  elif ! curl --fail --silent --show-error \
    --connect-timeout 10 --max-time 30 \
    -H "Accept: application/vnd.github+json" \
    -H "User-Agent: $user_agent" \
    "$url" >"$raw_response"; then
    printf 'GitHub request failed: %s\n' "$repo" >&2
    return 1
  fi

  if ! jq -e 'type == "array"' "$raw_response" >/dev/null; then
    printf 'Unexpected GitHub response: %s\n' "$repo" >&2
    return 1
  fi

  jq --arg repo "$repo" 'map(._tessera_repository = $repo)' "$raw_response" >"$response"

  printf '%s\t%s\n' "$lane" "$response"
}

fetched="$tmp_dir/fetched.tsv"
: >"$fetched"
for repo_spec in "${repos[@]}"; do
  lane=${repo_spec%%:*}
  repo=${repo_spec#*:}
  if ! fetch_repo "$lane" "$repo" >>"$fetched"; then
    exit 1
  fi
done

write_lane() {
  local lane=$1
  local prefix=$2
  local output="$research_dir/tessera-disk-rescue-${lane}-${output_suffix}-ledger.jsonl"
  local filtered="$tmp_dir/${lane}-filtered.jsonl"
  local -a files=()

  if [[ -e "$output" ]]; then
    printf 'Keeping existing output: %s\n' "$output" >&2
    return
  fi

  while IFS=$'\t' read -r file_lane file_path; do
    [[ "$file_lane" == "$lane" ]] || continue
    files+=("$file_path")
  done <"$fetched"

  if ((${#files[@]} == 0)); then
    printf 'No fetched files for lane: %s\n' "$lane" >&2
    exit 1
  fi

  jq -c --arg lane "$lane" --arg prefix "$prefix" --arg collection "$run_id" \
    --arg issue_page "$issue_page" --arg keyword_re "$keyword_re" --slurpfile current "$current_urls" '
    .[] |
    select((.pull_request? // null) == null) |
    select((.title // "") != "") |
    select((.body // "") != "") |
    select(((.title + " " + .body) | test($keyword_re; "i"))) |
    select((.html_url as $url | ($current[0] | index($url)) == null)) |
    . as $issue |
    (($issue.title + " " + $issue.body) | gsub("[[:space:]]+"; " ") | gsub("^ +| +$"; "")) as $text |
    {
      record_id: ($prefix + "-" + ($issue._tessera_repository | gsub("/"; "-")) + "-" + ($issue.number | tostring)),
      source_type: "owner_issue_report",
      source_family: $issue._tessera_repository,
      collection_id: $collection,
      collected_at: "2026-08-31",
      title: $issue.title,
      url: $issue.html_url,
      evidence_class: (if ($text | test("\\b(I|my|me|we|our|I\\x27m|I\\x27ve|I\\x27ll)\\b"; "i")) then "core" else "adjacent" end),
      source_kind: "GitHub issue tracker",
      topic_flags: (
        [
          {name: "storage", pattern: "storage|disk|space|volume"},
          {name: "cache", pattern: "cache|temporary|temp"},
          {name: "profile", pattern: "profile|session|credential|password|cookie|database"},
          {name: "save", pattern: "save|backup|restore|data-loss"},
          {name: "offline", pattern: "offline|local|download|upload|sync"},
          {name: "move", pattern: "move|relocate|path|library"},
          {name: "workspace", pattern: "workspace|project|install|uninstall"},
          {name: "delete", pattern: "delete|remove|reclaim|cleanup"}
        ] |
        map(.name as $name | .pattern as $pattern | select($text | test($pattern; "i")) | $name)
      ),
      observation: ($text[0:900]),
      product_implication: (
        if $lane == "game" then "Separate redownloadable payloads from saves, mods, registration, and live runtime state before any reclaim action."
        elif $lane == "package" then "Separate shared stores from project materializations, lock state, configured roots, and offline rebuild sources."
        elif $lane == "profile" then "Treat profiles, credentials, sessions, drafts, and workspace databases as durable owner state, not cache."
        else "Treat attachments, offline copies, drafts, sessions, and account state as separate recovery roles. Check the active writer before action."
        end
      ),
      screening_status: "automated_candidate",
      screening_method: ("issue_page_" + $issue_page + "_title_body_keyword_screen"),
      quality_note: ("Automated issue-page " + $issue_page + " title/body screen of a public owner issue tracker. This is a reported case, not a prevalence estimate; the issue may include maintainer discussion or duplicate experiences.")
    }
  ' "${files[@]}" >"$filtered"

  if [[ ! -s "$filtered" ]]; then
    printf 'No matching records for lane: %s\n' "$lane" >&2
    exit 1
  fi

  mv -- "$filtered" "$output"
  printf '%s records -> %s\n' "$(wc -l <"$output" | tr -d ' ')" "$output"
}

write_lane game GFR
write_lane package PCR
write_lane profile APR
write_lane communication CFR
