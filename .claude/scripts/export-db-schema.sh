#!/usr/bin/env bash
# .claude/scripts/export-db-schema.sh
#
# Export DB SCHEMA ONLY (no data rows) into the repo, so KB evidence stays repo-resident
# and re-verifiable. Closes the `DB-resident logic not in repo` blind spot of /discover.
#
# Usage:
#   export-db-schema.sh --engine <sqlserver|mysql|postgres|mongodb|oracle> --out db/schema-snapshot/<name> \
#       ( --from-config <file> --key <ConnectionStrings:Default>   # preferred: secret never on the CLI
#       | --host H [--port P] --db D --user U )                    # password prompted with read -s
#   Optional: --yes            (skip the confirm prompt — CI only, where a human already decided)
#             --owner <SCHEMA> (Oracle: export another schema's objects; default = the connecting user)
#
# SAFETY CONTRACT (do not weaken):
#   - schema-only: DDL + routines/triggers/views/functions; NEVER dumps data rows
#   - never echoes the password: masked in every message, passed to tools via env var
#     (SQLCMDPASSWORD / MYSQL_PWD / PGPASSWORD) — never as a command-line argument
#   - prints the target engine@host/db + user and requires an explicit y/N before connecting
#   - writes a provenance banner into the output; the caller commits the snapshot
#
# Reference: .claude/commands/discover.md §Phase 1b — Guided schema export

set -uo pipefail

ENGINE="" OUT="" FROM_CONFIG="" KEY="" HOST="" PORT="" DB="" USER_NAME="" ASSUME_YES=0
PASSWORD=""   # never printed, never passed on a command line
RAW_CS=""     # original connection string (MongoDB reuses it verbatim — no lossy rebuild)
OWNER=""      # Oracle only: schema to export (default = connecting user)

has() { command -v "$1" >/dev/null 2>&1; }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

usage() { sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --engine)      ENGINE="$2"; shift 2 ;;
        --out)         OUT="$2"; shift 2 ;;
        --from-config) FROM_CONFIG="$2"; shift 2 ;;
        --key)         KEY="$2"; shift 2 ;;
        --host)        HOST="$2"; shift 2 ;;
        --port)        PORT="$2"; shift 2 ;;
        --db)          DB="$2"; shift 2 ;;
        --user)        USER_NAME="$2"; shift 2 ;;
        --owner)       OWNER="$2"; shift 2 ;;
        --yes)         ASSUME_YES=1; shift ;;
        -h|--help)     usage ;;
        *)             die "unknown argument: $1 (use --help)" ;;
    esac
done

[ -n "$ENGINE" ] || die "--engine is required (sqlserver|mysql|postgres)"
[ -n "$OUT" ]    || die "--out is required (e.g. db/schema-snapshot/main)"

# ── Read the connection FROM the config file (preferred): the secret never reaches
#    a command line, a chat message, or a log — only this process's memory.
read_from_config() {
    local file="$1" key="$2" raw=""
    [ -f "$file" ] || die "config file not found: $file"

    case "$file" in
        *.json)
            has python3 || die "python3 required to read a JSON config"
            raw=$(python3 - "$file" "$key" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
node = json.load(open(path, encoding="utf-8-sig"))
for part in key.replace("__", ":").split(":"):
    if not isinstance(node, dict) or part not in node:
        sys.exit(3)
    node = node[part]
print(node if isinstance(node, str) else "")
PY
            ) || die "key not found in $file: $key"
            ;;
        *)  # .env / properties style: KEY=value
            raw=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -1 | sed -E "s/^[^=]*=[[:space:]]*//; s/^\"//; s/\"$//")
            [ -n "$raw" ] || die "key not found in $file: $key"
            ;;
    esac
    parse_connection "$raw"
}

# Accepts both key=value connection strings (SQL Server / MySQL ADO style) and URIs
# (postgresql://user:pass@host:port/db, mysql://…).
parse_connection() {
    local cs="$1"
    RAW_CS="$cs"
    # `[a-z+]` so `mongodb+srv://` (Atlas) is recognised as a URI too.
    if printf '%s' "$cs" | grep -qE '^[a-z+]+://'; then
        local rest="${cs#*://}" creds="" hostpart=""
        case "$rest" in *@*) creds="${rest%%@*}"; rest="${rest#*@}" ;; esac
        USER_NAME="${USER_NAME:-${creds%%:*}}"
        [ "$creds" != "${creds#*:}" ] && PASSWORD="${creds#*:}"
        hostpart="${rest%%/*}"; DB="${DB:-${rest#*/}}"; DB="${DB%%\?*}"
        HOST="${HOST:-${hostpart%%:*}}"
        [ "$hostpart" != "${hostpart#*:}" ] && PORT="${PORT:-${hostpart#*:}}"
        return
    fi
    local IFS=';' pair k v
    for pair in $cs; do
        k=$(printf '%s' "${pair%%=*}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        v="${pair#*=}"
        case "$k" in
            server|host|datasource|addr) HOST="${HOST:-${v%%,*}}"
                                          [ "$v" != "${v#*,}" ] && PORT="${PORT:-${v#*,}}" ;;
            port)                         PORT="${PORT:-$v}" ;;
            database|initialcatalog|db)   DB="${DB:-$v}" ;;
            userid|user|uid|username)     USER_NAME="${USER_NAME:-$v}" ;;
            password|pwd)                 PASSWORD="$v" ;;
        esac
    done
}

[ -n "$FROM_CONFIG" ] && { [ -n "$KEY" ] || die "--from-config requires --key"; read_from_config "$FROM_CONFIG" "$KEY"; }

# Oracle EZConnect lives in one field (`Data Source=//host:1521/SERVICE`) — split it out
# BEFORE the generic checks below, otherwise "database not resolved" fires on a valid string.
normalize_oracle_target() {
    local ds="$HOST"
    case "$ds" in *//*) ds="${ds#*//}" ;; esac
    case "$ds" in */*)  [ -n "$DB" ] || DB="${ds#*/}"; ds="${ds%%/*}" ;; esac
    case "$ds" in *:*)  PORT="${PORT:-${ds##*:}}"; ds="${ds%%:*}" ;; esac
    HOST="$ds"; PORT="${PORT:-1521}"
}
[ "$ENGINE" = "oracle" ] && normalize_oracle_target

[ -n "$HOST" ] || die "host not resolved — pass --host or fix --key"
[ -n "$DB" ]   || die "database not resolved — pass --db or fix --key"
[ -n "$USER_NAME" ] || die "user not resolved — pass --user or fix --key"

if [ -z "$PASSWORD" ]; then
    printf 'Password for %s@%s/%s (not echoed): ' "$USER_NAME" "$HOST" "$DB"
    read -rs PASSWORD; printf '\n'
fi

# ── Informed consent: show WHAT is about to be touched; the password is never shown.
if [ "$ASSUME_YES" -ne 1 ]; then
    printf 'Export schema FROM: %s@%s%s/%s  (user: %s, password: ***)\n' \
        "$ENGINE" "$HOST" "${PORT:+:$PORT}" "$DB" "$USER_NAME"
    printf 'Read-only, SCHEMA-ONLY (no data rows). Output: %s\n' "$OUT"
    printf 'Continue? [y/N] '
    read -r answer
    [ "$answer" = "y" ] || [ "$answer" = "Y" ] || { echo "aborted by user"; exit 2; }
fi

mkdir -p "$OUT" || die "cannot create output dir: $OUT"
PARTIAL_NOTE=""

dump_sqlserver() {
    export SQLCMDPASSWORD="$PASSWORD"
    if has mssql-scripter; then
        mssql-scripter --schema-only --server "$HOST${PORT:+,$PORT}" --database "$DB" \
            --user "$USER_NAME" > "$OUT/schema.sql" || die "mssql-scripter failed"
    elif has sqlcmd; then
        PARTIAL_NOTE=" · PARTIAL: sqlcmd fallback (routines full; tables as a column listing) — install mssql-scripter for full CREATE TABLE DDL"
        sqlcmd -S "$HOST${PORT:+,$PORT}" -d "$DB" -U "$USER_NAME" -y0 -h-1 \
            -Q "SET NOCOUNT ON; SELECT OBJECT_DEFINITION(object_id) FROM sys.objects WHERE type IN ('P','V','TR','FN','IF','TF') ORDER BY name;" \
            > "$OUT/routines.sql" || die "sqlcmd (routines) failed"
        sqlcmd -S "$HOST${PORT:+,$PORT}" -d "$DB" -U "$USER_NAME" -s'|' -W \
            -Q "SET NOCOUNT ON; SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS ORDER BY TABLE_NAME, ORDINAL_POSITION;" \
            > "$OUT/tables.txt" || die "sqlcmd (tables) failed"
    else
        die "need mssql-scripter or sqlcmd on PATH"
    fi
    unset SQLCMDPASSWORD
}

dump_mysql() {
    has mysqldump || die "need mysqldump on PATH"
    export MYSQL_PWD="$PASSWORD"
    mysqldump --no-data --routines --triggers --events --skip-dump-date \
        -h "$HOST" ${PORT:+-P "$PORT"} -u "$USER_NAME" "$DB" > "$OUT/schema.sql" || die "mysqldump failed"
    unset MYSQL_PWD
}

dump_postgres() {
    has pg_dump || die "need pg_dump on PATH"
    export PGPASSWORD="$PASSWORD"
    pg_dump --schema-only --no-owner --no-privileges \
        -h "$HOST" ${PORT:+-p "$PORT"} -U "$USER_NAME" -d "$DB" > "$OUT/schema.sql" || die "pg_dump failed"
    unset PGPASSWORD
}

# Oracle: DDL comes from DBMS_METADATA (text, client-side) — NOT Data Pump, whose dump would
# land on the DB server as a binary file, useless as a committed repo artifact.
# The connect string goes through STDIN, never argv (a password in argv is visible via `ps`).
dump_oracle() {
    local bin
    bin=$(command -v sqlplus || command -v sql) || die "need sqlplus (or SQLcl 'sql') on PATH — or use the MCP fallback (see discover.md §Phase 1b)"
    local owner="${OWNER:-$USER_NAME}"
    {
        printf 'connect %s/%s@%s:%s/%s\n' "$USER_NAME" "$PASSWORD" "$HOST" "$PORT" "$DB"
        printf 'DEFINE OWNER = "%s"\n' "$owner"
        cat <<'SQL'
SET LONG 20000000 LONGCHUNKSIZE 32767 PAGESIZE 0 LINESIZE 32767 FEEDBACK OFF ECHO OFF VERIFY OFF HEADING OFF TRIMSPOOL ON
WHENEVER SQLERROR CONTINUE
BEGIN
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',TRUE);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',FALSE);
  DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SEGMENT_ATTRIBUTES',FALSE);
END;
/
PROMPT -- ===== structural objects (tables, views, sequences) =====
SELECT DBMS_METADATA.GET_DDL(REPLACE(o.object_type,' ','_'), o.object_name, o.owner)
FROM   all_objects o
WHERE  o.owner = UPPER('&OWNER')
AND    o.object_type IN ('TABLE','VIEW','SEQUENCE','MATERIALIZED VIEW','SYNONYM')
AND    o.generated = 'N'          -- skip system-generated objects (identity-column sequences,
AND    o.object_name NOT LIKE 'BIN$%'   -- constraint indexes…): GET_DDL raises ORA-31603 on them
ORDER  BY CASE o.object_type WHEN 'TABLE' THEN 1 WHEN 'SEQUENCE' THEN 2 ELSE 3 END, o.object_name;
PROMPT -- ===== PL/SQL (procedures, functions, packages + bodies, types) =====
SELECT DBMS_METADATA.GET_DDL(REPLACE(o.object_type,' ','_'), o.object_name, o.owner)
FROM   all_objects o
WHERE  o.owner = UPPER('&OWNER')
AND    o.object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','TYPE','TYPE BODY')
AND    o.generated = 'N' AND o.object_name NOT LIKE 'BIN$%'
ORDER  BY o.object_type, o.object_name;
PROMPT -- ===== triggers =====
SELECT DBMS_METADATA.GET_DDL('TRIGGER', o.object_name, o.owner)
FROM   all_objects o
WHERE  o.owner = UPPER('&OWNER') AND o.object_type = 'TRIGGER'
AND    o.generated = 'N' AND o.object_name NOT LIKE 'BIN$%'
ORDER  BY o.object_name;
PROMPT -- ===== indexes (constraint-generated ones excluded — they come with their table DDL) =====
SELECT DBMS_METADATA.GET_DDL('INDEX', i.index_name, i.owner)
FROM   all_indexes i
WHERE  i.owner = UPPER('&OWNER') AND i.generated = 'N' AND i.index_name NOT LIKE 'BIN$%';
SQL
        printf 'exit\n'
    } | "$bin" -S /nolog > "$OUT/schema.sql" || die "sqlplus export failed"
    grep -q "ORA-" "$OUT/schema.sql" && PARTIAL_NOTE=" · PARTIAL: some objects raised ORA- errors (privileges or unsupported type) — see the file"
}

# MongoDB has no DDL, but it DOES hold behavior-critical structure the code often never
# declares: $jsonSchema validators, views (stored aggregation pipelines), and indexes —
# especially TTL (documents auto-delete) and unique (duplicate-key → the app's 409 path).
# This reads metadata only: getCollectionInfos() + getIndexes(). ZERO documents are read.
# NOT reachable this way: Atlas Triggers/Functions/Search (a separate service with its own
# API credentials) — those stay a named blind spot, exported by hand (see the note printed below).
dump_mongodb() {
    has mongosh || die "need mongosh on PATH"
    # The URI (with credentials) goes through the environment, never through argv.
    export MONGO_URI="${RAW_CS:-mongodb://${USER_NAME}:${PASSWORD}@${HOST}${PORT:+:$PORT}/${DB}}"
    export MONGO_DB="$DB"
    mongosh --quiet --nodb --eval '
        const conn = Mongo(process.env.MONGO_URI);
        const db = conn.getDB(process.env.MONGO_DB);
        const out = { database: db.getName(), exportedAt: new Date().toISOString(), collections: [] };
        db.getCollectionInfos().forEach(function (c) {
            const entry = { name: c.name, type: c.type, options: c.options || {} };
            if (c.type !== "view") { entry.indexes = db.getCollection(c.name).getIndexes(); }
            out.collections.push(entry);
        });
        print(JSON.stringify(out, null, 2));
    ' > "$OUT/schema.json" || die "mongosh export failed"
    unset MONGO_URI MONGO_DB

    # Derived summary: the items whose behavior is INVISIBLE when reading application code.
    if has python3; then
        python3 - "$OUT/schema.json" > "$OUT/BEHAVIOR-CRITICAL.md" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ttl, uniq, val, views = [], [], [], []
for c in d.get("collections", []):
    opts = c.get("options") or {}
    if c.get("type") == "view":
        views.append(f"- `{c['name']}` ← view on `{opts.get('viewOn')}` (pipeline stored in the DB)")
    if "validator" in opts:
        val.append(f"- `{c['name']}` has a `$jsonSchema`/validator — writes violating it are rejected by the DB")
    for ix in c.get("indexes", []) or []:
        if "expireAfterSeconds" in ix:
            ttl.append(f"- `{c['name']}.{ix['name']}` TTL {ix['expireAfterSeconds']}s — documents **auto-delete**")
        if ix.get("unique"):
            uniq.append(f"- `{c['name']}.{ix['name']}` unique {json.dumps(ix.get('key'))} — duplicate ⇒ error 11000")
print("# Behavior-critical structure found in the database\n")
print("> Read this before writing as-is stories: each item changes observable behavior and is typically NOT visible in application code.\n")
for title, rows in (("TTL indexes (data disappears on its own)", ttl), ("Unique indexes (duplicate-key errors)", uniq),
                    ("Schema validators (writes rejected by the DB)", val), ("Views (logic stored in the DB)", views)):
    print(f"## {title}\n"); print("\n".join(rows) if rows else "_none_"); print()
PY
    fi
    printf 'NOTE: Atlas Triggers/Functions/Search indexes are NOT in this snapshot (separate service).\n'
    printf '      If the cluster uses Atlas App Services, export them by hand and commit:\n'
    printf '        appservices pull --remote <app-id>   # then commit the pulled functions/triggers\n'
}

case "$ENGINE" in
    sqlserver) dump_sqlserver ;;
    mysql)     dump_mysql ;;
    postgres)  dump_postgres ;;
    mongodb)   dump_mongodb ;;
    oracle)    dump_oracle ;;
    *)         die "unsupported engine: $ENGINE (sqlserver|mysql|postgres|mongodb|oracle)" ;;
esac

PASSWORD=""   # drop it from memory as soon as the dump is done

cat > "$OUT/README.md" <<EOF
> GENERATED by \`.claude/scripts/export-db-schema.sh\` — do not hand-edit.
> Source: ${ENGINE}@${HOST}${PORT:+:$PORT}/${DB} · exported: $(date +%F) · approved by user · schema-only (no data rows).${PARTIAL_NOTE}
> Refresh: re-run the script and commit. Indexed by \`docs/CODEBASE_MAP.md\` §DB-object inventory.
EOF

printf 'Done → %s (schema-only). Commit it so the evidence stays repo-resident.\n' "$OUT"
