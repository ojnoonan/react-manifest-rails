// hooks/use_permissions.js
// Returns permission flags for the current user role.
// No import/export — globals only.

function usePermissions(resource) {
  const role = window.currentUserRole || 'user';

  const canRead = Permissions.can('read', resource || 'default');
  const canWrite = Permissions.can('write', resource || 'default');
  const canDelete = Permissions.can('delete', resource || 'default');
  const isAdmin = Permissions.isAdmin();
  const isModerator = Permissions.isModerator();

  return {
    canRead: canRead,
    canWrite: canWrite,
    canDelete: canDelete,
    isAdmin: isAdmin,
    isModerator: isModerator,
    role: role,
  };
}
