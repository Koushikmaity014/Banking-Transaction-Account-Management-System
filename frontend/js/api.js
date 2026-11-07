
/**
 * API layer for the IITG Bank DBMS project.
 * All requests use the FastAPI backend.
 */
const BASE_URL = (
  window.BANK_API_BASE_URL || "http://127.0.0.1:8000/api"
).replace(/\/$/, "");

const TOKEN_KEY = "bank_access_token";

function getToken() {
  return sessionStorage.getItem(TOKEN_KEY);
}

function saveToken(token) {
  if (token) sessionStorage.setItem(TOKEN_KEY, token);
}

function clearToken() {
  sessionStorage.removeItem(TOKEN_KEY);
}

async function request(path, options = {}) {
  const headers = new Headers(options.headers || {});

  if (options.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const token = getToken();
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let response;

  try {
    response = await fetch(`${BASE_URL}${path}`, {
      ...options,
      headers
    });
  } catch (_) {
    return {
      success: false,
      data: null,
      message:
        "Cannot connect to FastAPI. Start the backend at http://127.0.0.1:8000."
    };
  }

  let body = {};

  try {
    body = await response.json();
  } catch (_) {
    // Some successful responses may have no JSON body.
  }

  if (!response.ok) {
    if (response.status === 401) {
      clearToken();

      if (!path.startsWith("/auth/login")) {
        sessionStorage.removeItem("bank_current_user");
      }
    }

    const detail =
      body.detail || body.message || `Request failed (${response.status})`;

    return {
      success: false,
      data: null,
      message: Array.isArray(detail)
        ? detail.map(item => item.msg || String(item)).join("; ")
        : String(detail),
      status: response.status
    };
  }

  if (Object.prototype.hasOwnProperty.call(body, "success")) {
    return body;
  }

  return {
    success: true,
    data: body,
    message: "Request completed successfully."
  };
}

const api = {
  login: async function(username, password, role) {
    clearToken();

    const result = await request("/auth/login", {
      method: "POST",
      body: JSON.stringify({
        username: username.trim(),
        password,
        role: String(role || "").toLowerCase()
      })
    });

    if (result.success && result.data?.access_token) {
      saveToken(result.data.access_token);
    }

    return result;
  },

  getCustomerDashboardData: async function() {
    return request("/customer/dashboard");
  },

  getEmployeeDashboardData: async function() {
    return request("/employee/dashboard");
  },

  // Fetch the complete customer directory for the authenticated employee's branch.
  getAllCustomers: async function() {
    return request("/employee/customers");
  },

  getAdminDashboardData: async function() {
    return request("/admin/dashboard");
  },

  getBranches: async function() {
    return request("/branches");
  },

  
  // Admin-only employee management
  getEmployees: async function() {
    return request("/admin/employees");
  },

  createEmployee: async function(payload) {
    return request("/admin/employees", {
      method: "POST",
      body: JSON.stringify({
        ifsc: String(payload.ifsc || "").trim().toUpperCase(),
        first_name: String(payload.first_name || "").trim(),
        last_name: String(payload.last_name || "").trim(),
        dob: payload.dob,
        gender: payload.gender || null,
        contact: String(payload.contact || "").trim(),
        address: String(payload.address || "").trim() || null,
        role: payload.role,
        salary: Number(payload.salary)
      })
    });
  },

  deactivateEmployee: async function(employeeId) {
    return request(
      `/admin/employees/${encodeURIComponent(employeeId)}`,
      { method: "DELETE" }
    );
  },


  getAccounts: async function() {
    return request("/accounts");
  },

  // NEW: Fetch the authenticated customer's personal details
  // and all linked bank accounts.
  getCustomerProfile: async function() {
    return request("/accounts/profile");
  },

  getAccountTypes: async function() {
    return request("/account-types");
  },

  getBranchCustomers: async function() {
    return request("/customers");
  },

  
  getCustomerProfileByCif: async function(cif) {
    return request(
      `/customers/${encodeURIComponent(cif)}/profile`
    );
  },


  createCustomer: async function(payload) {
    const body = {
      first_name: payload.first_name,
      last_name: payload.last_name,
      dob: payload.dob || payload.date_of_birth,
      gender: payload.gender,
      contact: payload.contact || payload.phone,
      pan: String(payload.pan || "").toUpperCase(),
      aadhar_no: payload.aadhar_no,
      address: payload.address || null
    };

    return request("/customers", {
      method: "POST",
      body: JSON.stringify(body)
    });
  },

  openAccount: async function(payload) {
    return request("/accounts", {
      method: "POST",
      body: JSON.stringify({
        cif: payload.cif,
        ifsc: payload.ifsc,
        nominee: payload.nominee || null,
        account_type_id: String(payload.account_type_id),
        initial_balance: Number(
          payload.initial_balance ?? payload.initial_deposit
        )
      })
    });
  },

  getTransactions: async function(accountNo, limit = 50, offset = 0) {
    return request(
      `/accounts/${encodeURIComponent(accountNo)}/transactions?limit=${limit}&offset=${offset}`
    );
  },

  deposit: async function(accountNo, amount, channel = "Online_Banking") {
    return request("/deposits", {
      method: "POST",
      body: JSON.stringify({
        account_no: accountNo,
        amount: Number(amount),
        channel
      })
    });
  },

  withdraw: async function(accountNo, amount, channel = "Online_Banking") {
    return request("/withdrawals", {
      method: "POST",
      body: JSON.stringify({
        account_no: accountNo,
        amount: Number(amount),
        channel
      })
    });
  },

  // Employee dashboard forms pass a single payload object.
  staffDeposit: async function(payload) {
    return api.deposit(payload.account_no, payload.amount, "Branch");
  },

  staffWithdrawal: async function(payload) {
    return api.withdraw(payload.account_no, payload.amount, "Branch");
  },

  transfer: async function(
    fromAccountNo,
    toAccountNo,
    amount,
    transferMode = "Internal_Transfer"
  ) {
    return request("/transfers", {
      method: "POST",
      body: JSON.stringify({
        from_account_no: fromAccountNo,
        to_account_no: toAccountNo,
        amount: Number(amount),
        transfer_mode: transferMode
      })
    });
  },

  getLoans: async function() {
    return request("/loans");
  },

  getLoanTypes: async function() {
    return request("/loans/types");
  },

  applyLoan: async function(payload) {
    return request("/loans/applications", {
      method: "POST",
      body: JSON.stringify(payload)
    });
  },

  createStaffLoan: async function(payload) {
    return request("/loans/staff-applications", {
      method: "POST",
      body: JSON.stringify({
        cif: payload.cif,
        account_no: payload.account_no,
        loan_type_id: String(payload.loan_type_id),
        principal: Number(payload.principal ?? payload.principal_amount),
        tenure_months: Number(payload.tenure_months)
      })
    });
  },

  decideLoan: async function(loanId, decision) {
    return request(
      `/loans/${encodeURIComponent(loanId)}/decision`,
      {
        method: "POST",
        body: JSON.stringify({ decision })
      }
    );
  },

  // Compatibility methods for the current employee dashboard.
  approveLoan: async function(loanId) {
    return api.decideLoan(loanId, "Approved");
  },

  rejectLoan: async function(loanId) {
    return api.decideLoan(loanId, "Rejected");
  },

  payLoan: async function(loanId, payload) {
    return request(
      `/loans/${encodeURIComponent(loanId)}/payments`,
      {
        method: "POST",
        body: JSON.stringify({
          loan_id: loanId,
          ...payload
        })
      }
    );
  },

  clearToken
};

window.api = api;
