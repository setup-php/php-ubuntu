#!/usr/bin/env bash
set -euo pipefail

PHP_VERSION=${PHP_VERSION:?}
mods_dir=/etc/php/"$PHP_VERSION"/mods-available
ext_dir="$(php-config --extension-dir)"
enabled_extensions=()

extension_ini_directive() {
  case "$1" in
    opcache|xdebug)
      echo zend_extension
      ;;
    *)
      echo extension
      ;;
  esac
}

extension_loaded_name() {
  case "$1" in
    opcache)
      echo 'Zend OPcache'
      ;;
    *)
      echo "$1"
      ;;
  esac
}

ensure_extension_ini() {
  local directive extension ini_file priority
  extension=$1
  ini_file=$mods_dir/$extension.ini

  if [ -f "$ini_file" ]; then
    return
  fi

  priority=20
  directive="$(extension_ini_directive "$extension")"
  {
    echo "; priority=$priority"
    echo "$directive=$extension.so"
  } | sudo tee "$ini_file" >/dev/null
}

enable_extension() {
  local extension=$1
  local ini_file=$mods_dir/$extension.ini
  local priority

  ensure_extension_ini "$extension"

  if command -v phpenmod >/dev/null 2>&1; then
    sudo phpenmod -v "$PHP_VERSION" -s ALL "$extension"
    return
  fi

  priority="$(sed -n 's/^; priority=//p' "$ini_file" | head -n 1)"
  priority="${priority:-20}"
  for conf_dir in /etc/php/"$PHP_VERSION"/*/conf.d; do
    [ -d "$conf_dir" ] || continue
    sudo ln -sf "$ini_file" "$conf_dir"/"$priority-$extension.ini"
  done
}

mapfile -t shared_extensions < <(find "$ext_dir" -maxdepth 1 -type f -name '*.so' -printf '%f\n' | sed 's/\.so$//' | sort -u)

for extension in "${shared_extensions[@]}"; do
  echo "Enabling shared extension: $extension"
  enable_extension "$extension"
  enabled_extensions+=("$extension")
done

if [ "${#enabled_extensions[@]}" -eq 0 ]; then
  echo "No shared extensions found in $ext_dir"
  exit 0
fi

php_modules="$(php -m 2>&1)" || {
  echo "$php_modules"
  exit 1
}

echo "$php_modules"
if echo "$php_modules" | grep -Eiq 'PHP (Warning|Fatal error|Parse error)|Unable to load|Cannot load|undefined symbol|already loaded'; then
  exit 1
fi

missing_extensions=()
for extension in "${enabled_extensions[@]}"; do
  loaded_name="$(extension_loaded_name "$extension")"
  # shellcheck disable=SC2016
  if ! php -d display_errors=1 -r 'exit(extension_loaded($argv[1]) ? 0 : 1);' "$loaded_name"; then
    missing_extensions+=("$extension")
  fi
done

if [ "${#missing_extensions[@]}" -gt 0 ]; then
  printf 'Extensions present in %s but not loaded:\n' "$ext_dir"
  printf '%s\n' "${missing_extensions[@]}"
  exit 1
fi
