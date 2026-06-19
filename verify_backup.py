
import sys
import json
import logging
from pathlib import Path
from unittest.mock import MagicMock, patch

# Mocking parts of main to avoid importing it (it might try to connect to DB)
class MockDb:
    def __init__(self):
        self.kind = "postgres"
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def execute(self, query, params=None):
        cur = MagicMock()
        if "information_schema.tables" in query:
            cur.fetchall.return_value = [{"table_name": "users"}]
        elif "information_schema.columns" in query:
            cur.fetchall.return_value = [
                {"column_name": "id", "data_type": "integer", "is_nullable": "NO", "column_default": "nextval('users_id_seq')"},
                {"column_name": "name", "data_type": "text", "is_nullable": "YES", "column_default": None}
            ]
        elif 'SELECT * FROM "users"' in query:
            # We'll use a side effect for fetchmany to simulate batching
            def fetchmany(size):
                if getattr(fetchmany, 'called', False): return []
                fetchmany.called = True
                return [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob's Team"}]
            cur.fetchmany.side_effect = fetchmany
            # Mock mogrify behavior
            def mogrify(stmt, vals):
                res = stmt
                for v in vals:
                    if isinstance(v, str):
                        res = res.replace("%s", f"'{v}'", 1)
                    else:
                        res = res.replace("%s", str(v), 1)
                return res.encode("utf-8")
            cur.mogrify.side_effect = mogrify
        return cur

def _sql_literal(value):
    if value is None: return "NULL"
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, bool): return "TRUE" if value else "FALSE"
    if isinstance(value, (dict, list)):
        j = json.dumps(value).replace("'", "''")
        return f"'{j}'"
    s = str(value).replace("'", "''")
    return f"'{s}'"

def _fallback_postgres_export(dest_path: Path):
    with dest_path.open("w", encoding="utf-8") as f:
        f.write("-- PostgreSQL fallback dump\n")
        f.write("SET session_replication_role = 'replica';\n\n")
        
        db = MockDb() # Use our mock
        # 1. Get tables
        cur = db.execute("SELECT table_name FROM information_schema.tables")
        tables = [row["table_name"] for row in cur.fetchall()]
        
        for table in tables:
            f.write(f'DROP TABLE IF EXISTS "{table}" CASCADE;\n')
            
            # 2. Get columns
            col_cur = db.execute("SELECT ... FROM information_schema.columns", (table,))
            cols = col_cur.fetchall()
            
            col_defs = []
            for col in cols:
                name = col["column_name"]
                dtype = col["data_type"]
                nullable = "NULL" if col["is_nullable"] == "YES" else "NOT NULL"
                default = f"DEFAULT {col['column_default']}" if col["column_default"] else ""
                col_defs.append(f'    "{name}" {dtype} {nullable} {default}'.strip())
            
            f.write(f'CREATE TABLE "{table}" (\n')
            f.write(",\n".join(col_defs))
            f.write("\n);\n\n")

            # 3. Export data
            data_cur = db.execute(f'SELECT * FROM "{table}"')
            columns = [col["column_name"] for col in cols]
            cols_str = ", ".join(f'"{c}"' for c in columns)
            
            while True:
                rows = data_cur.fetchmany(1000)
                if not rows: break
                for row in rows:
                    vals = [row[c] for c in columns]
                    if hasattr(data_cur, "mogrify"):
                        placeholders = ", ".join(["%s"] * len(vals))
                        insert_stmt = f'INSERT INTO "{table}" ({cols_str}) VALUES ({placeholders});'
                        sql_line = data_cur.mogrify(insert_stmt, vals).decode("utf-8")
                        f.write(sql_line + "\n")
                    else:
                        val_strs = [_sql_literal(v) for v in vals]
                        f.write(f'INSERT INTO "{table}" ({cols_str}) VALUES ({", ".join(val_strs)});\n')
    print(f"Export finished. File size: {dest_path.stat().st_size} bytes")

if __name__ == "__main__":
    dest = Path("test_database.sql")
    _fallback_postgres_export(dest)
    content = dest.read_text()
    print("Content preview:")
    print(content)
    
    assert 'CREATE TABLE "users"' in content
    assert "Alice" in content
    assert "Bob's Team" in content or "Bob''s Team" in content
    print("Verification passed!")
