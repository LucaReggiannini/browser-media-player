#!/usr/bin/env bash

show_help() {
  cat <<EOF
bmphelper - Clipboard command listener for BMP (Browser Media Player)

Source: https://github.com/LucaReggiannini/browser-media-player

Usage:
  ./bmphelper.sh /path/to/media/folder

Description:
  This script monitors the system clipboard (via wl-clipboard) and listens for
  delete commands issued by BMP (Browser Media Player). When it detects a clipboard
  string in the format:

    bmp_cmd_delete:filename.ext

  it searches for the specified file inside the target directory and moves it to
  the trash using 'gio trash'.

Current Features:
  - Delete command: detects and deletes files requested by BMP.
  - Ignores clipboard content longer than 256 characters or empty clips.
  - Clears the clipboard after a successful deletion to avoid repeated processing.
  - Prints a single message on first valid delete to confirm activation.
  - Dynamically adjusts polling interval based on clipboard content.

Requirements:
  - wl-clipboard (wl-paste, wl-copy)
  - gio (provided by GVfs)

EOF
}

# Show help if requested
if [[ "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# Require target directory as argument
TARGET_DIR="$1"
if [[ -z "$TARGET_DIR" || ! -d "$TARGET_DIR" ]]; then
  show_help
  exit 1
fi

# Ensure gio is available for trashing
if ! command -v gio &> /dev/null; then
  show_help
  exit 1
fi

LAST_CLIP=""
SLEEP_INTERVAL=5
FIRST_DELETE_DONE=0

# Main monitoring loop
while true; do
  CLIP=$(wl-paste --no-newline)

  # Ignore empty clipboard or very large clipboard content
  if [[ -z "$CLIP" || ${#CLIP} -gt 256 ]]; then
    sleep "$SLEEP_INTERVAL"
    continue
  fi

  if [[ "$CLIP" != "$LAST_CLIP" ]]; then
    LAST_CLIP="$CLIP"

    if [[ "$CLIP" == bmp_cmd_delete:* ]]; then
      FILE_NAME="${CLIP#bmp_cmd_delete:}"
      FILE_NAME="${FILE_NAME//$'\n'/}"
      FILE_PATH="$TARGET_DIR/$FILE_NAME"

      if [[ -e "$FILE_PATH" ]]; then
        echo "[-] $FILE_PATH"
        gio trash -- "$FILE_PATH"
        wl-copy "" >/dev/null 2>&1

        if [[ "$FIRST_DELETE_DONE" -eq 0 ]]; then
          echo "[!] Sleep time set to 1"
          FIRST_DELETE_DONE=1
        fi

        SLEEP_INTERVAL=1
      else
        notify-send "bmphelper" "File not found: $FILE_NAME"
      fi
    else
      SLEEP_INTERVAL=5
      echo "[!] Sleep time set to 5"
    fi
  fi

  sleep "$SLEEP_INTERVAL"
done
