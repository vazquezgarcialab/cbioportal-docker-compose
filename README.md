# Run cBioPortal using Docker Compose

Welcome to the cBioPortal Docker Compose repository!

For documentation and usage instructions, see here: https://docs.cbioportal.org/deployment/docker/

## Backups & Restore

The `cbioportal-database` service ships a ClickHouse backup disk wired to a
named volume so the native `BACKUP DATABASE` / `RESTORE DATABASE` SQL works
out of the box:

| Piece | Where |
| --- | --- |
| Disk config | [`data/clickhouse_backups.xml`](data/clickhouse_backups.xml) (mounted into `config.d/`) |
| Storage | named volume `cbioportal_backups`, mounted at `/backups` in the container |

### Take a backup

```bash
docker exec \
    -e BACKUP_QUERY="BACKUP DATABASE cbioportal TO Disk('backups', 'cbio_$(date -u +%Y_%m_%dT%H_%M_%S).zip')" \
    cbioportal-database-container \
    sh -c 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" -q "$BACKUP_QUERY"'
```

The resulting `cbio_<ts>.zip` lives inside the `cbioportal_backups` named volume
at `/backups/`. To copy it out:

```bash
docker run --rm \
    -v cbioportal-docker-compose_cbioportal_backups:/b:ro \
    -v "$PWD":/out \
    alpine sh -c 'cp "$(ls -t /b/cbio_*.zip | head -1)" /out/'
```

(In the Vazquez-Garcia lab deployment this is automated by the
`cbioportal_backup_db` DAG in
[`vazquezlab_airflow`](https://github.com/vazquezgarcialab/vazquezlab_airflow);
backups are copied weekly to MAD3 archival storage.)

### Restore from a backup

Stage the zip back into the named volume, then run `RESTORE DATABASE`:

```bash
# 1. Copy cbio_<ts>.zip into the cbioportal_backups volume
docker run --rm \
    -v cbioportal-docker-compose_cbioportal_backups:/b \
    -v "$PWD":/in:ro \
    alpine cp /in/cbio_<ts>.zip /b/

# 2. Restore. The DB must NOT contain `cbioportal` already -- drop it first if so.
docker exec \
    -e RESTORE_QUERY="RESTORE DATABASE cbioportal FROM Disk('backups', 'cbio_<ts>.zip')" \
    cbioportal-database-container \
    sh -c 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" -q "$RESTORE_QUERY"'
```

> Note on operator umask: `data/init.sh` runs `chmod a+r` over its SQL/XML
> output so the ClickHouse container UID (101) can read the bind-mounted
> files even when the operator's umask strips world-read. If you re-fetch
> the repo by hand without running `data/init.sh`, you may need to
> `chmod o+r data/*.xml data/*.sql data/*.sql.gz` yourself.
