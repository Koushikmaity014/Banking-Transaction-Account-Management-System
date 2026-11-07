
from uuid import uuid4
from datetime import date

from fastapi import APIRouter, Depends, Query, HTTPException
from psycopg.rows import dict_row

from app.database import db_connection
from app.security import current_user, require_roles, hash_password
from app.schemas import (
    DepositRequest,
    WithdrawalRequest,
    TransferRequest,
    OpenAccountRequest,
    CustomerCreateRequest,
)
from app.services import banking


router = APIRouter(prefix="/api", tags=["accounts"])


def _new_cif():
    # CIF plus 12 hexadecimal characters = 15 characters.
    return "CIF" + uuid4().hex[:12].upper()


# =========================================================
# CUSTOMER PROFILE
# GET /api/accounts/profile
# =========================================================

@router.get("/accounts/profile")
def get_customer_profile(
    user: dict = Depends(current_user),
):
    # Only customers can access this endpoint.
    if user.get("role") != "customer":
        raise HTTPException(
            status_code=403,
            detail="This profile endpoint is for customers only.",
        )

    # The CIF comes from the authenticated session, not the browser.
    cif = user.get("cif")

    if not cif:
        raise HTTPException(
            status_code=401,
            detail="Customer identity is missing from the login session.",
        )

    with db_connection() as conn, conn.cursor(
        row_factory=dict_row
    ) as cur:

        # Fetch the customer's personal details.
        cur.execute(
            """
            SELECT
                cif,
                first_name,
                last_name,
                dob,
                gender,
                contact,
                pan,
                aadhar_no,
                address,
                status
            FROM customer
            WHERE cif = %s
            """,
            (cif,),
        )

        customer = cur.fetchone()

        if not customer:
            raise HTTPException(
                status_code=404,
                detail="Customer profile not found.",
            )

        # Fetch all accounts belonging to this customer.
        cur.execute(
            """
            SELECT
                a.account_no,
                a.cif,
                a.ifsc,
                a.nominee,
                a.account_type_id,
                a.opening_date,
                a.status,
                a.current_balance,
                at.type_name AS account_type_name
            FROM account AS a
            LEFT JOIN account_type AS at
                ON at.account_type_id = a.account_type_id
            WHERE a.cif = %s
            ORDER BY a.opening_date DESC NULLS LAST
            """,
            (cif,),
        )

        accounts = cur.fetchall()

        # Convert date and decimal values into JSON-friendly values.
        customer["dob"] = (
            customer["dob"].isoformat()
            if customer.get("dob")
            else None
        )

        account_list = []

        for account in accounts:
            account["opening_date"] = (
                account["opening_date"].isoformat()
                if account.get("opening_date")
                else None
            )

            if account.get("current_balance") is not None:
                account["current_balance"] = str(
                    account["current_balance"]
                )

            account_list.append(account)

        return {
            "customer": customer,
            "accounts": account_list,
            "total_accounts": len(account_list),
        }


# =========================================================
# LIST ACCOUNTS
# GET /api/accounts
# =========================================================

@router.get("/accounts")
def accounts(
    user: dict = Depends(current_user),
):
    return banking.list_accounts(user)


# =========================================================
# ACCOUNT DETAILS
# GET /api/accounts/{account_no}
# =========================================================

@router.get("/accounts/{account_no}")
def account_detail(
    account_no: str,
    user: dict = Depends(current_user),
):
    return banking.get_account(user, account_no)


# =========================================================
# ACCOUNT TRANSACTION HISTORY
# GET /api/accounts/{account_no}/transactions
# =========================================================

@router.get("/accounts/{account_no}/transactions")
def transactions(
    account_no: str,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user: dict = Depends(current_user),
):
    return banking.transaction_history(
        user,
        account_no,
        limit,
        offset,
    )


# =========================================================
# DEPOSIT
# POST /api/deposits
# =========================================================

@router.post("/deposits")
def make_deposit(
    payload: DepositRequest,
    user: dict = Depends(current_user),
):
    return banking.deposit(
        user,
        payload.account_no,
        payload.amount,
        payload.channel,
    )


# =========================================================
# WITHDRAWAL
# POST /api/withdrawals
# =========================================================

@router.post("/withdrawals")
def make_withdrawal(
    payload: WithdrawalRequest,
    user: dict = Depends(current_user),
):
    return banking.withdraw(
        user,
        payload.account_no,
        payload.amount,
        payload.channel,
    )


# =========================================================
# FUND TRANSFER
# POST /api/transfers
# =========================================================

@router.post("/transfers")
def make_transfer(
    payload: TransferRequest,
    user: dict = Depends(current_user),
):
    return banking.transfer(
        user,
        payload.from_account_no,
        payload.to_account_no,
        payload.amount,
        payload.transfer_mode,
    )


# =========================================================
# ACCOUNT TYPES
# GET /api/account-types
# =========================================================

@router.get("/account-types")
def account_types(
    user: dict = Depends(require_roles("employee", "admin")),
):
    with db_connection() as conn, conn.cursor(
        row_factory=dict_row
    ) as cur:
        cur.execute(
            """
            SELECT
                account_type_id AS account_type_id,
                type_name AS type_name,
                minimum_balance AS minimum_balance,
                interest_rate AS interest_rate
            FROM account_type
            ORDER BY type_name
            """
        )

        return cur.fetchall()


# =========================================================
# CREATE CUSTOMER AND LOGIN CREDENTIALS
# POST /api/customers
# =========================================================

@router.post("/customers", status_code=201)
def create_customer(
    payload: CustomerCreateRequest,
    user: dict = Depends(require_roles("employee", "admin")),
):
    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()

    if not first_name or not last_name:
        raise HTTPException(
            status_code=422,
            detail="First name and last name are required.",
        )

    if payload.dob >= date.today():
        raise HTTPException(
            status_code=422,
            detail="Date of birth must be in the past.",
        )

    cif = _new_cif()

    # Username format: firstname.lastname
    base_username = (
        f"{first_name}.{last_name}"
        .lower()
        .replace(" ", "")
    )

    # Initial password: firstname + birth day + birth month.
    # Example: Rahul born on 13 September -> rahul1309.
    initial_password = (
        first_name.lower() + payload.dob.strftime("%d%m")
    )

    password_hash_value = hash_password(initial_password)

    with db_connection() as conn, conn.cursor(
        row_factory=dict_row
    ) as cur:

        # Validate employee status when an employee creates a customer.
        if user["role"] == "employee":
            cur.execute(
                """
                SELECT employee_id
                FROM employee
                WHERE employee_id = %s
                  AND status = 'Active'
                """,
                (user.get("employee_id"),),
            )

            if not cur.fetchone():
                raise HTTPException(
                    status_code=403,
                    detail="An active employee account is required.",
                )

        # Ensure username uniqueness.
        username = base_username
        suffix = 2

        while True:
            cur.execute(
                """
                SELECT 1
                FROM login
                WHERE username = %s
                """,
                (username,),
            )

            if not cur.fetchone():
                break

            username = f"{base_username}{suffix}"
            suffix += 1

        # Insert customer information.
        cur.execute(
            """
            INSERT INTO customer (
                cif,
                first_name,
                last_name,
                dob,
                gender,
                contact,
                pan,
                aadhar_no,
                address,
                status
            )
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, 'Active'
            )
            RETURNING
                cif AS "CIF",
                first_name AS "First_Name",
                last_name AS "Last_Name",
                status AS "Status"
            """,
            (
                cif,
                first_name,
                last_name,
                payload.dob,
                payload.gender,
                payload.contact.strip(),
                payload.pan.strip().upper(),
                payload.aadhar_no.strip(),
                payload.address.strip() if payload.address else None,
            ),
        )

        customer = cur.fetchone()

        # Create login credentials. Store only the password hash.
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
            VALUES (
                %s, %s, 'customer', NULL, %s, 'Active'
            )
            """,
            (
                username,
                password_hash_value,
                cif,
            ),
        )

    return {
        "message": "Customer and login credentials created successfully",
        "customer": customer,
        "credentials": {
            "username": username,
            "initial_password": initial_password,
            "note": (
                "Give these credentials securely to the customer. "
                "The database stores only the password hash."
            ),
        },
    }


@router.get("/customers/{cif}/profile")
def get_staff_customer_profile(
    cif: str,
    user: dict = Depends(require_roles("employee", "admin")),
):
    with db_connection() as conn, conn.cursor(
        row_factory=dict_row
    ) as cur:

        staff_ifsc = None

        if user["role"] == "employee":
            cur.execute(
                """
                SELECT ifsc
                FROM employee
                WHERE employee_id = %s
                  AND status = 'Active'
                """,
                (user.get("employee_id"),),
            )

            employee = cur.fetchone()

            if not employee:
                raise HTTPException(
                    status_code=403,
                    detail="An active employee account is required.",
                )

            staff_ifsc = employee["ifsc"]

        # Fetch the selected customer's details.
        if staff_ifsc:
            cur.execute(
                """
                SELECT
                    c.cif,
                    c.first_name,
                    c.last_name,
                    c.dob,
                    c.gender,
                    c.contact,
                    c.pan,
                    c.aadhar_no,
                    c.address,
                    c.status
                FROM customer c
                WHERE c.cif = %s
                  AND EXISTS (
                      SELECT 1
                      FROM account a
                      WHERE a.cif = c.cif
                        AND a.ifsc = %s
                  )
                """,
                (cif, staff_ifsc),
            )
        else:
            cur.execute(
                """
                SELECT
                    cif,
                    first_name,
                    last_name,
                    dob,
                    gender,
                    contact,
                    pan,
                    aadhar_no,
                    address,
                    status
                FROM customer
                WHERE cif = %s
                """,
                (cif,),
            )

        customer = cur.fetchone()

        if not customer:
            raise HTTPException(
                status_code=404,
                detail="Customer not found or not accessible to this branch.",
            )

        if customer.get("dob"):
            customer["dob"] = customer["dob"].isoformat()

        # Return only accounts at the employee's branch, or all accounts
        # for an admin.
        if staff_ifsc:
            cur.execute(
                """
                SELECT
                    a.account_no,
                    a.ifsc,
                    a.nominee,
                    a.account_type_id,
                    at.type_name AS account_type_name,
                    a.opening_date,
                    a.status,
                    a.current_balance
                FROM account a
                LEFT JOIN account_type at
                    ON at.account_type_id = a.account_type_id
                WHERE a.cif = %s
                  AND a.ifsc = %s
                ORDER BY a.opening_date DESC NULLS LAST
                """,
                (cif, staff_ifsc),
            )
        else:
            cur.execute(
                """
                SELECT
                    a.account_no,
                    a.ifsc,
                    a.nominee,
                    a.account_type_id,
                    at.type_name AS account_type_name,
                    a.opening_date,
                    a.status,
                    a.current_balance
                FROM account a
                LEFT JOIN account_type at
                    ON at.account_type_id = a.account_type_id
                WHERE a.cif = %s
                ORDER BY a.opening_date DESC NULLS LAST
                """,
                (cif,),
            )

        accounts = cur.fetchall()

        for account in accounts:
            if account.get("opening_date"):
                account["opening_date"] = (
                    account["opening_date"].isoformat()
                )

            if account.get("current_balance") is not None:
                account["current_balance"] = str(
                    account["current_balance"]
                )

        return {
            "customer": customer,
            "accounts": accounts,
            "total_accounts": len(accounts),
        }


# =========================================================
# OPEN ACCOUNT
# POST /api/accounts
# =========================================================

@router.post("/accounts", status_code=201)
def open_account(
    payload: OpenAccountRequest,
    user: dict = Depends(require_roles("employee", "admin")),
):
    account_no = banking.new_transaction_id("AC")

    with db_connection() as conn, conn.cursor() as cur:

        # Employees can open accounts only at their assigned branch.
        if user["role"] == "employee":
            cur.execute(
                """
                SELECT ifsc
                FROM employee
                WHERE employee_id = %s
                  AND status = 'Active'
                """,
                (user.get("employee_id"),),
            )

            staff_branch = cur.fetchone()

            if not staff_branch:
                raise HTTPException(
                    status_code=403,
                    detail="Active employee record not found.",
                )

            if staff_branch[0] != payload.ifsc:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        "Employees may open accounts only "
                        "at their assigned branch."
                    ),
                )

        cur.execute(
            """
            CALL sp_open_account(%s, %s, %s, %s, %s, %s)
            """,
            (
                account_no,
                payload.cif,
                payload.ifsc,
                payload.nominee,
                payload.account_type_id,
                payload.initial_balance,
            ),
        )

    return {
        "message": "Account opened successfully",
        "account_no": account_no,
    }
