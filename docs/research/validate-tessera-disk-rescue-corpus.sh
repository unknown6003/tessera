#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
research_dir=${1:-$script_dir}

mapfile -t corpus_files < <(
  rg --files "$research_dir" |
    rg 'tessera-disk-rescue-(.+-ledger|market-scan)\.jsonl$' |
    sort
)

if ((${#corpus_files[@]} == 0)); then
  printf 'No corpus files found in %s\n' "$research_dir" >&2
  exit 1
fi

for corpus_file in "${corpus_files[@]}"; do
  if ! jq -s -e '
    length > 0 and
    all(.[];
      type == "object" and
      (.url | type == "string") and
      (.url | length > 0) and
      (.title | type == "string") and
      (.title | length > 0) and
      (.source_type | type == "string") and
      (.source_type | length > 0) and
      (.evidence_class | type == "string") and
      (.evidence_class | length > 0) and
      (.collection_id | type == "string") and
      (.collection_id | length > 0) and
      (.collected_at | type == "string") and
      (.collected_at | length > 0) and
      (((.topic_flags? // .topics?) | type) == "array")
    )
  ' "$corpus_file" >/dev/null; then
    printf 'Invalid corpus records: %s\n' "$corpus_file" >&2
    exit 1
  fi
done

url_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-urls.XXXXXX")
duplicate_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-duplicates.XXXXXX")
normalized_url_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-normalized-urls.XXXXXX")
normalized_duplicate_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-normalized-duplicates.XXXXXX")
record_id_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-record-ids.XXXXXX")
duplicate_record_id_file=$(mktemp "${TMPDIR:-/tmp}/tessera-corpus-duplicate-record-ids.XXXXXX")
trap 'rm -f -- "$url_file" "$duplicate_file" "$normalized_url_file" "$normalized_duplicate_file" "$record_id_file" "$duplicate_record_id_file"' EXIT

jq -r '.url' "${corpus_files[@]}" >"$url_file"
sort "$url_file" | uniq -d >"$duplicate_file"

ruby -ruri -e '
  def normalize_url(raw)
    uri = URI.parse(raw.strip)
    return raw.strip unless uri.is_a?(URI::HTTP)

    scheme = uri.scheme.downcase
    host = uri.host.downcase.sub(/\Awww\./, "")
    default_port = (scheme == "http" && uri.port == 80) ||
      (scheme == "https" && uri.port == 443)
    port = default_port ? "" : ":#{uri.port}"
    path = uri.path.to_s.sub(%r{/+\z}, "")
    path = "/" if path.empty?
    query_pairs = URI.decode_www_form(uri.query.to_s).sort
    query = query_pairs.empty? ? "" : "?#{URI.encode_www_form(query_pairs)}"
    "#{scheme}://#{host}#{port}#{path}#{query}"
  rescue URI::InvalidURIError, ArgumentError
    raw.strip
  end

  File.foreach(ARGV.fetch(0), chomp: true) do |line|
    puts normalize_url(line)
  end
' "$url_file" >"$normalized_url_file"

sort "$normalized_url_file" | uniq -d >"$normalized_duplicate_file"
jq -r 'select(has("record_id")) | .record_id' "${corpus_files[@]}" >"$record_id_file"
sort "$record_id_file" | uniq -d >"$duplicate_record_id_file"

record_count=$(wc -l <"$url_file" | tr -d ' ')
unique_url_count=$(sort -u "$url_file" | wc -l | tr -d ' ')
duplicate_url_count=$(wc -l <"$duplicate_file" | tr -d ' ')
normalized_unique_url_count=$(sort -u "$normalized_url_file" | wc -l | tr -d ' ')
normalized_duplicate_url_count=$(wc -l <"$normalized_duplicate_file" | tr -d ' ')
record_id_count=$(wc -l <"$record_id_file" | tr -d ' ')
duplicate_record_id_count=$(wc -l <"$duplicate_record_id_file" | tr -d ' ')

printf 'corpus_files=%s\n' "${#corpus_files[@]}"
printf 'records=%s\n' "$record_count"
printf 'unique_urls=%s\n' "$unique_url_count"
printf 'duplicate_urls=%s\n' "$duplicate_url_count"
printf 'normalized_unique_urls=%s\n' "$normalized_unique_url_count"
printf 'normalized_duplicate_urls=%s\n' "$normalized_duplicate_url_count"
printf 'record_ids=%s\n' "$record_id_count"
printf 'duplicate_record_ids=%s\n' "$duplicate_record_id_count"

if ((duplicate_url_count > 0)); then
  printf 'Duplicate URLs:\n' >&2
  sed 's/^/  /' "$duplicate_file" >&2
  exit 1
fi

if ((normalized_duplicate_url_count > 0)); then
  printf 'Normalized duplicate URLs:\n' >&2
  sed 's/^/  /' "$normalized_duplicate_file" >&2
  exit 1
fi

if ((duplicate_record_id_count > 0)); then
  printf 'Duplicate record IDs:\n' >&2
  sed 's/^/  /' "$duplicate_record_id_file" >&2
  exit 1
fi
