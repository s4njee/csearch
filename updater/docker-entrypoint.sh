#!/bin/sh
set -eu

runtime_root="${CONGRESSDIR:-/srv/csearch}"
postgres_host="${POSTGRESURI:-postgres}"

mkdir -p "$runtime_root"
mkdir -p "$runtime_root/data" "$runtime_root/cache"

if [ ! -d "$runtime_root/congress" ]; then
    cp -R /opt/csearch/congress "$runtime_root/congress"
fi

export PYTHONPATH="$runtime_root${PYTHONPATH:+:$PYTHONPATH}"

until pg_isready -h "$postgres_host" -U postgres -d csearch >/dev/null 2>&1; do
    echo "waiting for postgres at $postgres_host..."
    sleep 2
done

exec "$@"
