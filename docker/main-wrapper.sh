#!/command/with-contenv sh
# shellcheck shell=sh
# /opt/triibal/docker/main-wrapper.sh — wraps the container's CMD with
# the same argument-routing logic the pre-s6 entrypoint.sh used. Runs
# as /init's "main program" (Docker CMD) so it inherits stdin/stdout/
# stderr from the container.
#
# Shebang note: /init scrubs env before invoking CMD, so a plain
# `#!/bin/sh` wrapper sees an empty environ and `ENV TRIIBAL_HOME=/opt/data`
# from the Dockerfile never reaches `triibal`. with-contenv repopulates
# the env from /run/s6/container_environment before exec'ing, which is
# what s6-supervised services use too (see main-triibal/run).
#
# Routing:
#   no args                       → exec `triibal` (the default)
#   first arg is an executable    → exec it directly (sleep, bash, sh, …)
#   first arg is anything else    → exec `triibal <args>` (subcommand passthrough)
#
# We drop to the triibal user via `s6-setuidgid` so the supervised
# workload runs unprivileged (UID 10000 by default).
set -e

# HOME comes through with-contenv as /root (the /init context). Override
# to the triibal user's home before dropping privileges so libraries that
# resolve paths via $HOME (e.g. discord lockfile under XDG_STATE_HOME)
# don't try to write to /root.
export HOME=/opt/data

cd /opt/data
# shellcheck disable=SC1091
. /opt/triibal/.venv/bin/activate

if [ $# -eq 0 ]; then
    exec s6-setuidgid triibal triibal
fi

if command -v "$1" >/dev/null 2>&1; then
    # Bare executable — pass through directly.
    exec s6-setuidgid triibal "$@"
fi

# Triibal subcommand pass-through.
exec s6-setuidgid triibal triibal "$@"
