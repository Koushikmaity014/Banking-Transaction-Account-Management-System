from decimal import Decimal
from uuid import uuid4
from fastapi import HTTPException
from psycopg.rows import dict_row
from app.database import db_connection

CHANNELS = {"Branch", "ATM", "Online_Banking", "UPI", "POS", "Cheque", "NEFT", "RTGS", "IMPS"}
TRANSFER_MODES = {"UPI", "Internal_Transfer", "Cheque", "NEFT", "RTGS", "IMPS"}
PAYMENT_METHODS = TRANSFER_MODES


def new_transaction_id(prefix: str = "TX") -> str:
    # TX + 18 hex chars = 20 characters, matching VARCHAR(20).
    return f"{prefix}{uuid4().hex[:18].upper()}"


def new_reference() -> str:
    return f"REF{uuid4().hex[:27].upper()}"[:30]


def assert_account_access(conn, user: dict, account_no: str, *, allow_staff: bool = True) -> dict:
    with conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            '''
            SELECT a.account_no AS account_no, a.cif AS cif, a.ifsc AS ifsc,
                   a.account_type_id AS account_type_id, a.status AS status,
                   a.current_balance AS current_balance
            FROM account a
            WHERE a.account_no = %s
            ''',
            (account_no,),
        )
        account = cur.fetchone()
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    if user["role"] == "customer":
        if account["cif"] != user.get("cif"):
            raise HTTPException(status_code=403, detail="You are not authorized to access this account")
    elif not allow_staff or user["role"] not in {"employee", "admin"}:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    elif user["role"] == "employee":
        # Staff access is limited to the branch assigned to that employee.
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT ifsc FROM employee WHERE employee_id = %s AND status = 'Active'",
                (user.get("employee_id"),),
            )
            staff = cur.fetchone()
        if not staff or staff["ifsc"] != account["ifsc"]:
            raise HTTPException(status_code=403, detail="Employee access is limited to their assigned branch")
    return account


def list_accounts(user: dict):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        if user["role"] == "customer":
            cur.execute(
                '''SELECT account_no AS account_no, ifsc AS ifsc,
                          account_type_id AS account_type_id, status AS status,
                          current_balance AS current_balance, opening_date AS opening_date
                   FROM account WHERE cif = %s ORDER BY opening_date DESC''',
                (user["cif"],),
            )
        elif user["role"] == "employee":
            cur.execute(
                '''SELECT account_no AS account_no, ifsc AS ifsc,
                          account_type_id AS account_type_id, status AS status,
                          current_balance AS current_balance, opening_date AS opening_date
                   FROM account
                   WHERE ifsc = (SELECT ifsc FROM employee WHERE employee_id = %s AND status = 'Active')
                   ORDER BY opening_date DESC LIMIT 100''',
                (user.get("employee_id"),),
            )
        else:
            cur.execute(
                '''SELECT account_no AS account_no, ifsc AS ifsc,
                          account_type_id AS account_type_id, status AS status,
                          current_balance AS current_balance, opening_date AS opening_date
                   FROM account ORDER BY opening_date DESC LIMIT 100'''
            )
        return cur.fetchall()


def get_account(user: dict, account_no: str):
    with db_connection() as conn:
        return assert_account_access(conn, user, account_no)


def transaction_history(user: dict, account_no: str, limit: int = 50, offset: int = 0):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        assert_account_access(conn, user, account_no)
        cur.execute(
            '''SELECT transaction_id AS transaction_id,
                      transaction_type AS transaction_type,
                      amount AS amount,
                      transaction_date_time AS transaction_date_time,
                      balance_after AS balance_after,
                      channel AS channel, status AS status
               FROM "TRANSACTION"
               WHERE account_no = %s
               ORDER BY transaction_date_time DESC, transaction_id DESC
               LIMIT %s OFFSET %s''',
            (account_no, limit, offset),
        )
        return cur.fetchall()


def deposit(user: dict, account_no: str, amount: Decimal, channel: str):
    if channel not in CHANNELS:
        raise HTTPException(status_code=422, detail="Invalid transaction channel")
    if user["role"] == "customer":
        employee_id = None
    else:
        employee_id = user.get("employee_id")
    txid = new_transaction_id()
    with db_connection() as conn:
        assert_account_access(conn, user, account_no)
        with conn.cursor() as cur:
            cur.execute("CALL sp_deposit(%s, %s, %s, %s, %s)", (txid, account_no, amount, channel, employee_id))
    return {"transaction_id": txid, "status": "Completed"}


def withdraw(user: dict, account_no: str, amount: Decimal, channel: str):
    if channel not in CHANNELS:
        raise HTTPException(status_code=422, detail="Invalid transaction channel")
    employee_id = None if user["role"] == "customer" else user.get("employee_id")
    txid = new_transaction_id()
    with db_connection() as conn:
        assert_account_access(conn, user, account_no)
        with conn.cursor() as cur:
            cur.execute("CALL sp_withdraw(%s, %s, %s, %s, %s)", (txid, account_no, amount, channel, employee_id))
    return {"transaction_id": txid, "status": "Completed"}


def transfer(user: dict, from_account: str, to_account: str, amount: Decimal, mode: str):
    if mode not in TRANSFER_MODES:
        raise HTTPException(status_code=422, detail="Invalid transfer mode")
    if from_account == to_account:
        raise HTTPException(status_code=422, detail="Source and destination accounts must differ")
    debit_id, credit_id, reference = new_transaction_id("D"), new_transaction_id("C"), new_reference()
    employee_id = None if user["role"] == "customer" else user.get("employee_id")
    with db_connection() as conn:
        assert_account_access(conn, user, from_account)
        # Destination must exist and be active; customer ownership is not required for receiving funds.
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute('SELECT status AS status FROM account WHERE account_no = %s', (to_account,))
            destination = cur.fetchone()
        if not destination:
            raise HTTPException(status_code=404, detail="Destination account not found")
        if destination["status"] != "Active":
            raise HTTPException(status_code=409, detail="Destination account is not active")
        with conn.cursor() as cur:
            cur.execute(
                "CALL sp_fund_transfer(%s, %s, %s, %s, %s, %s, %s, %s)",
                (debit_id, credit_id, from_account, to_account, amount, mode, reference, employee_id),
            )
    return {"reference_no": reference, "debit_transaction_id": debit_id,
            "credit_transaction_id": credit_id, "status": "Completed"}


def loan_list(user: dict):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        if user["role"] == "customer":
            cur.execute(
                '''SELECT loan_id AS loan_id, loan_type_id AS loan_type_id,
                          account_no AS account_no, principal_amount AS principal_amount,
                          remaining_amount AS remaining_amount, emi_amount AS emi_amount,
                          loan_status AS loan_status, start_date AS start_date, end_date AS end_date
                   FROM loan WHERE cif = %s ORDER BY loan_id''',
                (user["cif"],),
            )
        elif user["role"] == "employee":
            cur.execute(
                '''SELECT l.loan_id AS loan_id, l.cif AS cif, l.loan_type_id AS loan_type_id,
                          l.account_no AS account_no, l.principal_amount AS principal_amount,
                          l.remaining_amount AS remaining_amount, l.emi_amount AS emi_amount,
                          l.loan_status AS loan_status, l.start_date AS start_date, l.end_date AS end_date
                   FROM loan l JOIN account a ON a.account_no = l.account_no
                   WHERE a.ifsc = (SELECT ifsc FROM employee WHERE employee_id = %s AND status = 'Active')
                   ORDER BY l.loan_id LIMIT 100''',
                (user.get("employee_id"),),
            )
        else:
            cur.execute(
                '''SELECT loan_id AS loan_id, cif AS cif, loan_type_id AS loan_type_id,
                          account_no AS account_no, principal_amount AS principal_amount,
                          remaining_amount AS remaining_amount, emi_amount AS emi_amount,
                          loan_status AS loan_status, start_date AS start_date, end_date AS end_date
                   FROM loan ORDER BY loan_id LIMIT 100'''
            )
        return cur.fetchall()


def apply_loan(user: dict, account_no: str, loan_type_id: str, principal: Decimal, tenure_months: int):
    if user["role"] != "customer":
        raise HTTPException(status_code=403, detail="Use the employee loan workflow for staff-assisted applications")
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        assert_account_access(conn, user, account_no)
        cur.execute(
            '''SELECT lt.interest_rate AS interest_rate, lt.max_amount AS max_amount,
                      a.cif AS cif
               FROM loan_type lt CROSS JOIN account a
               WHERE lt.loan_type_id = %s AND a.account_no = %s AND a.cif = %s''',
            (loan_type_id, account_no, user["cif"]),
        )
        info = cur.fetchone()
        if not info:
            raise HTTPException(status_code=404, detail="Loan type or eligible account not found")
        if principal > info["max_amount"]:
            raise HTTPException(status_code=422, detail="Principal exceeds the maximum amount for this loan type")
        rate = Decimal(info["interest_rate"]) / Decimal(100) / Decimal(12)
        if rate == 0:
            emi = principal / Decimal(tenure_months)
        else:
            factor = (Decimal(1) + rate) ** tenure_months
            emi = principal * rate * factor / (factor - Decimal(1))
        emi = emi.quantize(Decimal("0.01"))
        loan_id = "LN" + uuid4().hex[:10].upper()
        # Application has no approving employee yet; schema patch makes Employee_ID nullable.
        cur.execute(
            "CALL sp_apply_loan(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            (loan_id, user["cif"], account_no, loan_type_id, None, principal,
             Decimal(info["interest_rate"]), tenure_months, emi, None, None),
        )
        return {"loan_id": loan_id, "loan_status": "Applied", "emi_amount": emi}


def decide_loan(user: dict, loan_id: str, decision: str):
    if user["role"] not in {"employee", "admin"}:
        raise HTTPException(status_code=403, detail="Only authorized staff may decide loan applications")
    if decision not in {"Approved", "Rejected"}:
        raise HTTPException(status_code=422, detail="Decision must be Approved or Rejected")
    employee_id = user.get("employee_id")
    if not employee_id:
        raise HTTPException(status_code=403, detail="Staff identity is missing")
    with db_connection() as conn, conn.cursor() as cur:
        cur.execute("CALL sp_approve_loan(%s, %s, %s)", (loan_id, employee_id, decision))
    return {"loan_id": loan_id, "decision": decision}


def pay_loan(user: dict, loan_id: str, principal_paid: Decimal, interest_paid: Decimal, method: str):
    if method not in PAYMENT_METHODS:
        raise HTTPException(status_code=422, detail="Invalid loan payment method")
    employee_id = None if user["role"] == "customer" else user.get("employee_id")
    payment_id = "LP" + uuid4().hex[:10].upper()
    txid = new_transaction_id()
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            '''SELECT l.account_no AS account_no, l.cif AS cif
               FROM loan l WHERE l.loan_id = %s''',
            (loan_id,),
        )
        loan = cur.fetchone()
        if not loan:
            raise HTTPException(status_code=404, detail="Loan not found")
        if user["role"] == "customer" and loan["cif"] != user.get("cif"):
            raise HTTPException(status_code=403, detail="You are not authorized to pay this loan")
        assert_account_access(conn, user, loan["account_no"])
        cur.execute(
            "CALL sp_loan_payment(%s, %s, %s, %s, %s, %s, %s)",
            (payment_id, txid, loan_id, principal_paid, interest_paid, method, employee_id),
        )
    return {"payment_id": payment_id, "transaction_id": txid, "status": "Completed"}
