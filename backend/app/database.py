
from contextlib import contextmanager

from psycopg_pool import ConnectionPool

from app.config import get_settings


_pool: ConnectionPool | None = None


def open_pool() -> None:
    """Initialize the PostgreSQL connection pool."""
    global _pool

    if _pool is None:
        _pool = ConnectionPool(
            conninfo=get_settings().database_url,
            min_size=1,
            max_size=10,
            open=True,
            kwargs={"autocommit": False},
        )


def close_pool() -> None:
    """Close the PostgreSQL connection pool."""
    global _pool

    if _pool is not None:
        _pool.close()
        _pool = None


def get_pool() -> ConnectionPool:
    """Return the initialized connection pool."""
    if _pool is None:
        open_pool()

    assert _pool is not None
    return _pool


@contextmanager
def db_connection():
    """
    Provide a pooled database connection.

    Commit on successful exit and roll back on exceptions.
    The connection is returned to the pool afterward.
    """
    with get_pool().connection() as conn:
        with conn.transaction():
            yield conn
