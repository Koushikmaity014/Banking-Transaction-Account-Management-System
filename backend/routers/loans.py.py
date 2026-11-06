
from decimal import Decimal
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from psycopg.rows import dict_row

from app.database import db_connection
from app.security import current_user, require_roles
from app.schemas import (
    LoanApplicationRequest,
    LoanDecisionRequest,
    LoanPaymentRequest,
    StaffLoanApplicationRequest,
)
from app.services import banking


router = APIRouter(prefix="/api/loans", tags=["loans"])


@router.get("")
def loans(user: dict = Depends(current_user)):
    return banking.loan_list(user)


@router.get("/types")
def loan_types(
    user: dict = Depends(require_roles("employee", "admin")),
):
    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        cur.execute(
            """
            SELECT loan_type_id AS loan_type_id,
                   loan_type_name AS loan_type_name,
                   interest_rate AS interest_rate,
                   max_amount AS max_amount
            FROM loan_type
            ORDER BY loan_type_name
            """
        )
        return cur.fetchall()


@router.post("/applications", status_code=201)
def apply(
    payload: LoanApplicationRequest,
    user: dict = Depends(current_user),
):
    return banking.apply_loan(
        user,
        payload.account_no,
        payload.loan_type_id,
        payload.principal,
        payload.tenure_months,
    )


@router.post("/staff-applications", status_code=201)
def staff_apply(
    payload: StaffLoanApplicationRequest,
    user: dict = Depends(require_roles("employee", "admin")),
):
    employee_id = user.get("employee_id")

    with db_connection() as conn, conn.cursor(row_factory=dict_row) as cur:
        # Confirm that the selected account belongs to the supplied CIF.
        cur.execute(
            """
            SELECT a.account_no AS account_no,
                   a.cif AS cif,
                   a.ifsc AS ifsc,
                   a.status AS account_status,
                   c.status AS customer_status
            FROM account a
            JOIN customer c ON c.cif = a.cif
            WHERE a.account_no = %s AND a.cif = %s
            """,
            (payload.account_no, payload.cif),
        )
        account = cur.fetchone()

        if not account:
            raise HTTPException(
                status_code=404,
                detail="The selected account does not belong to this customer",
            )

        if account["account_status"] != "Active":
            raise HTTPException(
                status_code=409,
                detail="Loan applications require an active account",
            )

        if account["customer_status"] != "Active":
            raise HTTPException(
                status_code=409,
                detail="Loan applications require an active customer",
            )

        if user["role"] == "employee":
            cur.execute(
                """
                SELECT ifsc
                FROM employee
                WHERE employee_id = %s AND status = 'Active'
                """,
                (employee_id,),
            )
            employee = cur.fetchone()

            if not employee or employee["ifsc"] != account["ifsc"]:
                raise HTTPException(
                    status_code=403,
                    detail=(
                        "Employees may submit loan applications "
                        "only for accounts at their assigned branch"
                    ),
                )

        cur.execute(
            """
            SELECT interest_rate, max_amount
            FROM loan_type
            WHERE loan_type_id = %s
            """,
            (payload.loan_type_id,),
        )
        loan_type = cur.fetchone()

        if not loan_type:
            raise HTTPException(
                status_code=404,
                detail="Loan type not found",
            )

        principal = payload.principal
        if principal > loan_type["max_amount"]:
            raise HTTPException(
                status_code=422,
                detail="Principal exceeds the maximum amount for this loan type",
            )

        rate = Decimal(str(loan_type["interest_rate"])) / Decimal(100) / Decimal(12)
        months = payload.tenure_months

        if rate == 0:
            emi = principal / Decimal(months)
        else:
            factor = (Decimal(1) + rate) ** months
            emi = principal * rate * factor / (factor - Decimal(1))

        emi = emi.quantize(Decimal("0.01"))
        loan_id = "LN" + uuid4().hex[:10].upper()

        cur.execute(
            """
            CALL sp_apply_loan(
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            """,
            (
                loan_id,
                payload.cif,
                payload.account_no,
                payload.loan_type_id,
                employee_id,
                principal,
                Decimal(str(loan_type["interest_rate"])),
                months,
                emi,
                None,
                None,
            ),
        )

    return {
        "message": "Loan application submitted successfully",
        "loan_id": loan_id,
        "loan_status": "Applied",
        "emi_amount": emi,
    }


@router.post("/{loan_id}/decision")
def decide(
    loan_id: str,
    payload: LoanDecisionRequest,
    user: dict = Depends(require_roles("employee", "admin")),
):
    # Enforce branch scope in the API before invoking the stored procedure.
    if user["role"] == "employee":
        with db_connection() as conn, conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1
                FROM loan l
                JOIN account a ON a.account_no = l.account_no
                JOIN employee e ON e.ifsc = a.ifsc
                WHERE l.loan_id = %s
                  AND e.employee_id = %s
                  AND e.status = 'Active'
                """,
                (loan_id, user.get("employee_id")),
            )
            if not cur.fetchone():
                raise HTTPException(
                    status_code=403,
                    detail="This loan is outside your assigned branch",
                )

    return banking.decide_loan(user, loan_id, payload.decision)


@router.post("/{loan_id}/payments")
def payment(
    loan_id: str,
    payload: LoanPaymentRequest,
    user: dict = Depends(current_user),
):
    if payload.loan_id != loan_id:
        raise HTTPException(
            status_code=422,
            detail="Loan ID in path and body must match",
        )

    return banking.pay_loan(
        user,
        loan_id,
        payload.principal_paid,
        payload.interest_paid,
        payload.payment_method,
    )
