#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

VERSION=$(grep DOCKER_IMAGE_CBIOPORTAL "${SCRIPT_DIR}/../.env" | tail -n 1 | cut -d '=' -f 2-)

CONTAINER=$(docker create $VERSION)
trap 'docker rm $CONTAINER' EXIT

docker cp $CONTAINER:/cbioportal/db-scripts/clickhouse/init/schema.sql "${SCRIPT_DIR}/schema.sql"
docker cp $CONTAINER:/cbioportal/db-scripts/clickhouse/init/seed-cbioportal_hg19_hg38_v2.14.5.sql.gz "${SCRIPT_DIR}/seed.sql.gz"
docker cp $CONTAINER:/cbioportal/db-scripts/clickhouse/clickhouse.sql "${SCRIPT_DIR}/clickhouse.sql"

# Ensure config + SQL files bind-mounted into the ClickHouse container are
# readable by its UID (clickhouse user, uid 101) regardless of operator umask.
# Without this, a restrictive umask (e.g. 0027) leaves files mode 640 and the
# server fails to merge config.d/*.xml with "Access to file denied".
chmod a+r "${SCRIPT_DIR}"/*.sql "${SCRIPT_DIR}"/*.sql.gz "${SCRIPT_DIR}"/*.xml 2>/dev/null || true
