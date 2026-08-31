#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
research_dir=${1:-$script_dir}

"$script_dir/validate-tessera-disk-rescue-corpus.sh" "$research_dir" >/dev/null

mapfile -t corpus_files < <(
  rg --files "$research_dir" |
    rg 'tessera-disk-rescue-(.+-ledger|market-scan)\.jsonl$' |
    sort
)

market_scan_file="$research_dir/tessera-disk-rescue-market-scan.jsonl"
if [[ ! -f "$market_scan_file" ]]; then
  printf 'Market scan not found: %s\n' "$market_scan_file" >&2
  exit 1
fi

market_scan_records=$(wc -l <"$market_scan_file" | tr -d ' ')

jq -s \
  --argjson corpus_files "${#corpus_files[@]}" \
  --argjson market_scan_records "$market_scan_records" '
  {
    corpus_files: $corpus_files,
    records: length,
    behavior_evidence: ([.[] | select(
      .evidence_class != "system_fact" and
      .evidence_class != "owner_fact" and
      .evidence_class != "market_signal" and
      (.screening_status // "") != "automated_candidate"
    )] | length),
    automated_candidates: ([.[] | select(.screening_status == "automated_candidate")] | length),
    automated_candidate_core_labels: ([.[] | select(.screening_status == "automated_candidate" and .evidence_class == "core")] | length),
    automated_candidate_adjacent_labels: ([.[] | select(.screening_status == "automated_candidate" and .evidence_class == "adjacent")] | length),
    system_facts: ([.[] | select(.evidence_class == "system_fact")] | length),
    owner_facts: ([.[] | select(.evidence_class == "owner_fact")] | length),
    market_signals: ([.[] | select(.evidence_class == "market_signal")] | length),
    market_signals_inside_evidence_ledgers: (([.[] | select(.evidence_class == "market_signal")] | length) - $market_scan_records),
    separate_market_scan: $market_scan_records,
    evidence_and_authority_records: (length - $market_scan_records),
    records_with_ids: ([.[] | select(has("record_id"))] | length)
  }
' "${corpus_files[@]}"
