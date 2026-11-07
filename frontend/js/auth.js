/**
 * ==============================================================================
 * AUTHENTICATION & SESSION MANAGEMENT - Banking Management System
 * ==============================================================================
 * 
 * RESPONSIBILITIES:
 * 1. Manage user session strictly using browser `sessionStorage`.
 * 2. Handle login flow, session storage, and role-based redirects.
 * 3. Protect dashboard pages (kick unauthenticated or wrong-role users to login).
 * 4. Redirect already-logged-in users from login page to their dashboard.
 * 5. Handle clean logout.
 * ==============================================================================
 */

// Storage key for the authenticated user session object
const SESSION_KEY = 'bank_current_user';

/**
 * Helper to determine relative path prefix depending on current page location
 * (Root level vs subdirectories like /customer/, /employee/, /admin/)
 */
function getPathPrefix() {
  const path = window.location.pathname.replace(/\\/g, '/');
  if (path.includes('/customer/') || path.includes('/employee/') || path.includes('/admin/')) {
    return '../';
  }
  return './';
}

const auth = {
  /**
   * Get the currently logged-in user from sessionStorage
   * @returns {Object|null}
   */
  getCurrentUser: function() {
    try {
      const userJson = sessionStorage.getItem(SESSION_KEY);
      return userJson ? JSON.parse(userJson) : null;
    } catch (err) {
      console.error("Error reading session user:", err);
      return null;
    }
  },

  /**
   * Save user session to sessionStorage
   * @param {Object} userData
   */
  setCurrentUser: function(userData) {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(userData));
  },

  /**
   * Clear user session from sessionStorage
   */
  clearCurrentUser: function() {
    sessionStorage.removeItem(SESSION_KEY);
    if (window.api && typeof window.api.clearToken === 'function') window.api.clearToken();
  },

  /**
   * Get target dashboard URL for a specific role
   * @param {string} role - 'customer' | 'employee' | 'admin'
   * @returns {string}
   */
  getDashboardUrlForRole: function(role) {
    const prefix = getPathPrefix();
    const cleanRole = (role || '').toLowerCase();
    switch (cleanRole) {
      case 'customer':
        return `${prefix}customer/dashboard.html`;
      case 'employee':
        return `${prefix}employee/dashboard.html`;
      case 'admin':
        return `${prefix}admin/dashboard.html`;
      default:
        return `${prefix}index.html`;
    }
  },

  /**
   * Perform login through api.login, update session, and handle redirection
   * @param {string} username
   * @param {string} password
   * @param {string} role - 'customer' | 'employee' | 'admin'
   * @returns {Promise<Object>} API response object
   */
  login: async function(username, password, role) {
    // 1. Delegate verification to the API layer
    const result = await window.api.login(username, password, role);

    if (result.success && result.data) {
      // 2. Persist in sessionStorage
      auth.setCurrentUser(result.data);
    }

    return result;
  },

  /**
   * Perform logout: wipe session and redirect to login page
   */
  logout: function() {
    auth.clearCurrentUser();
    const prefix = getPathPrefix();
    window.location.href = `${prefix}index.html`;
  },

  /**
   * Page Protection Guard:
   * Call this at the start of every dashboard page.
   * If not logged in, or logged into the wrong role, redirect immediately.
   * @param {string} requiredRole - 'customer' | 'employee' | 'admin'
   * @returns {Object|null} The validated user object
   */
  requireAuth: function(requiredRole) {
    const user = auth.getCurrentUser();
    const prefix = getPathPrefix();

    // Check 1: User must be logged in
    if (!user) {
      console.warn("Unauthenticated access attempt. Redirecting to login...");
      window.location.href = `${prefix}index.html`;
      return null;
    }

    // Check 2: Role must match the required dashboard role
    if (!user.Role || user.Role.toLowerCase() !== requiredRole.toLowerCase()) {
      console.warn(`Role mismatch! Current user is ${user.Role}, page requires ${requiredRole}. Redirecting...`);
      window.location.href = auth.getDashboardUrlForRole(user.Role);
      return null;
    }

    return user;
  },

  /**
   * Login Page Guard:
   * If user visits login page while already authenticated, send them to their dashboard.
   */
  redirectIfLoggedIn: function() {
    const user = auth.getCurrentUser();
    if (user && user.Role) {
      console.info("User already logged in. Redirecting to dashboard...");
      window.location.href = auth.getDashboardUrlForRole(user.Role);
    }
  }
};

// Expose auth to window
window.auth = auth;
