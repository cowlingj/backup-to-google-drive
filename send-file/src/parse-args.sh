#!/usr/bin/env bash

parse_args() {

  while getopts 'c:a:i:o:' OPT; do
      case "$OPT" in
          c) CONFIG_FILE="$OPTARG" ;;
          a) AUTHENTICATION_FILE="$OPTARG" ;;
          o) OUTPUT_FILE="$OPTARG" ;;
          i) REPLACE_FILE="$OPTARG" ;;
          ?)
            usage
            return 1
            ;;
      esac
  done
  shift "$(( OPTIND - 1))"

  [ ! -f "${AUTHENTICATION_FILE-}" ] && return 1
  ACCESS_TOKEN="$( jq -r '.access_token' "$AUTHENTICATION_FILE" )"
  REFRESH_TOKEN="$( jq -r '.refresh_token' "$AUTHENTICATION_FILE" )"

  [ ! -f "${CONFIG_FILE-}" ] && return 1
  CLIENT_ID="$( jq -r '.client_id' "$CONFIG_FILE" )"
  CLIENT_SECRET="$( jq -r '.client_secret' "$CONFIG_FILE" )"

  SRC="${1-}"
  DEST="${2-}"

  if [ ! -f "${REPLACE_FILE-}" ]; then
    return 1
  else
    local _FILE_ID="$( jq -r '.id' < "$REPLACE_FILE" )"
    local _MIME_TYPE="$( jq -r '.mimeType' < "$REPLACE_FILE" )"

    [ "$_FILE_ID" != "null" ] && FILE_ID="$_FILE_ID"
    [ "$_MIME_TYPE" != "null" ] && MIME_TYPE="$_MIME_TYPE"
  fi

  if [ ! -f "$SRC" ] ||
     [ -z "${OUTPUT_FILE-}" ] ||
     [ -z "${MIME_TYPE-}" ] ||
     [ -z "$DEST" ]; then
    echo "invalid args"
    return 1
  fi
}