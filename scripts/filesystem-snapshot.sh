#!/usr/bin/env bash

tracked_roots() {
  local root

  for root in /bin /lib /lib64 /sbin /usr /var /run/php; do
    [ -e "$root" ] && printf '%s\0' "$root"
  done

  find /etc -maxdepth 1 -mindepth 1 -type d -print0
}

write_filesystem_manifest() {
  local output root tmp_manifest

  output=$1
  tmp_manifest="$(mktemp)"

  while IFS= read -r -d '' root; do
    find "$root" \
      \( -path /var/cache/apt -o -path /var/lib/apt/lists -o -path /var/log -o -path /var/tmp \) -prune -o \
      \( -type f -o -type l \) -printf '%p\t%y\t%m\t%U\t%G\t%s\t%T@\t%C@\t%l\n' >> "$tmp_manifest"
  done < <(tracked_roots)

  LC_ALL=C sort -u "$tmp_manifest" > "$output"
  rm -f "$tmp_manifest"
}
