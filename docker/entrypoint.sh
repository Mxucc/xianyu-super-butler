#!/bin/sh
set -eu
umask 077
python /app/docker/bootstrap.py
exec xvfb-run -a --server-args="-screen 0 1920x1080x24 -nolisten tcp" "$@"
