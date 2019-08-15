#!/usr/bin/env bash

INFO_FILE="test/file-info.txt"

./bin/send-file -c "test/config.json" -a "test/creds.json" -i "$INFO_FILE" -o "$INFO_FILE" ./test/file.test.gz file.test.gz