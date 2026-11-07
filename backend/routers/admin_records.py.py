from fastapi import APIRouter, Depends, HTTPException
from psycopg import sql

from app.database import db_connection
from app.security import require_roles

router = APIRouter(prefix="/api", tags=["admin-records"])

admin_required = Depends(require_roles("admin"))

# Only explicitly approved database tables can be queried.
TABLES = {
    "branches": "branch",
    "employees": "employee",
    "customers": "customer",
    "account-types": "account_type",
    "loan-types": "loan_type",
    "transactions": "TRANSACTION",
    "fund-transfers": "fund_transfer",
    "loan-payments": "loan_payment",
    "logins": "login",
    "audit-logs": "audit_log",
}

# Never expose credentials or secret authentication material.
SENSITIVE_COLUMNS = {
    "password",
    "password_hash",
    "hashed_password",
    "access_token",
    "refresh_token",
    "token",
    "secret",
}


def read_table(table_name: str):
    try:
        with db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL("SELECT * FROM {}").format(
                        sql.Identifier(table_name)
                    )
                )

                columns = [column.name for column in cur.description]

                visible_columns = [
                    column for column in columns
                    if column.lower() not in SENSITIVE_COLUMNS
                ]

                records = cur.fetchall()

                return [
                    {
                        column: row[columns.index(column)]
                        for column in visible_columns
                    }
                    for row in records
                ]

    except Exception as exc:
        # Log the underlying exception on the server, not in the response.
        import logging
        logging.exception("Failed to retrieve table %s", table_name)

        raise HTTPException(
            status_code=500,
            detail=f"Unable to retrieve records from {table_name}",
        ) from exc


def register_read_route(path: str, table_name: str):
    def endpoint():
        return read_table(table_name)

    endpoint.__name__ = f"list_{path.replace('-', '_')}"

    router.add_api_route(
        f"/{path}",
        endpoint,
        methods=["GET"],
        dependencies=[admin_required],
        response_model=None,
    )


for route_path, table_name in TABLES.items():
    register_read_route(route_path, table_name)