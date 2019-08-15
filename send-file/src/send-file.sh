#!/usr/bin/env bash

set -u

source "$BASE/src/clean.sh"
source "$BASE/src/setup.sh"
source "$BASE/src/usage.sh"
source "$BASE/src/parse-args.sh"
source "$BASE/src/upload.sh"
source "$BASE/src/curl-utils.sh"

trap clean EXIT

parse_args "$@" || exit 1

setup || exit 1

CONTENT_LENGTH="$( du -b "$SRC" | sed -ne 's|^\([[:digit:]]\+\)\t\+.*|\1|p' )"
LAST_BYTE="$(( CONTENT_LENGTH - "1" ))"

create_upload_session || exit 1

BYTES_UPLOADED='0'

while true; do
  
  upload
  
  case "$?" in
    0)
      echo "upload complete"
      mv "$SESSION_UPLOAD_BODY" "$OUTPUT_FILE"
      exit 0
      ;;
    1)
      echo "upload interrupted, retrying..."
      continue
      ;;
    *)
      echo "upload failed"
      exit 2
      ;;
  esac
done
