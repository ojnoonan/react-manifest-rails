var AdminUsersIndex = function() {
  var e = React.createElement;

  var _selectAll = React.useState(false);
  var selectAll  = _selectAll[0];
  var setSelectAll = _selectAll[1];

  var users = [
    { id: 1, name: 'Priya Sharma',    email: 'priya@acme.com',      role: 'admin',     status: 'active',    lastLogin: new Date(Date.now() - 10 * 60 * 1000).toISOString() },
    { id: 2, name: 'Marcus Webb',     email: 'marcus@globex.io',    role: 'user',      status: 'active',    lastLogin: new Date(Date.now() - 2  * 60 * 60 * 1000).toISOString() },
    { id: 3, name: 'Elena Voronova',  email: 'elena@initech.com',   role: 'user',      status: 'suspended', lastLogin: new Date(Date.now() - 7  * 24 * 60 * 60 * 1000).toISOString() },
    { id: 4, name: 'James Okafor',    email: 'james@umbrella.co',   role: 'moderator', status: 'active',    lastLogin: new Date(Date.now() - 1  * 24 * 60 * 60 * 1000).toISOString() },
    { id: 5, name: 'Lin Tao',         email: 'lin@saarlane.dev',    role: 'user',      status: 'pending',   lastLogin: null },
  ];

  var roleColors   = { admin: 'red',    moderator: 'yellow', user: 'gray' };
  var statusColors = { active: 'green', suspended: 'red',    pending: 'yellow' };

  var columns = [
    { key: 'name',  label: 'Name' },
    { key: 'email', label: 'Email' },
    {
      key: 'role',
      label: 'Role',
      render: function(val) { return e(Badge, { color: roleColors[val] || 'gray' }, val); },
    },
    {
      key: 'status',
      label: 'Status',
      render: function(val) { return e(Badge, { color: statusColors[val] || 'gray' }, val); },
    },
    {
      key: 'lastLogin',
      label: 'Last Login',
      render: function(val) { return val ? formatRelative(val) : e('span', { className: 'text-gray-400' }, 'Never'); },
    },
    {
      key: 'id',
      label: 'Actions',
      render: function(id) {
        return e('div', { className: 'flex items-center gap-2' },
          e(IconButton, { icon: '✏️', title: 'Edit',        onClick: function() {} }),
          e(IconButton, { icon: '👤', title: 'Impersonate', onClick: function() {} }),
          e(DangerButton, { onClick: function() {} }, 'Suspend')
        );
      },
    },
  ];

  return e('div', { className: 'p-6 max-w-6xl mx-auto' },

    e('div', { className: 'flex items-center justify-between mb-4' },
      e('div', null,
        e(PageHeader, { title: 'User Management' }),
        e('p', { className: 'text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded px-3 py-1 inline-block mt-1' },
          '🔐 Admin View — showing all users with full controls'
        )
      ),
      e(PrimaryButton, { onClick: function() {} }, 'Add User')
    ),

    e('div', { className: 'flex items-center gap-4 mb-4 bg-gray-50 border border-gray-200 rounded-lg px-4 py-3' },
      e(CheckboxInput, {
        id: 'select-all',
        label: 'Select all',
        checked: selectAll,
        onChange: function(ev) { setSelectAll(ev.target.checked); },
      }),
      e(DangerButton,  { onClick: function() {} }, 'Suspend Selected'),
      e(LinkButton,    { onClick: function() {} }, 'Export')
    ),

    e(DataTable, {
      columns: columns,
      rows: users,
      emptyMessage: 'No users found.',
    })
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'AdminUsersIndex') {
    ReactDOM.createRoot(container).render(React.createElement(AdminUsersIndex));
  }
});
