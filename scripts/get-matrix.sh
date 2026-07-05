#!/usr/bin/env bash

json_array=()

php_version="${PHP_VERSION:?}"
IFS=' ' read -r -a build_array <<<"${BUILDS:?}"
IFS=' ' read -r -a ts_array <<<"${TS:?}"
IFS=' ' read -r -a container_array <<<"${CONTAINERS:?}"

if [[ "$php_version" =~ [[:space:]] ]]; then
  echo "Expected exactly one PHP version, got: ${PHP_VERSION}" >&2
  exit 1
fi

get_container_base() {
  [[ $1 = *arm64v8* ]] && echo "${BASE_OS_ARM:?}" || echo "${BASE_OS:?}"
}

get_os_version() {
  [[ $1 = *arm64v8* ]] && echo "${1##*:}-arm" || echo "${1##*:}"
}

for build in "${build_array[@]}"; do
  for ts in "${ts_array[@]}"; do
    for os in "${container_array[@]}"; do
      os_base="$(get_container_base "$os")"
      os_version="ubuntu-$(get_os_version "$os")"
      json_array+=("{\"php\": \"$php_version\", \"builds\": \"$build\", \"ts\": \"$ts\", \"container\": \"$os\", \"container-base\": \"$os_base\", \"os\": \"$os_version\" }")
    done
  done
done

matrix_entries="$(printf '%s\n' "${json_array[@]}" | paste -sd, -)"
echo "matrix={\"include\":[$matrix_entries]}" >> "$GITHUB_OUTPUT"
