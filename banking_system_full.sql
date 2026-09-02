-- =====================================================================
-- Banking Transaction & Account Management System — Academic Prototype
-- Complete PostgreSQL Database Creation Script
-- =====================================================================
-- Contents:
--   1. Table creation (DDL)
--   2. Indexes
--   3. Triggers
--   4. Stored Procedures
--   5. Views
--   6. Sample / dummy data
-- =====================================================================


-- =====================================================================
-- SECTION 0: CLEAN SLATE (safe to re-run during development)
-- =====================================================================
DROP TABLE IF EXISTS LOAN_PAYMENT   CASCADE;
DROP TABLE IF EXISTS LOAN           CASCADE;
DROP TABLE IF EXISTS LOAN_TYPE      CASCADE;
DROP TABLE IF EXISTS FUND_TRANSFER  CASCADE;
DROP TABLE IF EXISTS TRANSACTION    CASCADE;
DROP TABLE IF EXISTS ACCOUNT        CASCADE;
DROP TABLE IF EXISTS ACCOUNT_TYPE   CASCADE;
DROP TABLE IF EXISTS LOGIN          CASCADE;
DROP TABLE IF EXISTS CUSTOMER       CASCADE;
DROP TABLE IF EXISTS EMPLOYEE       CASCADE;
DROP TABLE IF EXISTS BRANCH         CASCADE;


-- =====================================================================
-- SECTION 1: TABLE CREATION
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. BRANCH
-- ---------------------------------------------------------------------
CREATE TABLE BRANCH (
    Branch_ID       SERIAL PRIMARY KEY,
    Branch_Name     VARCHAR(100) NOT NULL,
    Address         VARCHAR(255),
    City            VARCHAR(100) NOT NULL,
    IFSC_Code       VARCHAR(15)  NOT NULL UNIQUE,
    Phone           VARCHAR(20)
);

-- ---------------------------------------------------------------------
-- 2. EMPLOYEE  (Admins are Employees with Position = 'Admin')
-- ---------------------------------------------------------------------
CREATE TABLE EMPLOYEE (
    Employee_ID     SERIAL PRIMARY KEY,
    First_Name      VARCHAR(50) NOT NULL,
    Last_Name       VARCHAR(50) NOT NULL,
    Branch_ID       INT NOT NULL REFERENCES BRANCH(Branch_ID),
    Position        VARCHAR(30) NOT NULL
                     CHECK (Position IN ('Teller','Loan_Officer','Manager','Admin')),
    Phone           VARCHAR(20),
    Email           VARCHAR(100) NOT NULL UNIQUE,
    Hire_Date       DATE NOT NULL DEFAULT CURRENT_DATE
);

-- ---------------------------------------------------------------------
-- 3. CUSTOMER
-- ---------------------------------------------------------------------
CREATE TABLE CUSTOMER (
    Customer_ID     SERIAL PRIMARY KEY,
    First_Name      VARCHAR(50) NOT NULL,
    Last_Name       VARCHAR(50) NOT NULL,
    DOB             DATE NOT NULL,
    Address         VARCHAR(255),
    Phone           VARCHAR(20),
    Email           VARCHAR(100) NOT NULL UNIQUE,
    Created_At      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 4. LOGIN  (auth layer, decoupled from business entities)
-- ---------------------------------------------------------------------
CREATE TABLE LOGIN (
    Login_ID        SERIAL PRIMARY KEY,
    Username        VARCHAR(50) NOT NULL UNIQUE,
    Password_Hash   VARCHAR(255) NOT NULL,
    Role            VARCHAR(10) NOT NULL CHECK (Role IN ('customer','employee','admin')),
    Customer_ID     INT REFERENCES CUSTOMER(Customer_ID),
    Employee_ID     INT REFERENCES EMPLOYEE(Employee_ID),
    Created_At      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_login_owner CHECK (
        (Role = 'customer' AND Customer_ID IS NOT NULL AND Employee_ID IS NULL)
        OR
        (Role IN ('employee','admin') AND Employee_ID IS NOT NULL AND Customer_ID IS NULL)
    )
);

-- ---------------------------------------------------------------------
-- 5. ACCOUNT_TYPE  (lookup table)
-- ---------------------------------------------------------------------
CREATE TABLE ACCOUNT_TYPE (
    Account_Type_ID SERIAL PRIMARY KEY,
    Type_Name       VARCHAR(30) NOT NULL UNIQUE,
    Interest_Rate   DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    Min_Balance     DECIMAL(12,2) NOT NULL DEFAULT 0.00
);

-- ---------------------------------------------------------------------
-- 6. ACCOUNT
-- ---------------------------------------------------------------------
CREATE TABLE ACCOUNT (
    Account_ID      SERIAL PRIMARY KEY,
    Account_Number  VARCHAR(20) NOT NULL UNIQUE,
    Customer_ID     INT NOT NULL REFERENCES CUSTOMER(Customer_ID),
    Branch_ID       INT NOT NULL REFERENCES BRANCH(Branch_ID),
    Account_Type_ID INT NOT NULL REFERENCES ACCOUNT_TYPE(Account_Type_ID),
    Balance         DECIMAL(14,2) NOT NULL DEFAULT 0.00 CHECK (Balance >= 0),
    Status          VARCHAR(15) NOT NULL DEFAULT 'Active'
                     CHECK (Status IN ('Active','Frozen','Closed')),
    Opened_Date     DATE NOT NULL DEFAULT CURRENT_DATE
);

-- ---------------------------------------------------------------------
-- 7. TRANSACTION  (unified log; Employee_ID NULL = customer self-service)
-- ---------------------------------------------------------------------
CREATE TABLE TRANSACTION (
    Transaction_ID   SERIAL PRIMARY KEY,
    Account_ID       INT NOT NULL REFERENCES ACCOUNT(Account_ID),
    Employee_ID      INT REFERENCES EMPLOYEE(Employee_ID),
    Transaction_Type VARCHAR(20) NOT NULL
                      CHECK (Transaction_Type IN
                             ('Deposit','Withdrawal','Transfer_In','Transfer_Out','Loan_Payment')),
    Amount           DECIMAL(14,2) NOT NULL CHECK (Amount > 0),
    Balance_After    DECIMAL(14,2) NOT NULL,
    Status           VARCHAR(10) NOT NULL DEFAULT 'Completed'
                      CHECK (Status IN ('Completed','Failed','Pending')),
    Txn_Timestamp    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 8. FUND_TRANSFER  (links the two TRANSACTION legs of one transfer)
-- ---------------------------------------------------------------------
CREATE TABLE FUND_TRANSFER (
    Transfer_ID           SERIAL PRIMARY KEY,
    From_Account_ID       INT NOT NULL REFERENCES ACCOUNT(Account_ID),
    To_Account_ID         INT NOT NULL REFERENCES ACCOUNT(Account_ID),
    Amount                DECIMAL(14,2) NOT NULL CHECK (Amount > 0),
    Employee_ID           INT REFERENCES EMPLOYEE(Employee_ID),
    Debit_Transaction_ID  INT NOT NULL REFERENCES TRANSACTION(Transaction_ID),
    Credit_Transaction_ID INT NOT NULL REFERENCES TRANSACTION(Transaction_ID),
    Status                VARCHAR(10) NOT NULL DEFAULT 'Completed'
                           CHECK (Status IN ('Completed','Failed','Pending')),
    Transfer_Timestamp    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transfer_accounts CHECK (From_Account_ID <> To_Account_ID)
);

-- ---------------------------------------------------------------------
-- 9. LOAN_TYPE  (lookup table)
-- ---------------------------------------------------------------------
CREATE TABLE LOAN_TYPE (
    Loan_Type_ID      SERIAL PRIMARY KEY,
    Type_Name         VARCHAR(30) NOT NULL UNIQUE,
    Interest_Rate     DECIMAL(5,2) NOT NULL,
    Max_Tenure_Months INT NOT NULL
);

-- ---------------------------------------------------------------------
-- 10. LOAN
-- ---------------------------------------------------------------------
CREATE TABLE LOAN (
    Loan_ID          SERIAL PRIMARY KEY,
    Customer_ID      INT NOT NULL REFERENCES CUSTOMER(Customer_ID),
    Branch_ID        INT NOT NULL REFERENCES BRANCH(Branch_ID),
    Loan_Type_ID     INT NOT NULL REFERENCES LOAN_TYPE(Loan_Type_ID),
    Employee_ID      INT REFERENCES EMPLOYEE(Employee_ID),
    Principal_Amount DECIMAL(14,2) NOT NULL CHECK (Principal_Amount > 0),
    Interest_Rate    DECIMAL(5,2) NOT NULL,
    Tenure_Months    INT NOT NULL CHECK (Tenure_Months > 0),
    EMI_Amount       DECIMAL(12,2) NOT NULL,
    Status           VARCHAR(15) NOT NULL DEFAULT 'Applied'
                      CHECK (Status IN ('Applied','Approved','Rejected','Active','Closed')),
    Start_Date       DATE,
    End_Date         DATE
);

-- ---------------------------------------------------------------------
-- 11. LOAN_PAYMENT  (each payment also produces a TRANSACTION row)
-- ---------------------------------------------------------------------
CREATE TABLE LOAN_PAYMENT (
    Payment_ID       SERIAL PRIMARY KEY,
    Loan_ID          INT NOT NULL REFERENCES LOAN(Loan_ID),
    Account_ID       INT NOT NULL REFERENCES ACCOUNT(Account_ID),
    Employee_ID      INT REFERENCES EMPLOYEE(Employee_ID),
    Transaction_ID   INT NOT NULL REFERENCES TRANSACTION(Transaction_ID),
    Amount           DECIMAL(12,2) NOT NULL CHECK (Amount > 0),
    Payment_Date     DATE NOT NULL DEFAULT CURRENT_DATE,
    Status           VARCHAR(10) NOT NULL DEFAULT 'Completed'
                      CHECK (Status IN ('Completed','Failed','Pending'))
);


-- =====================================================================
-- SECTION 2: INDEXES
-- =====================================================================
CREATE INDEX idx_account_customer      ON ACCOUNT(Customer_ID);
CREATE INDEX idx_transaction_account   ON TRANSACTION(Account_ID);
CREATE INDEX idx_transaction_employee  ON TRANSACTION(Employee_ID);
CREATE INDEX idx_transaction_timestamp ON TRANSACTION(Txn_Timestamp);
CREATE INDEX idx_loan_customer         ON LOAN(Customer_ID);
CREATE INDEX idx_loanpayment_loan      ON LOAN_PAYMENT(Loan_ID);


-- =====================================================================
-- SECTION 3: TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1 (BEFORE INSERT on TRANSACTION):
--   - blocks transactions on non-Active accounts
--   - blocks withdrawals/transfers-out/loan-payments that would
--     overdraw the account
--   - computes Balance_After automatically (caller doesn't need to)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validate_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_balance DECIMAL(14,2);
    v_status  VARCHAR(15);
BEGIN
    SELECT Balance, Status INTO v_balance, v_status
    FROM ACCOUNT
    WHERE Account_ID = NEW.Account_ID
    FOR UPDATE;

    IF v_status <> 'Active' THEN
        RAISE EXCEPTION 'Account % is not active (status: %)', NEW.Account_ID, v_status;
    END IF;

    IF NEW.Transaction_Type IN ('Withdrawal','Transfer_Out','Loan_Payment') THEN
        IF v_balance < NEW.Amount THEN
            RAISE EXCEPTION 'Insufficient balance in account % (balance %, requested %)',
                NEW.Account_ID, v_balance, NEW.Amount;
        END IF;
        NEW.Balance_After := v_balance - NEW.Amount;
    ELSE  -- Deposit, Transfer_In
        NEW.Balance_After := v_balance + NEW.Amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_transaction
BEFORE INSERT ON TRANSACTION
FOR EACH ROW EXECUTE FUNCTION fn_validate_transaction();

-- ---------------------------------------------------------------------
-- Trigger 2 (AFTER INSERT on TRANSACTION):
--   - applies the computed Balance_After to the ACCOUNT row
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_apply_balance_update()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE ACCOUNT
    SET Balance = NEW.Balance_After
    WHERE Account_ID = NEW.Account_ID;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_apply_balance_update
AFTER INSERT ON TRANSACTION
FOR EACH ROW EXECUTE FUNCTION fn_apply_balance_update();

-- ---------------------------------------------------------------------
-- Trigger 3 (AFTER INSERT on LOAN_PAYMENT):
--   - auto-closes a loan once total payments reach the principal
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_check_loan_closure()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid DECIMAL(14,2);
    v_principal  DECIMAL(14,2);
BEGIN
    SELECT COALESCE(SUM(Amount), 0) INTO v_total_paid
    FROM LOAN_PAYMENT
    WHERE Loan_ID = NEW.Loan_ID AND Status = 'Completed';

    SELECT Principal_Amount INTO v_principal
    FROM LOAN
    WHERE Loan_ID = NEW.Loan_ID;

    IF v_total_paid >= v_principal THEN
        UPDATE LOAN
        SET Status = 'Closed', End_Date = CURRENT_DATE
        WHERE Loan_ID = NEW.Loan_ID;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_loan_closure
AFTER INSERT ON LOAN_PAYMENT
FOR EACH ROW EXECUTE FUNCTION fn_check_loan_closure();


-- =====================================================================
-- SECTION 4: STORED PROCEDURES
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_deposit: customer/employee deposit into an account
--   p_employee_id = NULL when the customer performs it themselves
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_deposit(
    p_account_id  INT,
    p_employee_id INT,
    p_amount      DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TRANSACTION(Account_ID, Employee_ID, Transaction_Type, Amount, Balance_After, Status)
    VALUES (p_account_id, p_employee_id, 'Deposit', p_amount, 0, 'Completed');
    -- Balance_After is overwritten by trg_validate_transaction
END;
$$;

-- ---------------------------------------------------------------------
-- sp_withdraw: customer/employee withdrawal from an account
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_withdraw(
    p_account_id  INT,
    p_employee_id INT,
    p_amount      DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO TRANSACTION(Account_ID, Employee_ID, Transaction_Type, Amount, Balance_After, Status)
    VALUES (p_account_id, p_employee_id, 'Withdrawal', p_amount, 0, 'Completed');
END;
$$;

-- ---------------------------------------------------------------------
-- sp_fund_transfer: atomic transfer between two accounts.
--   Inserts a Transfer_Out leg, a Transfer_In leg, and links both via
--   FUND_TRANSFER. If either leg fails (e.g. insufficient balance),
--   the whole procedure call rolls back — nothing is left half-done.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_fund_transfer(
    p_from_account_id INT,
    p_to_account_id   INT,
    p_employee_id     INT,
    p_amount          DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_debit_txn_id  INT;
    v_credit_txn_id INT;
BEGIN
    IF p_from_account_id = p_to_account_id THEN
        RAISE EXCEPTION 'Cannot transfer to the same account';
    END IF;

    INSERT INTO TRANSACTION(Account_ID, Employee_ID, Transaction_Type, Amount, Balance_After, Status)
    VALUES (p_from_account_id, p_employee_id, 'Transfer_Out', p_amount, 0, 'Completed')
    RETURNING Transaction_ID INTO v_debit_txn_id;

    INSERT INTO TRANSACTION(Account_ID, Employee_ID, Transaction_Type, Amount, Balance_After, Status)
    VALUES (p_to_account_id, p_employee_id, 'Transfer_In', p_amount, 0, 'Completed')
    RETURNING Transaction_ID INTO v_credit_txn_id;

    INSERT INTO FUND_TRANSFER(
        From_Account_ID, To_Account_ID, Amount, Employee_ID,
        Debit_Transaction_ID, Credit_Transaction_ID, Status
    )
    VALUES (
        p_from_account_id, p_to_account_id, p_amount, p_employee_id,
        v_debit_txn_id, v_credit_txn_id, 'Completed'
    );
END;
$$;

-- ---------------------------------------------------------------------
-- sp_loan_payment: pay down a loan from an account.
--   Inserts a Loan_Payment transaction, then a LOAN_PAYMENT record;
--   trg_check_loan_closure auto-closes the loan once fully paid.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_loan_payment(
    p_loan_id     INT,
    p_account_id  INT,
    p_employee_id INT,
    p_amount      DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_txn_id     INT;
    v_loan_status VARCHAR(15);
BEGIN
    SELECT Status INTO v_loan_status FROM LOAN WHERE Loan_ID = p_loan_id;

    IF v_loan_status NOT IN ('Active','Approved') THEN
        RAISE EXCEPTION 'Loan % is not payable (status: %)', p_loan_id, v_loan_status;
    END IF;

    INSERT INTO TRANSACTION(Account_ID, Employee_ID, Transaction_Type, Amount, Balance_After, Status)
    VALUES (p_account_id, p_employee_id, 'Loan_Payment', p_amount, 0, 'Completed')
    RETURNING Transaction_ID INTO v_txn_id;

    INSERT INTO LOAN_PAYMENT(Loan_ID, Account_ID, Employee_ID, Transaction_ID, Amount, Status)
    VALUES (p_loan_id, p_account_id, p_employee_id, v_txn_id, p_amount, 'Completed');

    IF v_loan_status = 'Approved' THEN
        UPDATE LOAN SET Status = 'Active', Start_Date = COALESCE(Start_Date, CURRENT_DATE)
        WHERE Loan_ID = p_loan_id;
    END IF;
END;
$$;


-- =====================================================================
-- SECTION 5: VIEWS
-- =====================================================================

-- View 1: per-customer account summary
CREATE OR REPLACE VIEW vw_customer_account_summary AS
SELECT
    c.Customer_ID,
    c.First_Name || ' ' || c.Last_Name AS Customer_Name,
    a.Account_ID,
    a.Account_Number,
    at.Type_Name AS Account_Type,
    a.Balance,
    a.Status AS Account_Status,
    b.Branch_Name
FROM CUSTOMER c
JOIN ACCOUNT a       ON a.Customer_ID = c.Customer_ID
JOIN ACCOUNT_TYPE at ON at.Account_Type_ID = a.Account_Type_ID
JOIN BRANCH b         ON b.Branch_ID = a.Branch_ID;

-- View 2: readable transaction history (who did what, on whose behalf)
CREATE OR REPLACE VIEW vw_transaction_history AS
SELECT
    t.Transaction_ID,
    t.Txn_Timestamp,
    a.Account_Number,
    c.First_Name || ' ' || c.Last_Name AS Customer_Name,
    t.Transaction_Type,
    t.Amount,
    t.Balance_After,
    t.Status,
    CASE WHEN t.Employee_ID IS NULL THEN 'Self-service'
         ELSE e.First_Name || ' ' || e.Last_Name END AS Processed_By
FROM TRANSACTION t
JOIN ACCOUNT a  ON a.Account_ID = t.Account_ID
JOIN CUSTOMER c ON c.Customer_ID = a.Customer_ID
LEFT JOIN EMPLOYEE e ON e.Employee_ID = t.Employee_ID;

-- View 3: active/approved loans with outstanding balance
CREATE OR REPLACE VIEW vw_active_loans AS
SELECT
    l.Loan_ID,
    c.First_Name || ' ' || c.Last_Name AS Customer_Name,
    lt.Type_Name AS Loan_Type,
    l.Principal_Amount,
    COALESCE(SUM(lp.Amount) FILTER (WHERE lp.Status = 'Completed'), 0) AS Total_Paid,
    l.Principal_Amount - COALESCE(SUM(lp.Amount) FILTER (WHERE lp.Status = 'Completed'), 0) AS Outstanding_Balance,
    l.EMI_Amount,
    l.Status
FROM LOAN l
JOIN CUSTOMER c   ON c.Customer_ID = l.Customer_ID
JOIN LOAN_TYPE lt ON lt.Loan_Type_ID = l.Loan_Type_ID
LEFT JOIN LOAN_PAYMENT lp ON lp.Loan_ID = l.Loan_ID
WHERE l.Status IN ('Active','Approved')
GROUP BY l.Loan_ID, c.First_Name, c.Last_Name, lt.Type_Name, l.Principal_Amount, l.EMI_Amount, l.Status;

-- View 4: branch-level summary report
CREATE OR REPLACE VIEW vw_branch_summary AS
SELECT
    b.Branch_ID,
    b.Branch_Name,
    b.City,
    COUNT(DISTINCT a.Account_ID) AS Total_Accounts,
    COALESCE(SUM(a.Balance), 0) AS Total_Deposits,
    COUNT(DISTINCT l.Loan_ID) AS Total_Loans_Issued,
    COALESCE(SUM(l.Principal_Amount), 0) AS Total_Loan_Amount
FROM BRANCH b
LEFT JOIN ACCOUNT a ON a.Branch_ID = b.Branch_ID
LEFT JOIN LOAN l    ON l.Branch_ID = b.Branch_ID
GROUP BY b.Branch_ID, b.Branch_Name, b.City;

-- View 5: employee transaction audit log (accountability reporting)
CREATE OR REPLACE VIEW vw_employee_transaction_log AS
SELECT
    e.Employee_ID,
    e.First_Name || ' ' || e.Last_Name AS Employee_Name,
    e.Position,
    t.Transaction_ID,
    t.Transaction_Type,
    t.Amount,
    t.Txn_Timestamp,
    a.Account_Number
FROM TRANSACTION t
JOIN EMPLOYEE e ON e.Employee_ID = t.Employee_ID
JOIN ACCOUNT a  ON a.Account_ID = t.Account_ID
WHERE t.Employee_ID IS NOT NULL
ORDER BY t.Txn_Timestamp DESC;


-- =====================================================================
-- SECTION 6: SAMPLE / DUMMY DATA
-- =====================================================================

-- Branches
INSERT INTO BRANCH (Branch_Name, Address, City, IFSC_Code, Phone) VALUES
('Guwahati Main Branch', 'GS Road', 'Guwahati', 'ACAD0001001', '9000000001'),
('Dispur Branch',        'Dispur Circle', 'Guwahati', 'ACAD0001002', '9000000002'),
('Silchar Branch',       'Park Road', 'Silchar', 'ACAD0001003', '9000000003');

-- Employees (Employee_ID 5 is an Admin)
INSERT INTO EMPLOYEE (First_Name, Last_Name, Branch_ID, Position, Phone, Email) VALUES
('Anita', 'Sharma', 1, 'Teller',       '9111100001', 'anita.sharma@acadbank.test'),
('Rahul', 'Das',    1, 'Loan_Officer', '9111100002', 'rahul.das@acadbank.test'),
('Priya', 'Bora',   2, 'Manager',      '9111100003', 'priya.bora@acadbank.test'),
('Sanjay','Gogoi',  3, 'Teller',       '9111100004', 'sanjay.gogoi@acadbank.test'),
('Meera', 'Kalita', 1, 'Admin',        '9111100005', 'meera.kalita@acadbank.test');

-- Customers
INSERT INTO CUSTOMER (First_Name, Last_Name, DOB, Address, Phone, Email) VALUES
('Arjun', 'Verma',   '1995-03-12', 'Zoo Road, Guwahati',   '9222200001', 'arjun.verma@example.test'),
('Sneha', 'Kumar',   '1998-07-25', 'Fancy Bazar, Guwahati','9222200002', 'sneha.kumar@example.test'),
('Vikram','Choudhury','1990-11-02','Dispur, Guwahati',     '9222200003', 'vikram.c@example.test'),
('Ritu',  'Saikia',  '2000-01-18', 'Silchar Town',         '9222200004', 'ritu.saikia@example.test');

-- Login (password hashes are placeholders — hash real passwords with
-- bcrypt at the application layer before inserting)
INSERT INTO LOGIN (Username, Password_Hash, Role, Customer_ID, Employee_ID) VALUES
('arjun.verma',  '$2b$12$placeholderhash0000000000000000000000000001', 'customer', 1, NULL),
('sneha.kumar',  '$2b$12$placeholderhash0000000000000000000000000002', 'customer', 2, NULL),
('vikram.c',     '$2b$12$placeholderhash0000000000000000000000000003', 'customer', 3, NULL),
('ritu.saikia',  '$2b$12$placeholderhash0000000000000000000000000004', 'customer', 4, NULL),
('anita.sharma', '$2b$12$placeholderhash0000000000000000000000000005', 'employee', NULL, 1),
('rahul.das',    '$2b$12$placeholderhash0000000000000000000000000006', 'employee', NULL, 2),
('priya.bora',   '$2b$12$placeholderhash0000000000000000000000000007', 'employee', NULL, 3),
('meera.kalita', '$2b$12$placeholderhash0000000000000000000000000008', 'admin',    NULL, 5);

-- Account types
INSERT INTO ACCOUNT_TYPE (Type_Name, Interest_Rate, Min_Balance) VALUES
('Savings',       3.50, 500.00),
('Current',       0.00, 1000.00),
('Fixed_Deposit', 6.50, 10000.00);

-- Loan types
INSERT INTO LOAN_TYPE (Type_Name, Interest_Rate, Max_Tenure_Months) VALUES
('Personal',  12.00, 60),
('Home',       8.50, 240),
('Auto',      10.00, 84),
('Education',  7.50, 120);

-- Accounts (opening balances inserted directly here, not via TRANSACTION,
-- since these represent initial account funding, not a logged transaction)
INSERT INTO ACCOUNT (Account_Number, Customer_ID, Branch_ID, Account_Type_ID, Balance, Status) VALUES
('AC10001001', 1, 1, 1, 25000.00, 'Active'),
('AC10001002', 2, 1, 1, 15000.00, 'Active'),
('AC10001003', 3, 2, 2, 50000.00, 'Active'),
('AC10001004', 4, 3, 1, 8000.00,  'Active');

-- Sample transactions via stored procedures (demonstrates triggers firing)
CALL sp_deposit(1, NULL, 5000.00);          -- Arjun deposits himself
CALL sp_withdraw(2, 1, 2000.00);             -- Anita (employee) withdraws for Sneha
CALL sp_fund_transfer(1, 3, NULL, 3000.00);  -- Arjun transfers to Vikram, self-service

-- Sample loan + loan payment
INSERT INTO LOAN (Customer_ID, Branch_ID, Loan_Type_ID, Employee_ID, Principal_Amount, Interest_Rate, Tenure_Months, EMI_Amount, Status, Start_Date) VALUES
(3, 2, 1, 2, 100000.00, 12.00, 24, 4708.33, 'Active', CURRENT_DATE);

CALL sp_loan_payment(1, 3, 2, 4708.33);      -- Rahul processes Vikram's EMI

-- =====================================================================
-- End of script. Verify with:
--   SELECT * FROM vw_customer_account_summary;
--   SELECT * FROM vw_transaction_history;
--   SELECT * FROM vw_active_loans;
--   SELECT * FROM vw_branch_summary;
--   SELECT * FROM vw_employee_transaction_log;
-- =====================================================================
