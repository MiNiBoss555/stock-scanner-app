
try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
    print("Psycopg2 is installed.")
    # We can't connect, but we can check the class
    print(f"RealDictCursor has mogrify: {hasattr(RealDictCursor, 'mogrify')}")
    # Let's check a standard cursor too
    from psycopg2.extensions import cursor
    print(f"Standard cursor has mogrify: {hasattr(cursor, 'mogrify')}")
except ImportError:
    print("Psycopg2 is not installed in this environment.")
except Exception as e:
    print(f"Error: {e}")
