#!/usr/bin/env bash
set -euo pipefail

side=${1:?use before or after}
if [[ "$side" != before && "$side" != after ]]; then
  echo 'Expected before or after.' >&2
  exit 2
fi

cd /opt/jmeter-research
expected=2c2e7ce6aac675ab1f2924e4dea4a07bae70dbd587618fd5c64e4ebb5e7365b4
actual=$(docker exec jmeter-research-sql-1 sha256sum /var/opt/mssql/data/financial-pristine.bak | cut -d ' ' -f1)
if [[ "$actual" != "$expected" ]]; then
  echo 'Pristine backup hash differs from the frozen fixture.' >&2
  exit 1
fi

docker compose --env-file .env -f compose-target.yaml stop api
docker exec jmeter-research-sql-1 bash -lc 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -d master -Q "ALTER DATABASE [Financial] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [Financial] FROM DISK = N'"'"'/var/opt/mssql/data/financial-pristine.bak'"'"' WITH REPLACE, CHECKSUM; ALTER DATABASE [Financial] SET MULTI_USER;"'

counts=$(docker exec jmeter-research-sql-1 bash -lc 'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -b -d Financial -h -1 -W -Q "SET NOCOUNT ON; SELECT (SELECT COUNT(*) FROM dbo.ChartOfAccounts), (SELECT COUNT(*) FROM dbo.JournalEntries), (SELECT COUNT(*) FROM dbo.JournalEntries WHERE Status=N'"'"'Posted'"'"');"' | tr -d '\r' | tail -n 1)
if [[ "$counts" != "120 30000 5000" ]]; then
  echo "Restored fixture counts differ: $counts" >&2
  exit 1
fi

sed -i -E "s/^API_IMAGE=.*/API_IMAGE=financial-api:$side/" .env
chmod 600 .env
docker compose --env-file .env -f compose-target.yaml up -d --force-recreate api
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 3 -o /dev/null http://10.240.42.10:8080/health/ready; then
    printf 'side=%s restored_counts=%s api_ready=true\n' "$side" "$counts"
    exit 0
  fi
  sleep 2
done
echo 'API readiness did not recover after restore.' >&2
exit 1
