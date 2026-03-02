#!/usr/bin/env bash
# Don't use -l here; we want to preserve the PATH and other env vars 
# as set in the base image, and not have it overridden by a login shell

# ███╗   ███╗███████╗████████╗████████╗██╗     ███████╗ ██████╗██╗
# ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝██║
# ██╔████╔██║█████╗     ██║      ██║   ██║     █████╗  ██║     ██║
# ██║╚██╔╝██║██╔══╝     ██║      ██║   ██║     ██╔══╝  ██║     ██║
# ██║ ╚═╝ ██║███████╗   ██║      ██║   ███████╗███████╗╚██████╗██║
# ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚══════╝╚══════╝ ╚═════╝╚═╝
# MettleCI DevOps for DataStage       (C) 2025-2026 Data Migrators
#                      _
#   _____   _____ _ __| | __ _ _   _  
#  / _ \ \ / / _ \ '__| |/ _` | | | | 
# | (_) \ V /  __/ |  | | (_| | |_| | 
#  \___/ \_/ \___|_|  |_|\__,_|\__, | 
#                    _         |___/  
#   __ _ _ __  _ __ | |_   _
#  / _` | '_ \| '_ \| | | | |
# | (_| | |_) | |_) | | |_| |
#  \__,_| .__/| .__/|_|\__, |
#       |_|   |_|      |___/
# 
set -euo pipefail

# Import MettleCI GitHub Actions utility functions
. "/usr/share/mcix/common.sh"

# -----
# Setup
# -----
export MCIX_BIN_DIR="/usr/share/mcix/bin"
export MCIX_LOG_DIR="/usr/share/mcix"
export MCIX_CMD="mcix" 
export MCIX_CMD_NAME="mcix overlay apply"
export MCIX_JUNIT_CMD="/usr/share/mcix/mcix-junit-to-summary"
export MCIX_JUNIT_CMD_OPTIONS="--annotations"
# Make us immune to runner differences or potential base-image changes
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$MCIX_BIN_DIR"

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT must be set}"

# We'll store the real command status here so the trap can see it
MCIX_STATUS=0
# Populated if command output matches: "It has been logged (ID ...)"
MCIX_LOGGED_ERROR_ID=""

# -------------------
# Validate parameters
# -------------------
require PARAM_ASSETS "assets"
require PARAM_OUTPUT "output"
require PARAM_OVERLAYS "overlays"

# ------------------------
# Build command to execute
# ------------------------

# Start argv
set -- "$MCIX_CMD" overlay apply 

# Core flags
set -- "$@" -assets "$PARAM_ASSETS"
set -- "$@" -output "$PARAM_OUTPUT"

# Handle multiple overlays by splitting the newline-separated list and adding multiple -overlay flags.
# We'll support both comma- and newline-separated lists for flexibility, but we'll normalize to newlines for processing.
OVERLAYS_NL="${PARAM_OVERLAYS//,/\\n}"
# Process values split by newlines, ignore empty/whitespace-only lines and add a -overlay flag for each non-empty line. 
while IFS= read -r line; do
  trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$trimmed" ] && continue
  set -- "$@" -overlay "$trimmed"
done <<EOF
${OVERLAYS_NL}
EOF

# Create path to specified output file, since mcix overlay apply doesn't create it if it doesn't exist.
mkdir -p "$(dirname "$PARAM_OUTPUT")"

# -properties (PARAM_PROPERTIES) (optional)
if [ -n "${PARAM_PROPERTIES:-}" ]; then
  set -- "$@" -properties "$PARAM_PROPERTIES"
fi

# ------------
# Step summary
# ------------
write_step_summary() {
  echo "Writing step summary for command '$MCIX_CMD_NAME' ..."

  # Surface "logged error ID" failures (if detected)
  if [ -n "${MCIX_LOGGED_ERROR_ID:-}" ] && \
     [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -w "$GITHUB_STEP_SUMMARY" ]; then
    {
      echo "**❌ Error:** There was an error logged while running command '$MCIX_CMD_NAME'."
      if [ -n "${MCIX_LOGGED_ERROR_ID:-}" ]; then
        # Capture the log entry and include it in the summary for visibility. 
        grep "(ID ${MCIX_LOGGED_ERROR_ID}" ${MCIX_LOG_DIR}/*.log | sed -n 's/.*(ID [^)]*): //p' \
          || echo "(Failed to extract log details for ID ${MCIX_LOGGED_ERROR_ID})"
      fi
    } >>"$GITHUB_STEP_SUMMARY"
    # Set a workflow error annotation for visibility. This will show up in the 'Annotations' tab 
    # but it won't fail the action on its own (since some errors are "log and continue".)
    gh_error "$MCIX_CMD_NAME" "There was an error logged during the execution of '$MCIX_CMD_NAME'"
  fi

  # Did GitHub provide a writable summary file?
  if [ -z "${GITHUB_STEP_SUMMARY:-}" ] || [ ! -w "$GITHUB_STEP_SUMMARY" ]; then
    gh_warn "GITHUB_STEP_SUMMARY not writable" "Skipping JUnit summary generation."

  else
    # Generate summary
    # gh_notice "Generating step summary" "Running JUnit summarizer and appending to GITHUB_STEP_SUMMARY."

    gh_notice "$MCIX_CMD_NAME" "$MCIX_CMD_NAME completed successfully."

#    # mcix-junit-to-summary [--annotations] [--max-annotations N] <junit.xml> [title]
#    echo "Executing: $MCIX_JUNIT_CMD $MCIX_JUNIT_CMD_OPTIONS $PARAM_REPORT \"$MCIX_CMD_NAME\""
#    "$MCIX_JUNIT_CMD" \
#      "$MCIX_JUNIT_CMD_OPTIONS" \
#      "$PARAM_REPORT" \
#      "$MCIX_CMD_NAME"  >> "$GITHUB_STEP_SUMMARY" || \
#      gh_warn "JUnit summarizer failed" "Continuing without failing the action."
  fi
}

# ---------
# Exit trap
# ---------
write_return_code_and_summary() {
  # Prefer MCIX_STATUS if set; fall back to $?
  rc=${MCIX_STATUS:-$?}

  echo "Return code is $rc"
  echo "return-code=$rc" >>"$GITHUB_OUTPUT"

  [ -z "${GITHUB_STEP_SUMMARY:-}" ] && return

  write_step_summary
}


# -------
# Execute
# -------
# Check the repository has been checked out
if [ ! -e "/github/workspace/.git" ]; then
  die "Repo contents not found in /github/workspace. Did you forget to run actions/checkout before this action?"
fi

# Capture output so we can detect "It has been logged (ID ...)" failures.
tmp_out="$(mktemp)"
cleanup() { rm -f "$tmp_out"; }

# Combine summary/output writing + temp cleanup in a single EXIT trap.
trap 'write_return_code_and_summary; cleanup' EXIT

# Run the command, capture its output and status, but don't let `set -e` kill us.
set +e
"$@" 2>&1 | tee "$tmp_out"
MCIX_STATUS=$?
set -e

# If the known "logged error" signature occurred, stash details for the summary.
MCIX_LOGGED_ERROR_ID=""
if mcix_has_logged_error "$tmp_out"; then
  MCIX_LOGGED_ERROR_ID="$(mcix_extract_logged_error_id "$tmp_out")"
fi

# Let the trap handle outputs & summary using MCIX_STATUS
exit "$MCIX_STATUS"
