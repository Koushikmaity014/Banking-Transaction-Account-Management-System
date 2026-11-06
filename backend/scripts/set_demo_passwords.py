"""Optional LOCAL-ONLY helper: set the listed academic demo logins to pass123.
Run only against your disposable project database after the login rows exist.
Do not run against a real or shared database.
"""
import os
import sys
from pathlib import Path

import psycopg
from pwdlib import PasswordHash

# Allow running this file from backend/ or backend/scripts/.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.config import get_settings

DEMO_USERS = ('customer1', 'employee1', 'admin1', 'locked_user', 'disabled_user', 'ananya_iyer', 'manager1')
DEMO_PASSWORD = 'pass123'


def main():
    if os.getenv('CONFIRM_DEMO_PASSWORD_RESET') != 'YES':
        raise SystemExit('Safety stop: set CONFIRM_DEMO_PASSWORD_RESET=YES to reset local demo passwords.')
    hashed = PasswordHash.recommended().hash(DEMO_PASSWORD)
    with psycopg.connect(get_settings().database_url) as conn:
        with conn.cursor() as cur:
            cur.execute('UPDATE login SET password_hash = %s WHERE username = ANY(%s)', (hashed, list(DEMO_USERS)))
            print(f'Updated password hash for {cur.rowcount} matching demo login(s).')
    print('Demo password is pass123 for the matching accounts.')


if __name__ == '__main__':
    main()
