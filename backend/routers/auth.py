from fastapi import APIRouter, HTTPException, status
from psycopg.rows import dict_row
from app.database import db_connection
from app.schemas import LoginRequest
from app.security import verify_password, create_access_token
from app.config import get_settings

router = APIRouter(prefix='/api/auth', tags=['authentication'])


@router.post('/login')
def login(payload: LoginRequest):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute('''SELECT l.login_id AS login_id, l.username AS username,
                              l.password_hash AS password_hash, lower(l.role) AS role,
                              l.employee_id AS employee_id, l.cif AS cif,
                              l.account_status AS account_status,
                              l.last_login AS previous_login,
                              c.status AS customer_status, c.first_name AS customer_first_name,
                              c.last_name AS customer_last_name, c.contact AS customer_contact,
                              c.pan AS customer_pan,
                              e.status AS employee_status, e.first_name AS employee_first_name,
                              e.last_name AS employee_last_name, e.contact AS employee_contact,
                              e.ifsc AS employee_ifsc, e.role AS employee_role,
                              b.branch_name AS branch_name, b.city AS branch_city
                       FROM login l
                       LEFT JOIN customer c ON c.cif = l.cif
                       LEFT JOIN employee e ON e.employee_id = l.employee_id
                       LEFT JOIN branch b ON b.ifsc = e.ifsc
                       WHERE lower(l.username) = lower(%s)''', (payload.username.strip(),))
        row = cur.fetchone()
        if not row or not verify_password(payload.password, row['password_hash']):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid username or password')
        if payload.role and row['role'] != payload.role.lower():
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"This account is not a {payload.role.title()} account")
        if row['account_status'] != 'Active':
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='This login is not active')
        if row['role'] == 'customer' and row['customer_status'] != 'Active':
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Customer account is not active')
        if row['role'] in {'employee', 'admin'} and row['employee_status'] != 'Active':
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Employee account is not active')
        cur.execute('UPDATE login SET last_login = CURRENT_TIMESTAMP WHERE login_id = %s', (row['login_id'],))

    claims = {'sub': row['username'], 'login_id': row['login_id'], 'role': row['role'],
              'employee_id': row['employee_id'], 'cif': row['cif']}
    token = create_access_token(claims)
    if row['role'] == 'customer':
        first_name = row.get('customer_first_name') or row['username']
        last_name = row.get('customer_last_name') or ''
        profile = {
            'CIF': row.get('cif'), 'FirstName': first_name, 'LastName': last_name,
            'DisplayName': f'{first_name} {last_name}'.strip(), 'Contact': row.get('customer_contact'),
            'PAN': row.get('customer_pan'), 'Initials': (first_name[:1] + last_name[:1]).upper(),
        }
    else:
        first_name = row.get('employee_first_name') or row['username']
        last_name = row.get('employee_last_name') or ''
        profile = {
            'Employee_ID': row.get('employee_id'), 'FirstName': first_name, 'LastName': last_name,
            'DisplayName': f'{first_name} {last_name}'.strip(), 'Contact': row.get('employee_contact'),
            'IFSC': row.get('employee_ifsc'), 'EmployeeRole': row.get('employee_role'),
            'BranchName': row.get('branch_name') or 'Corporate Office',
            'BranchCity': row.get('branch_city') or '',
            'Initials': (first_name[:1] + last_name[:1]).upper(),
        }
    data = {
        **profile, 'Login_ID': row['login_id'], 'Username': row['username'],
        'Role': row['role'], 'Account_Status': row['account_status'],
        'Last_Login': row['previous_login'].isoformat(sep=' ') if row.get('previous_login') else None,
        'access_token': token, 'token_type': 'bearer',
        'expires_in': get_settings().jwt_expire_minutes * 60,
    }
    return {'success': True, 'data': data, 'message': 'Login successful.'}
