/* =========================================================
   IITG BANK — ADMIN DATABASE MANAGEMENT
   File: frontend/admin/admin-records.js
   ========================================================= */

(() => {
    "use strict";

    // -----------------------------------------------------
    // API CONFIGURATION
    // Change these paths if your FastAPI routes differ.
    // -----------------------------------------------------

    const API_BASE = "http://127.0.0.1:8000";

    const ENDPOINTS = {
      branches: {
          table: "branch",
          label: "Branches",
          path: "/api/branches",
          editable: false
      },
      employees: {
        table: "employee",
        label: "Employees",
        path: "/api/admin/employees",
        editable: false
    },
      customers: {
          table: "customer",
          label: "Customers",
          path: "/api/customers",
          editable: false
      },
      accounts: {
          table: "account",
          label: "Accounts",
          path: "/api/accounts",
          editable: false
      },
      account_types: {
          table: "account_type",
          label: "Account Types",
          path: "/api/account-types",
          editable: false
      },
      loan_types: {
          table: "loan_type",
          label: "Loan Types",
          path: "/api/loan-types",
          editable: false
      },
      transactions: {
          table: "TRANSACTION",
          label: "Transactions",
          path: "/api/transactions",
          editable: false
      },
      fund_transfers: {
          table: "fund_transfer",
          label: "Fund Transfers",
          path: "/api/fund-transfers",
          editable: false
      },
      loans: {
          table: "loan",
          label: "Loans",
          path: "/api/loans",
          editable: false
      },
      loan_payments: {
          table: "loan_payment",
          label: "Loan Payments",
          path: "/api/loan-payments",
          editable: false
      },
      user_logins: {
          table: "login",
          label: "User Logins",
          path: "/api/logins",
          editable: false
      },
      audit_logs: {
          table: "audit_log",
          label: "Audit Logs",
          path: "/api/audit-logs",
          editable: false
      }
  };

    const state = {
        key: null,
        records: [],
        filtered: [],
        columns: [],
        editing: null,
        loading: false,
        requestNumber: 0,
        sortColumn: null,
        sortDirection: "asc"
    };

    const $ = id => document.getElementById(id);

    const nav = $("table-navigation");

    // -----------------------------------------------------
    // UTILITIES
    // -----------------------------------------------------

    function escapeHtml(value) {
        return String(value ?? "").replace(/[&<>"']/g, character => ({
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#39;"
        })[character]);
    }

    function nice(value) {
        return String(value)
            .replace(/_/g, " ")
            .replace(/\b\w/g, character => character.toUpperCase());
    }

    function formatValue(value) {
        if (value === null || value === undefined || value === "") {
            return "—";
        }

        if (typeof value === "object") {
            return JSON.stringify(value);
        }

        return String(value);
    }

    function apiUrl(key, id = null) {
        const endpoint = ENDPOINTS[key];

        if (!endpoint) {
            throw new Error("Unknown database table: " + key);
        }

        return API_BASE +
            endpoint.path +
            (id === null ? "" : "/" + encodeURIComponent(id));
    }

    function showNotice(message, type = "info") {
        const notice = $("notice");

        if (!notice) return;

        notice.textContent = message;
        notice.className = "notice " + type;
        notice.hidden = false;
    }

    function clearNotice() {
        const notice = $("notice");

        if (notice) {
            notice.hidden = true;
        }
    }

    // -----------------------------------------------------
    // AUTHENTICATION
    // -----------------------------------------------------

    /*
     * Prefer the token key already used by your auth.js.
     *
     * The keys below are common examples, not a guarantee
     * of your application's actual token storage key.
     */

    function getAuthToken() {
        const knownKeys = [
            "access_token",
            "accessToken",
            "authToken",
            "token",
            "jwt",
            "bank_token",
            "bank_access_token"
        ];

        for (const storage of [sessionStorage, localStorage]) {
            for (const key of knownKeys) {
                const value = storage.getItem(key);

                if (!value) continue;

                try {
                    const parsed = JSON.parse(value);

                    if (typeof parsed === "string") {
                        return parsed;
                    }

                    if (parsed && typeof parsed === "object") {
                        const token =
                            parsed.access_token ||
                            parsed.accessToken ||
                            parsed.token;

                        if (typeof token === "string") {
                            return token;
                        }
                    }
                } catch {
                    return value;
                }
            }
        }

        return null;
    }

    // -----------------------------------------------------
    // API REQUESTS
    // -----------------------------------------------------

    async function request(url, options = {}) {
        const headers = {
            Accept: "application/json",
            ...(options.body
                ? { "Content-Type": "application/json" }
                : {}),
            ...(options.headers || {})
        };

        const token = getAuthToken();

        if (token) {
            headers.Authorization = `Bearer ${token}`;
        }

        const response = await fetch(url, {
            ...options,
            headers
        });

        const text = await response.text();

        let body = null;

        try {
            body = text ? JSON.parse(text) : null;
        } catch {
            body = text;
        }

        if (!response.ok) {
            let message = "";

            if (body && typeof body === "object") {
                message = body.detail || body.message || "";
            } else {
                message = String(body || "");
            }

            if (response.status === 401) {
                throw new Error(
                    "Authentication required. Check auth.js and use the exact token storage key used by your login implementation."
                );
            }

            if (response.status === 403) {
                throw new Error(
                    "Access denied. Your current user may not have administrator permissions."
                );
            }

            throw new Error(
                message || `HTTP error ${response.status}`
            );
        }

        return body;
    }

    function normalizeList(body) {
        if (Array.isArray(body)) {
            return body;
        }

        if (body && Array.isArray(body.data)) {
            return body.data;
        }

        if (body && Array.isArray(body.items)) {
            return body.items;
        }

        if (body && Array.isArray(body.results)) {
            return body.results;
        }

        if (body && Array.isArray(body.records)) {
            return body.records;
        }

        throw new Error(
            "The API response must contain a list of records."
        );
    }

    // -----------------------------------------------------
    // PRIMARY KEY DETECTION
    // -----------------------------------------------------

    function primaryKey(record) {
        if (!record || typeof record !== "object") {
            return null;
        }

        const keys = Object.keys(record);

        const candidates = [
            "id",
            "branch_id",
            "Branch_ID",
            "employee_id",
            "Employee_ID",
            "customer_id",
            "Customer_ID",
            "account_no",
            "Account_No",
            "account_id",
            "Account_ID",
            "account_type_id",
            "Account_Type_ID",
            "loan_type_id",
            "Loan_Type_ID",
            "transaction_id",
            "Transaction_ID",
            "transfer_id",
            "fund_transfer_id",
            "loan_id",
            "Loan_ID",
            "loan_payment_id",
            "login_id",
            "Login_ID",
            "audit_id",
            "audit_log_id"
        ];

        for (const candidate of candidates) {
            if (keys.includes(candidate)) {
                return {
                    key: candidate,
                    value: record[candidate]
                };
            }
        }

        const found = keys.find(key =>
            /(^id$|_id$|^id_)/i.test(key)
        );

        return found
            ? { key: found, value: record[found] }
            : null;
    }

    // -----------------------------------------------------
    // SIDEBAR NAVIGATION
    // -----------------------------------------------------

    function iconFor(key) {
        const icons = {
            branches: "fa-network-wired",
            employees: "fa-id-card-clip",
            customers: "fa-users",
            accounts: "fa-book",
            account_types: "fa-layer-group",
            loan_types: "fa-percent",
            transactions: "fa-list-check",
            fund_transfers: "fa-money-bill-transfer",
            loans: "fa-file-invoice-dollar",
            loan_payments: "fa-money-check-dollar",
            user_logins: "fa-key",
            audit_logs: "fa-file-shield"
        };

        return icons[key] || "fa-table";
    }

    function renderNavigation() {
        if (!nav) {
            console.error(
                'Missing element with id="table-navigation" in admin-records.html'
            );
            return;
        }

        const groups = [
            {
                title: "Administration",
                keys: [
                    "branches",
                    "employees",
                    "customers",
                    "accounts",
                    "account_types",
                    "loan_types"
                ]
            },
            {
                title: "Transactions & Loans",
                keys: [
                    "transactions",
                    "fund_transfers",
                    "loans",
                    "loan_payments"
                ]
            },
            {
                title: "System & Audit",
                keys: [
                    "user_logins",
                    "audit_logs"
                ]
            }
        ];

        nav.innerHTML = groups.map(group => `
            <div class="nav-section-title">
                ${escapeHtml(group.title)}
            </div>

            ${group.keys.map(key => {
                const config = ENDPOINTS[key];

                return `
                    <a
                        href="#${key}"
                        class="nav-item"
                        data-key="${key}"
                        aria-current="false"
                    >
                        <span class="nav-icon">
                            <i class="fa-solid ${iconFor(key)}"></i>
                        </span>
                        <span>${escapeHtml(config.label)}</span>
                    </a>
                `;
            }).join("")}
        `).join("");

        nav.querySelectorAll("[data-key]").forEach(link => {
            link.addEventListener("click", event => {
                event.preventDefault();

                const key = link.dataset.key;

                if (!ENDPOINTS[key]) return;

                if (location.hash !== "#" + key) {
                    location.hash = key;
                } else {
                    selectTable(key);
                }

                $("sidebar")?.classList.remove("open");
            });
        });

        updateActiveLink();
    }

    function updateActiveLink() {
        nav?.querySelectorAll("[data-key]").forEach(link => {
            const active = link.dataset.key === state.key;

            link.classList.toggle("active", active);
            link.setAttribute(
                "aria-current",
                active ? "page" : "false"
            );
        });
    }

    // -----------------------------------------------------
    // LOAD SELECTED TABLE
    // -----------------------------------------------------

    async function selectTable(key) {
        if (!ENDPOINTS[key]) {
            key = "branches";
        }

        const requestId = ++state.requestNumber;

        state.key = key;
        state.records = [];
        state.filtered = [];
        state.columns = [];
        state.editing = null;
        state.sortColumn = null;
        state.sortDirection = "asc";

        renderNavigation();
        updateActiveLink();

        const config = ENDPOINTS[key];

        $("crumb-title").textContent = config.label;
        $("page-title").textContent = config.label;

        $("page-description").textContent = config.editable
            ? `View and manage ${config.table} records.`
            : `View ${config.table} records.`;

        $("table-name-card").textContent = config.table;
        $("search-input").value = "";
        $("add-record").hidden = !config.editable && key !== "employees";

        const addButtonText = $("add-record").querySelector("span");
        if (addButtonText) {
            addButtonText.textContent =
                key === "employees" ? "Add Employee" : "Add record";
        }

        $("api-status").textContent = "Loading";
        $("api-status-detail").textContent = "Requesting records";

        $("records-head").innerHTML = "";
        $("records-body").innerHTML =
            '<tr><td class="empty-cell">Loading records...</td></tr>';

        $("table-caption").textContent =
            `Loading ${config.label.toLowerCase()}...`;

        clearNotice();

        try {
            const response = await request(apiUrl(key));

            // Ignore a response if the user selected another table.
            if (requestId !== state.requestNumber) return;

            state.records = normalizeList(response);
            state.columns = collectColumns(state.records);
            state.filtered = [...state.records];

            renderTable();

            $("api-status").textContent = "Connected";
            $("api-status-detail").textContent = "Records loaded";

            $("connection-label").textContent = "API connected";

            document.querySelector(".connection-dot")
                ?.classList.remove("offline");

            document.querySelector(".connection-dot")
                ?.classList.add("online");

        } catch (error) {
            if (requestId !== state.requestNumber) return;

            state.records = [];
            state.filtered = [];
            state.columns = [];

            renderTable();

            $("api-status").textContent = "Unavailable";
            $("api-status-detail").textContent = "Check API and permissions";

            $("connection-label").textContent = "API unavailable";

            document.querySelector(".connection-dot")
                ?.classList.remove("online");

            document.querySelector(".connection-dot")
                ?.classList.add("offline");

            showNotice(
                `Could not load ${config.label}: ${error.message}`,
                "error"
            );

            console.error("Table loading error:", error);
        }
    }

    function collectColumns(records) {
        const columns = [];

        records.forEach(record => {
            if (!record || typeof record !== "object") return;

            Object.keys(record).forEach(key => {
                if (!columns.includes(key)) {
                    columns.push(key);
                }
            });
        });

        return columns;
    }

    // -----------------------------------------------------
    // TABLE SORTING
    // -----------------------------------------------------

    function compareValues(a, b, column) {
        // Keep missing values at the bottom in either direction.
        const aMissing = a === null || a === undefined || a === "";
        const bMissing = b === null || b === undefined || b === "";

        if (aMissing && bMissing) return 0;
        if (aMissing) return 1;
        if (bMissing) return -1;

        // Sort numeric values numerically, including numeric strings.
        const numericColumn =
            /amount|balance|salary|interest|rate|count|total|number|_id$|^id$|account_no|ifsc|micr/i.test(column);

        if (typeof a === "number" && typeof b === "number") {
            return a - b;
        }

        if (numericColumn) {
            const numA = Number(a);
            const numB = Number(b);

            if (Number.isFinite(numA) && Number.isFinite(numB)) {
                return numA - numB;
            }
        }

        // Dates and timestamps should sort chronologically.
        const dateColumn = /date|time|created_at|updated_at|last_login|dob|joining/i.test(column);

        if (dateColumn) {
            const timeA = Date.parse(a);
            const timeB = Date.parse(b);

            if (Number.isFinite(timeA) && Number.isFinite(timeB)) {
                return timeA - timeB;
            }
        }

        // Fall back to case-insensitive natural text ordering.
        return String(a).localeCompare(String(b), undefined, {
            numeric: true,
            sensitivity: "base"
        });
    }

    function getSortedRecords() {
        const records = [...state.filtered];

        if (!state.sortColumn) return records;

        records.sort((recordA, recordB) => {
            const result = compareValues(
                recordA[state.sortColumn],
                recordB[state.sortColumn],
                state.sortColumn
            );

            return state.sortDirection === "desc" ? -result : result;
        });

        return records;
    }

    // -----------------------------------------------------
    // RENDER TABLE
    // -----------------------------------------------------

    function renderTable() {
        const config = ENDPOINTS[state.key];

        const showActions = config.editable || state.key === "employees";
        const actionColumn = showActions ? "<th>Actions</th>" : "";

        $("records-head").innerHTML = `
            <tr>
                ${state.columns.map(column => {
                    const active = state.sortColumn === column;
                    const arrow = active
                        ? (state.sortDirection === "asc" ? " ▲" : " ▼")
                        : " ↕";

                    return `
                        <th>
                            <button
                                type="button"
                                class="column-sort-button"
                                data-sort-column="${escapeHtml(column)}"
                                aria-label="Sort by ${escapeHtml(nice(column))}"
                                title="Sort by ${escapeHtml(nice(column))}"
                                style="border:0;background:transparent;color:inherit;font:inherit;font-weight:inherit;letter-spacing:inherit;text-transform:inherit;padding:0;cursor:pointer;white-space:nowrap"
                            >${escapeHtml(nice(column))}${arrow}</button>
                        </th>
                    `;
                }).join("")}
                ${actionColumn}
            </tr>
        `;

        $("records-head")
            .querySelectorAll("[data-sort-column]")
            .forEach(button => {
                button.addEventListener("click", () => {
                    const column = button.dataset.sortColumn;

                    if (state.sortColumn === column) {
                        state.sortDirection =
                            state.sortDirection === "asc" ? "desc" : "asc";
                    } else {
                        state.sortColumn = column;
                        state.sortDirection = "asc";
                    }

                    renderTable();
                });
            });

        if (!state.filtered.length) {
            const colspan = Math.max(
                1,
                state.columns.length +
                    ((config.editable || state.key === "employees") ? 1 : 0)
            );

            const message = state.records.length
                ? "No records match your search."
                : "No records returned by the API.";

            $("records-body").innerHTML = `
                <tr>
                    <td colspan="${colspan}" class="empty-cell">
                        ${message}
                    </td>
                </tr>
            `;
        } else {
            $("records-body").innerHTML = getSortedRecords()
                .map(record => {
                    const index = state.filtered.indexOf(record);
                    const cells = state.columns.map(column => {
                        const value = formatValue(record[column]);

                        return `
                            <td title="${escapeHtml(value)}">
                                ${escapeHtml(value)}
                            </td>
                        `;
                    }).join("");

                    
            let actions = "";

            if (state.key === "employees") {
                const employeeId =
                    record.Employee_ID ?? record.employee_id;

                const status = String(
                    record.Status ?? record.status ?? ""
                ).toLowerCase();

                actions = `
                    <td>
                        ${
                            status === "active"
                                ? `<button
                                    type="button"
                                    class="small-action danger"
                                    data-deactivate="${escapeHtml(employeeId)}"
                                >Deactivate</button>`
                                : `<span>Inactive</span>`
                        }
                    </td>
                `;
            } else if (config.editable) {
                const pk = primaryKey(record);

                actions = `
                    <td>
                        <div class="row-actions">
                            <button
                                type="button"
                                class="small-action"
                                data-edit="${index}"
                            >Edit</button>

                            ${pk ? `
                                <button
                                    type="button"
                                    class="small-action danger"
                                    data-delete="${index}"
                                >Delete</button>
                            ` : ""}
                        </div>
                    </td>
                `;
            }


                    return `<tr>${cells}${actions}</tr>`;
                }).join("");

            $("records-body")
                .querySelectorAll("[data-edit]")
                .forEach(button => {
                    button.addEventListener("click", () => {
                        openEditor(
                            state.filtered[Number(button.dataset.edit)]
                        );
                    });
                });

            $("records-body")
                .querySelectorAll("[data-delete]")
                .forEach(button => {
                    button.addEventListener("click", () => {
                        deleteRecord(
                            state.filtered[Number(button.dataset.delete)]
                        );
                    });
                });
            
            
            $("records-body")
                .querySelectorAll("[data-deactivate]")
                .forEach(button => {
                    button.addEventListener("click", async () => {
                        const employeeId = button.dataset.deactivate;

                        if (!confirm(
                            `Deactivate employee ${employeeId}?\n\n` +
                            "Their login access will be disabled."
                        )) {
                            return;
                        }

                        button.disabled = true;

                        try {
                            const result = await request(
                                `${API_BASE}/api/admin/employees/${encodeURIComponent(employeeId)}`,
                                { method: "DELETE" }
                            );

                            showNotice(
                                result.message || "Employee deactivated successfully.",
                                "success"
                            );

                            await selectTable("employees");
                        } catch (error) {
                            showNotice(
                                `Could not deactivate employee: ${error.message}`,
                                "error"
                            );
                            button.disabled = false;
                        }
                    });
                });

        }

        $("record-count").textContent =
            state.filtered.length.toLocaleString();

        $("table-caption").textContent =
            `${config.label} · ${state.filtered.length} shown`;

        $("column-caption").textContent =
            `${state.columns.length} columns detected`;

        $("footer-count").textContent =
            `${state.filtered.length} record(s)`;
    }

    // -----------------------------------------------------
    // SEARCH
    // -----------------------------------------------------

    function applySearch() {
        const query = $("search-input")
            .value.trim().toLowerCase();

        state.filtered = !query
            ? [...state.records]
            : state.records.filter(record =>
                Object.values(record).some(value =>
                    formatValue(value).toLowerCase().includes(query)
                )
            );

        renderTable();
    }

    // -----------------------------------------------------
    // RECORD EDITOR
    // -----------------------------------------------------

    function inferInputType(key, value) {
        if (typeof value === "boolean") return "boolean";
        if (typeof value === "number") return "number";

        if (/password|hash|token|secret/i.test(key)) {
            return "password";
        }

        if (/email/i.test(key)) {
            return "email";
        }

        return "text";
    }

    
async function openEmployeeEditor() {
    $("modal-title").textContent = "Add Employee";
    $("modal-help").textContent =
        "Create an employee record and login. The backend generates the employee ID and initial credentials.";
    $("form-error").hidden = true;

    $("form-fields").innerHTML = `
        <div class="field">
            <label for="emp-first-name">First name</label>
            <input id="emp-first-name" name="first_name" required maxlength="50">
        </div>

        <div class="field">
            <label for="emp-last-name">Last name</label>
            <input id="emp-last-name" name="last_name" required maxlength="50">
        </div>

        <div class="field">
            <label for="emp-dob">Date of birth</label>
            <input id="emp-dob" name="dob" type="date" required>
        </div>

        <div class="field">
            <label for="emp-gender">Gender</label>
            <select id="emp-gender" name="gender">
                <option value="">Prefer not to specify</option>
                <option value="Male">Male</option>
                <option value="Female">Female</option>
                <option value="Other">Other</option>
            </select>
        </div>

        <div class="field">
            <label for="emp-contact">Contact number</label>
            <input id="emp-contact" name="contact" required minlength="7" maxlength="20">
        </div>

        <div class="field">
            <label for="emp-role">Designation</label>
            <select id="emp-role" name="role" required>
                <option value="Employee">Employee</option>
                <option value="Manager">Manager</option>
            </select>
        </div>

        <div class="field">
            <label for="emp-branch">Branch</label>
            <select id="emp-branch" name="ifsc" required>
                <option value="">Loading active branches...</option>
            </select>
        </div>

        <div class="field">
            <label for="emp-salary">Salary (₹)</label>
            <input id="emp-salary" name="salary" type="number"
                   min="0" step="0.01" required>
        </div>

        <div class="field full">
            <label for="emp-address">Address</label>
            <textarea id="emp-address" name="address" rows="2"
                      maxlength="255"></textarea>
        </div>
    `;

    $("save-record").textContent = "Create Employee";
    $("record-modal").hidden = false;

    try {
        const response = await request(`${API_BASE}/api/branches`);
        const branches = normalizeList(response);
        const activeBranches = branches.filter(
            branch => String(branch.Status ?? branch.status ?? "")
                .toLowerCase() === "active"
        );

        const select = $("emp-branch");
        select.innerHTML = `
            <option value="">Select a branch</option>
            ${activeBranches.map(branch => {
                const ifsc = branch.IFSC ?? branch.ifsc;
                const name = branch.Branch_Name ?? branch.branch_name ?? ifsc;
                return `
                    <option value="${escapeHtml(ifsc)}">
                        ${escapeHtml(name)} — ${escapeHtml(ifsc)}
                    </option>
                `;
            }).join("")}
        `;

        if (!activeBranches.length) {
            select.innerHTML =
                '<option value="">No active branches available</option>';
        }
    } catch (error) {
        $("emp-branch").innerHTML =
            '<option value="">Could not load branches</option>';
        $("form-error").textContent =
            `Could not load branches: ${error.message}`;
        $("form-error").hidden = false;
    }
}


    function openEditor(record = null) {
        const config = ENDPOINTS[state.key];

        if (!config.editable) {
            showNotice(
                "This table is read-only in the current interface.",
                "info"
            );
            return;
        }

        state.editing = record;

        const isEdit = Boolean(record);
        const pk = primaryKey(record);

        $("modal-title").textContent = isEdit
            ? `Edit ${config.label} record`
            : `Add ${config.label} record`;

        $("modal-help").textContent =
            "Fill in the fields and save. The backend must validate all values.";

        $("form-error").hidden = true;

        const fields = state.columns.filter(key => {
            if (pk && key === pk.key) return false;

            // Do not display password hashes or tokens for editing.
            if (/password_hash|token|secret/i.test(key)) return false;

            return true;
        });

        if (!fields.length) {
            $("form-fields").innerHTML = `
                <p class="modal-help">
                    No columns are available for this table.
                    Load existing records or define a table-specific form.
                </p>
            `;
        } else {
            $("form-fields").innerHTML = fields.map((key, index) => {
                const value = record ? record[key] : "";
                const type = inferInputType(key, value);
                const longText =
                    typeof value === "string" && value.length > 80;

                let control;

                if (type === "boolean") {
                    control = `
                        <select name="${escapeHtml(key)}">
                            <option value="">Select...</option>
                            <option value="true"
                                ${value === true ? "selected" : ""}>
                                True
                            </option>
                            <option value="false"
                                ${value === false ? "selected" : ""}>
                                False
                            </option>
                        </select>
                    `;
                } else if (longText) {
                    control = `
                        <textarea
                            name="${escapeHtml(key)}"
                            rows="3"
                        >${escapeHtml(value ?? "")}</textarea>
                    `;
                } else {
                    control = `
                        <input
                            name="${escapeHtml(key)}"
                            type="${type}"
                            value="${escapeHtml(value ?? "")}"
                            ${type === "number" ? 'step="any"' : ""}
                            ${isEdit && /created_at|updated_at|last_login/i.test(key)
                                ? "readonly"
                                : ""}
                        >
                    `;
                }

                return `
                    <div class="field ${longText ? "full" : ""}">
                        <label for="field-${index}">
                            ${escapeHtml(nice(key))}
                        </label>
                        ${control}
                    </div>
                `;
            }).join("");
        }

        $("record-modal").hidden = false;
    }

    function closeEditor() {
        $("record-modal").hidden = true;
        state.editing = null;
    }

    // -----------------------------------------------------
    // CREATE AND UPDATE
    // -----------------------------------------------------

    async function saveRecord(event) {
        event.preventDefault();

        
        if (state.key === "employees") {
            const form = $("record-form");

            if (!form.reportValidity()) return;

            const formData = new FormData(form);
            const payload = Object.fromEntries(formData.entries());

            payload.salary = Number(payload.salary);
            payload.gender = payload.gender || null;
            payload.address = payload.address || null;

            $("save-record").disabled = true;
            $("save-record").textContent = "Creating...";
            $("form-error").hidden = true;

            try {
                const result = await request(`${API_BASE}/api/admin/employees`, {
                    method: "POST",
                    body: JSON.stringify(payload)
                });

                const data = result?.data ?? result;

                closeEditor();

                // Show the initial credentials once to the administrator.
                if (data.username && data.initial_password) {
                    alert(
                        "Employee created successfully.\n\n" +
                        "Employee ID: " + (data.employee_id || "Generated") + "\n" +
                        "Username: " + data.username + "\n" +
                        "Initial password: " + data.initial_password + "\n\n" +
                        "Share these credentials securely."
                    );
                } else {
                    showNotice(
                        result.message || "Employee created successfully.",
                        "success"
                    );
                }

                await selectTable("employees");
            } catch (error) {
                $("form-error").textContent = error.message;
                $("form-error").hidden = false;
            } finally {
                $("save-record").disabled = false;
                $("save-record").textContent = "Save record";
            }

            return;
        }


        const config = ENDPOINTS[state.key];
        const form = $("record-form");
        const payload = {};

        new FormData(form).forEach((value, key) => {
            if (value === "") return;

            if (value === "true" || value === "false") {
                payload[key] = value === "true";
                return;
            }

            const originalValue = state.editing
                ? state.editing[key]
                : undefined;

            if (
                typeof originalValue === "number" &&
                /^-?\d+(\.\d+)?$/.test(value)
            ) {
                payload[key] = Number(value);
            } else {
                payload[key] = value;
            }
        });

        const pk = primaryKey(state.editing);

        const isUpdate = Boolean(state.editing && pk);

        const url = isUpdate
            ? apiUrl(state.key, pk.value)
            : apiUrl(state.key);

        const method = isUpdate ? "PUT" : "POST";

        $("save-record").disabled = true;
        $("save-record").textContent = "Saving...";
        $("form-error").hidden = true;

        try {
            await request(url, {
                method,
                body: JSON.stringify(payload)
            });

            closeEditor();

            showNotice(
                `${config.label} record saved successfully.`,
                "success"
            );

            await selectTable(state.key);

        } catch (error) {
            $("form-error").textContent = error.message;
            $("form-error").hidden = false;
        } finally {
            $("save-record").disabled = false;
            $("save-record").textContent = "Save record";
        }
    }

    // -----------------------------------------------------
    // DELETE
    // -----------------------------------------------------

    async function deleteRecord(record) {
        const config = ENDPOINTS[state.key];
        const pk = primaryKey(record);

        if (!config.editable || !pk) {
            showNotice(
                "This record cannot be deleted through this interface.",
                "error"
            );
            return;
        }

        const confirmed = confirm(
            `Delete ${config.label} record ${pk.value}? This cannot be undone.`
        );

        if (!confirmed) return;

        try {
            await request(apiUrl(state.key, pk.value), {
                method: "DELETE"
            });

            showNotice("Record deleted successfully.", "success");

            await selectTable(state.key);

        } catch (error) {
            showNotice(
                `Delete failed: ${error.message}`,
                "error"
            );
        }
    }

    // -----------------------------------------------------
    // EVENT LISTENERS
    // -----------------------------------------------------

    $("search-input").addEventListener("input", applySearch);

    $("refresh-button").addEventListener("click", () => {
        selectTable(state.key);
    });

    $("clear-search").addEventListener("click", () => {
        $("search-input").value = "";
        applySearch();
    });

    $("add-record").addEventListener("click", () => {
        if (state.key === "employees") {
            openEmployeeEditor();
        } else {
            openEditor();
        }
    });

    $("record-form").addEventListener("submit", saveRecord);

    $("close-modal").addEventListener("click", closeEditor);

    $("cancel-modal").addEventListener("click", closeEditor);

    $("record-modal").addEventListener("click", event => {
        if (event.target === $("record-modal")) {
            closeEditor();
        }
    });

    $("open-sidebar").addEventListener("click", () => {
        $("sidebar").classList.add("open");
    });

    $("close-sidebar").addEventListener("click", () => {
        $("sidebar").classList.remove("open");
    });

    $("logout-button").addEventListener("click", () => {
        if (window.auth && typeof window.auth.logout === "function") {
            window.auth.logout();
        } else {
            window.location.href = "../index.html";
        }
    });

    // When the sidebar URL fragment changes, load the correct table.
    window.addEventListener("hashchange", () => {
        const key = location.hash.slice(1);

        if (ENDPOINTS[key] && key !== state.key) {
            selectTable(key);
        }
    });

    // -----------------------------------------------------
    // INITIALIZATION
    // -----------------------------------------------------

    renderNavigation();

    const initialKey = location.hash.slice(1);

    selectTable(
        ENDPOINTS[initialKey] ? initialKey : "branches"
    );
})();