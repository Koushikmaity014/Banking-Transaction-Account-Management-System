-- ONE-TIME DEVELOPMENT SEED DATA. Run only against an empty/disposable database.
-- The identifiers and personal data are synthetic; do not use these records for real banking.
BEGIN;
SET LOCAL TIME ZONE 'Asia/Kolkata';

INSERT INTO ACCOUNT_TYPE
    (Account_Type_ID, Type_Name, Minimum_Balance, Interest_Rate, Transaction_Limit)
VALUES
    ('AT-SAV', 'Savings',       1000.00, 3.00, 200000.00),
    ('AT-CUR', 'Current',          0.00, 0.00, 500000.00),
    ('AT-SAL', 'Salary',           0.00, 2.50, 200000.00),
    ('AT-FD',  'Fixed Deposit',  5000.00, 6.50, 500000.00),
    ('AT-STU', 'Student',         500.00, 3.50, 100000.00);

INSERT INTO LOAN_TYPE (Loan_Type_ID, Loan_Type_Name, Interest_Rate, Max_Amount)
VALUES
    ('LT-HOME', 'Home Loan',       8.25, 8000000.00),
    ('LT-PERS', 'Personal Loan',  12.50, 1000000.00),
    ('LT-EDU',  'Education Loan',  7.50, 2500000.00),
    ('LT-AUTO', 'Auto Loan',       9.25, 3000000.00),
    ('LT-BUS',  'Business Loan',  11.00, 5000000.00);

-- ---------------------------------------------------------------------
-- 2. Branches
-- IFSC shape: 4 letters + 0 + 6 alphanumeric characters.
-- Fictional bank prefix "DUMY"; never use as a real bank routing code.
-- MICR shape: 3-digit city code + 3-digit synthetic bank code + 3-digit
-- branch code. MICR values are plausible in shape, not official assignments.
-- ---------------------------------------------------------------------
INSERT INTO BRANCH
    (IFSC, Branch_Name, MICR, Address, City, State, PIN, Contact,
     Manager_ID, Opening_Date, Status)
VALUES
('DUMY0KOL001','Lake Town Branch','700999001',
 'P-14, Block A, Lake Town, near VIP Road','Kolkata','West Bengal','700089',
 '+91-33-4000-1001',NULL,CURRENT_DATE - 3200,'Active'),
('DUMY0KOL002','Salt Lake Branch','700999002',
 'BD-22, Sector I, Bidhannagar, Salt Lake','Kolkata','West Bengal','700091',
 '+91-33-4000-1002',NULL,CURRENT_DATE - 2900,'Active'),
('DUMY0KOL003','Park Street Branch','700999003',
 '27A, Park Street, near Mullick Bazar','Kolkata','West Bengal','700016',
 '+91-33-4000-1003',NULL,CURRENT_DATE - 2600,'Active'),
('DUMY0KOL004','Gariahat Branch','700999004',
 '8, Gariahat Road, near Gariahat Market','Kolkata','West Bengal','700019',
 '+91-33-4000-1004',NULL,CURRENT_DATE - 2300,'Active'),
('DUMY0HOW005','Howrah Maidan Branch','711999005',
 '19, Grand Trunk Road, near Howrah Maidan','Howrah','West Bengal','711101',
 '+91-33-4000-1005',NULL,CURRENT_DATE - 2100,'Active'),
('DUMY0DUM006','Dum Dum Branch','700999006',
 '5, Jessore Road, near Dum Dum Junction','Kolkata','West Bengal','700028',
 '+91-33-4000-1006',NULL,CURRENT_DATE - 1800,'Active'),
('DUMY0NEW007','New Town Branch','700999007',
 'AA-I, Street 12, New Town Action Area I','Kolkata','West Bengal','700156',
 '+91-33-4000-1007',NULL,CURRENT_DATE - 1500,'Active'),
('DUMY0BEH008','Behala Branch','700999008',
 '44, Diamond Harbour Road, near Behala Chowrasta','Kolkata','West Bengal','700034',
 '+91-33-4000-1008',NULL,CURRENT_DATE - 1200,'Active'),
('DUMY0ESP009','Esplanade Branch','700999009',
 '12, Jawaharlal Nehru Road, Esplanade area','Kolkata','West Bengal','700069',
 '+91-33-4000-1009',NULL,CURRENT_DATE - 900,'Active'),
('DUMY0JAD010','Jadavpur Branch','700999010',
 '3, Raja S.C. Mullick Road, near Jadavpur University','Kolkata','West Bengal','700032',
 '+91-33-4000-1010',NULL,CURRENT_DATE - 600,'Active');

-- ---------------------------------------------------------------------
-- 3. Employees: 10 managers, 18 employees, 2 admins.
-- Manager_ID stays NULL until employees exist because of circular FK.
-- ---------------------------------------------------------------------
INSERT INTO EMPLOYEE
    (Employee_ID, IFSC, First_Name, Last_Name, DOB, Gender, Contact,
     Address, Joining_Date, Role, Salary, Status)
SELECT
    'EMP' || LPAD(g::text,4,'0'),
    (ARRAY['DUMY0KOL001','DUMY0KOL002','DUMY0KOL003','DUMY0KOL004',
           'DUMY0HOW005','DUMY0DUM006','DUMY0NEW007','DUMY0BEH008',
           'DUMY0ESP009','DUMY0JAD010'])[((g - 1) % 10) + 1],
    (ARRAY['Aarav','Ishita','Rohan','Ananya','Vivaan','Diya','Aditya',
           'Saanvi','Arjun','Aadhya','Reyansh','Kiara','Krishna',
           'Myra','Ishaan','Pari','Kabir','Sara','Dev','Tara',
           'Rahul','Mira','Neel','Riya','Ayan','Nisha','Soham',
           'Piya','Kunal','Ritu'])[g],
    (ARRAY['Sen','Das','Roy','Dutta','Ghosh','Bose','Mitra','Saha',
           'Banerjee','Chatterjee','Mukherjee','Datta','Pal','Paul',
           'Sharma','Verma','Gupta','Jain','Nair','Reddy',
           'Mondal','Biswas','Kundu','Sarkar','Dey','Basu',
           'Mallick','Karmakar','Ganguly','Chakraborty'])[g],
    DATE '1975-01-01' + ((g * 431) % 9000),
    (ARRAY['Male','Female','Other'])[((g - 1) % 3) + 1],
    '+91-' || (CASE WHEN g % 3 = 0 THEN '9' WHEN g % 3 = 1 THEN '8' ELSE '7' END)
      || LPAD((210000000 + g)::text,9,'0'),
    (ARRAY[
      'Staff Quarter 2A, Salt Lake Sector I, Kolkata - 700091',
      'Flat 3C, 18 Lake Town Road, Kolkata - 700089',
      '12/4 Park Street Area, Kolkata - 700016',
      'House 8, Gariahat Road, Kolkata - 700019',
      'Flat 5B, 22 Shibpur Road, Howrah - 711102',
      'Quarter 7, Dum Dum Road, Kolkata - 700028',
      'Flat 2A, Action Area I, New Town - 700156',
      'House 31, Diamond Harbour Road, Behala - 700034',
      'Flat 6D, Chowringhee Road, Kolkata - 700069',
      'Staff Housing, Raja S.C. Mullick Road, Jadavpur - 700032'
    ])[((g - 1) % 10) + 1],
    CURRENT_DATE - ((g * 37) % 4000),
    CASE WHEN g <= 10 THEN 'Manager'
         WHEN g <= 28 THEN 'Employee' ELSE 'Admin' END,
    CASE WHEN g <= 10 THEN 85000 + g * 1000
         WHEN g <= 28 THEN 42000 + g * 750
         ELSE 110000 + g * 1000 END,
    'Active'
FROM generate_series(1,30) AS gs(g);

UPDATE BRANCH b
   SET Manager_ID = 'EMP' || LPAD(n::text,4,'0')
  FROM generate_series(1,10) AS gs(n)
 WHERE b.IFSC = (ARRAY['DUMY0KOL001','DUMY0KOL002','DUMY0KOL003','DUMY0KOL004',
                       'DUMY0HOW005','DUMY0DUM006','DUMY0NEW007','DUMY0BEH008',
                       'DUMY0ESP009','DUMY0JAD010'])[n];

-- ---------------------------------------------------------------------
-- 4. Customers: 120 fictional customers.
-- CIF is numeric, exactly 9 digits. PAN is format-shaped but synthetic.
-- Aadhaar-shaped numbers are synthetic, not assigned to real people.
-- ---------------------------------------------------------------------
INSERT INTO CUSTOMER
    (CIF, First_Name, Last_Name, DOB, Gender, Contact, PAN, Aadhar_No,
     Address, Status)
SELECT
    LPAD((700000000 + g)::text,9,'0'),
    (ARRAY['Amit','Priya','Suman','Sneha','Rahul','Riya','Sourav',
           'Poulomi','Aniket','Moumita','Abhishek','Tanushree',
           'Koushik','Debjani','Arindam','Ira','Ritwik','Nandita',
           'Sayan','Madhurima'])[((g - 1) % 20) + 1],
    (ARRAY['Sen','Das','Roy','Dutta','Ghosh','Bose','Mitra','Saha',
           'Banerjee','Chatterjee','Mukherjee','Datta','Pal','Paul',
           'Sharma','Verma','Gupta','Jain','Mondal','Biswas'])[(((g * 7) - 1) % 20) + 1],
    DATE '1965-01-01' + ((g * 173) % 15000),
    (ARRAY['Male','Female','Other'])[((g - 1) % 3) + 1],
    '+91-' || (CASE WHEN g % 4 = 0 THEN '8' WHEN g % 4 = 1 THEN '9'
                    WHEN g % 4 = 2 THEN '7' ELSE '6' END)
      || LPAD((100000000 + g)::text,9,'0'),
    (ARRAY['ABCPD','EFGPM','HJKPR','LMNPS','PQRST','UVWPA',
           'BCDPK','FGHPL','JKMPR','NPRST'])[((g - 1) % 10) + 1]
      || LPAD(g::text,4,'0')
      || (ARRAY['A','B','C','D','E','F','G','H','J','K'])[((g - 1) % 10) + 1],
    LPAD((800000000000 + g)::text,12,'0'),
    (ARRAY[
      'Flat 3B, 14 Lake View Road, Lake Town, Kolkata - 700089',
      '2nd Floor, 21 Bidhannagar Road, Salt Lake, Kolkata - 700091',
      'Flat 4A, 8 Hindustan Park, Gariahat, Kolkata - 700029',
      '12/3A Dover Lane, Ballygunge, Kolkata - 700019',
      'Flat 5C, 33 Prince Anwar Shah Road, Kolkata - 700045',
      'House 18, Sarat Bose Road, Kolkata - 700020',
      'Flat 2D, 7 N.S.C. Bose Road, Tollygunge, Kolkata - 700040',
      '12/1 Shibpur Road, Howrah - 711102',
      'Flat 6A, 9 New Town Main Road, Kolkata - 700156',
      'House 25, Behala Tram Depot Road, Kolkata - 700034',
      'Flat 3A, 17 Jadavpur Central Road, Kolkata - 700032',
      'House 11, Dum Dum Road, Kolkata - 700074'
    ])[((g - 1) % 12) + 1],
    'Active'
FROM generate_series(1,120) AS gs(g);

-- ---------------------------------------------------------------------
-- 5. Accounts: 150 accounts, all initially zero balance.
-- Balances are built only via "TRANSACTION" triggers.
-- ---------------------------------------------------------------------
INSERT INTO ACCOUNT
    (Account_No, CIF, IFSC, Nominee, Account_Type_ID, Opening_Date, Status, Current_Balance)
SELECT
    'AC' || LPAD(g::text,8,'0'),
    LPAD((700000000 + (((g - 1) % 120) + 1))::text,9,'0'),
    (ARRAY['DUMY0KOL001','DUMY0KOL002','DUMY0KOL003','DUMY0KOL004',
           'DUMY0HOW005','DUMY0DUM006','DUMY0NEW007','DUMY0BEH008',
           'DUMY0ESP009','DUMY0JAD010'])[((g - 1) % 10) + 1],
    (ARRAY['Amit Sen','Priya Das','Rohan Roy','Sneha Bose','Rahul Dutta',
           'Suman Ghosh','Ananya Roy','Arjun Sen','Mira Das','Neel Pal'])[((g - 1) % 10) + 1],
    (ARRAY['AT-SAV','AT-CUR','AT-SAL','AT-FD','AT-STU'])[((g - 1) % 5) + 1],
    CURRENT_DATE - ((g * 11) % 2500),
    'Active',
    0.00000
FROM generate_series(1,150) AS gs(g);

-- ---------------------------------------------------------------------
-- 6. Logins. Placeholder password hashes are intentionally not valid
-- credentials. Replace with proper Argon2id/bcrypt hashes in backend.
-- ---------------------------------------------------------------------
INSERT INTO LOGIN
    (Username, Password_Hash, Role, Employee_ID, CIF, Last_Login, Account_Status)
SELECT
    'customer' || LPAD(g::text,4,'0'),
    'DUMMY_HASH_NOT_FOR_AUTH',
    'customer', NULL, LPAD((700000000 + g)::text,9,'0'),
    CASE WHEN g % 4 = 0 THEN NULL
         ELSE CURRENT_TIMESTAMP - ((g % 90) || ' days')::interval END,
    'Active'
FROM generate_series(1,120) AS gs(g);

INSERT INTO LOGIN
    (Username, Password_Hash, Role, Employee_ID, CIF, Last_Login, Account_Status)
SELECT
    CASE WHEN g >= 29 THEN 'admin' ELSE 'employee' END || LPAD(g::text,4,'0'),
    'DUMMY_HASH_NOT_FOR_AUTH',
    CASE WHEN g >= 29 THEN 'admin' ELSE 'employee' END,
    'EMP' || LPAD(g::text,4,'0'),
    NULL,
    CASE WHEN g % 5 = 0 THEN NULL
         ELSE CURRENT_TIMESTAMP - ((g % 60) || ' days')::interval END,
    'Active'
FROM generate_series(1,30) AS gs(g);

-- ---------------------------------------------------------------------
-- 7. Opening deposits: 150 rows; trigger sets Balance_After and updates
-- Current_Balance. Amounts all exceed account-type minimum balances.
-- ---------------------------------------------------------------------
INSERT INTO "TRANSACTION"
    (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount,
     Transaction_Date_Time, Balance_After, Channel, Status)
SELECT
    'TX-OPEN-' || LPAD(g::text,6,'0'),
    'AC' || LPAD(g::text,8,'0'),
    CASE WHEN g % 3 = 0 THEN 'EMP' || LPAD((((g - 1) % 30) + 1)::text,4,'0') ELSE NULL END,
    'Deposit',
    LEAST((25000 + ((g * 1379) % 80000))::numeric(14,5), typ.Transaction_Limit),
    CURRENT_TIMESTAMP - ((g % 300) || ' days')::interval,
    0,
    CASE WHEN g % 3 = 0 THEN 'Branch'
         WHEN g % 3 = 1 THEN 'Online_Banking' ELSE 'UPI' END,
    'Completed'
FROM generate_series(1,150) AS gs(g)
JOIN ACCOUNT ac ON ac.Account_No = 'AC' || LPAD(g::text,8,'0')
JOIN ACCOUNT_TYPE typ ON typ.Account_Type_ID = ac.Account_Type_ID;

-- ---------------------------------------------------------------------
-- 8. 450 ordinary deposits/withdrawals. Withdrawals are only generated
-- when the current balance will remain above that account's minimum.
-- Each insert is a real trigger-managed transaction.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    a RECORD;
    i INTEGER;
    v_balance NUMERIC(14,5);
    v_minimum NUMERIC(12,2);
    v_limit NUMERIC(14,2);
    v_amount NUMERIC(14,5);
    v_type VARCHAR(20);
    v_channel VARCHAR(20);
    v_txid VARCHAR(20);
BEGIN
    FOR a IN SELECT Account_No FROM ACCOUNT ORDER BY Account_No LOOP
        FOR i IN 1..3 LOOP
            SELECT ac.Current_Balance, typ.Minimum_Balance, typ.Transaction_Limit
              INTO v_balance, v_minimum, v_limit
              FROM ACCOUNT ac
              JOIN ACCOUNT_TYPE typ ON typ.Account_Type_ID = ac.Account_Type_ID
             WHERE ac.Account_No = a.Account_No;

            v_amount := (500 + ((i * 311 +
                SUBSTRING(a.Account_No FROM 3)::integer * 13) % 4500))::numeric(14,5);
            v_type := 'Deposit';

            IF SUBSTRING(a.Account_No FROM 3)::integer % (i + 2) = 0
               AND v_balance - v_amount >= v_minimum THEN
                v_type := 'Withdrawal';
            END IF;

            v_amount := LEAST(v_amount, v_limit);
            v_txid := 'TX-ACT-' || LPAD(
                (SUBSTRING(a.Account_No FROM 3)::integer * 10 + i)::text,6,'0');
            v_channel := (ARRAY['UPI','Online_Banking','POS','ATM','NEFT'])
                [((SUBSTRING(a.Account_No FROM 3)::integer + i - 1) % 5) + 1];

            INSERT INTO "TRANSACTION"
                (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount,
                 Transaction_Date_Time, Balance_After, Channel, Status)
            VALUES
                (v_txid, a.Account_No, NULL, v_type, v_amount,
                 CURRENT_TIMESTAMP - ((i * 7 +
                   SUBSTRING(a.Account_No FROM 3)::integer % 90) || ' days')::interval,
                 0, v_channel, 'Completed');
        END LOOP;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 9. Loans. 30 become Active; 10 remain Applied; 10 are Rejected.
-- Account and CIF ownership match exactly. Amounts do not exceed loan type caps.
-- ---------------------------------------------------------------------
INSERT INTO LOAN
    (Loan_ID, CIF, Account_No, Loan_Type_ID, Employee_ID, Principal_Amount,
     Interest_Rate, Tenure_Months, EMI_Amount, Remaining_Amount,
     Start_Date, End_Date, Loan_Status)
SELECT
    'LN' || LPAD(g::text,6,'0'),
    a.CIF,
    a.Account_No,
    (ARRAY['LT-HOME','LT-PERS','LT-EDU','LT-AUTO','LT-BUS'])[((g - 1) % 5) + 1],
    'EMP' || LPAD((((g - 1) % 30) + 1)::text,4,'0'),
    CASE WHEN g % 5 = 1 THEN 600000.00
         WHEN g % 5 = 2 THEN 150000.00
         WHEN g % 5 = 3 THEN 300000.00
         WHEN g % 5 = 4 THEN 450000.00 ELSE 250000.00 END,
    CASE WHEN g % 5 = 1 THEN 8.25
         WHEN g % 5 = 2 THEN 12.50
         WHEN g % 5 = 3 THEN 7.50
         WHEN g % 5 = 4 THEN 9.25 ELSE 11.00 END,
    CASE WHEN g % 5 = 1 THEN 120
         WHEN g % 5 = 2 THEN 36
         WHEN g % 5 = 3 THEN 60
         WHEN g % 5 = 4 THEN 48 ELSE 60 END,
    CASE WHEN g % 5 = 1 THEN 7400.00
         WHEN g % 5 = 2 THEN 5000.00
         WHEN g % 5 = 3 THEN 6000.00
         WHEN g % 5 = 4 THEN 11200.00 ELSE 5500.00 END,
    CASE WHEN g % 5 = 1 THEN 600000.00
         WHEN g % 5 = 2 THEN 150000.00
         WHEN g % 5 = 3 THEN 300000.00
         WHEN g % 5 = 4 THEN 450000.00 ELSE 250000.00 END,
    NULL, NULL,
    CASE WHEN g <= 30 THEN 'Approved'
         WHEN g <= 40 THEN 'Applied' ELSE 'Rejected' END
FROM generate_series(1,50) AS gs(g)
JOIN ACCOUNT a ON a.Account_No = 'AC' || LPAD(g::text,8,'0');

UPDATE LOAN
   SET Loan_Status = 'Active',
       Start_Date = CURRENT_DATE - ((SUBSTRING(Loan_ID FROM 3)::integer % 180) + 30)
 WHERE Loan_Status = 'Approved';

-- ---------------------------------------------------------------------
-- 10. Loan payments: 30 completed payments spread across active loans.
-- Each payment transaction is linked to the loan's own account and uses
-- amount = principal + interest. Account debit and loan principal reduction
-- are handled by the supplied triggers.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    l RECORD;
    v_principal NUMERIC(12,2);
    v_interest NUMERIC(12,2);
    v_amount NUMERIC(14,5);
    v_balance NUMERIC(14,5);
    v_minimum NUMERIC(12,2);
    v_limit NUMERIC(14,2);
    v_txid VARCHAR(20);
    v_pid VARCHAR(20);
    v_done INTEGER := 0;
BEGIN
    FOR l IN
        SELECT ln.Loan_ID, ln.Account_No, ln.Remaining_Amount
          FROM LOAN ln
         WHERE ln.Loan_Status = 'Active'
         ORDER BY ln.Loan_ID
    LOOP
        EXIT WHEN v_done >= 30;

        SELECT a.Current_Balance, typ.Minimum_Balance, typ.Transaction_Limit
          INTO v_balance, v_minimum, v_limit
          FROM ACCOUNT a
          JOIN ACCOUNT_TYPE typ ON typ.Account_Type_ID = a.Account_Type_ID
         WHERE a.Account_No = l.Account_No;

        v_principal := LEAST(1000.00, l.Remaining_Amount);
        v_interest := 100.00;
        v_amount := (v_principal + v_interest)::numeric(14,5);

        IF v_principal <= 0 OR v_balance - v_amount < v_minimum
           OR v_amount > v_limit THEN
            CONTINUE;
        END IF;

        v_txid := 'TX-LP-' || LPAD(SUBSTRING(l.Loan_ID FROM 3),6,'0');
        v_pid := 'LP' || LPAD(SUBSTRING(l.Loan_ID FROM 3),6,'0');

        INSERT INTO "TRANSACTION"
            (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount,
             Transaction_Date_Time, Balance_After, Channel, Status)
        VALUES
            (v_txid, l.Account_No, NULL, 'Loan_Payment', v_amount,
             CURRENT_TIMESTAMP - ((v_done + 1) || ' days')::interval,
             0, 'Online_Banking', 'Completed');

        INSERT INTO LOAN_PAYMENT
            (Payment_ID, Loan_ID, Transaction_ID, Payment_Method, Payment_Status,
             Principal_Paid, Interest_Paid, Remaining_Balance)
        VALUES
            (v_pid, l.Loan_ID, v_txid, 'NEFT', 'Completed',
             v_principal, v_interest, l.Remaining_Amount);

        v_done := v_done + 1;
    END LOOP;
    RAISE NOTICE 'Inserted % completed loan payments.', v_done;
END $$;

-- ---------------------------------------------------------------------
-- 11. Fund transfers: 40 transfers (up to 80 transaction rows).
-- Paired transaction rows are inserted first, then transfer header.
-- Debit/credit amounts match; source account retains minimum balance.
-- ---------------------------------------------------------------------
DO $$
DECLARE
    i INTEGER;
    v_from VARCHAR(20);
    v_to VARCHAR(20);
    v_from_balance NUMERIC(14,5);
    v_minimum NUMERIC(12,2);
    v_limit NUMERIC(14,2);
    v_amount NUMERIC(14,5);
    v_debit VARCHAR(20);
    v_credit VARCHAR(20);
    v_mode VARCHAR(20);
    v_channel VARCHAR(20);
BEGIN
    FOR i IN 1..40 LOOP
        v_from := 'AC' || LPAD(i::text,8,'0');
        v_to := 'AC' || LPAD((i + 80)::text,8,'0');

        SELECT a.Current_Balance, typ.Minimum_Balance, typ.Transaction_Limit
          INTO v_from_balance, v_minimum, v_limit
          FROM ACCOUNT a
          JOIN ACCOUNT_TYPE typ ON typ.Account_Type_ID = a.Account_Type_ID
         WHERE a.Account_No = v_from;

        v_amount := LEAST(500.00 + (i * 17)::numeric, 3000.00, v_limit,
                          v_from_balance - v_minimum - 1.00);
        IF v_amount <= 0 THEN CONTINUE; END IF;
        v_amount := ROUND(v_amount,2);

        v_debit := 'TX-TR-D-' || LPAD(i::text,5,'0');
        v_credit := 'TX-TR-C-' || LPAD(i::text,5,'0');
        v_mode := (ARRAY['UPI','Internal_Transfer','NEFT','IMPS','RTGS'])
                    [((i - 1) % 5) + 1];
        v_channel := CASE WHEN v_mode IN ('UPI','NEFT','IMPS','RTGS') THEN v_mode
                          ELSE 'Online_Banking' END;

        INSERT INTO "TRANSACTION"
            (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount,
             Transaction_Date_Time, Balance_After, Channel, Status)
        VALUES
            (v_debit, v_from, NULL, 'Transfer_Out', v_amount,
             CURRENT_TIMESTAMP - ((i % 45) || ' days')::interval,
             0, v_channel, 'Completed');

        INSERT INTO "TRANSACTION"
            (Transaction_ID, Account_No, Employee_ID, Transaction_Type, Amount,
             Transaction_Date_Time, Balance_After, Channel, Status)
        VALUES
            (v_credit, v_to, NULL, 'Transfer_In', v_amount,
             CURRENT_TIMESTAMP - ((i % 45) || ' days')::interval,
             0, v_channel, 'Completed');

        INSERT INTO FUND_TRANSFER
            (Transaction_ID, From_Account_No, To_Account_No, Transfer_Mode,
             Reference_No, Debit_Transaction_ID, Credit_Transaction_ID)
        VALUES
            (v_debit, v_from, v_to, v_mode,
             'REF-DUMMY-' || LPAD(i::text,6,'0'), v_debit, v_credit);
    END LOOP;
END $$;

COMMIT;

-- =====================================================================
-- POST-SEED VERIFICATION
-- =====================================================================

-- Row counts for all tables.
SELECT 'BRANCH' AS table_name, COUNT(*) AS row_count FROM BRANCH
UNION ALL SELECT 'EMPLOYEE', COUNT(*) FROM EMPLOYEE
UNION ALL SELECT 'CUSTOMER', COUNT(*) FROM CUSTOMER
UNION ALL SELECT 'LOGIN', COUNT(*) FROM LOGIN
UNION ALL SELECT 'ACCOUNT_TYPE', COUNT(*) FROM ACCOUNT_TYPE
UNION ALL SELECT 'ACCOUNT', COUNT(*) FROM ACCOUNT
UNION ALL SELECT 'TRANSACTION', COUNT(*) FROM "TRANSACTION"
UNION ALL SELECT 'FUND_TRANSFER', COUNT(*) FROM FUND_TRANSFER
UNION ALL SELECT 'LOAN_TYPE', COUNT(*) FROM LOAN_TYPE
UNION ALL SELECT 'LOAN', COUNT(*) FROM LOAN
UNION ALL SELECT 'LOAN_PAYMENT', COUNT(*) FROM LOAN_PAYMENT
UNION ALL SELECT 'AUDIT_LOG', COUNT(*) FROM AUDIT_LOG
ORDER BY table_name;

-- CIFs should all be numeric, exactly 9 digits (invalid count = 0).
SELECT COUNT(*) AS invalid_cif_count
FROM CUSTOMER
WHERE CIF !~ '^[0-9]{9}$';

-- PAN values should have the common AAAAA9999A shape (invalid count = 0).
SELECT COUNT(*) AS invalid_pan_format_count
FROM CUSTOMER
WHERE PAN !~ '^[A-Z]{5}[0-9]{4}[A-Z]$';

-- All loan CIFs must match their account owners (count = 0).
SELECT COUNT(*) AS mismatched_loan_owners
FROM LOAN l
JOIN ACCOUNT a ON a.Account_No = l.Account_No
WHERE l.CIF <> a.CIF;

-- Balance reconciliation should return no rows.
SELECT a.Account_No, a.Current_Balance,
       COALESCE(SUM(
           CASE WHEN t.Status = 'Completed'
                     AND t.Transaction_Type IN ('Deposit','Transfer_In')
                THEN t.Amount
                WHEN t.Status = 'Completed'
                     AND t.Transaction_Type IN ('Withdrawal','Transfer_Out','Loan_Payment')
                THEN -t.Amount
                ELSE 0 END
       ),0) AS balance_from_transactions
FROM ACCOUNT a
LEFT JOIN "TRANSACTION" t ON t.Account_No = a.Account_No
GROUP BY a.Account_No, a.Current_Balance
HAVING ROUND(a.Current_Balance,5) <>
       ROUND(COALESCE(SUM(
           CASE WHEN t.Status = 'Completed'
                     AND t.Transaction_Type IN ('Deposit','Transfer_In')
                THEN t.Amount
                WHEN t.Status = 'Completed'
                     AND t.Transaction_Type IN ('Withdrawal','Transfer_Out','Loan_Payment')
                THEN -t.Amount
                ELSE 0 END
       ),0),5)
ORDER BY a.Account_No;

-- Review loan balances after the inserted payments.
SELECT Loan_ID, Principal_Amount, Remaining_Amount, Loan_Status
FROM LOAN
ORDER BY Loan_ID
LIMIT 20;
