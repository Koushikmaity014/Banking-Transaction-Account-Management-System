-- Run after schema, triggers, procedures, and seed data. Every *_count should be zero.
SELECT COUNT(*) AS invalid_ifsc_count FROM branch WHERE ifsc !~ '^[A-Z]{4}0[A-Z0-9]{6}$';
SELECT COUNT(*) AS invalid_micr_count FROM branch WHERE micr !~ '^[0-9]{9}$';
SELECT COUNT(*) AS invalid_pan_count FROM customer WHERE pan !~ '^[A-Z]{5}[0-9]{4}[A-Z]$';
SELECT COUNT(*) AS invalid_aadhaar_count FROM customer WHERE aadhar_no !~ '^[0-9]{12}$';
SELECT COUNT(*) AS mismatched_loan_owners FROM loan l JOIN account a ON a.account_no=l.account_no WHERE l.cif<>a.cif;
SELECT COUNT(*) AS invalid_completed_transfer_count
FROM fund_transfer f
JOIN "TRANSACTION" d ON d.transaction_id=f.debit_transaction_id
JOIN "TRANSACTION" c ON c.transaction_id=f.credit_transaction_id
WHERE d.transaction_type<>'Transfer_Out' OR c.transaction_type<>'Transfer_In'
   OR d.account_no<>f.from_account_no OR c.account_no<>f.to_account_no
   OR d.amount<>c.amount OR d.status<>'Completed' OR c.status<>'Completed';
SELECT a.account_no, a.current_balance, COALESCE(SUM(CASE
    WHEN t.status='Completed' AND t.transaction_type IN ('Deposit','Transfer_In') THEN t.amount
    WHEN t.status='Completed' AND t.transaction_type IN ('Withdrawal','Transfer_Out','Loan_Payment') THEN -t.amount
    ELSE 0 END),0) AS calculated_balance
FROM account a LEFT JOIN "TRANSACTION" t ON t.account_no=a.account_no
GROUP BY a.account_no,a.current_balance
HAVING ROUND(a.current_balance,5)<>ROUND(COALESCE(SUM(CASE
    WHEN t.status='Completed' AND t.transaction_type IN ('Deposit','Transfer_In') THEN t.amount
    WHEN t.status='Completed' AND t.transaction_type IN ('Withdrawal','Transfer_Out','Loan_Payment') THEN -t.amount
    ELSE 0 END),0),5);
