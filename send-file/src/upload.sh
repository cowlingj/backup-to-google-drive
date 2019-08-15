#!/usr/bin/env bash

create_upload_session() {

  local METHOD="POST"
  [ -n "${FILE_ID-}" ] && METHOD="PATCH"

  curl -s \
    -X "$METHOD" \
    -D "$SESSION_CREATE_HEADERS" \
    --data "{ \"name\": \"$DEST\"}" \
    -H "X-Upload-Type: $MIME_TYPE" \
    -H "X-Upload-Content-Length: $CONTENT_LENGTH" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json; charset=UTF-8" \
    "https://www.googleapis.com/upload/drive/v3/files/${FILE_ID-}?uploadType=resumable" &>/dev/null

  if [ "$?" -ne "0" ]; then
    echo "failed to create upload session, exiting"
    return 2
  fi

  case "$(status_code_from_file "$SESSION_CREATE_HEADERS")" in
    2??)
      UPLOAD_URL="$( header_from_file "location" "$SESSION_CREATE_HEADERS" )"
      ;;
    401)

      [ -n "${1-}" ] && return 2

      echo "auth out of date, using refresh token"

      curl -s \
        -D "$SESSION_REFRESH_TOKEN_HEADERS" \
        -X 'POST' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data "client_id=$CLIENT_ID&grant_type=refresh_token&client_secret=$CLIENT_SECRET&refresh_token=$REFRESH_TOKEN" \
        'https://www.googleapis.com/oauth2/v4/token' > "$SESSION_REFRESH_TOKEN_BODY"

        [ "$?" -ne "0" ] && return 2

        case "$(status_code_from_file "$SESSION_REFRESH_TOKEN_HEADERS")" in
          2??)
            ACCESS_TOKEN="$(jq -r '.access_token' "$SESSION_REFRESH_TOKEN_BODY")"

            cat > "$AUTHENTICATION_FILE" <<EOF
{
  "access_token": "${ACCESS_TOKEN}",
  "refresh_token": "${REFRESH_TOKEN}"
}
EOF

            create_upload_session "x"
            return "$?"
            ;;
          *)
            echo "Failed to resume upload"
            return 2
            ;;
        esac  
      ;;
    *)
      echo "failed to create session"
      return 2
      ;;
  esac
}

upload() {

  if [ -n "${STARTED_UPLOAD-}" ]; then

  curl -s \
    -X "PUT" \
    -D "$SESSION_STATUS_HEADERS" \
    -H "Content-Length: $CONTENT_LENGTH" \
    -H "Content-Type: $MIME_TYPE" \
    -H "Content-Range: */$CONTENT_LENGTH"
    "$UPLOAD_URL" > /dev/null

  [ "$?" -ne "0" ] && return 2

  case "$(status_code_from_file "$SESSION_STATUS_HEADERS")" in
    2??) return 0 ;;
    308) return 1 ;;
    *)
      echo "Failed to resume upload"
      return 2
      ;;
  esac
  fi

  if [ -f "$SESSION_STATUS_HEADERS" ]; then
    RANGE_UPLOADED="$(header_from_file "Range"  "$SESSION_STATUS_HEADERS")"

    BYTES_UPLOADED="$(sed -ne 's|bytes=0-\([[:digit:]]\+\)|\1|' <<< "$RANGE_UPLOADED")"
  fi

  STARTED_UPLOAD="x"

  tail -c "+${BYTES_UPLOADED-0}" "$SRC" | \
  curl -s \
    -D "$SESSION_UPLOAD_HEADERS" \
    -H "Content-Type: application/gzip" \
    -H "Content-Range: bytes $BYTES_UPLOADED-$LAST_BYTE/$CONTENT_LENGTH" \
    -X "PUT" \
    --data-binary "@-" \
    "$UPLOAD_URL" > "$SESSION_UPLOAD_BODY"

  [ "$?" -ne "0" ] && return 1

  case "$(status_code_from_file "$SESSION_UPLOAD_HEADERS")" in
    2??) return 0 ;;
    5??)
      echo "server error"
      return 1
      ;;
    *)
      echo "other error $( cat "$SESSION_UPLOAD_BODY" )"
      return 2 ;;
  esac
}
