const AdminUsersIndex = () => {
  const { useState } = React;
  const _selectAll = useState(false);
  const selectAll  = _selectAll[0];
  const setSelectAll = _selectAll[1];

  const users = [
    { id: 1, name: 'Priya Sharma',    email: 'priya@acme.com',      role: 'admin',     status: 'active',    lastLogin: new Date(Date.now() - 10 * 60 * 1000).toISOString() },
    { id: 2, name: 'Marcus Webb',     email: 'marcus@globex.io',    role: 'user',      status: 'active',    lastLogin: new Date(Date.now() - 2  * 60 * 60 * 1000).toISOString() },
    { id: 3, name: 'Elena Voronova',  email: 'elena@initech.com',   role: 'user',      status: 'suspended', lastLogin: new Date(Date.now() - 7  * 24 * 60 * 60 * 1000).toISOString() },
    { id: 4, name: 'James Okafor',    email: 'james@umbrella.co',   role: 'moderator', status: 'active',    lastLogin: new Date(Date.now() - 1  * 24 * 60 * 60 * 1000).toISOString() },
    { id: 5, name: 'Lin Tao',         email: 'lin@saarlane.dev',    role: 'user',      status: 'pending',   lastLogin: null },
  ];

  const roleColors   = { admin: 'red',    moderator: 'yellow', user: 'gray' };
  const statusColors = { active: 'green', suspended: 'red',    pending: 'yellow' };

  const columns = [
    { key: 'name',  label: 'Name' },
    { key: 'email', label: 'Email' },
    {
      key: 'role',
      label: 'Role',
      render: function(val) { return React.createElement(Badge, { color: roleColors[val] || 'gray' }, val); },
    },
    {
      key: 'status',
      label: 'Status',
      render: function(val) { return React.createElement(Badge, { color: statusColors[val] || 'gray' }, val); },
    },
    {
      key: 'lastLogin',
      label: 'Last Login',
      render: function(val) { return val ? formatRelative(val) : React.createElement('span', { className: 'text-gray-400' }, 'Never'); },
    },
    {
      key: 'id',
      label: 'Actions',
      render: function(id) {
        return React.createElement('div', { className: 'flex items-center gap-2' },
          React.createElement(IconButton, { icon: '✏️', title: 'Edit',        onClick: function() {} }),
          React.createElement(IconButton, { icon: '👤', title: 'Impersonate', onClick: function() {} }),
          React.createElement(DangerButton, { onClick: function() {} }, 'Suspend')
        );
      },
    },
  ];

  return React.createElement('div', { className: 'p-6 max-w-6xl mx-auto' },

    React.createElement('div', { className: 'flex items-center justify-between mb-4' },
      React.createElement('div', null,
        React.createElement(PageHeader, { title: 'User Management' }),
        React.createElement('p', { className: 'text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded px-3 py-1 inline-block mt-1' },
          '🔐 Admin View — showing all users with full controls'
        )
      ),
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Add User')
    ),

    React.createElement('div', { className: 'flex items-center gap-4 mb-4 bg-gray-50 border border-gray-200 rounded-lg px-4 py-3' },
      React.createElement(CheckboxInput, {
        id: 'select-all',
        label: 'Select all',
        checked: selectAll,
        onChange: function(ev) { setSelectAll(ev.target.checked); },
      }),
      React.createElement(DangerButton,  { onClick: function() {} }, 'Suspend Selected'),
      React.createElement(LinkButton,    { onClick: function() {} }, 'Export')
    ),

    React.createElement(DataTable, {
      columns: columns,
      rows: users,
      emptyMessage: 'No users found.',
    })
  );
};

window.AdminUsersIndex = AdminUsersIndex;
