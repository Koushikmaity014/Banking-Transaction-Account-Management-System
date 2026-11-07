
import sys

from app.database import db_connection
from app.security import hash_password


ADMINS = [
    {
        "employee_id": "EMP901",
        "username": "moyukh.mondal",
        "password": "Moyukh901",
    },
    {
        "employee_id": "EMP902",
        "username": "koushik.maity",
        "password": "Koushik902",
    },
    {
        "employee_id": "EMP903",
        "username": "rajeev.lalawat",
        "password": "Rajeev903",
    },
]


def create_admins():
    try:
        # db_connection() manages the transaction and connection lifecycle.
        with db_connection() as conn:
            with conn.cursor() as cur:
                for admin in ADMINS:
                    employee_id = admin["employee_id"]
                    username = admin["username"]
                    password_hash = hash_password(admin["password"])

                    # Verify that the employee exists.
                    cur.execute(
                        """
                        SELECT employee_id, first_name, last_name, status
                        FROM employee
                        WHERE employee_id = %s
                        """,
                        (employee_id,),
                    )
                    employee = cur.fetchone()

                    if employee is None:
                        raise RuntimeError(
                            f"Employee {employee_id} does not exist. "
                            "Create the employee record first."
                        )

                    _, first_name, last_name, status = employee

                    if status and status.lower() != "active":
                        raise RuntimeError(
                            f"Employee {employee_id} is not active."
                        )

                    # Find logins matching this employee or username.
                    cur.execute(
                        """
                        SELECT login_id, username, employee_id
                        FROM login
                        WHERE employee_id = %s
                           OR username = %s
                        """,
                        (employee_id, username),
                    )
                    existing = cur.fetchall()

                    if len(existing) > 1:
                        raise RuntimeError(
                            f"Conflicting login records for {username}. "
                            "Resolve them manually before continuing."
                        )

                    if existing:
                        login_id, old_username, old_employee_id = existing[0]

                        # Never take over another employee's login.
                        if old_employee_id != employee_id:
                            raise RuntimeError(
                                f"Username {old_username} is already linked "
                                f"to employee {old_employee_id}."
                            )

                        # Update the existing login.
                        cur.execute(
                            """
                            UPDATE login
                            SET username = %s,
                                password_hash = %s,
                                role = %s,
                                account_status = %s
                            WHERE login_id = %s
                            """,
                            (
                                username,
                                password_hash,
                                "admin",
                                "Active",
                                login_id,
                            ),
                        )

                        print(
                            f"Updated login for {first_name} {last_name} "
                            f"({employee_id})."
                        )

                    else:
                        # Create a new login.
                        # PostgreSQL must generate login_id automatically.
                        cur.execute(
                            """
                            INSERT INTO login (
                                username,
                                password_hash,
                                role,
                                employee_id,
                                cif,
                                account_status
                            )
                            VALUES (%s, %s, %s, %s, %s, %s)
                            """,
                            (
                                username,
                                password_hash,
                                "admin",
                                employee_id,
                                None,
                                "Active",
                            ),
                        )

                        print(
                            f"Created login for {first_name} {last_name} "
                            f"({employee_id})."
                        )

        # Reaching here means the context exited successfully.
        print(
            "\nAll administrator login changes committed successfully."
        )

    except Exception as exc:
        print(
            f"\nERROR: Administrator setup failed: {exc}",
            file=sys.stderr,
        )
        print(
            "The database transaction should be rolled back automatically "
            "if an exception occurred inside its transaction context.",
            file=sys.stderr,
        )
        raise


if __name__ == "__main__":
    create_admins()
