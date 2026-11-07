
BEGIN;

-- ============================================================
-- 1. TRANSACTION VALIDATION AND BALANCE SNAPSHOT
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_balance       NUMERIC(14,5);
    v_status        VARCHAR(10);
    v_minimum       NUMERIC(12,2);
    v_limit         NUMERIC(14,2);
    v_new_balance   NUMERIC(14,5);
BEGIN
    -- Pending and failed transactions do not change balances.
    IF NEW.Status <> 'Completed' THEN
        SELECT Current_Balance
          INTO v_balance
          FROM ACCOUNT
         WHERE Account_No = NEW.Account_No
         FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Account % does not exist', NEW.Account_No;
        END IF;

        NEW.Balance_After := v_balance;
        RETURN NEW;
    END IF;

    SELECT a.Current_Balance,
           a.Status,
           at.Minimum_Balance,
           at.Transaction_Limit
      INTO v_balance, v_status, v_minimum, v_limit
      FROM ACCOUNT a
      JOIN ACCOUNT_TYPE at
        ON at.Account_Type_ID = a.Account_Type_ID
     WHERE a.Account_No = NEW.Account_No
     FOR UPDATE OF a;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % does not exist or has no account type',
            NEW.Account_No;
    END IF;

    IF v_status <> 'Active' THEN
        RAISE EXCEPTION
            'Transactions require an Active account. Account % has status %',
            NEW.Account_No, v_status;
    END IF;

    IF NEW.Amount IS NULL OR NEW.Amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be positive';
    END IF;

    IF NEW.Amount > v_limit THEN
        RAISE EXCEPTION
            'Amount % exceeds transaction limit %',
            NEW.Amount, v_limit;
    END IF;

    CASE NEW.Transaction_Type
        WHEN 'Deposit' THEN
            v_new_balance := v_balance + NEW.Amount;

        WHEN 'Transfer_In' THEN
            v_new_balance := v_balance + NEW.Amount;

        WHEN 'Withdrawal' THEN
            v_new_balance := v_balance - NEW.Amount;

        WHEN 'Transfer_Out' THEN
            v_new_balance := v_balance - NEW.Amount;

        WHEN 'Loan_Payment' THEN
            v_new_balance := v_balance - NEW.Amount;

        ELSE
            RAISE EXCEPTION
                'Unsupported transaction type: %',
                NEW.Transaction_Type;
    END CASE;

    -- Apply the minimum-balance rule to debit transactions.
    IF NEW.Transaction_Type IN
       ('Withdrawal', 'Transfer_Out', 'Loan_Payment') THEN

        IF v_new_balance < v_minimum THEN
            RAISE EXCEPTION
                'Transaction would reduce balance below minimum balance %',
                v_minimum;
        END IF;
    ELSIF v_new_balance < 0 THEN
        RAISE EXCEPTION
            'Insufficient funds in account %',
            NEW.Account_No;
    END IF;

    -- Always calculate this value; do not trust caller-supplied values.
    NEW.Balance_After := v_new_balance;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 2. AUTOMATIC ACCOUNT BALANCE UPDATE
-- ============================================================

CREATE OR REPLACE FUNCTION fn_apply_transaction_to_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_delta NUMERIC(14,5) := 0;
BEGIN
    IF NEW.Status <> 'Completed' THEN
        RETURN NEW;
    END IF;

    CASE NEW.Transaction_Type
        WHEN 'Deposit' THEN
            v_delta := NEW.Amount;

        WHEN 'Transfer_In' THEN
            v_delta := NEW.Amount;

        WHEN 'Withdrawal' THEN
            v_delta := -NEW.Amount;

        WHEN 'Transfer_Out' THEN
            v_delta := -NEW.Amount;

        WHEN 'Loan_Payment' THEN
            v_delta := -NEW.Amount;

        ELSE
            RAISE EXCEPTION
                'Unsupported transaction type: %',NEW.Transaction_Type;
    END CASE;

    UPDATE ACCOUNT
       SET Current_Balance = Current_Balance + v_delta
     WHERE Account_No = NEW.Account_No;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Account % does not exist', NEW.Account_No;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 3. FUND TRANSFER VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_fund_transfer()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    d RECORD;
    c RECORD;
    s_status VARCHAR(10);
    t_status VARCHAR(10);
BEGIN
    IF NEW.Debit_Transaction_ID IS NULL
       OR NEW.Credit_Transaction_ID IS NULL THEN
        RAISE EXCEPTION
            'Debit_Transaction_ID and Credit_Transaction_ID are required';
    END IF;

    IF NEW.Debit_Transaction_ID = NEW.Credit_Transaction_ID THEN
        RAISE EXCEPTION
            'Debit and credit transaction IDs must differ';
    END IF;

    IF NEW.From_Account_No = NEW.To_Account_No THEN
        RAISE EXCEPTION
            'Source and destination accounts must differ';
    END IF;

    IF NEW.Transaction_ID IS DISTINCT FROM NEW.Debit_Transaction_ID THEN
        RAISE EXCEPTION
            'Transaction_ID must equal Debit_Transaction_ID';
    END IF;

    -- Lock both accounts in a consistent order.
    PERFORM 1
      FROM ACCOUNT
     WHERE Account_No IN
           (NEW.From_Account_No, NEW.To_Account_No)
     ORDER BY Account_No
     FOR UPDATE;

    IF (
        SELECT COUNT(*)
          FROM ACCOUNT
         WHERE Account_No IN
               (NEW.From_Account_No, NEW.To_Account_No)
    ) <> 2 THEN
        RAISE EXCEPTION
            'Source and destination accounts must both exist';
    END IF;

    SELECT Status
      INTO s_status
      FROM ACCOUNT
     WHERE Account_No = NEW.From_Account_No;

    SELECT Status
      INTO t_status
      FROM ACCOUNT
     WHERE Account_No = NEW.To_Account_No;

    IF s_status <> 'Active' OR t_status <> 'Active' THEN
        RAISE EXCEPTION
            'Both source and destination accounts must be Active';
    END IF;

    SELECT *
      INTO d
      FROM "TRANSACTION"
     WHERE Transaction_ID = NEW.Debit_Transaction_ID;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Debit transaction % does not exist',
            NEW.Debit_Transaction_ID;
    END IF;

    SELECT *
      INTO c
      FROM "TRANSACTION"
     WHERE Transaction_ID = NEW.Credit_Transaction_ID;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Credit transaction % does not exist',
            NEW.Credit_Transaction_ID;
    END IF;

    IF d.Account_No <> NEW.From_Account_No
       OR d.Transaction_Type <> 'Transfer_Out' THEN
        RAISE EXCEPTION
            'Debit transaction must be Transfer_Out on the source account';
    END IF;

    IF c.Account_No <> NEW.To_Account_No
       OR c.Transaction_Type <> 'Transfer_In' THEN
        RAISE EXCEPTION
            'Credit transaction must be Transfer_In on the destination account';
    END IF;

    IF d.Status <> 'Completed'
       OR c.Status <> 'Completed'
       OR d.Amount <> c.Amount THEN
        RAISE EXCEPTION
            'Transfer transactions must be Completed and have equal amounts';
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 4. LOAN PAYMENT VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_loan_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    l RECORD;
    tx RECORD;
BEGIN
    SELECT *
      INTO l
      FROM LOAN
     WHERE Loan_ID = NEW.Loan_ID
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist', NEW.Loan_ID;
    END IF;

    IF l.Loan_Status <> 'Active' THEN
        RAISE EXCEPTION
            'Loan payments require an Active loan';
    END IF;

    SELECT *
      INTO tx
      FROM "TRANSACTION"
     WHERE Transaction_ID = NEW.Transaction_ID;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Transaction % does not exist', NEW.Transaction_ID;
    END IF;

    IF tx.Transaction_Type <> 'Loan_Payment' THEN
        RAISE EXCEPTION
            'Linked transaction must have type Loan_Payment';
    END IF;

    IF tx.Status <> NEW.Payment_Status THEN
        RAISE EXCEPTION
            'Transaction status and loan payment status must match';
    END IF;

    IF NEW.Principal_Paid < 0 OR NEW.Interest_Paid < 0 THEN
        RAISE EXCEPTION
            'Principal and interest paid cannot be negative';
    END IF;

    IF NEW.Principal_Paid + NEW.Interest_Paid <= 0 THEN
        RAISE EXCEPTION
            'Principal plus interest paid must be positive';
    END IF;

    IF tx.Status = 'Completed' THEN
        IF tx.Account_No <> l.Account_No THEN
            RAISE EXCEPTION
                'Loan payment must debit the account linked to the loan';
        END IF;

        IF ROUND(tx.Amount::NUMERIC, 2) <>
           ROUND((NEW.Principal_Paid + NEW.Interest_Paid)::NUMERIC, 2) THEN
            RAISE EXCEPTION
                'Transaction amount must equal principal plus interest paid';
        END IF;

        IF NEW.Principal_Paid > l.Remaining_Amount THEN
            RAISE EXCEPTION
                'Principal paid exceeds outstanding principal %',
                l.Remaining_Amount;
        END IF;

        NEW.Remaining_Balance :=
            l.Remaining_Amount - NEW.Principal_Paid;
    ELSE
        -- Failed/pending payments do not reduce loan principal.
        NEW.Remaining_Balance := l.Remaining_Amount;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 5. UPDATE LOAN BALANCE AND CLOSE FULLY PAID LOANS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_apply_loan_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_remaining NUMERIC(14,2);
BEGIN
    IF NEW.Payment_Status <> 'Completed' THEN
        RETURN NEW;
    END IF;

    UPDATE LOAN
       SET Remaining_Amount = Remaining_Amount - NEW.Principal_Paid
     WHERE Loan_ID = NEW.Loan_ID
     RETURNING Remaining_Amount INTO v_remaining;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist', NEW.Loan_ID;
    END IF;

    IF v_remaining < 0 THEN
        RAISE EXCEPTION
            'Loan remaining amount cannot be negative';
    END IF;

    IF v_remaining = 0 THEN
        UPDATE LOAN
           SET Loan_Status = 'Closed',
               End_Date = COALESCE(End_Date, CURRENT_DATE)
         WHERE Loan_ID = NEW.Loan_ID;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 6. LOAN STATUS TRANSITION VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_loan_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.Loan_Status = OLD.Loan_Status THEN
        RETURN NEW;
    END IF;

    IF OLD.Loan_Status = 'Applied'
       AND NEW.Loan_Status IN ('Approved', 'Rejected') THEN
        RETURN NEW;
    END IF;

    IF OLD.Loan_Status = 'Approved'
       AND NEW.Loan_Status = 'Active' THEN

        IF NEW.Start_Date IS NULL THEN
            NEW.Start_Date := CURRENT_DATE;
        END IF;

        RETURN NEW;
    END IF;

    IF OLD.Loan_Status = 'Active'
       AND NEW.Loan_Status = 'Closed' THEN

        IF NEW.Remaining_Amount <> 0 THEN
            RAISE EXCEPTION
                'Loan can be Closed only when Remaining_Amount is zero';
        END IF;

        IF NEW.End_Date IS NULL THEN
            NEW.End_Date := CURRENT_DATE;
        END IF;

        RETURN NEW;
    END IF;

    RAISE EXCEPTION
        'Invalid loan status transition: % -> %',
        OLD.Loan_Status, NEW.Loan_Status;
END;
$$;


-- ============================================================
-- 7. ACCOUNT LIFECYCLE VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_account_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_status VARCHAR(10);
    v_branch_status   VARCHAR(10);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT Status
          INTO v_customer_status
          FROM CUSTOMER
         WHERE CIF = NEW.CIF;

        IF v_customer_status IS DISTINCT FROM 'Active' THEN
            RAISE EXCEPTION
                'Only Active customers may open accounts';
        END IF;

        SELECT Status
          INTO v_branch_status
          FROM BRANCH
         WHERE IFSC = NEW.IFSC;

        IF v_branch_status IS DISTINCT FROM 'Active' THEN
            RAISE EXCEPTION
                'Accounts can be opened only at Active branches';
        END IF;

        IF NEW.Status IS DISTINCT FROM 'Active' THEN
            RAISE EXCEPTION
                'New accounts must start as Active';
        END IF;

        RETURN NEW;
    END IF;

    -- Balance updates are allowed from the transaction-processing
    -- trigger, but not from ordinary direct UPDATE statements.
    IF NEW.Current_Balance IS DISTINCT FROM OLD.Current_Balance
       AND pg_trigger_depth() = 1 THEN
        RAISE EXCEPTION
            'Current_Balance must be changed through a TRANSACTION record';
    END IF;

    IF NEW.Status = 'Closed' AND OLD.Status <> 'Closed' THEN
        IF NEW.Current_Balance <> 0 THEN
            RAISE EXCEPTION
                'Account cannot be closed with a non-zero balance';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM LOAN
             WHERE Account_No = OLD.Account_No
               AND Loan_Status IN ('Applied', 'Approved', 'Active')
        ) THEN
            RAISE EXCEPTION
                'Account cannot be closed while it has an open loan';
        END IF;
    END IF;

    IF OLD.Status = 'Closed' AND NEW.Status <> 'Closed' THEN
        RAISE EXCEPTION
            'Closed accounts cannot be reactivated';
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 8. BRANCH MANAGER VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_branch_manager()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    e RECORD;
BEGIN
    IF NEW.Manager_ID IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT Employee_ID, IFSC, Role, Status
      INTO e
      FROM EMPLOYEE
     WHERE Employee_ID = NEW.Manager_ID;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Manager employee % does not exist', NEW.Manager_ID;
    END IF;

    IF e.Role <> 'Manager' THEN
        RAISE EXCEPTION
            'Assigned employee must have Role Manager';
    END IF;

    IF e.Status <> 'Active' THEN
        RAISE EXCEPTION
            'Assigned manager must be Active';
    END IF;

    IF e.IFSC <> NEW.IFSC THEN
        RAISE EXCEPTION
            'Manager must belong to the same branch';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION fn_protect_assigned_manager()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (
        NEW.Status <> 'Active'
        OR NEW.Role <> 'Manager'
        OR NEW.IFSC <> OLD.IFSC
    )
    AND EXISTS (
        SELECT 1
          FROM BRANCH
         WHERE Manager_ID = OLD.Employee_ID
    ) THEN
        RAISE EXCEPTION
            'Remove or reassign the branch manager before deactivating, '
            'changing the role, or moving this employee';
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 9. LOGIN OWNER VALIDATION
-- ============================================================

CREATE OR REPLACE FUNCTION fn_validate_login_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(10);
    v_role   VARCHAR(30);
BEGIN
    IF NEW.Role = 'customer' THEN
        SELECT Status
          INTO v_status
          FROM CUSTOMER
         WHERE CIF = NEW.CIF;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Login customer does not exist';
        END IF;

        IF v_status <> 'Active'
           AND NEW.Account_Status = 'Active' THEN
            RAISE EXCEPTION
                'Inactive customer cannot have an Active login';
        END IF;

    ELSE
        SELECT Status, Role
          INTO v_status, v_role
          FROM EMPLOYEE
         WHERE Employee_ID = NEW.Employee_ID;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Login employee does not exist';
        END IF;

        IF v_status <> 'Active'
           AND NEW.Account_Status = 'Active' THEN
            RAISE EXCEPTION
                'Inactive employee cannot have an Active login';
        END IF;

        IF NEW.Role = 'admin' AND v_role <> 'Admin' THEN
            RAISE EXCEPTION
                'Admin login requires Employee.Role = Admin';
        END IF;

        IF NEW.Role = 'employee'
           AND v_role NOT IN ('Employee', 'Manager') THEN
            RAISE EXCEPTION
                'Employee login requires Employee or Manager role';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 10. SYNCHRONIZE LOGIN STATUS WITH CUSTOMER/EMPLOYEE STATUS
-- ============================================================

CREATE OR REPLACE FUNCTION fn_sync_login_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.Status IS DISTINCT FROM OLD.Status THEN
        IF TG_TABLE_NAME = 'customer' THEN
            UPDATE LOGIN
               SET Account_Status =
                   CASE
                       WHEN NEW.Status = 'Active' THEN 'Active'
                       ELSE 'Disabled'
                   END
             WHERE CIF = NEW.CIF
               AND Account_Status <> 'Locked';

        ELSIF TG_TABLE_NAME = 'employee' THEN
            UPDATE LOGIN
               SET Account_Status =
                   CASE
                       WHEN NEW.Status = 'Active' THEN 'Active'
                       ELSE 'Disabled'
                   END
             WHERE Employee_ID = NEW.Employee_ID
               AND Account_Status <> 'Locked';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


-- ============================================================
-- 11. MAKE TRANSACTION HISTORY IMMUTABLE
-- ============================================================

CREATE OR REPLACE FUNCTION fn_prevent_transaction_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Transaction history is immutable; create a reversal or adjustment transaction instead';
END;
$$;


-- ============================================================
-- 12. AUDIT TRAIL
-- Password hashes are deliberately excluded from audit JSON.
-- ============================================================

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

-- ============================================================
-- 13. CREATE THE ACTUAL TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_transaction_validate ON "TRANSACTION";

CREATE TRIGGER trg_transaction_validate
BEFORE INSERT ON "TRANSACTION"
FOR EACH ROW
EXECUTE FUNCTION fn_validate_transaction();

DROP TRIGGER IF EXISTS trg_transaction_apply_balance ON "TRANSACTION";

CREATE TRIGGER trg_transaction_apply_balance
AFTER INSERT ON "TRANSACTION"
FOR EACH ROW
EXECUTE FUNCTION fn_apply_transaction_to_balance();

DROP TRIGGER IF EXISTS trg_transaction_immutable ON "TRANSACTION";

CREATE TRIGGER trg_transaction_immutable
BEFORE UPDATE OR DELETE ON "TRANSACTION"
FOR EACH ROW
EXECUTE FUNCTION fn_prevent_transaction_mutation();


DROP TRIGGER IF EXISTS trg_fund_transfer_validate ON FUND_TRANSFER;

CREATE TRIGGER trg_fund_transfer_validate
BEFORE INSERT ON FUND_TRANSFER
FOR EACH ROW
EXECUTE FUNCTION fn_validate_fund_transfer();


DROP TRIGGER IF EXISTS trg_loan_payment_validate ON LOAN_PAYMENT;

CREATE TRIGGER trg_loan_payment_validate
BEFORE INSERT ON LOAN_PAYMENT
FOR EACH ROW
EXECUTE FUNCTION fn_validate_loan_payment();

DROP TRIGGER IF EXISTS trg_loan_payment_apply ON LOAN_PAYMENT;

CREATE TRIGGER trg_loan_payment_apply
AFTER INSERT ON LOAN_PAYMENT
FOR EACH ROW
EXECUTE FUNCTION fn_apply_loan_payment();


DROP TRIGGER IF EXISTS trg_loan_status_transition ON LOAN;

CREATE TRIGGER trg_loan_status_transition
BEFORE UPDATE OF Loan_Status ON LOAN
FOR EACH ROW
EXECUTE FUNCTION fn_validate_loan_status_transition();


DROP TRIGGER IF EXISTS trg_account_lifecycle ON ACCOUNT;

CREATE TRIGGER trg_account_lifecycle
BEFORE INSERT OR UPDATE ON ACCOUNT
FOR EACH ROW
EXECUTE FUNCTION fn_validate_account_lifecycle();


DROP TRIGGER IF EXISTS trg_branch_manager_validate ON BRANCH;

CREATE TRIGGER trg_branch_manager_validate
BEFORE INSERT OR UPDATE ON BRANCH
FOR EACH ROW
EXECUTE FUNCTION fn_validate_branch_manager();


DROP TRIGGER IF EXISTS trg_protect_assigned_manager ON EMPLOYEE;

CREATE TRIGGER trg_protect_assigned_manager
BEFORE UPDATE ON EMPLOYEE
FOR EACH ROW
EXECUTE FUNCTION fn_protect_assigned_manager();


DROP TRIGGER IF EXISTS trg_login_validate ON LOGIN;

CREATE TRIGGER trg_login_validate
BEFORE INSERT OR UPDATE ON LOGIN
FOR EACH ROW
EXECUTE FUNCTION fn_validate_login_owner();


DROP TRIGGER IF EXISTS trg_customer_sync_login ON CUSTOMER;

CREATE TRIGGER trg_customer_sync_login
AFTER UPDATE OF Status ON CUSTOMER
FOR EACH ROW
EXECUTE FUNCTION fn_sync_login_status();

DROP TRIGGER IF EXISTS trg_employee_sync_login ON EMPLOYEE;

CREATE TRIGGER trg_employee_sync_login
AFTER UPDATE OF Status ON EMPLOYEE
FOR EACH ROW
EXECUTE FUNCTION fn_sync_login_status();


-- ============================================================
-- 14. AUDIT TRIGGERS
-- ============================================================

DROP TRIGGER IF EXISTS trg_audit_branch ON BRANCH;

CREATE TRIGGER trg_audit_branch
AFTER INSERT OR UPDATE OR DELETE ON BRANCH
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_customer ON CUSTOMER;

CREATE TRIGGER trg_audit_customer
AFTER INSERT OR UPDATE OR DELETE ON CUSTOMER
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_employee ON EMPLOYEE;

CREATE TRIGGER trg_audit_employee
AFTER INSERT OR UPDATE OR DELETE ON EMPLOYEE
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_account ON ACCOUNT;

CREATE TRIGGER trg_audit_account
AFTER INSERT OR UPDATE OR DELETE ON ACCOUNT
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_login ON LOGIN;

CREATE TRIGGER trg_audit_login
AFTER INSERT OR UPDATE OR DELETE ON LOGIN
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_transaction ON "TRANSACTION";

CREATE TRIGGER trg_audit_transaction
AFTER INSERT ON "TRANSACTION"
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_fund_transfer ON FUND_TRANSFER;

CREATE TRIGGER trg_audit_fund_transfer
AFTER INSERT OR UPDATE OR DELETE ON FUND_TRANSFER
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_loan ON LOAN;

CREATE TRIGGER trg_audit_loan
AFTER INSERT OR UPDATE OR DELETE ON LOAN
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();

DROP TRIGGER IF EXISTS trg_audit_loan_payment ON LOAN_PAYMENT;

CREATE TRIGGER trg_audit_loan_payment
AFTER INSERT OR UPDATE OR DELETE ON LOAN_PAYMENT
FOR EACH ROW
EXECUTE FUNCTION fn_audit_row_change();


COMMIT;
