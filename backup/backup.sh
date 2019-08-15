#!/usr/bin/env bash

set -u -e

clean() {
  [ -d "$BACKUP_DIR" ] && rm -r "$BACKUP_DIR"
}
trap clean EXIT

usage() {
  echo "usage: $0 -f <FILES_TO_BACKUP> -n <BACKUP_NAME>"
}

ROOT="/"
BACKUP_DIR="$(mktemp -d)"

while getopts "f:n:" OPT; do
  case "$OPT" in
    f) BACKUP_FILES="$OPTARG" ;;
    n) BACKUP_NAME="$OPTARG" ;;
    ?|:)
      usage
      exit 1
    ;;
  esac
done

if [ ! -f "${BACKUP_FILES-}" ] || [ ! -n "${BACKUP_NAME-}" ]; then 
  usage && exit 1
fi

envsubst < "$BACKUP_FILES" | rsync -av --progress --filter="merge -" "$ROOT" "$BACKUP_DIR"
tar --transform "s|^${BACKUP_DIR#/}|backup_$(date --iso-8601=seconds)|" -C "$BACKUP_DIR" -czf "$BACKUP_NAME" "$BACKUP_DIR/"
