clean() {
   [ -d "${SESSION_DIR-}" ] && rm -r "$SESSION_DIR"
}