// hooks/use_permissions.js
// Returns permission flags for the current user role.
// No import/export — globals only.

function usePermissions(resource) {
  var role = window.currentUserRole || 'user';

  var canRead = Permissions.can('read', resource || 'default');
  var canWrite = Permissions.can('write', resource || 'default');
  var canDelete = Permissions.can('delete', resource || 'default');
  var isAdmin = Permissions.isAdmin();
  var isModerator = Permissions.isModerator();

  return {
    canRead: canRead,
    canWrite: canWrite,
    canDelete: canDelete,
    isAdmin: isAdmin,
    isModerator: isModerator,
    role: role,
  };
}
