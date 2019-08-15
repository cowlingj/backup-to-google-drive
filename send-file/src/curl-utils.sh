status_code_from_file() {
  sed -ne '1 s|[[:graph:]]* \([[:digit:]]\{3\}\) [[:graph:]]*\r|\1|p; q' "$1"
}

header_from_file() {
  sed -ne '/^'"$1"': .*$/ { s/^'"$1"': \([[:graph:]]\+\)\r/\1/p; q }' "$2"
}