#!/usr/bin/env bash

set -ue

usage() {
  echo "$0 -c <filename> -o <filename> | -h"
  echo "  -c <filename> config file"
  echo "  -o <filename> output file for credentials"
  echo "  -h (help) show this message"
}

while getopts "c:o:h" OPT; do
  case "$OPT" in
    c) CONFIG_FILE="$OPTARG" ;;
    o) CREDENTIALS_FILE="$OPTARG" ;;
    h) SHOW_HELP="x";;
    ?|:)
       usage
       exit 1
  esac
done

if [ -n "${SHOW_HELP-}" ]; then
  usage
  exit 0
fi

if [ ! -f "${CONFIG_FILE-}" ]; then
  echo "config file '${CONFIG_FILE-}' doesn't exist" 1>&2

  usage
  exit 1
fi

CLIENT_ID="$( jq -r '.client_id' "$CONFIG_FILE" )"
CLIENT_SECRET="$( jq -r '.client_secret' "$CONFIG_FILE" )"
SCOPE="$( jq -r '.scope' "$CONFIG_FILE" )"

if [ -z "${CLIENT_ID-}" ] ||
   [ -z "${CLIENT_SECRET-}" ] ||
   [ -z "${SCOPE-}" ] ||
   [ -z "${CREDENTIALS_FILE-}" ]; then

  echo "incorrect config" 1>&2
  usage
  exit 1
fi

RESPONSE="$(curl -s \
           --data "client_id=$CLIENT_ID&scope=$SCOPE" \
           'https://accounts.google.com/o/oauth2/device/code'
           )"

INTERVAL="$(jq -r ".interval?" <<< "$RESPONSE")"
EXPIRES_IN="$(jq -r ".expires_in?" <<< "$RESPONSE")"
USER_CODE="$(jq -r ".user_code" <<< "$RESPONSE")"
DEVICE_CODE="$(jq -r ".device_code?" <<< "$RESPONSE")"
URL="$(jq -r '.verification_url?' <<< "$RESPONSE")"
ERROR_CODE="$(jq -r '.error_code?' <<< "$RESPONSE")"
ERROR="$(jq -r '.error?' <<< "$RESPONSE")"

unset RESPONSE

if [ "$ERROR" != "null" ]; then
  echo "error authenticating with google: $ERROR"
  exit 1
fi

if [ "$ERROR_CODE" != "null" ]; then
  echo "error authenticating with google: $ERROR_CODE"
  exit 1
fi
unset ERROR_CODE ERROR

echo "enter the code \"$USER_CODE\" in the browser"
echo "press enter to continue (opens browser)..."
read

xdg-open "$URL" &>/dev/null &

COUNT="0"

while true; do

  if [ "$COUNT" -ge "$EXPIRES_IN" ]; then
    echo "google login expired"
    exit 2
  fi

  if (( "$COUNT" % "$INTERVAL" == 0 )); then
    RESPONSE="$(curl -s -d "client_id=$CLIENT_ID&\
client_secret=$CLIENT_SECRET&\
code=$DEVICE_CODE&\
grant_type=http://oauth.net/grant_type/device/1.0" \
         -H "Content-Type: application/x-www-form-urlencoded" \
         'https://www.googleapis.com/oauth2/v4/token')"

    ERROR="$(jq -r '.error?' <<< "$RESPONSE")"
    ACCESS_TOKEN="$(jq -r '.access_token?' <<< "$RESPONSE")"
    REFRESH_TOKEN="$(jq -r '.refresh_token?' <<< "$RESPONSE")"
    TOKEN_EXPIRES_IN="$(jq -r '.expires_in?' <<< "$RESPONSE")"
 
    if [ "$ERROR" == "null" ]; then
      break
    fi

    if [ "$ERROR" != "authorization_pending" ]; then
      echo
      echo "error authenticating with google"
      exit 2
    fi
  fi
  
  SPINNER=""
  case "$(( COUNT % 4))" in
    0) SPINNER='|' ;;
    1) SPINNER='/' ;;
    2) SPINNER='-' ;;
    3) SPINNER='\' ;;
  esac

  echo -ne "\r$SPINNER"
  sleep 1
  set +e
    (( COUNT++ ))
  set -e
done

echo
cat > "$CREDENTIALS_FILE" <<EOF
{
  "access_token": "${ACCESS_TOKEN}",
  "refresh_token": "${REFRESH_TOKEN}"
}
EOF

echo "success"
