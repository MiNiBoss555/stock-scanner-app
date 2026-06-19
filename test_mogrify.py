
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path
import os
import sys

# Add current dir to sys.path so we can import main (though it might be too large/have side effects)
# Instead of importing main, I'll mock the necessary parts or just mock psycopg2 and run a small script.

class MockCursor:
    def __init__(self, data=None, columns=None):
        self.data = data or []
        self.columns = columns or []
        self.idx = 0
    
    def execute(self, query, params=None):
        pass
    
    def fetchall(self):
        return self.data
    
    def fetchmany(self, size):
        batch = self.data[self.idx : self.idx + size]
        self.idx += size
        return batch
    
    def mogrify(self, stmt, vals):
        # Simple mock mogrify
        res = stmt
        for v in vals:
            if isinstance(v, str):
                res = res.replace("%s", f"'{v}'", 1)
            else:
                res = res.replace("%s", str(v), 1)
        return res.encode("utf-8")

def test_mogrify_presence():
    try:
        import psycopg2
        from psycopg2.extras import RealDictCursor
        from psycopg2.extensions import cursor
        print(f"Standard cursor has mogrify: {hasattr(cursor, 'mogrify')}")
        print(f"RealDictCursor has mogrify: {hasattr(RealDictCursor, 'mogrify')}")
    except ImportError:
        print("psycopg2 not available for direct check")

if __name__ == "__main__":
    test_mogrify_presence()
    
    # Simulate the export logic
    table_data = [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"}
    ]
    columns = ["id", "name"]
    mock_cur = MockCursor(table_data, columns)
    
    insert_stmt = 'INSERT INTO "users" ("id", "name") VALUES (%s, %s);'
    vals = [1, "Alice"]
    sql = mock_cur.mogrify(insert_stmt, vals).decode("utf-8")
    print(f"Mock SQL: {sql}")
    assert sql == "INSERT INTO \"users\" (\"id\", \"name\") VALUES (1, 'Alice');"
    print("Mogrify logic verified in mock.")
