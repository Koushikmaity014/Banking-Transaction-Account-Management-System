
from decimal import Decimal
from datetime import date

from pydantic import BaseModel, Field, ConfigDict


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1, max_length=256)
    role: str | None = Field(
        default=None,
        pattern=r"^(customer|employee|admin)$",
    )


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class DepositRequest(BaseModel):
    account_no: str = Field(min_length=1, max_length=20)
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    channel: str = "Online_Banking"


class WithdrawalRequest(BaseModel):
    account_no: str = Field(min_length=1, max_length=20)
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    channel: str = "Online_Banking"


class TransferRequest(BaseModel):
    from_account_no: str = Field(min_length=1, max_length=20)
    to_account_no: str = Field(min_length=1, max_length=20)
    amount: Decimal = Field(gt=0, max_digits=14, decimal_places=2)
    transfer_mode: str = "Internal_Transfer"


class OpenAccountRequest(BaseModel):
    cif: str = Field(min_length=1, max_length=15)
    ifsc: str = Field(min_length=1, max_length=11)
    nominee: str | None = Field(default=None, max_length=100)
    account_type_id: str = Field(min_length=1, max_length=20)
    initial_balance: Decimal = Field(
        gt=0, max_digits=14, decimal_places=5
    )


class CustomerCreateRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=50)
    last_name: str = Field(min_length=1, max_length=50)
    dob: date
    gender: str = Field(pattern=r"^(Male|Female|Other)$")
    contact: str = Field(min_length=7, max_length=20)
    pan: str = Field(pattern=r"^[A-Z]{5}[0-9]{4}[A-Z]$")
    aadhar_no: str = Field(pattern=r"^[0-9]{12}$")
    address: str | None = Field(default=None, max_length=255)


class LoanApplicationRequest(BaseModel):
    account_no: str = Field(min_length=1, max_length=20)
    loan_type_id: str = Field(min_length=1, max_length=20)
    principal: Decimal = Field(
        gt=0, max_digits=14, decimal_places=2
    )
    tenure_months: int = Field(gt=0, le=480)


class StaffLoanApplicationRequest(BaseModel):
    cif: str = Field(min_length=1, max_length=15)
    account_no: str = Field(min_length=1, max_length=20)
    loan_type_id: str = Field(min_length=1, max_length=20)
    principal: Decimal = Field(
        gt=0, max_digits=14, decimal_places=2
    )
    tenure_months: int = Field(gt=0, le=480)


class LoanDecisionRequest(BaseModel):
    decision: str = Field(pattern=r"^(Approved|Rejected)$")


class LoanPaymentRequest(BaseModel):
    loan_id: str = Field(min_length=1, max_length=20)
    principal_paid: Decimal = Field(
        ge=0, max_digits=14, decimal_places=2
    )
    interest_paid: Decimal = Field(
        ge=0, max_digits=14, decimal_places=2
    )
    payment_method: str = "Internal_Transfer"


class AccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    account_no: str
    ifsc: str
    account_type_id: str
    status: str
    current_balance: Decimal
