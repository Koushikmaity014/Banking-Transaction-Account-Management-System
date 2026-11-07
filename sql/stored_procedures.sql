-- Backend compatibility patch for the uploaded schema/triggers.
-- Apply AFTER tables.sql and triggers.sql, BEFORE the seed script.
-- Test first on a disposable development database.
BEGIN;


-- Fix audit JSON key casing. The schema uses unquoted identifiers, so JSON keys
-- are lowercase. This also ensures password_hash is excluded from audit data.
CREATE OR REPLACE FUNCTION fn_audit_row_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    old_json JSONB;
    new_json JSONB;
    key_text TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        new_json := to_jsonb(NEW) - 'password_hash';
        key_text := COALESCE(
            new_json->>'cif', new_json->>'employee_id', new_json->>'account_no',
            new_json->>'ifsc', new_json->>'login_id', new_json->>'loan_id',
            new_json->>'payment_id', new_json->>'transaction_id', 'unknown'
        );
        INSERT INTO audit_log (table_name, record_key, operation, new_data)
        VALUES (TG_TABLE_NAME, key_text, TG_OP, new_json);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        old_json := to_jsonb(OLD) - 'password_hash';
        new_json := to_jsonb(NEW) - 'password_hash';
        key_text := COALESCE(
            new_json->>'cif', new_json->>'employee_id', new_json->>'account_no',
            new_json->>'ifsc', new_json->>'login_id', new_json->>'loan_id',
            new_json->>'payment_id', new_json->>'transaction_id', 'unknown'
        );
        INSERT INTO audit_log (table_name, record_key, operation, old_data, new_data)
        VALUES (TG_TABLE_NAME, key_text, TG_OP, old_json, new_json);
        RETURN NEW;
    ELSE
        old_json := to_jsonb(OLD) - 'password_hash';
        key_text := COALESCE(
            old_json->>'cif', old_json->>'employee_id', old_json->>'account_no',
            old_json->>'ifsc', old_json->>'login_id', old_json->>'loan_id',
            old_json->>'payment_id', old_json->>'transaction_id', 'unknown'
        );
        INSERT INTO audit_log (table_name, record_key, operation, old_data)
        VALUES (TG_TABLE_NAME, key_text, TG_OP, old_json);
        RETURN OLD;
    END IF;
END;
$$;

-- Changing an argument type creates an overload in PostgreSQL rather than
-- replacing the old signature. Remove the two incompatible original versions.
DROP PROCEDURE IF EXISTS sp_open_account(VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, NUMERIC);
DROP PROCEDURE IF EXISTS sp_apply_loan(VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, NUMERIC, NUMERIC, INTEGER, NUMERIC, DATE, DATE);

-- A loan application has no approving employee yet. The employee is assigned
-- when an authorized manager/admin decides the application.
ALTER TABLE LOAN ALTER COLUMN Employee_ID DROP NOT NULL;

-- Deposit: do not update ACCOUNT directly. The TRANSACTION trigger owns balance changes.
CREATE OR REPLACE PROCEDURE sp_deposit(
    IN p_transaction_id VARCHAR(20),
    IN p_account_no VARCHAR(20),
    IN p_amount NUMERIC(14,5),
    IN p_channel VARCHAR(20),
    IN p_employee_id VARCHAR(20) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Deposit amount must be positive';
    END IF;
    IF p_channel IS NULL OR p_channel NOT IN
       ('Branch','ATM','Online_Banking','UPI','POS','Cheque','NEFT','RTGS','IMPS') THEN
        RAISE EXCEPTION 'Invalid transaction channel';
    END IF;

    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Employee_ID, Transaction_Type,
         Amount, Channel, Status)
    VALUES
        (p_transaction_id, p_account_no, p_employee_id, 'Deposit',
         p_amount, p_channel, 'Completed');
END;
$$;

-- Withdrawal: trigger validates active status, minimum balance and transaction limit.
CREATE OR REPLACE PROCEDURE sp_withdraw(
    IN p_transaction_id VARCHAR(20),
    IN p_account_no VARCHAR(20),
    IN p_amount NUMERIC(14,5),
    IN p_channel VARCHAR(20),
    IN p_employee_id VARCHAR(20) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Withdrawal amount must be positive';
    END IF;
    IF p_channel IS NULL OR p_channel NOT IN
       ('Branch','ATM','Online_Banking','UPI','POS','Cheque','NEFT','RTGS','IMPS') THEN
        RAISE EXCEPTION 'Invalid transaction channel';
    END IF;

    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Employee_ID, Transaction_Type,
         Amount, Channel, Status)
    VALUES
        (p_transaction_id, p_account_no, p_employee_id, 'Withdrawal',
         p_amount, p_channel, 'Completed');
END;
$$;

-- Transfer: lock accounts in consistent order; only insert transaction rows.
-- The transaction triggers apply each balance delta. The whole CALL is atomic.
CREATE OR REPLACE PROCEDURE sp_fund_transfer(
    IN p_debit_transaction_id VARCHAR(20),
    IN p_credit_transaction_id VARCHAR(20),
    IN p_from_account VARCHAR(20),
    IN p_to_account VARCHAR(20),
    IN p_amount NUMERIC(14,5),
    IN p_transfer_mode VARCHAR(20),
    IN p_reference_no VARCHAR(30),
    IN p_employee_id VARCHAR(20) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_channel VARCHAR(20);
    v_active_count INTEGER;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive';
    END IF;
    IF p_from_account IS NULL OR p_to_account IS NULL OR p_from_account = p_to_account THEN
        RAISE EXCEPTION 'Source and destination accounts must differ';
    END IF;
    IF p_debit_transaction_id IS NULL OR p_credit_transaction_id IS NULL
       OR p_debit_transaction_id = p_credit_transaction_id THEN
        RAISE EXCEPTION 'Debit and credit transaction IDs must be distinct';
    END IF;
    IF p_transfer_mode IS NULL OR p_transfer_mode NOT IN
       ('UPI','Internal_Transfer','Cheque','NEFT','RTGS','IMPS') THEN
        RAISE EXCEPTION 'Invalid transfer mode';
    END IF;
    IF p_reference_no IS NULL OR length(trim(p_reference_no)) = 0 THEN
        RAISE EXCEPTION 'Reference number is required';
    END IF;

    v_channel := CASE WHEN p_transfer_mode = 'Internal_Transfer'
                      THEN 'Online_Banking' ELSE p_transfer_mode END;

    PERFORM 1
      FROM ACCOUNT
     WHERE Account_No IN (p_from_account, p_to_account)
     ORDER BY Account_No
     FOR UPDATE;

    SELECT COUNT(*) INTO v_active_count
      FROM ACCOUNT
     WHERE Account_No IN (p_from_account, p_to_account)
       AND Status = 'Active';
    IF v_active_count <> 2 THEN
        RAISE EXCEPTION 'Both accounts must exist and be active';
    END IF;

    -- Debit first, credit second. Any failure rolls back both rows and balances.
    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount, Channel, Status)
    VALUES
        (p_debit_transaction_id, p_from_account, p_employee_id,
         'Transfer_Out', p_amount, v_channel, 'Completed');

    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount, Channel, Status)
    VALUES
        (p_credit_transaction_id, p_to_account, p_employee_id,
         'Transfer_In', p_amount, v_channel, 'Completed');

    INSERT INTO FUND_TRANSFER
        (Transaction_ID, From_Account_No, To_Account_No, Transfer_Mode,
         Reference_No, Debit_Transaction_ID, Credit_Transaction_ID)
    VALUES
        (p_debit_transaction_id, p_from_account, p_to_account, p_transfer_mode,
         p_reference_no, p_debit_transaction_id, p_credit_transaction_id);
END;
$$;

-- Open account: compatible VARCHAR account-type ID and a real opening transaction.
CREATE OR REPLACE PROCEDURE sp_open_account(
    IN p_account_no VARCHAR(20),
    IN p_cif VARCHAR(15),
    IN p_ifsc VARCHAR(11),
    IN p_nominee VARCHAR(100),
    IN p_account_type_id VARCHAR(20),
    IN p_initial_balance NUMERIC(14,5)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_min_balance NUMERIC(12,2);
    v_opening_tx VARCHAR(20);
BEGIN
    IF p_initial_balance IS NULL OR p_initial_balance <= 0 THEN
        RAISE EXCEPTION 'Initial balance must be positive';
    END IF;

    SELECT Minimum_Balance INTO v_min_balance
      FROM ACCOUNT_TYPE WHERE Account_Type_ID = p_account_type_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account type does not exist';
    END IF;
    IF p_initial_balance < v_min_balance THEN
        RAISE EXCEPTION 'Initial balance is below the minimum required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM CUSTOMER WHERE CIF = p_cif AND Status = 'Active') THEN
        RAISE EXCEPTION 'Customer does not exist or is inactive';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM BRANCH WHERE IFSC = p_ifsc AND Status = 'Active') THEN
        RAISE EXCEPTION 'Branch does not exist or is inactive';
    END IF;

    INSERT INTO ACCOUNT
        (Account_No, CIF, IFSC, Nominee, Account_Type_ID, Opening_Date, Status, Current_Balance)
    VALUES
        (p_account_no, p_cif, p_ifsc, p_nominee, p_account_type_id, CURRENT_DATE, 'Active', 0);

    v_opening_tx := 'OP' || substr(md5(random()::text || clock_timestamp()::text), 1, 18);
    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Transaction_Type, Amount, Channel, Status)
    VALUES
        (v_opening_tx, p_account_no, 'Deposit', p_initial_balance, 'Branch', 'Completed');
END;
$$;

-- Apply loan: compatible VARCHAR loan-type ID; approval employee is NULL at application time.
-- The rate is read from LOAN_TYPE, not trusted from the caller. Start/end dates are
-- assigned only when the loan is approved/activated.
CREATE OR REPLACE PROCEDURE sp_apply_loan(
    IN p_loan_id VARCHAR(20),
    IN p_cif VARCHAR(15),
    IN p_account_no VARCHAR(20),
    IN p_loan_type_id VARCHAR(20),
    IN p_employee_id VARCHAR(20),
    IN p_principal NUMERIC(14,5),
    IN p_interest_rate NUMERIC(7,4),
    IN p_tenure_months INTEGER,
    IN p_emi NUMERIC(14,5),
    IN p_start_date DATE,
    IN p_end_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rate NUMERIC(5,2);
    v_max NUMERIC(14,2);
BEGIN
    IF p_principal IS NULL OR p_principal <= 0
       OR p_tenure_months IS NULL OR p_tenure_months <= 0
       OR p_emi IS NULL OR p_emi <= 0 THEN
        RAISE EXCEPTION 'Invalid loan principal, tenure, or EMI';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM ACCOUNT
         WHERE Account_No = p_account_no AND CIF = p_cif AND Status = 'Active'
    ) THEN
        RAISE EXCEPTION 'Customer does not own an active account';
    END IF;

    SELECT Interest_Rate, Max_Amount INTO v_rate, v_max
      FROM LOAN_TYPE WHERE Loan_Type_ID = p_loan_type_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan type does not exist';
    END IF;
    IF p_principal > v_max THEN
        RAISE EXCEPTION 'Principal exceeds the maximum amount for this loan type';
    END IF;
    IF p_interest_rate IS NOT NULL AND ROUND(p_interest_rate::numeric, 2) <> v_rate THEN
        RAISE EXCEPTION 'Interest rate does not match the selected loan type';
    END IF;
    IF p_employee_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM EMPLOYEE WHERE Employee_ID = p_employee_id AND Status = 'Active'
    ) THEN
        RAISE EXCEPTION 'Assigned employee does not exist or is inactive';
    END IF;

    INSERT INTO LOAN
        (Loan_ID, CIF, Account_No, Loan_Type_ID, Employee_ID,
         Principal_Amount, Interest_Rate, Tenure_Months, EMI_Amount,
         Remaining_Amount, Start_Date, End_Date, Loan_Status)
    VALUES
        (p_loan_id, p_cif, p_account_no, p_loan_type_id, p_employee_id,
         p_principal, v_rate, p_tenure_months, p_emi,
         p_principal, NULL, NULL, 'Applied');
END;
$$;

-- Approval respects the trigger's legal state transitions:
-- Applied -> Approved -> Active (or Applied -> Rejected).
CREATE OR REPLACE PROCEDURE sp_approve_loan(
    IN p_loan_id VARCHAR(20),
    IN p_employee_id VARCHAR(20),
    IN p_decision VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tenure INTEGER;
BEGIN
    IF p_decision IS NULL OR p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Decision must be Approved or Rejected';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM EMPLOYEE
         WHERE Employee_ID = p_employee_id AND Status = 'Active'
           AND Role IN ('Manager', 'Admin')
    ) THEN
        RAISE EXCEPTION 'An active manager or admin is required';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE LOAN
           SET Loan_Status = 'Rejected', Employee_ID = p_employee_id
         WHERE Loan_ID = p_loan_id AND Loan_Status = 'Applied';
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Loan not found or not awaiting approval';
        END IF;
        RETURN;
    END IF;

    UPDATE LOAN
       SET Loan_Status = 'Approved', Employee_ID = p_employee_id
     WHERE Loan_ID = p_loan_id AND Loan_Status = 'Applied'
     RETURNING Tenure_Months INTO v_tenure;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan not found or not awaiting approval';
    END IF;

    UPDATE LOAN
       SET Loan_Status = 'Active',
           Start_Date = CURRENT_DATE,
           End_Date = (CURRENT_DATE + make_interval(months => v_tenure))::date
     WHERE Loan_ID = p_loan_id AND Loan_Status = 'Approved';
END;
$$;

-- Loan payment: the transaction trigger debits the account; the loan-payment
-- trigger validates and updates remaining principal. Do not repeat either update here.
CREATE OR REPLACE PROCEDURE sp_loan_payment(
    IN p_payment_id VARCHAR(20),
    IN p_transaction_id VARCHAR(20),
    IN p_loan_id VARCHAR(20),
    IN p_principal_paid NUMERIC(14,5),
    IN p_interest_paid NUMERIC(14,5),
    IN p_payment_method VARCHAR(20),
    IN p_employee_id VARCHAR(20) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_account_no VARCHAR(20);
    v_total NUMERIC(14,5);
    v_channel VARCHAR(20);
BEGIN
    IF p_principal_paid IS NULL OR p_interest_paid IS NULL
       OR p_principal_paid < 0 OR p_interest_paid < 0
       OR p_principal_paid + p_interest_paid <= 0 THEN
        RAISE EXCEPTION 'Invalid payment amounts';
    END IF;
    IF p_payment_method IS NULL OR p_payment_method NOT IN
       ('UPI','Internal_Transfer','Cheque','NEFT','RTGS','IMPS') THEN
        RAISE EXCEPTION 'Invalid payment method';
    END IF;

    SELECT Account_No INTO v_account_no
      FROM LOAN WHERE Loan_ID = p_loan_id AND Loan_Status = 'Active'
      FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Active loan not found';
    END IF;

    v_total := p_principal_paid + p_interest_paid;
    v_channel := CASE WHEN p_payment_method = 'Internal_Transfer'
                      THEN 'Online_Banking' ELSE p_payment_method END;

    INSERT INTO "TRANSACTION"
        (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount, Channel, Status)
    VALUES
        (p_transaction_id, v_account_no, p_employee_id, 'Loan_Payment',
         v_total, v_channel, 'Completed');

    INSERT INTO LOAN_PAYMENT
        (Payment_ID, Loan_ID, Transaction_ID, Payment_Method, Payment_Status,
         Principal_Paid, Interest_Paid, Remaining_Balance)
    VALUES
        (p_payment_id, p_loan_id, p_transaction_id, p_payment_method, 'Completed',
         p_principal_paid, p_interest_paid, 0);
END;
$$;

-- Balance lookup retained for SQL clients.
CREATE OR REPLACE PROCEDURE sp_check_balance(
    IN p_account_no VARCHAR(20),
    OUT p_current_balance NUMERIC(14,5),
    OUT p_account_status VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT current_balance, status
      INTO p_current_balance, p_account_status
      FROM account
     WHERE account_no = p_account_no;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account not found';
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_get_transaction_history(
    IN p_account_no VARCHAR(20),
    INOUT p_result REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM account WHERE account_no = p_account_no) THEN
        RAISE EXCEPTION 'Account not found';
    END IF;
    OPEN p_result FOR
        SELECT transaction_id, transaction_type, amount, transaction_date_time,
               balance_after, channel, status
          FROM "TRANSACTION"
         WHERE account_no = p_account_no
         ORDER BY transaction_date_time DESC, transaction_id DESC;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_generate_account_statement(
    IN p_account_no VARCHAR(20),
    IN p_start_date DATE,
    IN p_end_date DATE,
    INOUT p_result REFCURSOR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Invalid statement date range';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM account WHERE account_no = p_account_no) THEN
        RAISE EXCEPTION 'Account not found';
    END IF;
    OPEN p_result FOR
        SELECT transaction_id, transaction_type, amount, transaction_date_time,
               balance_after, channel, status
          FROM "TRANSACTION"
         WHERE account_no = p_account_no
           AND transaction_date_time >= p_start_date
           AND transaction_date_time < p_end_date + INTERVAL '1 day'
         ORDER BY transaction_date_time, transaction_id;
END;
$$;


COMMIT;
