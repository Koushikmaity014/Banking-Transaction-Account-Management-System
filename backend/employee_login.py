
import os
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from pwdlib import PasswordHash


# ============================================================
# 1. CONFIGURATION
# ============================================================

SCRIPT_DIR = Path(__file__).resolve().parent
ENV_FILE = SCRIPT_DIR / ".env"

if not ENV_FILE.is_file():
    print(f"ERROR: Environment file not found: {ENV_FILE}")
    sys.exit(1)

load_dotenv(ENV_FILE, override=False)

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print(f"ERROR: DATABASE_URL is missing from {ENV_FILE}")
    sys.exit(1)

password_hasher = PasswordHash.recommended()


# ============================================================
# 2. CREDENTIAL GENERATION
# ============================================================

def normalize_name(value):
    if value is None:
        return ""
    return str(value).strip().lower()


def generate_credentials(first_name, last_name, employee_id):
    """
    Username: firstname.lastname
    Password: firstname + last 3 characters of employee ID

    EMP0001 -> aarav.sen / aarav001
    EMP901  -> moyukh.mondal / moyukh901
    """
    first = normalize_name(first_name)
    last = normalize_name(last_name)
    emp_id = str(employee_id).strip()

    if not first or not last:
        raise ValueError(
            f"Missing first or last name for employee {emp_id}"
        )

    if len(emp_id) < 3:
        raise ValueError(
            f"Employee ID {emp_id} must contain at least 3 characters"
        )

    return f"{first}.{last}", f"{first}{emp_id[-3:]}"


def get_login_role(employee_role):
    """Map EMPLOYEE.Role to the LOGIN.Role expected by the trigger."""
    role = str(employee_role).strip()

    if role == "Admin":
        return "admin"

    if role in ("Employee", "Manager"):
        return "employee"

    raise ValueError(
        f"Unsupported employee role '{role}'. "
        "Expected Employee, Manager, or Admin."
    )


# ============================================================
# 3. MAIN PROCESS
# ============================================================

def main():
    connection = None

    try:
        print(f"Loading environment from: {ENV_FILE}")

        connection = psycopg.connect(DATABASE_URL)

        # All changes are committed together or rolled back together.
        with connection.transaction():
            with connection.cursor() as cursor:

                cursor.execute(
                    "SELECT current_database(), current_user"
                )
                database_name, database_user = cursor.fetchone()

                print("Connected to PostgreSQL successfully.")
                print(f"Database: {database_name}")
                print(f"Database user: {database_user}")

                # Fetch every employee, including Admin employees.
                cursor.execute(
                    """
                    SELECT
                        employee_id,
                        first_name,
                        last_name,
                        role,
                        status
                    FROM employee
                    ORDER BY employee_id;
                    """
                )

                employees = cursor.fetchall()

                if not employees:
                    print("No employees found. Nothing to process.")
                    return

                # Prepare all records before making changes.
                prepared = []
                seen_usernames = set()

                for (
                    employee_id,
                    first_name,
                    last_name,
                    employee_role,
                    employee_status,
                ) in employees:

                    username, plain_password = generate_credentials(
                        first_name,
                        last_name,
                        employee_id,
                    )

                    login_role = get_login_role(employee_role)

                    if username in seen_usernames:
                        raise ValueError(
                            f"Duplicate generated username: {username}"
                        )

                    seen_usernames.add(username)

                    # Do not enable a login for an inactive employee.
                    if employee_status == "Active":
                        account_status = "Active"
                    else:
                        account_status = "Disabled"

                    password_hash = password_hasher.hash(plain_password)

                    prepared.append(
                        {
                            "employee_id": employee_id,
                            "username": username,
                            "password_hash": password_hash,
                            "login_role": login_role,
                            "account_status": account_status,
                        }
                    )

                # Check for username collisions with other login records.
                # A username already belonging to a different employee
                # or customer must not be overwritten.
                for record in prepared:
                    cursor.execute(
                        """
                        SELECT login_id, employee_id, cif
                        FROM login
                        WHERE username = %s;
                        """,
                        (record["username"],),
                    )

                    collision = cursor.fetchone()

                    if collision:
                        existing_login_id, existing_employee_id, existing_cif = (
                            collision
                        )

                        if str(existing_employee_id or "") != str(
                            record["employee_id"]
                        ):
                            raise ValueError(
                                f"Username '{record['username']}' already "
                                f"belongs to another login (login_id "
                                f"{existing_login_id}). Resolve the "
                                "collision before continuing."
                            )

                created = 0
                updated = 0

                # Insert missing logins and replace existing employee
                # credentials, without creating duplicate employee logins.
                for record in prepared:

                    employee_id = record["employee_id"]

                    cursor.execute(
                        """
                        SELECT login_id
                        FROM login
                        WHERE employee_id = %s
                        FOR UPDATE;
                        """,
                        (employee_id,),
                    )

                    existing = cursor.fetchone()

                    if existing:
                        cursor.execute(
                            """
                            UPDATE login
                            SET username = %s,
                                password_hash = %s,
                                role = %s,
                                account_status = %s
                            WHERE employee_id = %s;
                            """,
                            (
                                record["username"],
                                record["password_hash"],
                                record["login_role"],
                                record["account_status"],
                                employee_id,
                            ),
                        )

                        updated += 1
                        action = "Updated"

                    else:
                        cursor.execute(
                            """
                            INSERT INTO login (
                                username,
                                password_hash,
                                role,
                                employee_id,
                                cif,
                                account_status
                            )
                            VALUES (%s, %s, %s, %s, %s, %s);
                            """,
                            (
                                record["username"],
                                record["password_hash"],
                                record["login_role"],
                                employee_id,
                                None,
                                record["account_status"],
                            ),
                        )

                        created += 1
                        action = "Created"

                    print(
                        f"{action}: {employee_id} | "
                        f"{record['username']} | "
                        f"{record['login_role']} | "
                        f"{record['account_status']}"
                    )

        # The transaction has committed successfully at this point.
        print("\nSUCCESS: Employee login processing completed.")
        print(f"Employees processed: {len(prepared)}")
        print(f"Existing logins updated: {updated}")
        print(f"New logins created: {created}")

    except Exception as error:
        if connection is not None:
            connection.rollback()

        print("\nERROR: Employee login processing failed.")
        print(f"Details: {error}")
        sys.exit(1)

    finally:
        if connection is not None:
            connection.close()
            print("Database connection closed.")


if __name__ == "__main__":
    main()
