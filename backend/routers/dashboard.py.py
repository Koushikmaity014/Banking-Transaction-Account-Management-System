from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from psycopg.rows import dict_row
from app.database import db_connection
from app.security import current_user, require_roles

import re
import secrets
from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from app.security import hash_password

router = APIRouter(prefix="/api", tags=["dashboards"])


def _rows(cur):
    return cur.fetchall()


def _money(value):
    return float(value or 0)


@router.get('/customer/dashboard')
def customer_dashboard(user: dict = Depends(require_roles('customer'))):
    cif = user.get('cif')
    if not cif:
        raise HTTPException(status_code=403, detail='Customer identity is missing from this login')
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute('''SELECT cif AS "CIF", first_name AS "First_Name", last_name AS "Last_Name",
                              dob AS "DOB", gender AS "Gender", contact AS "Contact", address AS "Address",
                              pan AS "PAN", status AS "Status"
                       FROM customer WHERE cif = %s''', (cif,))
        customer = cur.fetchone()
        if not customer:
            raise HTTPException(status_code=404, detail='Customer profile not found')

        cur.execute('''SELECT a.account_no AS "Account_No", a.cif AS "CIF", a.ifsc AS "IFSC",
                              a.nominee AS "Nominee", a.account_type_id AS "Account_Type_ID",
                              a.opening_date AS "Opening_Date", a.status AS "Status",
                              a.current_balance AS "Current_Balance", at.type_name AS "Type_Name",
                              at.interest_rate AS "Interest_Rate", b.branch_name AS "Branch_Name", b.city AS "Branch_City"
                       FROM account a
                       LEFT JOIN account_type at ON at.account_type_id = a.account_type_id
                       LEFT JOIN branch b ON b.ifsc = a.ifsc
                       WHERE a.cif = %s ORDER BY a.opening_date DESC''', (cif,))
        accounts = _rows(cur)

        cur.execute('''SELECT l.loan_id AS "Loan_ID", l.cif AS "CIF", l.account_no AS "Account_No",
                              l.loan_type_id AS "Loan_Type_ID", l.principal_amount AS "Principal_Amount",
                              l.remaining_amount AS "Remaining_Amount", l.emi_amount AS "EMI_Amount",
                              l.loan_status AS "Loan_Status", l.start_date AS "Start_Date", l.end_date AS "End_Date",
                              lt.loan_type_name AS "Loan_Type_Name"
                       FROM loan l LEFT JOIN loan_type lt ON lt.loan_type_id = l.loan_type_id
                       WHERE l.cif = %s ORDER BY l.start_date DESC NULLS LAST''', (cif,))
        loans = _rows(cur)

        for loan in loans:
            principal = _money(loan.get('Principal_Amount'))
            remaining = _money(loan.get('Remaining_Amount'))
            loan['Paid_Amount'] = max(0, principal - remaining)
            loan['Progress_Percent'] = min(100, round(loan['Paid_Amount'] / principal * 100)) if principal else 0
            loan['Loan_Type_Name'] = loan.get('Loan_Type_Name') or 'Term Loan'

        account_numbers = [a['Account_No'] for a in accounts]
        recent_transactions = []
        if account_numbers:
            cur.execute('''SELECT t.transaction_id AS "Transaction_ID", t.account_no AS "Account_No",
                                  t.transaction_type AS "Transaction_Type", t.amount AS "Amount",
                                  t.transaction_date_time AS "Transaction_Date_Time", t.balance_after AS "Balance_After",
                                  t.channel AS "Channel", t.status AS "Status"
                           FROM "TRANSACTION" t WHERE t.account_no = ANY(%s)
                           ORDER BY t.transaction_date_time DESC LIMIT 6''', (account_numbers,))
            recent_transactions = _rows(cur)
        for tx in recent_transactions:
            kind = str(tx.get('Transaction_Type') or '').lower()
            channel = str(tx.get('Channel') or '')
            tx['Description'] = ('Deposit / Inward Transfer' if kind == 'credit' else 'Payment / Transfer')
            if channel.upper() == 'UPI': tx['Description'] = 'UPI Received' if kind == 'credit' else 'UPI Merchant Payment'
            elif channel.upper() == 'ATM': tx['Description'] = 'ATM Cash Withdrawal'
            tx['Reference_No'] = f"REF{tx.get('Transaction_ID', '')}"

        # The existing dashboard chart is retained. These values are computed from
        # the actual transaction table for the latest six calendar months.
        cur.execute('''SELECT to_char(date_trunc('month', transaction_date_time), 'Mon') AS month,
                              COALESCE(SUM(CASE WHEN lower(transaction_type) = 'credit' THEN amount ELSE 0 END), 0) AS inflow,
                              COALESCE(SUM(CASE WHEN lower(transaction_type) = 'debit' THEN amount ELSE 0 END), 0) AS outflow
                       FROM "TRANSACTION" WHERE account_no = ANY(%s)
                         AND transaction_date_time >= date_trunc('month', CURRENT_DATE) - interval '5 months'
                       GROUP BY date_trunc('month', transaction_date_time)
                       ORDER BY date_trunc('month', transaction_date_time)''', (account_numbers or ['__no_accounts__'],))
        monthly = _rows(cur)

    active_loans = [l for l in loans if str(l.get('Loan_Status', '')).lower() == 'active']
    due_date = date.today().replace(day=min(5, 28))
    return {
        'success': True,
        'data': {
            'customer': customer,
            'accounts': accounts,
            'loans': loans,
            'recentTransactions': recent_transactions,
            'stats': {
                'totalBalance': sum(_money(a.get('Current_Balance')) for a in accounts),
                'numAccounts': len(accounts),
                'activeLoansCount': len(active_loans),
                'nextEmiAmount': _money(active_loans[0].get('EMI_Amount')) if active_loans else 0,
                'nextEmiDueDate': due_date.strftime('%d %b %Y'),
            },
            'spendingStats': {
                'months': [r['month'] for r in monthly] or ['No data'],
                'inflow': [_money(r['inflow']) for r in monthly] or [0],
                'outflow': [_money(r['outflow']) for r in monthly] or [0],
            },
        },
        'message': 'Customer dashboard data loaded.'
    }


@router.get('/employee/dashboard')
def employee_dashboard(user: dict = Depends(require_roles('employee', 'admin'))):
    employee_id = user.get('employee_id')
    if not employee_id:
        raise HTTPException(status_code=403, detail='Employee identity is missing from this login')
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute('''SELECT e.employee_id AS "Employee_ID", e.ifsc AS "IFSC", e.first_name AS "First_Name",
                              e.last_name AS "Last_Name", e.contact AS "Contact", e.role AS "Role", e.status AS "Status",
                              b.branch_name AS "Branch_Name", b.city AS "City"
                       FROM employee e LEFT JOIN branch b ON b.ifsc = e.ifsc
                       WHERE e.employee_id = %s''', (employee_id,))
        employee = cur.fetchone()
        if not employee:
            raise HTTPException(status_code=404, detail='Employee profile not found')
        ifsc = employee.get('IFSC')

        cur.execute('''SELECT COUNT(DISTINCT a.cif) AS customers, COUNT(*) AS accounts
                       FROM account a WHERE a.ifsc = %s''', (ifsc,))
        totals = cur.fetchone() or {}
        cur.execute('''SELECT COUNT(*) AS count FROM "TRANSACTION" t JOIN account a ON a.account_no=t.account_no
                       WHERE a.ifsc=%s AND t.transaction_date_time::date=CURRENT_DATE''', (ifsc,))
        today_count = (cur.fetchone() or {}).get('count', 0)

        cur.execute('''SELECT l.loan_id AS "Loan_ID", c.first_name || ' ' || c.last_name AS "Customer_Name",
                              l.cif AS "CIF", lt.loan_type_name AS "Loan_Type_Name", l.principal_amount AS "Principal_Amount",
                              l.tenure_months AS "Tenure_Months", lt.interest_rate AS "Interest_Rate", l.start_date AS "Date_Applied", l.loan_status AS "Status"
                       FROM loan l JOIN account a ON a.account_no=l.account_no
                       LEFT JOIN customer c ON c.cif=l.cif LEFT JOIN loan_type lt ON lt.loan_type_id=l.loan_type_id
                       WHERE a.ifsc=%s AND lower(l.loan_status) IN ('pending','applied')
                       ORDER BY l.start_date DESC NULLS LAST LIMIT 50''', (ifsc,))
        pending = _rows(cur)
        cur.execute('''SELECT t.transaction_id AS "Transaction_ID", t.account_no AS "Account_No",
                              t.transaction_type AS "Transaction_Type", t.amount AS "Amount",
                              t.transaction_date_time AS "Transaction_Date_Time", t.channel AS "Channel", t.status AS "Status",
                              COALESCE(c.first_name || ' ' || c.last_name, 'Account Holder') AS "Customer_Name"
                       FROM "TRANSACTION" t JOIN account a ON a.account_no=t.account_no
                       LEFT JOIN customer c ON c.cif=a.cif WHERE a.ifsc=%s
                       ORDER BY t.transaction_date_time DESC LIMIT 6''', (ifsc,))
        transactions = _rows(cur)
        cur.execute('''SELECT c.cif AS "CIF", c.first_name || ' ' || c.last_name AS "Name", c.contact AS "Contact",
                              c.pan AS "PAN", c.status AS "Status", COUNT(a.account_no) AS "Account_Count"
                       FROM customer c JOIN account a ON a.cif=c.cif WHERE a.ifsc=%s
                       GROUP BY c.cif,c.first_name,c.last_name,c.contact,c.pan,c.status
                       ORDER BY MAX(a.opening_date) DESC LIMIT 5''', (ifsc,))
        recent_customers = _rows(cur)

    return {'success': True, 'data': {
        'employee': employee,
        'branch': {'IFSC': ifsc, 'Branch_Name': employee.get('Branch_Name'), 'City': employee.get('City')},
        'stats': {'totalCustomers': totals.get('customers', 0), 'totalAccounts': totals.get('accounts', 0),
                  'todayTransactions': today_count, 'pendingLoans': len(pending)},
        'pendingLoanApplications': pending,
        'recentBranchTransactions': transactions,
        'recentlyAddedCustomers': recent_customers,
    }, 'message': 'Employee dashboard data loaded.'}


@router.get('/employee/customers')
def employee_customer_directory(
    user: dict = Depends(require_roles('employee', 'admin'))
):
    """Return all customers who have at least one account at the logged-in employee's branch."""
    employee_id = user.get('employee_id')
    if not employee_id:
        raise HTTPException(
            status_code=403,
            detail='Employee identity is missing from this login'
        )

    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """SELECT e.ifsc
               FROM employee e
               WHERE e.employee_id = %s AND e.status = 'Active'""",
            (employee_id,)
        )
        employee = cur.fetchone()
        if not employee:
            raise HTTPException(
                status_code=403,
                detail='Active employee profile not found'
            )

        ifsc = employee.get('ifsc')
        if not ifsc:
            raise HTTPException(
                status_code=403,
                detail='Employee is not assigned to a branch'
            )

        cur.execute(
            """SELECT c.cif AS "CIF",
                      c.first_name || ' ' || c.last_name AS "Name",
                      c.contact AS "Contact",
                      c.pan AS "PAN",
                      c.status AS "Status",
                      COUNT(DISTINCT a.account_no) AS "Account_Count"
               FROM customer c
               JOIN account a ON a.cif = c.cif
               WHERE a.ifsc = %s
               GROUP BY c.cif, c.first_name, c.last_name,
                        c.contact, c.pan, c.status
               ORDER BY c.first_name, c.last_name, c.cif""",
            (ifsc,)
        )
        customers = cur.fetchall()

    return {
        'success': True,
        'data': customers,
        'message': 'Branch customer directory loaded.'
    }


@router.get('/admin/dashboard')
def admin_dashboard(user: dict = Depends(require_roles('admin'))):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute('''SELECT COUNT(*) AS branches FROM branch'''); total_branches = cur.fetchone()['branches']
        cur.execute('''SELECT COUNT(*) AS employees FROM employee'''); total_employees = cur.fetchone()['employees']
        cur.execute('''SELECT COUNT(*) AS customers FROM customer'''); total_customers = cur.fetchone()['customers']
        cur.execute('''SELECT COALESCE(SUM(current_balance),0) AS deposits FROM account'''); total_deposits = _money(cur.fetchone()['deposits'])
        cur.execute('''SELECT COUNT(*) FILTER (WHERE lower(loan_status)='active') AS active,
                              COUNT(*) FILTER (WHERE lower(loan_status) IN ('pending','applied')) AS pending,
                              COUNT(*) FILTER (WHERE lower(loan_status)='closed') AS closed,
                              COUNT(*) FILTER (WHERE lower(loan_status)='rejected') AS rejected
                       FROM loan'''); loan_summary = cur.fetchone()
        cur.execute('''SELECT b.ifsc AS "IFSC", b.branch_name AS "Branch_Name", b.city AS "City",
                              COALESCE(m.first_name || ' ' || m.last_name, 'Not Assigned') AS "Manager_Name",
                              COUNT(a.account_no) AS "Total_Accounts", COALESCE(SUM(a.current_balance),0) AS "Total_Deposits",
                              b.status AS "Status"
                       FROM branch b LEFT JOIN employee m ON m.employee_id=b.manager_id
                       LEFT JOIN account a ON a.ifsc=b.ifsc
                       GROUP BY b.ifsc,b.branch_name,b.city,m.first_name,m.last_name,b.status
                       ORDER BY b.branch_name''')
        branch_overview = _rows(cur)
        cur.execute('''SELECT login_id AS "Login_ID", username AS "Username", role AS "Role",
                              last_login AS "Last_Login", account_status AS "Account_Status"
                       FROM login ORDER BY last_login DESC NULLS LAST LIMIT 10''')
        recent_logins = _rows(cur)
        cur.execute('''SELECT transaction_id AS "Transaction_ID", account_no AS "Account_No",
                              transaction_type AS "Transaction_Type", channel AS "Channel",
                              transaction_date_time AS "Transaction_Date_Time", amount AS "Amount", status AS "Status"
                       FROM "TRANSACTION" ORDER BY transaction_date_time DESC LIMIT 6''')
        recent_transactions = _rows(cur)
        cur.execute('''SELECT at.type_name AS label, COUNT(a.account_no) AS count,
                              COALESCE(SUM(a.current_balance),0) AS balance
                       FROM account_type at LEFT JOIN account a ON a.account_type_id=at.account_type_id
                       GROUP BY at.account_type_id,at.type_name ORDER BY at.type_name''')
        account_type_rows = _rows(cur)
        cur.execute('''SELECT to_char(date_trunc('month',transaction_date_time),'Mon YYYY') AS month,
                              COALESCE(SUM(amount),0)/100000.0 AS volume,
                              COUNT(*) AS count
                       FROM "TRANSACTION"
                       WHERE transaction_date_time >= date_trunc('month',CURRENT_DATE)-interval '5 months'
                       GROUP BY date_trunc('month',transaction_date_time)
                       ORDER BY date_trunc('month',transaction_date_time)''')
        trend = _rows(cur)

    labels = [r['label'] for r in account_type_rows]
    return {'success': True, 'data': {
        'stats': {'totalBranches': total_branches, 'totalEmployees': total_employees,
                  'totalCustomers': total_customers, 'totalDeposits': total_deposits,
                  'activeLoans': loan_summary['active'], 'pendingLoans': loan_summary['pending']},
        'accountsByType': {'labels': labels, 'counts': [r['count'] for r in account_type_rows],
                           'balances': [_money(r['balance']) for r in account_type_rows]},
        'transactionMonthlyTrend': {'months': [r['month'] for r in trend] or ['No data'],
                                    'volumeInLakhs': [_money(r['volume']) for r in trend] or [0],
                                    'transactionCounts': [r['count'] for r in trend] or [0]},
        'branchOverview': branch_overview,
        'recentLogins': recent_logins,
        'recentTransactions': recent_transactions,
        'loanStatusSummary': {'Active': loan_summary['active'], 'Pending': loan_summary['pending'],
                              'Closed': loan_summary['closed'], 'Rejected': loan_summary['rejected']},
    }, 'message': 'Admin dashboard data loaded.'}


@router.get('/branches')
def branches(user: dict = Depends(current_user)):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute('''SELECT ifsc AS "IFSC", branch_name AS "Branch_Name", micr AS "MICR",
                              address AS "Address", city AS "City", state AS "State", pin AS "PIN",
                              contact AS "Contact", opening_date AS "Opening_Date", status AS "Status"
                       FROM branch ORDER BY branch_name''')
        return {'success': True, 'data': _rows(cur), 'message': 'Branches fetched successfully.'}



# ============================================================
# ADMIN: EMPLOYEE MANAGEMENT
# ============================================================

class EmployeeCreateRequest(BaseModel):
    ifsc: str = Field(min_length=11, max_length=11)
    first_name: str = Field(min_length=1, max_length=50)
    last_name: str = Field(min_length=1, max_length=50)
    dob: date
    gender: str | None = Field(default=None, pattern=r"^(Male|Female|Other)$")
    contact: str = Field(min_length=7, max_length=20)
    address: str | None = Field(default=None, max_length=255)
    role: str = Field(pattern=r"^(Employee|Manager)$")
    salary: float = Field(ge=0)


@router.get("/admin/employees")
def list_employees(user: dict = Depends(require_roles("admin"))):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            SELECT e.employee_id AS "Employee_ID",
                   e.ifsc AS "IFSC",
                   b.branch_name AS "Branch_Name",
                   e.first_name AS "First_Name",
                   e.last_name AS "Last_Name",
                   e.dob AS "DOB",
                   e.gender AS "Gender",
                   e.contact AS "Contact",
                   e.address AS "Address",
                   e.joining_date AS "Joining_Date",
                   e.role AS "Role",
                   e.salary AS "Salary",
                   e.status AS "Status",
                   l.username AS "Username",
                   l.account_status AS "Login_Status"
            FROM employee e
            LEFT JOIN branch b ON b.ifsc = e.ifsc
            LEFT JOIN login l ON l.employee_id = e.employee_id
            ORDER BY e.joining_date DESC, e.employee_id
        """)
        employees = cur.fetchall()

    return {
        "success": True,
        "data": employees,
        "message": "Employees fetched successfully."
    }


@router.post("/admin/employees", status_code=201)
def create_employee(
    payload: EmployeeCreateRequest,
    user: dict = Depends(require_roles("admin"))
):
    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()

    if not first_name or not last_name:
        raise HTTPException(
            status_code=422,
            detail="First name and last name are required."
        )

    if payload.dob >= date.today():
        raise HTTPException(
            status_code=422,
            detail="Date of birth must be in the past."
        )

    if not re.fullmatch(r"[A-Z]{4}0[A-Z0-9]{6}", payload.ifsc):
        raise HTTPException(
            status_code=422,
            detail="Enter a valid IFSC code."
        )

    # A unique employee ID is generated by the backend.
    employee_id = "EMP" + secrets.token_hex(6).upper()

    # Username is based on the employee's name. A numeric suffix
    # is added if that username already exists.
    username_base = (
        re.sub(r"[^a-z0-9]", "", first_name.lower())
        + "."
        + re.sub(r"[^a-z0-9]", "", last_name.lower())
    )

    if not username_base.strip("."):
        raise HTTPException(
            status_code=422,
            detail="Name cannot be used to generate a username."
        )

    initial_password = (
        re.sub(r"[^a-zA-Z]", "", first_name).lower()
        + payload.dob.strftime("%d%m")
    )

    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            "SELECT 1 FROM branch WHERE ifsc = %s AND status = 'Active'",
            (payload.ifsc,)
        )
        if not cur.fetchone():
            raise HTTPException(
                status_code=400,
                detail="The selected branch does not exist or is inactive."
            )

        username = username_base
        suffix = 2

        while True:
            cur.execute(
                "SELECT 1 FROM login WHERE username = %s",
                (username,)
            )
            if not cur.fetchone():
                break

            username = f"{username_base}{suffix}"
            suffix += 1

        cur.execute("""
            INSERT INTO employee (
                employee_id, ifsc, first_name, last_name, dob,
                gender, contact, address, joining_date, role, salary, status
            )
            VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s,
                CURRENT_DATE, %s, %s, 'Active'
            )
        """, (
            employee_id,
            payload.ifsc,
            first_name,
            last_name,
            payload.dob,
            payload.gender,
            payload.contact.strip(),
            payload.address.strip() if payload.address else None,
            payload.role,
            payload.salary
        ))

        # Store only the password hash. The plaintext initial password
        # is returned once to the authorized administrator.
        cur.execute("""
            INSERT INTO login (
                username, password_hash, role, employee_id,
                cif, account_status
            )
            VALUES (%s, %s, %s, %s, NULL, 'Active')
        """, (
            username,
            hash_password(initial_password),
            "employee",
            employee_id
        ))

    return {
        "success": True,
        "data": {
            "employee_id": employee_id,
            "username": username,
            "initial_password": initial_password
        },
        "message": "Employee and login account created successfully."
    }


@router.delete("/admin/employees/{employee_id}")
def deactivate_employee(
    employee_id: str,
    user: dict = Depends(require_roles("admin"))
):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute("""
            SELECT employee_id, first_name, last_name, role, status
            FROM employee
            WHERE employee_id = %s
            FOR UPDATE
        """, (employee_id,))
        employee = cur.fetchone()

        if not employee:
            raise HTTPException(
                status_code=404,
                detail="Employee not found."
            )

        if employee["status"] == "Inactive":
            return {
                "success": True,
                "message": "Employee is already inactive."
            }

        # The branch-manager trigger prevents deactivation of an employee
        # who is still assigned as a branch manager.
        cur.execute("""
            SELECT ifsc, branch_name
            FROM branch
            WHERE manager_id = %s
        """, (employee_id,))
        managed_branches = cur.fetchall()

        if managed_branches:
            branch_names = ", ".join(
                row["branch_name"] for row in managed_branches
            )
            raise HTTPException(
                status_code=409,
                detail=(
                    "Reassign the branch manager before deactivating this "
                    f"employee. Currently assigned branch(es): {branch_names}."
                )
            )

        cur.execute("""
            UPDATE employee
            SET status = 'Inactive'
            WHERE employee_id = %s
        """, (employee_id,))

        # The existing trigger synchronizes the linked login to Disabled.

    return {
        "success": True,
        "message": "Employee deactivated and login access disabled."
    }

