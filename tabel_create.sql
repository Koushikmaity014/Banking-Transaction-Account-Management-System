CREATE TABLE BRANCH (
    IFSC            VARCHAR(11)  PRIMARY KEY,
    Branch_Name     VARCHAR(100) NOT NULL,
    MICR            VARCHAR(9)   NOT NULL UNIQUE,
    Address         VARCHAR(255),
    City            VARCHAR(100) NOT NULL,
    State           VARCHAR(100) NOT NULL,
    PIN             CHAR(6)      NOT NULL,
    Contact         VARCHAR(20),
    Manager_ID      VARCHAR(20),
    Opening_Date    DATE         NOT NULL DEFAULT CURRENT_DATE,
    Status          VARCHAR(10)  NOT NULL DEFAULT 'Active'
                     CHECK (Status IN ('Active','Inactive'))
);



CREATE TABLE CUSTOMER (
    CIF             VARCHAR(15)  PRIMARY KEY,
    First_Name      VARCHAR(50)  NOT NULL,
    Last_Name       VARCHAR(50)  NOT NULL,
    DOB             DATE         NOT NULL,
    Gender          VARCHAR(10)  CHECK (Gender IN ('Male','Female','Other')),
    Contact         VARCHAR(20)  NOT NULL,
    PAN             CHAR(10)     NOT NULL UNIQUE,
    Aadhar_No       CHAR(12)     NOT NULL UNIQUE,
    Address         VARCHAR(255),
    Status          VARCHAR(10)  NOT NULL DEFAULT 'Active'
                     CHECK (Status IN ('Active','Inactive'))
);



CREATE TABLE EMPLOYEE (
    Employee_ID     VARCHAR(20)  PRIMARY KEY,
    IFSC            VARCHAR(11)  NOT NULL REFERENCES BRANCH(IFSC),
    First_Name      VARCHAR(50)  NOT NULL,
    Last_Name       VARCHAR(50)  NOT NULL,
    DOB             DATE         NOT NULL,
    Gender          VARCHAR(10)  CHECK (Gender IN ('Male','Female','Other')),
    Contact         VARCHAR(20)  NOT NULL,
    Address         VARCHAR(255),
    Joining_Date    DATE         NOT NULL DEFAULT CURRENT_DATE,
    Role            VARCHAR(30)  NOT NULL
                     CHECK (Role IN ('Employee','Manager','Admin')),
    Salary          DECIMAL(12,2) NOT NULL CHECK (Salary >= 0),
    Status          VARCHAR(10)  NOT NULL DEFAULT 'Active'
                     CHECK (Status IN ('Active','Inactive'))
);

-- Now that EMPLOYEE exists, add the BRANCH -> EMPLOYEE (Manager) foreign key
ALTER TABLE BRANCH
    ADD CONSTRAINT fk_branch_manager
    FOREIGN KEY (Manager_ID) REFERENCES EMPLOYEE(Employee_ID);



CREATE TABLE ACCOUNT_TYPE (
    Account_Type_ID   VARCHAR(20)   PRIMARY KEY,
    Type_Name         VARCHAR(30)   NOT NULL UNIQUE,
    Minimum_Balance   DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (Minimum_Balance >= 0),
    Interest_Rate     DECIMAL(5,2)  NOT NULL DEFAULT 0.00 CHECK (Interest_Rate >= 0),
    Transaction_Limit DECIMAL(14,2) NOT NULL CHECK (Transaction_Limit > 0)
);




CREATE TABLE ACCOUNT (
    Account_No       VARCHAR(20)   PRIMARY KEY,
    CIF              VARCHAR(15)   NOT NULL REFERENCES CUSTOMER(CIF),
    IFSC             VARCHAR(11)   NOT NULL REFERENCES BRANCH(IFSC),
    Nominee          VARCHAR(100),
    Account_Type_ID  VARCHAR(20)   NOT NULL REFERENCES ACCOUNT_TYPE(Account_Type_ID),
    Opening_Date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    Status           VARCHAR(10)   NOT NULL DEFAULT 'Active'
                      CHECK (Status IN ('Active','Frozen','Closed')),
    Current_Balance  DECIMAL(14,5) NOT NULL DEFAULT 0.00000
                      CHECK (Current_Balance >= 0)
);




CREATE TABLE TRANSACTION (
    Transaction_ID        VARCHAR(20)   PRIMARY KEY,
    Account_No            VARCHAR(20)   NOT NULL REFERENCES ACCOUNT(Account_No),
    Employee_ID           VARCHAR(20)   REFERENCES EMPLOYEE(Employee_ID),
    Transaction_Type      VARCHAR(20)   NOT NULL
                           CHECK (Transaction_Type IN
                                  ('Deposit','Withdrawal','Transfer_In','Transfer_Out','Loan_Payment')),
    Amount                DECIMAL(14,5) NOT NULL CHECK (Amount > 0),
    Transaction_Date_Time TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Balance_After         DECIMAL(14,5) NOT NULL CHECK (Balance_After >= 0),
    Channel               VARCHAR(20)   NOT NULL 
							CHECK (Channel IN('Branch','ATM','Online_Banking','UPI','POS','Cheque','NEFT','RTGS','IMPS')),
    Status                VARCHAR(10)   NOT NULL DEFAULT 'Completed'
                           CHECK (Status IN ('Completed','Failed','Pending'))
);




CREATE TABLE FUND_TRANSFER (
    Transaction_ID   VARCHAR(20)  PRIMARY KEY REFERENCES TRANSACTION(Transaction_ID),
    From_Account_No  VARCHAR(20)  NOT NULL REFERENCES ACCOUNT(Account_No),
    To_Account_No    VARCHAR(20)  NOT NULL REFERENCES ACCOUNT(Account_No),
    Transfer_Mode    VARCHAR(20)  NOT NULL CHECK (Transfer_Mode IN('UPI','Internal_Transfer','Cheque','NEFT','RTGS','IMPS')),
    Reference_No     VARCHAR(30)  NOT NULL UNIQUE,
    CONSTRAINT chk_transfer_accounts CHECK (From_Account_No <> To_Account_No)
);




CREATE TABLE LOAN_TYPE (
    Loan_Type_ID    VARCHAR(20)   PRIMARY KEY,
    Loan_Type_Name  VARCHAR(30)   NOT NULL UNIQUE,
    Interest_Rate   DECIMAL(5,2)  NOT NULL CHECK (Interest_Rate >= 0),
    Max_Amount      DECIMAL(14,2) NOT NULL CHECK (Max_Amount > 0)
);




CREATE TABLE LOAN (
    Loan_ID           VARCHAR(20)   PRIMARY KEY,
    CIF               VARCHAR(15)   NOT NULL REFERENCES CUSTOMER(CIF),
    Account_No        VARCHAR(20)   NOT NULL REFERENCES ACCOUNT(Account_No),
    Loan_Type_ID      VARCHAR(20)   NOT NULL REFERENCES LOAN_TYPE(Loan_Type_ID),
    Employee_ID       VARCHAR(20)   NOT NULL REFERENCES EMPLOYEE(Employee_ID),
    Principal_Amount  DECIMAL(14,2) NOT NULL CHECK (Principal_Amount > 0),
    Interest_Rate     DECIMAL(5,2)  NOT NULL CHECK (Interest_Rate >= 0),
    Tenure_Months     INT           NOT NULL CHECK (Tenure_Months > 0),
    EMI_Amount        DECIMAL(12,2) NOT NULL CHECK (EMI_Amount > 0),
    Remaining_Amount  DECIMAL(14,2) NOT NULL CHECK (Remaining_Amount >= 0),
    Start_Date        DATE,
    End_Date          DATE,
    Loan_Status       VARCHAR(15)   NOT NULL DEFAULT 'Applied'
                       CHECK (Loan_Status IN ('Applied','Approved','Rejected','Active','Closed'))
);




CREATE TABLE LOAN_PAYMENT (
    Payment_ID         VARCHAR(20)   PRIMARY KEY,
    Loan_ID            VARCHAR(20)   NOT NULL REFERENCES LOAN(Loan_ID),
    Transaction_ID     VARCHAR(20)   NOT NULL REFERENCES TRANSACTION(Transaction_ID),
    Payment_Method     VARCHAR(20)   NOT NULL CHECK (Payment_Method IN('UPI','Internal_Transfer','Cheque','NEFT','RTGS','IMPS')),
    Payment_Status     VARCHAR(10)   NOT NULL DEFAULT 'Completed'
                        CHECK (Payment_Status IN ('Completed','Failed','Pending')),
    Principal_Paid     DECIMAL(12,2) NOT NULL CHECK (Principal_Paid >= 0),
    Interest_Paid      DECIMAL(12,2) NOT NULL CHECK (Interest_Paid >= 0),
    Remaining_Balance  DECIMAL(14,2) NOT NULL CHECK (Remaining_Balance >= 0),
    CONSTRAINT chk_payment_positive CHECK (Principal_Paid + Interest_Paid > 0)
);



CREATE TABLE LOGIN (
    Login_ID        SERIAL        PRIMARY KEY,
    Username        VARCHAR(50)   NOT NULL UNIQUE,
    Password_Hash   VARCHAR(255)  NOT NULL,
    Role            VARCHAR(10)   NOT NULL CHECK (Role IN ('customer','employee','admin')),
    Employee_ID     VARCHAR(20)   REFERENCES EMPLOYEE(Employee_ID),
    CIF             VARCHAR(15)   REFERENCES CUSTOMER(CIF),
    Last_Login      TIMESTAMP,
    Account_Status  VARCHAR(10)   NOT NULL DEFAULT 'Active'
                     CHECK (Account_Status IN ('Active','Locked','Disabled')),
    CONSTRAINT chk_login_owner CHECK (
        (Role = 'customer' AND CIF IS NOT NULL AND Employee_ID IS NULL)
        OR
        (Role IN ('employee','admin') AND Employee_ID IS NOT NULL AND CIF IS NULL)
    )
);