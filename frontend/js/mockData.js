/**
 * ==============================================================================
 * MOCK DATA - Banking Management System (DBMS Project)
 * ==============================================================================
 * 
 * IMPORTANT ARCHITECTURAL NOTE:
 * This file contains ALL simulated database tables. The table names and column 
 * names EXACTLY match our relational SQL schema (same spelling, casing, and types).
 * 
 * In production / later weeks, this file will be completely replaced by real SQL 
 * tables on the backend server. The frontend NEVER calls this file directly; 
 * all access is mediated through `api.js`.
 * 
 * DEMO ONLY: Passwords in this mock dataset are stored for client-side demo 
 * authentication simulation. Real password checking and bcrypt hashing will be 
 * done exclusively on the backend server.
 * ==============================================================================
 */

// Global mock database object holding all database tables
const MOCK_DATABASE = {
  // ----------------------------------------------------------------------------
  // 1. BRANCH TABLE
  // ----------------------------------------------------------------------------
  BRANCH: [
    {
      IFSC: "APEX0001001",
      Branch_Name: "Connaught Place Central Branch",
      MICR: "110024002",
      Address: "B-Block, Inner Circle, Connaught Place",
      City: "New Delhi",
      State: "Delhi",
      PIN: "110001",
      Contact: "+91 11 2341 5500",
      Manager_ID: "EMP101",
      Opening_Date: "2015-04-12",
      Status: "Active"
    },
    {
      IFSC: "APEX0002002",
      Branch_Name: "Indiranagar Tech Hub Branch",
      MICR: "560024018",
      Address: "100 Feet Road, HAL 2nd Stage, Indiranagar",
      City: "Bengaluru",
      State: "Karnataka",
      PIN: "560038",
      Contact: "+91 80 2521 8890",
      Manager_ID: "EMP102",
      Opening_Date: "2018-09-20",
      Status: "Active"
    }
  ],

  // ----------------------------------------------------------------------------
  // 2. ACCOUNT_TYPE TABLE
  // ----------------------------------------------------------------------------
  ACCOUNT_TYPE: [
    {
      Account_Type_ID: "ACT101",
      Type_Name: "Savings Account",
      Minimum_Balance: 10000.00,
      Interest_Rate: 4.00,
      Transaction_Limit: 200000.00
    },
    {
      Account_Type_ID: "ACT102",
      Type_Name: "Current Account",
      Minimum_Balance: 25000.00,
      Interest_Rate: 0.00,
      Transaction_Limit: 1000000.00
    },
    {
      Account_Type_ID: "ACT103",
      Type_Name: "Salary Account",
      Minimum_Balance: 0.00,
      Interest_Rate: 3.50,
      Transaction_Limit: 300000.00
    }
  ],

  // ----------------------------------------------------------------------------
  // 3. CUSTOMER TABLE (6 customers with realistic Indian data)
  // ----------------------------------------------------------------------------
  CUSTOMER: [
    {
      CIF: "CIF10001",
      First_Name: "Rahul",
      Last_Name: "Sharma",
      DOB: "1994-08-14",
      Gender: "Male",
      Contact: "+91 98112 34567",
      Address: "42, Barakhamba Road, Connaught Place",
      PAN: "ABCDE1234F",
      Aadhaar_No: "4589 1234 5678",
      Status: "Active"
    },
    {
      CIF: "CIF10002",
      First_Name: "Ananya",
      Last_Name: "Iyer",
      DOB: "1997-03-22",
      Gender: "Female",
      Contact: "+91 99801 23456",
      Address: "78, 12th Main, HAL 2nd Stage, Indiranagar",
      PAN: "BKIPY5678K",
      Aadhaar_No: "8912 3456 7890",
      Status: "Active"
    },
    {
      CIF: "CIF10003",
      First_Name: "Rohan",
      Last_Name: "Desai",
      DOB: "1988-11-05",
      Gender: "Male",
      Contact: "+91 98200 45678",
      Address: "15, Nariman Point, Marine Drive",
      PAN: "CPZAD9012M",
      Aadhaar_No: "2345 6789 0123",
      Status: "Active"
    },
    {
      CIF: "CIF10004",
      First_Name: "Pooja",
      Last_Name: "Verma",
      DOB: "1995-12-19",
      Gender: "Female",
      Contact: "+91 98711 98765",
      Address: "104, Golf Links, Lodhi Estate",
      PAN: "DKLQE3456N",
      Aadhaar_No: "6789 0123 4567",
      Status: "Active"
    },
    {
      CIF: "CIF10005",
      First_Name: "Arjun",
      Last_Name: "Kapoor",
      DOB: "1991-06-30",
      Gender: "Male",
      Contact: "+91 97412 87654",
      Address: "22, Koramangala 4th Block",
      PAN: "EMRTW7890P",
      Aadhaar_No: "3456 7890 1234",
      Status: "Active"
    },
    {
      CIF: "CIF10006",
      First_Name: "Meera",
      Last_Name: "Patel",
      DOB: "1993-02-17",
      Gender: "Female",
      Contact: "+91 98980 11223",
      Address: "56, Shanti Niketan, Chanakyapuri",
      PAN: "FNUYX2345Q",
      Aadhaar_No: "9012 3456 7891",
      Status: "Active"
    }
  ],

  // ----------------------------------------------------------------------------
  // 4. EMPLOYEE TABLE (5 employees: 1 Employee, 1 Manager, 1 Admin, 2 extra Employees)
  // ----------------------------------------------------------------------------
  EMPLOYEE: [
    {
      Employee_ID: "EMP101",
      IFSC: "APEX0001001",
      First_Name: "Rajesh",
      Last_Name: "Sharma",
      DOB: "1982-05-10",
      Gender: "Male",
      Contact: "+91 98101 11223",
      Address: "C-12, Green Park Extension, New Delhi",
      Joining_Date: "2015-04-12",
      Role: "Manager",
      Salary: 125000.00,
      Status: "Active"
    },
    {
      Employee_ID: "EMP102",
      IFSC: "APEX0002002",
      First_Name: "Priya",
      Last_Name: "Nair",
      DOB: "1985-09-15",
      Gender: "Female",
      Contact: "+91 98450 33445",
      Address: "B-404, Prestige Palms, Whitefield, Bengaluru",
      Joining_Date: "2018-09-20",
      Role: "Manager",
      Salary: 120000.00,
      Status: "Active"
    },
    {
      Employee_ID: "EMP103",
      IFSC: "APEX0001001",
      First_Name: "Amit",
      Last_Name: "Verma",
      DOB: "1986-07-28",
      Gender: "Male",
      Contact: "+91 99110 55667",
      Address: "Flat 302, Cyber Heights, Sector 62, Noida",
      Joining_Date: "2016-01-15",
      Role: "Admin",
      Salary: 145000.00,
      Status: "Active"
    },
    {
      Employee_ID: "EMP104",
      IFSC: "APEX0001001",
      First_Name: "Sneha",
      Last_Name: "Patel",
      DOB: "1994-11-12",
      Gender: "Female",
      Contact: "+91 97230 77889",
      Address: "A-501, Vasant Kunj, New Delhi",
      Joining_Date: "2021-08-01",
      Role: "Employee",
      Salary: 65000.00,
      Status: "Active"
    },
    {
      Employee_ID: "EMP105",
      IFSC: "APEX0002002",
      First_Name: "Vikram",
      Last_Name: "Rao",
      DOB: "1993-04-03",
      Gender: "Male",
      Contact: "+91 98440 99001",
      Address: "14, HSR Layout Sector 1, Bengaluru",
      Joining_Date: "2022-03-15",
      Role: "Employee",
      Salary: 62000.00,
      Status: "Active"
    }
  ],

  // ----------------------------------------------------------------------------
  // 5. ACCOUNT TABLE (8 accounts across branches)
  // ----------------------------------------------------------------------------
  ACCOUNT: [
    {
      Account_No: "10010005421",
      CIF: "CIF10001",
      IFSC: "APEX0001001",
      Nominee: "Sunita Sharma (Mother)",
      Account_Type_ID: "ACT101", // Savings Account
      Opening_Date: "2021-03-10",
      Status: "Active",
      Current_Balance: 245850.00
    },
    {
      Account_No: "10010008890",
      CIF: "CIF10001",
      IFSC: "APEX0001001",
      Nominee: "Sunita Sharma (Mother)",
      Account_Type_ID: "ACT103", // Salary Account
      Opening_Date: "2022-06-15",
      Status: "Active",
      Current_Balance: 85200.00
    },
    {
      Account_No: "20020003112",
      CIF: "CIF10002",
      IFSC: "APEX0002002",
      Nominee: "K. R. Iyer (Father)",
      Account_Type_ID: "ACT101", // Savings Account
      Opening_Date: "2020-01-20",
      Status: "Active",
      Current_Balance: 512400.00
    },
    {
      Account_No: "20020007891",
      CIF: "CIF10002",
      IFSC: "APEX0002002",
      Nominee: "Self",
      Account_Type_ID: "ACT102", // Current Account
      Opening_Date: "2023-02-11",
      Status: "Active",
      Current_Balance: 650000.00
    },
    {
      Account_No: "10010007743",
      CIF: "CIF10003",
      IFSC: "APEX0001001",
      Nominee: "Pooja Desai (Spouse)",
      Account_Type_ID: "ACT102", // Current Account
      Opening_Date: "2019-11-04",
      Status: "Active",
      Current_Balance: 1280000.00
    },
    {
      Account_No: "10010009921",
      CIF: "CIF10004",
      IFSC: "APEX0001001",
      Nominee: "Rajeev Verma (Brother)",
      Account_Type_ID: "ACT101", // Savings Account
      Opening_Date: "2022-09-18",
      Status: "Active",
      Current_Balance: 165300.00
    },
    {
      Account_No: "20020004456",
      CIF: "CIF10005",
      IFSC: "APEX0002002",
      Nominee: "Nisha Kapoor (Spouse)",
      Account_Type_ID: "ACT101", // Savings Account
      Opening_Date: "2021-12-05",
      Status: "Active",
      Current_Balance: 390500.00
    },
    {
      Account_No: "10010006619",
      CIF: "CIF10006",
      IFSC: "APEX0001001",
      Nominee: "Kirit Patel (Father)",
      Account_Type_ID: "ACT102", // Current Account
      Opening_Date: "2020-07-29",
      Status: "Active",
      Current_Balance: 845000.00
    }
  ],

  // ----------------------------------------------------------------------------
  // 6. TRANSACTION TABLE (20 realistic transactions)
  // ----------------------------------------------------------------------------
  TRANSACTION: [
    {
      Transaction_ID: "TXN9001",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 85000.00,
      Transaction_Date_Time: "2026-10-14 10:30:15",
      Balance_After: 245850.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9002",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 1850.00,
      Transaction_Date_Time: "2026-10-13 19:45:10",
      Balance_After: 160850.00,
      Channel: "UPI",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9003",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 38760.00,
      Transaction_Date_Time: "2026-10-10 05:00:00",
      Balance_After: 162700.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9004",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 10000.00,
      Transaction_Date_Time: "2026-10-08 14:15:20",
      Balance_After: 201460.00,
      Channel: "ATM",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9005",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 450.00,
      Transaction_Date_Time: "2026-10-06 21:12:05",
      Balance_After: 211460.00,
      Channel: "UPI",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9006",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 12500.00,
      Transaction_Date_Time: "2026-10-03 16:20:45",
      Balance_After: 211910.00,
      Channel: "UPI",
      Status: "Failed"
    },
    {
      Transaction_ID: "TXN9007",
      Account_No: "10010008890",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 95000.00,
      Transaction_Date_Time: "2026-10-01 09:00:00",
      Balance_After: 85200.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9008",
      Account_No: "10010008890",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 16680.00,
      Transaction_Date_Time: "2026-10-05 06:30:00",
      Balance_After: 68520.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9009",
      Account_No: "20020003112",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 120000.00,
      Transaction_Date_Time: "2026-10-14 11:25:00",
      Balance_After: 512400.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9010",
      Account_No: "20020003112",
      Employee_ID: "EMP105",
      Transaction_Type: "Debit",
      Amount: 25000.00,
      Transaction_Date_Time: "2026-10-12 15:40:10",
      Balance_After: 392400.00,
      Channel: "Branch",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9011",
      Account_No: "10010007743",
      Employee_ID: "EMP104",
      Transaction_Type: "Credit",
      Amount: 250000.00,
      Transaction_Date_Time: "2026-10-15 11:10:00",
      Balance_After: 1280000.00,
      Channel: "Branch",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9012",
      Account_No: "10010007743",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 50000.00,
      Transaction_Date_Time: "2026-10-14 16:50:33",
      Balance_After: 1030000.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9013",
      Account_No: "10010009921",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 45000.00,
      Transaction_Date_Time: "2026-10-13 14:05:12",
      Balance_After: 165300.00,
      Channel: "UPI",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9014",
      Account_No: "10010009921",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 2200.00,
      Transaction_Date_Time: "2026-10-12 20:18:40",
      Balance_After: 120300.00,
      Channel: "UPI",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9015",
      Account_No: "20020004456",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 60000.00,
      Transaction_Date_Time: "2026-10-15 09:45:00",
      Balance_After: 390500.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9016",
      Account_No: "20020004456",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 8500.00,
      Transaction_Date_Time: "2026-10-11 18:30:25",
      Balance_After: 330500.00,
      Channel: "ATM",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9017",
      Account_No: "10010006619",
      Employee_ID: "EMP104",
      Transaction_Type: "Credit",
      Amount: 180000.00,
      Transaction_Date_Time: "2026-10-15 12:20:00",
      Balance_After: 845000.00,
      Channel: "Branch",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9018",
      Account_No: "20020007891",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 150000.00,
      Transaction_Date_Time: "2026-10-10 13:10:00",
      Balance_After: 650000.00,
      Channel: "NetBanking",
      Status: "Completed"
    },
    {
      Transaction_ID: "TXN9019",
      Account_No: "10010005421",
      Employee_ID: null,
      Transaction_Type: "Credit",
      Amount: 5000.00,
      Transaction_Date_Time: "2026-10-15 14:10:00",
      Balance_After: 250850.00,
      Channel: "UPI",
      Status: "Pending"
    },
    {
      Transaction_ID: "TXN9020",
      Account_No: "20020003112",
      Employee_ID: null,
      Transaction_Type: "Debit",
      Amount: 16490.00,
      Transaction_Date_Time: "2026-10-07 05:30:00",
      Balance_After: 417400.00,
      Channel: "NetBanking",
      Status: "Completed"
    }
  ],

  // ----------------------------------------------------------------------------
  // 7. FUND_TRANSFER TABLE (Tracks account-to-account transfers)
  // ----------------------------------------------------------------------------
  FUND_TRANSFER: [
    {
      Transaction_ID: "TXN9001",
      From_Account_No: "10010007743",
      To_Account_No: "10010005421",
      Transfer_Mode: "NEFT",
      Reference_No: "NEFT26101498124"
    },
    {
      Transaction_ID: "TXN9009",
      From_Account_No: "20020007891",
      To_Account_No: "20020003112",
      Transfer_Mode: "IMPS",
      Reference_No: "IMPS26101444192"
    },
    {
      Transaction_ID: "TXN9012",
      From_Account_No: "10010007743",
      To_Account_No: "10010009921",
      Transfer_Mode: "RTGS",
      Reference_No: "RTGS26101488103"
    }
  ],

  // ----------------------------------------------------------------------------
  // 8. LOAN_TYPE TABLE
  // ----------------------------------------------------------------------------
  LOAN_TYPE: [
    {
      Loan_Type_ID: "LN101",
      Loan_Type_Name: "Home Loan",
      Interest_Rate: 8.40,
      Max_Amount: 15000000.00
    },
    {
      Loan_Type_ID: "LN102",
      Loan_Type_Name: "Car Loan",
      Interest_Rate: 9.20,
      Max_Amount: 2500000.00
    },
    {
      Loan_Type_ID: "LN103",
      Loan_Type_Name: "Personal Loan",
      Interest_Rate: 11.50,
      Max_Amount: 1500000.00
    }
  ],

  // ----------------------------------------------------------------------------
  // 9. LOAN TABLE (4 loans)
  // ----------------------------------------------------------------------------
  LOAN: [
    {
      Loan_ID: "LOAN501",
      CIF: "CIF10001", // Rahul Sharma
      Account_No: "10010005421",
      Loan_Type_ID: "LN101", // Home Loan
      Employee_ID: "EMP101",
      Principal_Amount: 4500000.00,
      Interest_Rate: 8.40,
      Tenure_Months: 240,
      EMI_Amount: 38760.00,
      Remaining_Amount: 3240000.00,
      Start_Date: "2021-04-10",
      End_Date: "2041-04-10",
      Loan_Status: "Active"
    },
    {
      Loan_ID: "LOAN502",
      CIF: "CIF10001", // Rahul Sharma
      Account_No: "10010008890",
      Loan_Type_ID: "LN102", // Car Loan
      Employee_ID: "EMP104",
      Principal_Amount: 800000.00,
      Interest_Rate: 9.20,
      Tenure_Months: 60,
      EMI_Amount: 16680.00,
      Remaining_Amount: 385000.00,
      Start_Date: "2023-01-05",
      End_Date: "2028-01-05",
      Loan_Status: "Active"
    },
    {
      Loan_ID: "LOAN503",
      CIF: "CIF10002", // Ananya Iyer
      Account_No: "20020003112",
      Loan_Type_ID: "LN103", // Personal Loan
      Employee_ID: "EMP102",
      Principal_Amount: 500000.00,
      Interest_Rate: 11.50,
      Tenure_Months: 36,
      EMI_Amount: 16490.00,
      Remaining_Amount: 210000.00,
      Start_Date: "2024-03-01",
      End_Date: "2027-03-01",
      Loan_Status: "Active"
    },
    {
      Loan_ID: "LOAN504",
      CIF: "CIF10003", // Rohan Desai
      Account_No: "10010007743",
      Loan_Type_ID: "LN101", // Home Loan
      Employee_ID: "EMP101",
      Principal_Amount: 7500000.00,
      Interest_Rate: 8.40,
      Tenure_Months: 180,
      EMI_Amount: 73450.00,
      Remaining_Amount: 7500000.00,
      Start_Date: "2026-10-12",
      End_Date: "2041-10-12",
      Loan_Status: "Pending" // Used for Employee loan approval demonstration
    }
  ],

  // ----------------------------------------------------------------------------
  // 10. LOAN_PAYMENT TABLE
  // ----------------------------------------------------------------------------
  LOAN_PAYMENT: [
    {
      Payment_ID: "PMT701",
      Loan_ID: "LOAN501",
      Transaction_ID: "TXN9003",
      Payment_Method: "Auto-Debit",
      Payment_Status: "Completed",
      Principal_Paid: 16080.00,
      Interest_Paid: 22680.00,
      Remaining_Balance: 3240000.00
    },
    {
      Payment_ID: "PMT702",
      Loan_ID: "LOAN502",
      Transaction_ID: "TXN9008",
      Payment_Method: "Auto-Debit",
      Payment_Status: "Completed",
      Principal_Paid: 13730.00,
      Interest_Paid: 2950.00,
      Remaining_Balance: 385000.00
    },
    {
      Payment_ID: "PMT703",
      Loan_ID: "LOAN503",
      Transaction_ID: "TXN9020",
      Payment_Method: "Auto-Debit",
      Payment_Status: "Completed",
      Principal_Paid: 14480.00,
      Interest_Paid: 2010.00,
      Remaining_Balance: 210000.00
    }
  ],

  // ----------------------------------------------------------------------------
  // 11. LOGIN TABLE (Demo credentials and account status simulations)
  // ----------------------------------------------------------------------------
  LOGIN: [
    {
      Login_ID: "LOG001",
      Username: "customer1",
      Password_Hash: "pass123", // DEMO ONLY: Real system will store bcrypt/argon2 hash
      Role: "customer",
      Employee_ID: null,
      CIF: "CIF10001", // Rahul Sharma
      Last_Login: "2026-10-15 18:45:22",
      Account_Status: "Active"
    },
    {
      Login_ID: "LOG002",
      Username: "employee1",
      Password_Hash: "pass123",
      Role: "employee",
      Employee_ID: "EMP104", // Sneha Patel (Branch Employee)
      CIF: null,
      Last_Login: "2026-10-15 09:12:08",
      Account_Status: "Active"
    },
    {
      Login_ID: "LOG003",
      Username: "admin1",
      Password_Hash: "pass123",
      Role: "admin",
      Employee_ID: "EMP103", // Amit Verma (System Admin)
      CIF: null,
      Last_Login: "2026-10-15 14:30:45",
      Account_Status: "Active"
    },
    {
      Login_ID: "LOG004",
      Username: "locked_user",
      Password_Hash: "pass123",
      Role: "customer",
      Employee_ID: null,
      CIF: "CIF10004", // Pooja Verma
      Last_Login: "2026-10-02 11:20:10",
      Account_Status: "Locked" // Used for testing locked account message
    },
    {
      Login_ID: "LOG005",
      Username: "disabled_user",
      Password_Hash: "pass123",
      Role: "customer",
      Employee_ID: null,
      CIF: "CIF10005", // Arjun Kapoor
      Last_Login: "2026-09-18 16:04:55",
      Account_Status: "Disabled" // Used for testing disabled account message
    },
    {
      Login_ID: "LOG006",
      Username: "ananya_iyer",
      Password_Hash: "pass123",
      Role: "customer",
      Employee_ID: null,
      CIF: "CIF10002",
      Last_Login: "2026-10-14 21:10:00",
      Account_Status: "Active"
    },
    {
      Login_ID: "LOG007",
      Username: "manager1",
      Password_Hash: "pass123",
      Role: "employee",
      Employee_ID: "EMP101",
      CIF: null,
      Last_Login: "2026-10-15 08:30:19",
      Account_Status: "Active"
    }
  ]
};

// Expose mock data object safely to the window for api.js
window.MOCK_DATABASE = MOCK_DATABASE;
