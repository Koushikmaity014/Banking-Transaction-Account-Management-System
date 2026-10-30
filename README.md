# Banking Transaction & Account Management System

A DBMS course project that models core banking operations end to end: a **PostgreSQL** schema with the business rules enforced inside the database (constraints, triggers, stored procedures), a **FastAPI** backend with JWT authentication and role-based access, and a plain **HTML/CSS/JavaScript** web portal for three kinds of users — customers, branch employees and administrators.

> **Academic prototype.** All data is synthetic (fictional bank prefix `DUMY`, made-up PAN/Aadhaar-shaped numbers). Do not use it for real banking or with real personal data.

**Team:** Moyukh Mondal (252123017) · Koushik Maity (252123014) · Rajeev Lalawat (252123022)


---

## Table of contents

1. [Highlights](#highlights)
2. [Architecture](#architecture)
3. [Repository layout](#repository-layout)
4. [Tech stack](#tech-stack)
5. [Database design](#database-design)
6. [Business rules enforced in the database](#business-rules-enforced-in-the-database)
7. [Backend API](#backend-api)
8. [Frontend](#frontend)
9. [Getting started](#getting-started)
10. [Seed data and logins](#seed-data-and-logins)
11. [Request lifecycle example](#request-lifecycle-example)
12. [Security notes and hardening checklist](#security-notes-and-hardening-checklist)

---

## Highlights

- **Logic lives in the database.** Balances, limits, minimum-balance rules, loan state changes and audit logging are enforced by PostgreSQL triggers and stored procedures, so no client (API, script or SQL console) can bypass them.
- **One unified `TRANSACTION` table.** Every money movement — deposit, withdrawal, transfer leg, loan payment — is a row here. `Employee_ID` is `NULL` for customer-initiated actions and set when staff act on a customer's behalf.
- **Account balances are never edited directly.** A trigger recomputes the balance from each inserted transaction, and a direct `UPDATE` of `Current_Balance` is rejected.
- **Immutable history.** Transactions cannot be updated or deleted; corrections would be new adjustment rows.
- **Atomic fund transfers.** Debit row, credit row and the `FUND_TRANSFER` header are written in one procedure call; any failure rolls back everything. Accounts are locked in a consistent order to avoid deadlocks.
- **Role-based access with branch scoping.** Customers see only their own data. Employees are limited to accounts at their assigned branch. Admins see everything and manage staff.
- **Audit trail.** Row-level changes on the main tables are written to `AUDIT_LOG` as JSONB, with password hashes stripped out.
- **Argon2 password hashing and short-lived JWTs** (30 minutes by default).

---

## Architecture

```mermaid
flowchart LR
    B["Browser<br/>HTML / CSS / JS<br/>(customer, employee, admin portals)"]
    A["FastAPI backend<br/>JWT auth, role checks,<br/>input validation"]
    D[("PostgreSQL<br/>tables, triggers,<br/>stored procedures")]
    B -- "HTTP + JSON<br/>Bearer token" --> A
    A -- "psycopg 3<br/>connection pool" --> D
    D -- "results / RAISE EXCEPTION" --> A
    A -- "JSON / 4xx-5xx" --> B
```

Three layers separate user interaction, application logic and data storage. The backend checks *who* may do something; the database decides whether the operation is *valid* under banking rules. A rule violation inside PostgreSQL (`RAISE EXCEPTION`) is translated by the API into a generic `409` response.

---

## Repository layout

```
.
├── backend/
│   ├── app/
│   │   ├── main.py                 # FastAPI app, CORS, error handlers, /health, /docs
│   │   ├── config.py               # Settings loaded from .env (pydantic-settings)
│   │   ├── database.py             # psycopg connection pool + transaction context manager
│   │   ├── security.py             # Argon2 hashing, JWT creation/validation, role guards
│   │   ├── schemas.py              # Pydantic request models and validation rules
│   │   ├── routers/
│   │   │   ├── auth.py             # POST /api/auth/login
│   │   │   ├── accounts.py         # Accounts, deposits, withdrawals, transfers, customers
│   │   │   ├── loans.py            # Loan applications, decisions, payments
│   │   │   ├── dashboard.py        # Customer / employee / admin dashboards, employee management
│   │   │   └── admin_records.py    # Read-only admin views of 10 tables
│   │   └── services/banking.py     # Access checks and calls to stored procedures
│   ├── scripts/set_demo_passwords.py
│   ├── admin_create.py             # Helper: create/update admin logins
│   ├── employee_login.py           # Helper: generate logins for all employees
│   ├── customer_login.py           # Helper: generate logins for all customers
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── index.html                  # Login page with Customer / Employee / Admin tabs
│   ├── customer/dashboard.html
│   ├── employee/dashboard.html
│   ├── admin/
│   │   ├── dashboard.html
│   │   ├── admin-records.html/.js/.css   # Browse database tables, manage employees
│   ├── css/style.css               # Shared design system
│   └── js/
│       ├── api.js                  # fetch wrapper + one method per endpoint
│       ├── auth.js                 # Session handling, role guards, redirects
│       ├── ui.js                   # Toasts, currency/date formatting, sidebar helpers
│       └── mockData.js             # Early-stage mock data (no longer used by the pages)
├── sql/
│   ├── tables.sql                  # Schema, constraints, indexes
│   ├── triggers.sql                # Validation, balance, loan, audit triggers
│   ├── stored_procedures.sql       # Banking operations (plus compatibility patch)
│   ├── dummy_data_generation.sql   # Synthetic seed data
│   └── checks.sql                  # Integrity checks (every count should be 0)
└── dbms_project_final.pptx         # Project presentation (13 slides)
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Database | PostgreSQL (PL/pgSQL triggers and procedures) |
| Backend | Python, FastAPI, Uvicorn, psycopg 3 with `psycopg_pool` |
| Auth & security | PyJWT (HS256), `pwdlib` with Argon2, Pydantic validation |
| Frontend | HTML, CSS, vanilla JavaScript, Font Awesome, Google Fonts (Inter) |
| Config | `.env` file via `pydantic-settings` |

Python dependencies (`backend/requirements.txt`): `fastapi`, `uvicorn[standard]`, `psycopg[binary,pool]`, `pydantic-settings`, `pwdlib[argon2]`, `PyJWT`, `email-validator`, `httpx`, `pytest`.

---

## Database design

The schema has **12 tables**: the 11 business tables from the project deck plus an `AUDIT_LOG`.

```mermaid
erDiagram
    BRANCH ||--o{ EMPLOYEE : "employs"
    BRANCH |o--o| EMPLOYEE : "managed by"
    BRANCH ||--o{ ACCOUNT : "holds"
    CUSTOMER ||--o{ ACCOUNT : "owns"
    ACCOUNT_TYPE ||--o{ ACCOUNT : "classifies"
    ACCOUNT ||--o{ TRANSACTION : "records"
    EMPLOYEE |o--o{ TRANSACTION : "processes"
    TRANSACTION ||--o| FUND_TRANSFER : "debit leg"
    TRANSACTION ||--o| FUND_TRANSFER : "credit leg"
    ACCOUNT ||--o{ FUND_TRANSFER : "from / to"
    CUSTOMER ||--o{ LOAN : "takes"
    ACCOUNT ||--o{ LOAN : "linked to"
    LOAN_TYPE ||--o{ LOAN : "defines"
    EMPLOYEE |o--o{ LOAN : "decides"
    LOAN ||--o{ LOAN_PAYMENT : "repaid by"
    TRANSACTION ||--o| LOAN_PAYMENT : "debit"
    EMPLOYEE |o--o| LOGIN : "has"
    CUSTOMER |o--o| LOGIN : "has"
```

### Tables

| Table | Purpose | Notable columns and rules |
|---|---|---|
| `BRANCH` | Bank branches | `IFSC` primary key (format `^[A-Z]{4}0[A-Z0-9]{6}$`), unique 9-digit `MICR`, 6-digit `PIN`, optional `Manager_ID`, status Active/Inactive |
| `EMPLOYEE` | Staff | Roles `Employee`, `Manager`, `Admin`; `Salary >= 0`; belongs to one branch |
| `CUSTOMER` | Customers | `CIF` primary key, unique `PAN` (`AAAAA9999A`) and 12-digit `Aadhar_No`, status Active/Inactive |
| `ACCOUNT_TYPE` | Product definitions | `Minimum_Balance`, `Interest_Rate`, `Transaction_Limit` |
| `ACCOUNT` | Customer accounts | Status Active/Frozen/Closed, `Current_Balance >= 0` (5 decimal places), optional nominee, unique `(Account_No, CIF)` |
| `TRANSACTION` | Every money movement | Types `Deposit`, `Withdrawal`, `Transfer_In`, `Transfer_Out`, `Loan_Payment`; channels `Branch`, `ATM`, `Online_Banking`, `UPI`, `POS`, `Cheque`, `NEFT`, `RTGS`, `IMPS`; status Completed/Failed/Pending; `Balance_After` is computed by trigger |
| `FUND_TRANSFER` | Header row for a transfer | Links the debit and credit transactions, unique `Reference_No`, modes `UPI`, `Internal_Transfer`, `Cheque`, `NEFT`, `RTGS`, `IMPS`, source ≠ destination |
| `LOAN_TYPE` | Loan products | `Interest_Rate`, `Max_Amount` |
| `LOAN` | Loans | Status `Applied → Approved → Active → Closed` (or `Rejected`); composite foreign key `(Account_No, CIF)` guarantees a loan's customer owns its account; `Employee_ID` is `NULL` until a decision is made |
| `LOAN_PAYMENT` | Repayments | Principal and interest paid, remaining balance snapshot, linked one-to-one to a `Loan_Payment` transaction |
| `LOGIN` | Credentials | `Role` customer/employee/admin, Argon2 hash, `Account_Status` Active/Locked/Disabled; a check constraint ensures customers carry a CIF and staff carry an Employee ID, never both |
| `AUDIT_LOG` | Change history | Table, record key, operation, timestamp, DB user, old/new JSONB |

Indexes cover foreign keys and the hot lookup `TRANSACTION(Account_No, Transaction_Date_Time DESC)`.

---

## Business rules enforced in the database

**Triggers (`sql/triggers.sql`)**

| Trigger | What it does |
|---|---|
| `trg_transaction_validate` (before insert) | Requires an Active account, positive amount, amount within the account type's transaction limit, and a post-debit balance not below the account type's minimum. Computes `Balance_After`; the caller cannot supply it. |
| `trg_transaction_apply_balance` (after insert) | Applies the signed amount to `ACCOUNT.Current_Balance` for Completed transactions. |
| `trg_transaction_immutable` | Rejects `UPDATE` and `DELETE` on transactions. |
| `trg_fund_transfer_validate` | Checks both accounts exist and are Active, the legs are `Transfer_Out` on the source and `Transfer_In` on the destination, both Completed, equal amounts. |
| `trg_loan_payment_validate` / `trg_loan_payment_apply` | Loan must be Active; payment must debit the loan's own account; transaction amount must equal principal + interest; principal cannot exceed what remains. Then reduces the remaining principal and **closes the loan automatically at zero**. |
| `trg_loan_status_transition` | Enforces the state machine `Applied → Approved/Rejected`, `Approved → Active`, `Active → Closed` (only at zero balance). |
| `trg_account_lifecycle` | Only Active customers at Active branches can open accounts; new accounts start Active; balance changes only via transactions; an account cannot close with a non-zero balance or an open loan; closed accounts cannot be reopened. |
| `trg_branch_manager_validate` / `trg_protect_assigned_manager` | A branch manager must be an Active employee with role Manager at the same branch, and cannot be deactivated, demoted or moved while still assigned. |
| `trg_login_validate` | Login role must match the owner's record (admin logins require `Employee.Role = Admin`); inactive owners cannot have Active logins. |
| `trg_customer_sync_login` / `trg_employee_sync_login` | Deactivating a customer or employee automatically disables the linked login (unless it is Locked). |
| `trg_audit_*` | Writes row changes for branch, customer, employee, account, login, transaction (insert only), fund transfer, loan and loan payment into `AUDIT_LOG`. |

**Stored procedures (`sql/stored_procedures.sql`)**

| Procedure | Purpose |
|---|---|
| `sp_open_account` | Validates customer, branch, account type and minimum opening balance; creates the account at zero and posts the opening deposit as a real transaction. |
| `sp_deposit`, `sp_withdraw` | Validate amount and channel, then insert a transaction (the triggers do the rest). |
| `sp_fund_transfer` | Locks both accounts in sorted order, inserts debit and credit transactions, then the `FUND_TRANSFER` header. |
| `sp_apply_loan` | Creates an `Applied` loan; the interest rate is read from `LOAN_TYPE`, not trusted from the caller. |
| `sp_approve_loan` | Requires an active Manager or Admin; moves `Applied → Approved → Active` and stamps start/end dates, or rejects. |
| `sp_loan_payment` | Records the repayment transaction and `LOAN_PAYMENT` row. |
| `sp_check_balance`, `sp_get_transaction_history`, `sp_generate_account_statement` | Read helpers for SQL clients (the last two return refcursors). |

> `stored_procedures.sql` also contains a *compatibility patch*: it re-defines the audit function, drops two older procedure signatures, and makes `LOAN.Employee_ID` nullable so applications can exist before a reviewer is assigned.

---

## Backend API

Interactive docs are served at **`/docs`** (Swagger UI, loaded from the unpkg CDN). Health check: `GET /health`.

**Authentication.** `POST /api/auth/login` returns a JWT. Send it on later requests as `Authorization: Bearer <token>`. Claims include the username, login id, role, employee id and CIF. Tokens expire after `JWT_EXPIRE_MINUTES` (default 30).

### Auth

| Method | Path | Access | Description |
|---|---|---|---|
| POST | `/api/auth/login` | Public | Validates credentials, optional role check, account/owner status; returns profile and token |

### Accounts and money movement

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/api/accounts/profile` | Customer | Own personal details and all accounts |
| GET | `/api/accounts` | Any user | Accounts visible to the caller (own / branch / all, max 100 for staff) |
| GET | `/api/accounts/{account_no}` | Owner, branch staff, admin | Account summary |
| GET | `/api/accounts/{account_no}/transactions` | Owner, branch staff, admin | Paged history (`limit` 1–200, `offset`) |
| POST | `/api/deposits` | Any user with account access | Deposit via `sp_deposit` |
| POST | `/api/withdrawals` | Any user with account access | Withdrawal via `sp_withdraw` |
| POST | `/api/transfers` | Any user with access to the source account | Transfer via `sp_fund_transfer`; returns reference number and both transaction ids |
| GET | `/api/account-types` | Employee, Admin | Account type catalogue |
| POST | `/api/accounts` | Employee, Admin | Open an account (employees only at their own branch) |
| POST | `/api/customers` | Employee, Admin | Create customer and login; returns generated username and initial password |
| GET | `/api/customers/{cif}/profile` | Employee, Admin | Customer details and accounts (employees: branch only) |

### Loans

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/api/loans` | Any user | Own loans / branch loans / all loans |
| GET | `/api/loans/types` | Employee, Admin | Loan product catalogue |
| POST | `/api/loans/applications` | Customer | Apply for a loan; EMI is calculated server-side |
| POST | `/api/loans/staff-applications` | Employee, Admin | Apply on a customer's behalf (active customer and account required) |
| POST | `/api/loans/{loan_id}/decision` | Employee, Admin | `Approved` or `Rejected` (employees: branch only; the procedure additionally requires Manager or Admin) |
| POST | `/api/loans/{loan_id}/payments` | Customer (own loan), staff | Repay principal and interest |

EMI uses the standard reducing-balance formula with monthly rate `r = annual_rate / 12 / 100`:

```
EMI = P · r · (1 + r)^n / ((1 + r)^n − 1)        (P / n when r = 0)
```

### Dashboards and administration

| Method | Path | Access | Description |
|---|---|---|---|
| GET | `/api/customer/dashboard` | Customer | Profile, accounts, loans with progress, recent transactions, stats |
| GET | `/api/employee/dashboard` | Employee, Admin | Branch stats, pending loan applications, recent branch activity |
| GET | `/api/employee/customers` | Employee, Admin | Directory of customers with an account at the employee's branch |
| GET | `/api/admin/dashboard` | Admin | Bank-wide totals, accounts by type, monthly volume, branch overview, recent logins |
| GET | `/api/branches` | Any user | Branch list |
| GET | `/api/admin/employees` | Admin | Employee list with login status |
| POST | `/api/admin/employees` | Admin | Create employee and login (returns the generated initial password once) |
| DELETE | `/api/admin/employees/{employee_id}` | Admin | Soft-deactivate (blocked if the employee is a branch manager); login is disabled by trigger |
| GET | `/api/{branches, employees, customers, account-types, loan-types, transactions, fund-transfers, loan-payments, logins, audit-logs}` | Admin | Read-only table browser; sensitive columns such as `password_hash` are filtered out |

### Error handling

| Situation | Response |
|---|---|
| Missing/invalid/expired token | `401` |
| Wrong role or outside branch/ownership | `403` |
| Validation failure (Pydantic) | `422` |
| Rule violated inside PostgreSQL (`RAISE EXCEPTION`) | `409` with a generic "could not be completed under current banking rules" message |
| Duplicate key | `409` |
| Database unreachable | `503` |

---

## Frontend

A static multi-page app; no build step. Pages call the API through `js/api.js`, keep the token in `sessionStorage`, and use `js/auth.js` to redirect users to the page for their role.

- **Login (`index.html`)** — three role tabs (Customer, Employee, Admin), validation, show/hide password, "remember username".
- **Customer dashboard** — accounts, loans with repayment progress, recent transactions, fund transfer, EMI payment, profile view, statement download as CSV.
- **Employee dashboard** — branch customer directory and profiles, add customer, open account, deposits and withdrawals, new loan applications, approve/reject pending loans, ledger export, reports and desk tools.
- **Admin dashboard** — bank-wide statistics, branch overview, account mix, transaction trend, recent logins.
- **Admin database management (`admin/admin-records.html`)** — browse the 12 tables with search and sorting; create and deactivate employees.

The UI is branded **"IITG Bank"** for demonstration purposes.

---

## Getting started

### Prerequisites

- PostgreSQL 14 or newer (the code uses `FOR UPDATE`, procedures and JSONB)
- Python 3.10 or newer
- Any static file server for the frontend (for example VS Code *Live Server* on port 5500)

### 1. Create the database

```bash
createdb -U postgres Bank
```

### 2. Load the SQL, **in this order**

```bash
psql -U postgres -d Bank -f sql/tables.sql
psql -U postgres -d Bank -f sql/triggers.sql
psql -U postgres -d Bank -f sql/stored_procedures.sql
psql -U postgres -d Bank -f sql/dummy_data_generation.sql   # empty/disposable DB only
psql -U postgres -d Bank -f sql/checks.sql                  # every *_count should be 0
```

### 3. Configure the backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # then edit the values
```

`.env` settings:

| Variable | Meaning | Default |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string, e.g. `postgresql://USER:PASSWORD@localhost:5432/Bank` | required |
| `JWT_SECRET` | Long random secret for signing tokens (for example `python -c "import secrets; print(secrets.token_hex(32))"`) | required |
| `JWT_EXPIRE_MINUTES` | Token lifetime | `30` |
| `CORS_ORIGINS` | Comma-separated allowed frontend origins | `http://localhost:5500,http://127.0.0.1:5500` |
| `APP_ENV` | Environment label | `development` |

### 4. Create usable logins

The seed data inserts placeholder hashes that cannot log in. Generate real credentials once:

```bash
pip install python-dotenv           # needed by employee_login.py, not in requirements.txt
python employee_login.py            # creates/updates a login for every employee
python customer_login.py            # replaces ALL customer logins
```

Run these from `backend/` (they import `app.*` or read `.env` from that folder). See [Seed data and logins](#seed-data-and-logins) for the generated credential patterns.

### 5. Run the API

```bash
uvicorn app.main:app --reload --port 8000
```

Open <http://127.0.0.1:8000/docs>.

### 6. Run the frontend

Serve the `frontend/` folder (for example Live Server on port 5500) and open `index.html`. The frontend expects the API at `http://127.0.0.1:8000/api`; to change that, set `window.BANK_API_BASE_URL` before `js/api.js` loads, and add the new origin to `CORS_ORIGINS`.

---

## Seed data and logins

`dummy_data_generation.sql` builds a small bank, using real triggers so balances are produced the same way production traffic would produce them:

| Item | Count |
|---|---|
| Account types / loan types | 5 / 5 |
| Branches (Kolkata area, fictional `DUMY` IFSC prefix) | 10 |
| Employees | 30 (10 managers, 18 employees, 2 admins) |
| Customers | 120 |
| Accounts | 150 |
| Transactions | 150 opening deposits + 450 deposits/withdrawals + loan payments + transfer legs |
| Loans | 50 (30 Active, 10 Applied, 10 Rejected) |
| Loan payments / fund transfers | 30 / 40 |

Account types: Savings, Current, Salary, Fixed Deposit, Student. Loan types: Home, Personal, Education, Auto, Business.

**Generated login patterns (demo only)**

| Who | Script | Username | Initial password |
|---|---|---|---|
| Employees / managers / admins | `employee_login.py` | `firstname.lastname` | `firstname` + last 3 characters of the employee id |
| Customers | `customer_login.py` | `firstname.lastname` (CIF suffix added for duplicate names) | `FirstName` + last 3 characters of the CIF |
| Customers created in the portal | API | `firstname.lastname` (numeric suffix if taken) | `firstname` + birth day and month (`DDMM`) |
| Employees created in the portal | API | `firstname.lastname` | `firstname` + birth day and month (`DDMM`) |

Because these are predictable, change them before showing the system to anyone else.

---

## Request lifecycle example

A customer transfers money:

1. **Browser** — `api.transfer(from, to, amount, mode)` sends `POST /api/transfers` with the bearer token.
2. **FastAPI** — validates the JSON (`amount > 0`, max 14 digits, 2 decimals), decodes the JWT, checks the customer owns the source account, confirms the destination exists and is Active.
3. **Service layer** — generates debit/credit transaction ids and a reference number, then calls `sp_fund_transfer(...)`.
4. **PostgreSQL** — locks both accounts in sorted order, inserts the `Transfer_Out` row (trigger validates limit and minimum balance, sets `Balance_After`, updates the balance), inserts the `Transfer_In` row, inserts `FUND_TRANSFER` (trigger re-validates the pair), audit triggers fire.
5. **Result** — on success the API returns the reference number and both ids; on any rule violation the whole call rolls back and the API returns `409`.

---

## Security notes and hardening checklist

What the project already does well: Argon2 password hashes, hashes excluded from audit rows and admin table views, JWT expiry, server-side role and branch checks, parameterised SQL everywhere (admin table names come from a fixed allow-list), and an immutable transaction history.

Before this repo is shared or deployed anywhere, please address:

- **Remove committed secrets.** `backend/.env.example` contains what look like real values for the database password and JWT secret, and `backend/customer_login.py` has a hard-coded fallback `DATABASE_URL` with a password. Replace them with obvious placeholders, **rotate the database password and JWT secret**, and consider purging them from git history.
- **Do not keep plaintext passwords in source.** `backend/admin_create.py` stores initial admin passwords in a list. Read them from environment variables or prompt for them.
- **Replace guessable initial passwords** (name + date or ID digits) with random one-time passwords and force a change on first login.
- **Add brute-force protection.** The `Locked` login status exists in the schema, but nothing increments failed attempts or sets it.
- **Escape toast messages.** `ui.showToast` inserts the message with `innerHTML`; use `textContent` for any text that could contain user or server data.
- **Audit attribution.** `AUDIT_LOG.Changed_By` records the PostgreSQL session user, which is the same service account for every API action. Pass the application user (for example via `SET LOCAL app.user_id`) if you need per-user audit trails.
- **Serve over HTTPS** and move the token out of `sessionStorage` (for example to an HttpOnly cookie) if this ever leaves a lab setting.

---


## Disclaimer

This is a university DBMS project. It is not a certified banking product, is not security-audited, and must not be used with real customer data or real money.
