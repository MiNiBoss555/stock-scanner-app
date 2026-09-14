# SQLite to PostgreSQL migration runbook

No production cutover is performed by this change. Development keeps using
`STOCK_SCANNER_DB`; deployments may opt into PostgreSQL with `DATABASE_URL`.

1. Stop writes or enable a maintenance window, then copy the SQLite database
   and its `-wal`/`-shm` files consistently. Record a checksum and retain the
   backup outside Render's ephemeral filesystem.
2. Provision PostgreSQL and apply the application schema to an empty database.
3. Export every SQLite table and import it in dependency order inside a
   PostgreSQL transaction. Preserve primary keys and timestamps.
4. Compare row counts per table, validate foreign-key references, sample key
   records, and run the backend test suite against the migrated database.
5. Set `DATABASE_URL`, deploy one instance, and run read/write smoke tests
   before directing traffic to it.
6. If any check fails, remove `DATABASE_URL`, redeploy against the unchanged
   SQLite source, and restore traffic. Keep both databases until acceptance is
   complete.

Required owner actions: provision PostgreSQL, store `DATABASE_URL` as a secret,
schedule the write freeze, retain the verified backup, and approve cutover.
