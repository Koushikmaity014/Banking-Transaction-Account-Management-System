/**
 * ==============================================================================
 * UI HELPERS & SHARED COMPONENTS - Banking Management System
 * ==============================================================================
 * 
 * RESPONSIBILITIES:
 * 1. Global "Coming Soon" toast handler via single event listener on `[data-soon]`.
 * 2. Modern floating Toast notifications system.
 * 3. Indian Currency and Date formatting utilities.
 * 4. Responsive Mobile Sidebar slide-in and backdrop management.
 * 5. Interactive Account Balance show/hide toggles.
 * 6. Topbar initialization (greetings, badges, initials, logout binding).
 * ==============================================================================
 */

const ui = {

  // ============================================================================
  // 1. TOAST NOTIFICATION SYSTEM
  // ============================================================================

  /**
   * Initialize or get the global toast container in the DOM
   */
  getToastContainer: function() {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }
    return container;
  },

  /**
   * Display a floating toast notification
   * @param {string} message - Text or HTML message
   * @param {string} type - 'info' | 'success' | 'warning' | 'error'
   * @param {number} duration - Milliseconds to show (default 3200ms)
   */
  showToast: function(message, type = 'info', duration = 3200) {
    const container = ui.getToastContainer();

    const toast = document.createElement('div');
    toast.className = `toast-card toast-${type}`;

    let iconClass = 'fa-circle-info';
    if (type === 'success') iconClass = 'fa-circle-check';
    if (type === 'warning') iconClass = 'fa-triangle-exclamation';
    if (type === 'error') iconClass = 'fa-circle-exclamation';

    toast.innerHTML = `
      <div class="toast-content">
        <i class="fa-solid ${iconClass} toast-icon"></i>
        <span class="toast-message">${message}</span>
      </div>
      <button type="button" class="toast-close" aria-label="Close notification">&times;</button>
    `;

    // Close button handler
    const closeBtn = toast.querySelector('.toast-close');
    closeBtn.addEventListener('click', () => {
      ui.dismissToast(toast);
    });

    container.appendChild(toast);

    // Trigger enter animation
    requestAnimationFrame(() => {
      toast.classList.add('toast-visible');
    });

    // Auto dismiss timer
    const timer = setTimeout(() => {
      ui.dismissToast(toast);
    }, duration);

    toast._timer = timer;
  },

  /**
   * Gracefully dismiss and remove a toast card
   */
  dismissToast: function(toast) {
    if (!toast || toast._dismissing) return;
    toast._dismissing = true;
    if (toast._timer) clearTimeout(toast._timer);

    toast.classList.remove('toast-visible');
    toast.classList.add('toast-hiding');

    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, 280);
  },

  // ============================================================================
  // 2. DATA FORMATTING UTILITIES
  // ============================================================================

  /**
   * Format numbers into Indian Rupees standard: ₹1,25,000.00
   * @param {number} amount
   * @param {boolean} hideDecimals
   * @returns {string}
   */
  formatCurrency: function(amount, hideDecimals = false) {
    const num = Number(amount) || 0;
    return num.toLocaleString('en-IN', {
      style: 'currency',
      currency: 'INR',
      minimumFractionDigits: hideDecimals ? 0 : 2,
      maximumFractionDigits: hideDecimals ? 0 : 2
    });
  },

  /**
   * Format date string to Indian banking standard: "15 Oct 2026" or "15 Oct 2026, 04:30 PM"
   * @param {string} dateString
   * @param {boolean} includeTime
   * @returns {string}
   */
  formatDate: function(dateString, includeTime = false) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString.replace(' ', 'T'));
    if (isNaN(date.getTime())) return dateString;

    const options = {
      day: '2-digit',
      month: 'short',
      year: 'numeric'
    };

    if (includeTime) {
      options.hour = '2-digit',
      options.minute = '2-digit',
      options.hour12 = true;
    }

    return date.toLocaleDateString('en-IN', options);
  },

  /**
   * Mask account number: "XXXX4521" or "•••• •••• 4521"
   * @param {string} accNo
   * @returns {string}
   */
  maskAccountNumber: function(accNo) {
    if (!accNo) return '••••';
    const str = String(accNo);
    const last4 = str.slice(-4);
    return `XXXX •••• ${last4}`;
  },

  /**
   * Generate colored HTML badge for various database statuses
   * @param {string} status
   * @returns {string} HTML string
   */
  getStatusBadge: function(status) {
    const s = (status || '').toLowerCase();
    let badgeClass = 'badge-secondary';

    if (['active', 'completed', 'approved'].includes(s)) {
      badgeClass = 'badge-success';
    } else if (['pending', 'in review', 'processing'].includes(s)) {
      badgeClass = 'badge-warning';
    } else if (['locked', 'failed', 'rejected', 'disabled'].includes(s)) {
      badgeClass = 'badge-danger';
    } else if (['frozen', 'closed'].includes(s)) {
      badgeClass = 'badge-neutral';
    }

    return `<span class="badge ${badgeClass}">${status}</span>`;
  },

  // ============================================================================
  // 3. COMING SOON EVENT LISTENER
  // ============================================================================

  /**
   * Global event delegation handler for all [data-soon] elements.
   * If an element has data-soon="Transfer Money", clicking it displays:
   * "🚧 Transfer Money is coming soon."
   */
  initComingSoonHandler: function() {
    document.addEventListener('click', (event) => {
      // Traverse up to find element with [data-soon]
      const soonEl = event.target.closest('[data-soon]');
      if (!soonEl) return;

      // Prevent default navigation / submission
      event.preventDefault();
      event.stopPropagation();

      const featureName = soonEl.getAttribute('data-soon');
      if (featureName && featureName.trim() !== '') {
        ui.showToast(`🚧 ${featureName} is coming soon.`, 'info');
      } else {
        ui.showToast(`🚧 This feature is coming soon.`, 'info');
      }
    });
  },

  // ============================================================================
  // 4. MOBILE SIDEBAR MANAGEMENT
  // ============================================================================

  /**
   * Wire up the mobile hamburger toggle, close button, and backdrop overlay
   */
  initSidebar: function() {
    const sidebar = document.querySelector('.sidebar');
    const toggleBtn = document.querySelector('#sidebar-toggle-btn');
    const closeBtn = document.querySelector('#sidebar-close-btn');

    if (!sidebar) return;

    // Create backdrop overlay if not already present
    let overlay = document.querySelector('.sidebar-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.className = 'sidebar-overlay';
      document.body.appendChild(overlay);
    }

    const openSidebar = () => {
      sidebar.classList.add('sidebar-open');
      overlay.classList.add('active');
      document.body.classList.add('no-scroll');
    };

    const closeSidebar = () => {
      sidebar.classList.remove('sidebar-open');
      overlay.classList.remove('active');
      document.body.classList.remove('no-scroll');
    };

    if (toggleBtn) {
      toggleBtn.addEventListener('click', openSidebar);
    }

    if (closeBtn) {
      closeBtn.addEventListener('click', closeSidebar);
    }

    overlay.addEventListener('click', closeSidebar);
  },

  // ============================================================================
  // 5. ACCOUNT BALANCE SHOW / HIDE TOGGLE
  // ============================================================================

  /**
   * Wire up account balance eye-toggles that switch between hidden "₹••••••"
   * and the formatted numeric balance.
   */
  initBalanceToggles: function() {
    document.addEventListener('click', (event) => {
      const toggleBtn = event.target.closest('[data-balance-toggle]');
      if (!toggleBtn) return;

      event.preventDefault();
      const targetId = toggleBtn.getAttribute('data-balance-toggle');
      const balanceSpan = document.getElementById(targetId);
      const icon = toggleBtn.querySelector('i');

      if (!balanceSpan) return;

      const isHidden = balanceSpan.getAttribute('data-hidden') === 'true';
      const rawAmount = balanceSpan.getAttribute('data-amount');

      if (isHidden) {
        // Show actual balance
        balanceSpan.textContent = ui.formatCurrency(rawAmount);
        balanceSpan.setAttribute('data-hidden', 'false');
        if (icon) {
          icon.classList.remove('fa-eye');
          icon.classList.add('fa-eye-slash');
        }
        toggleBtn.setAttribute('title', 'Hide balance');
      } else {
        // Mask balance
        balanceSpan.textContent = '₹ ••••••••';
        balanceSpan.setAttribute('data-hidden', 'true');
        if (icon) {
          icon.classList.remove('fa-eye-slash');
          icon.classList.add('fa-eye');
        }
        toggleBtn.setAttribute('title', 'Show balance');
      }
    });
  },

  // ============================================================================
  // 6. TOPBAR GREETING & USER PROFILE INITIALIZATION
  // ============================================================================

  /**
   * Populate topbar greeting, role badge, initials avatar, and bind logout
   * @param {Object} user - The current authenticated user session
   */
  initTopBar: function(user) {
    if (!user) return;

    // 1. Time-based greeting (Morning / Afternoon / Evening)
    const hour = new Date().getHours();
    let timeGreeting = "Good Morning";
    if (hour >= 12 && hour < 17) timeGreeting = "Good Afternoon";
    else if (hour >= 17) timeGreeting = "Good Evening";

    const greetingName = user.FirstName || user.DisplayName || user.Username;

    // Populate Greeting text
    const greetingEl = document.getElementById('user-greeting');
    if (greetingEl) {
      greetingEl.innerHTML = `${timeGreeting}, <span class="greeting-highlight">${greetingName}</span>`;
    }

    // Populate Last Login text
    const lastLoginEl = document.getElementById('user-last-login');
    if (lastLoginEl && user.Last_Login) {
      lastLoginEl.textContent = `Last login: ${ui.formatDate(user.Last_Login, true)}`;
    }

    // Populate Initials Avatar
    const avatarEl = document.getElementById('user-avatar');
    if (avatarEl) {
      avatarEl.textContent = user.Initials || greetingName.substring(0, 2).toUpperCase();
    }

    // Populate Role Badge
    const roleBadgeEl = document.getElementById('user-role-badge');
    if (roleBadgeEl) {
      const roleCapitalized = user.Role.charAt(0).toUpperCase() + user.Role.slice(1);
      roleBadgeEl.textContent = roleCapitalized;
      roleBadgeEl.className = `role-badge role-${user.Role.toLowerCase()}`;
    }

    // Bind Logout button
    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', (e) => {
        e.preventDefault();
        ui.showToast("Logging out...", "info");
        setTimeout(() => {
          window.auth.logout();
        }, 300);
      });
    }
  },

  // ============================================================================
  // 7. INITIALIZE ALL SHARED UI HELPERS
  // ============================================================================
  init: function() {
    ui.initComingSoonHandler();
    ui.initSidebar();
    ui.initBalanceToggles();
  }
};

// Expose ui to window and auto-initialize on DOMContentLoaded
window.ui = ui;

document.addEventListener('DOMContentLoaded', () => {
  ui.init();
});
