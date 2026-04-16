// lib/permissions.js
// Role-based permission checks. Uses window.currentUserRole (default: 'user').
// No import/export — globals only.

const Permissions = {
  // Role hierarchy: admin > moderator > user > guest
  _roleLevel: function(role) {
    return { admin: 3, moderator: 2, user: 1, guest: 0 }[role] || 0;
  },

  _currentRole: function() {
    return window.currentUserRole || 'user';
  },

  // Returns true if current user role meets the required level
  _atLeast: function(requiredRole) {
    return Permissions._roleLevel(Permissions._currentRole()) >= Permissions._roleLevel(requiredRole);
  },

  can: function(action, resource) {
    const role = Permissions._currentRole();
    if (role === 'admin') return true;
    const rules = {
      read:     'user',
      write:    'user',
      delete:   'moderator',
      moderate: 'moderator',
      admin:    'admin',
    };
    const required = rules[action] || 'admin';
    return Permissions._atLeast(required);
  },

  isAdmin: function() {
    return Permissions._currentRole() === 'admin';
  },

  isModerator: function() {
    return Permissions._atLeast('moderator');
  },

  isUser: function() {
    return Permissions._atLeast('user');
  },

  currentRole: function() {
    return Permissions._currentRole();
  },
};
