print(">>> customer_login.py started", flush=True)
import os
import re
import logging

import psycopg
from pwdlib import PasswordHash

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:moyukh13@localhost:1234/Bank"
)

password_hasher = PasswordHash.recommended()

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s"
)


def normalize_name(name):
    return re.sub(r"[^a-z0-9]+", "", name.strip().lower())




def main():
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            with conn.cursor() as cur:

                cur.execute("""
                    SELECT cif, first_name, last_name
                    FROM customer
                    ORDER BY cif
                """)
                customers = cur.fetchall()

                if not customers:
                    print("No customer records found.")
                    return

                # Remove existing customer logins only.
                cur.execute("""
                    DELETE FROM login
                    WHERE cif IS NOT NULL
                """)

                deleted = cur.rowcount
                created = 0

                for cif, first_name, last_name in customers:
                    cif = str(cif).strip()
                    first = normalize_name(first_name)
                    last = normalize_name(last_name)

                    if len(cif) < 3:
                        print(f"Skipping invalid CIF: {cif}")
                        continue

                    base_username = f"{first}.{last}"

                    # Add CIF suffix to repeated names.
                    cur.execute("""
                        SELECT COUNT(*)
                        FROM customer
                        WHERE LOWER(first_name) = LOWER(%s)
                          AND LOWER(last_name) = LOWER(%s)
                    """, (first_name, last_name))

                    duplicate_count = cur.fetchone()[0]

                    username = (
                        f"{base_username}{cif[-3:]}"
                        if duplicate_count > 1
                        else base_username
                    )

                    password = f"{first_name.strip()}{cif[-3:]}"
                    hashed_password = password_hasher.hash(password)

                    cur.execute("""
                        INSERT INTO login (
                            username,
                            password_hash,
                            role,
                            employee_id,
                            cif,
                            account_status
                        )
                        VALUES (%s, %s, %s, %s, %s, %s)
                    """, (
                        username,
                        hashed_password,
                        "customer",
                        None,
                        cif,
                        "Active"
                    ))

                    created += 1
                    print(f"Created login: {username} (CIF: {cif})")

                print("\nCustomer login replacement completed.")
                print(f"Previous customer logins deleted: {deleted}")
                print(f"New customer logins created: {created}")

    except psycopg.Error:
        logging.exception("Database operation failed.")

    except Exception:
        logging.exception("Login replacement failed.")



if __name__ == "__main__":
    print(">>> Starting customer login replacement...", flush=True)
    main()
    print(">>> Script finished.", flush=True)
