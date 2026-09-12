#!/usr/bin/env bash
# Shared decision logic for the AIOS hooks.
#
# The decisions live here, separately from the code that parses a hook payload,
# for one reason: this half can be tested exhaustively on any machine, and the
# payload-parsing half depends on a CLI contract that changes. Keeping them
# apart means the security logic is provable even when the adapter needs
# updating. DRIFT.3 checks the adapter still matches the installed CLI.
#
# Every function here fails closed. If it cannot determine the answer, it denies.

AIOS_ROOT="${AIOS_ROOT:-/srv/aios}"
AIOS_DATA="${AIOS_DATA:-$AIOS_ROOT/data}"

# Directories the coaching layer trusts. Quarantined content must never be
# written into these by a session that has read it.
TRUSTED_SUBDIRS="goals review reference ops"
# The only path a utility-lane (free tier) invocation may touch.
UTILITY_SUBDIRS="utility untrusted-external"

# resolve <path> : absolute, symlink- and ..-resolved, without requiring the
# file to exist. A naive prefix match accepts /data/../conf/settings.json, and
# that is the first thing anyone probing this boundary will try.
resolve() { realpath -m -- "$1" 2>/dev/null || return 1; }

# under <parent> <path> : true if path is inside parent, after resolution.
under() {
  local parent child
  parent=$(resolve "$1") || return 1
  child=$(resolve "$2")  || return 1
  case "$child" in
    "$parent") return 0 ;;
    "$parent"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# tainted : has this session read quarantined content?
# The marker is per session and disappears with it. A marker that persisted
# between sessions would silently disable the weekly review for ever, because
# the first research scan would poison every session after it.
taint_file() { printf '%s' "${AIOS_TAINT:-${TMPDIR:-/tmp}/aios-taint-${AIOS_SESSION:-$PPID}}"; }
tainted()    { [ -e "$(taint_file)" ]; }
set_taint()  { : > "$(taint_file)" 2>/dev/null || true; }

# guard_read <path> : deny reads only where a lane restriction applies.
# Reading is otherwise unrestricted inside the data mount; the deny rules in
# settings.json handle the secrets path.
guard_read() {
  local p="$1" resolved sub ok=1
  resolved=$(resolve "$p") || { echo "unresolvable path"; return 1; }
  if [ "${AIOS_LANE:-}" = utility ]; then
    for sub in $UTILITY_SUBDIRS; do
      under "$AIOS_DATA/$sub" "$resolved" && ok=0
    done
    [ "$ok" -eq 0 ] || { echo "utility lane may read only: $UTILITY_SUBDIRS"; return 1; }
  fi
  # Reading quarantined content taints the session for writes.
  under "$AIOS_DATA/untrusted-external" "$resolved" && set_taint
  return 0
}

# guard_write <path> : the load-bearing one.
guard_write() {
  local p="$1" resolved sub ok=1
  resolved=$(resolve "$p") || { echo "unresolvable path"; return 1; }

  # 1. Nothing outside the data mount, ever. This is what stops a write to
  #    ../conf/settings.json, which would remove every rule binding the agent.
  under "$AIOS_DATA" "$resolved" || {
    echo "outside the data mount: $resolved"; return 1; }

  # 2. Utility lane writes only into its own directory.
  if [ "${AIOS_LANE:-}" = utility ]; then
    for sub in $UTILITY_SUBDIRS; do
      under "$AIOS_DATA/$sub" "$resolved" && ok=0
    done
    [ "$ok" -eq 0 ] || { echo "utility lane may write only: $UTILITY_SUBDIRS"; return 1; }
    return 0
  fi

  # 3. A session that has read quarantined content cannot write into the
  #    trusted tree for the rest of that session. External content is data,
  #    never instruction, and this is the line that enforces it rather than
  #    requesting it.
  if tainted; then
    for sub in $TRUSTED_SUBDIRS; do
      under "$AIOS_DATA/$sub" "$resolved" && {
        echo "session has read untrusted-external/; cannot write $sub/ until it ends"
        return 1; }
    done
  fi
  return 0
}

# guard_bash <command> : refuse the argument shapes a name pattern misses.
guard_bash() {
  local c="$1"
  case "$c" in
    *"rm -rf"*|*"rm -fr"*|*"rm -r -f"*)   echo "recursive force delete";        return 1 ;;
    *"restic forget"*|*"restic prune"*)   echo "destroys backup history";      return 1 ;;
    *docker*)                             echo "container control";            return 1 ;;
    *crontab*)                            echo "schedule control";             return 1 ;;
    *"chmod"*|*"chown"*)
        case "$c" in *conf*|*secrets*|*"$AIOS_ROOT"*)
          echo "permission change on config or secrets"; return 1 ;; esac ;;
    *"mkfs"*|*"dd if="*)                  echo "destructive device operation"; return 1 ;;
  esac
  case "$c" in
    *"${AIOS_SECRETS:-$AIOS_ROOT/secrets}"*) echo "names the secrets path"; return 1 ;;
  esac
  return 0
}
