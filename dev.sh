#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
REMOTE_HOST="ec2"
REMOTE_DIR="set_dev/"
SCRIPT_NAME="$(basename "$0")"

# --- Logging helpers ---
log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  ${SCRIPT_NAME}: $*"; }
warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  ${SCRIPT_NAME}: $*" >&2; }
error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] ${SCRIPT_NAME}: $*" >&2; }

# --- Pre-flight checks ---
if ! command -v rsync &>/dev/null; then
    error "rsync is not installed. Please install rsync and try again."
    exit 1
fi

log "Starting dev deployment to ${REMOTE_HOST}:${REMOTE_DIR}"

# Verify SSH connectivity before attempting rsync
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_HOST}" true 2>/dev/null; then
    error "Cannot connect to remote host '${REMOTE_HOST}'."
    error "Possible causes: network issue, SSH key not configured, or host unreachable."
    exit 1
fi

log "SSH connection to '${REMOTE_HOST}' verified."

# --- Run rsync ---
log "Syncing files (excluding .git, .env*, *.pem, *.key) ..."
if rsync -rv \
    --exclude='.git' \
    --exclude='.env*' \
    --exclude='*.pem' \
    --exclude='*.key' \
    ./* "${REMOTE_HOST}:${REMOTE_DIR}"; then
    log "Dev deployment to ${REMOTE_HOST}:${REMOTE_DIR} completed successfully."
else
    exit_code=$?
    error "rsync failed with exit code ${exit_code}."
    case ${exit_code} in
        1)  error "Syntax or usage error. Check rsync arguments." ;;
        2)  error "Protocol incompatibility. Remote rsync version may differ." ;;
        3)  error "Errors selecting input/output files or dirs." ;;
        5)  error "Error starting client-server protocol. Check remote rsync daemon." ;;
        10) error "Error in socket I/O. Possible network interruption." ;;
        11) error "Error in file I/O. Check disk space and file permissions." ;;
        12) error "Error in rsync protocol data stream." ;;
        23) error "Partial transfer due to error. Some files may not have been transferred (permission denied?)." ;;
        24) warn  "Some files vanished before they could be transferred (non-fatal)." ;;
        25) error "The --max-delete limit was reached." ;;
        30) error "Timeout in data send/receive. Check network stability." ;;
        35) error "Timeout waiting for daemon connection." ;;
        *)  error "Unexpected rsync error. See rsync man page for exit code ${exit_code}." ;;
    esac
    exit "${exit_code}"
fi
