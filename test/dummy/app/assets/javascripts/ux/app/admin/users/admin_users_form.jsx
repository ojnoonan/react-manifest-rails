const AdminUsersForm = () => {
  const { useState } = React;
  const _firstName = useState('Marcus');
  const _lastName  = useState('Webb');
  const _email     = useState('marcus@globex.io');
  const _phone     = useState('+1 (415) 555-0192');
  const _role      = useState('user');
  const _status    = useState('active');
  const _notes     = useState('');

  const firstName = _firstName[0]; const setFirstName = _firstName[1];
  const lastName  = _lastName[0];  const setLastName  = _lastName[1];
  const email     = _email[0];     const setEmail     = _email[1];
  const phone     = _phone[0];     const setPhone     = _phone[1];
  const role      = _role[0];      const setRole      = _role[1];
  const status    = _status[0];    const setStatus    = _status[1];
  const notes     = _notes[0];     const setNotes     = _notes[1];

  const _permProducts = useState(false);
  const _permOrders   = useState(true);
  const _permReports  = useState(false);
  const _permUsers    = useState(false);

  const permProducts = _permProducts[0]; const setPermProducts = _permProducts[1];
  const permOrders   = _permOrders[0];   const setPermOrders   = _permOrders[1];
  const permReports  = _permReports[0];  const setPermReports  = _permReports[1];
  const permUsers    = _permUsers[0];    const setPermUsers    = _permUsers[1];

  return React.createElement('div', { className: 'p-6 max-w-2xl mx-auto' },

    React.createElement(Breadcrumbs, {
      items: [
        { label: 'Admin', href: '/admin' },
        { label: 'Users', href: '/admin/users' },
        { label: 'Edit' },
      ],
    }),

    React.createElement(PageHeader, { title: 'Edit User' }),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      React.createElement('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Account Details'),
      React.createElement('div', { className: 'grid grid-cols-2 gap-4 mb-4' },
        React.createElement(TextInput, { id: 'first-name', label: 'First Name', value: firstName, onChange: function(ev) { setFirstName(ev.target.value); } }),
        React.createElement(TextInput, { id: 'last-name',  label: 'Last Name',  value: lastName,  onChange: function(ev) { setLastName(ev.target.value); } })
      ),
      React.createElement('div', { className: 'space-y-4' },
        React.createElement(TextInput, { id: 'admin-email', label: 'Email', type: 'email', value: email, onChange: function(ev) { setEmail(ev.target.value); } }),
        React.createElement(TextInput, { id: 'admin-phone', label: 'Phone', value: phone, onChange: function(ev) { setPhone(ev.target.value); } }),
        React.createElement('div', { className: 'grid grid-cols-2 gap-4' },
          React.createElement(SelectInput, {
            id: 'admin-role',
            label: 'Role',
            value: role,
            onChange: function(ev) { setRole(ev.target.value); },
            options: [
              { value: 'user',      label: 'User' },
              { value: 'moderator', label: 'Moderator' },
              { value: 'admin',     label: 'Admin' },
            ],
          }),
          React.createElement(SelectInput, {
            id: 'admin-status',
            label: 'Status',
            value: status,
            onChange: function(ev) { setStatus(ev.target.value); },
            options: [
              { value: 'active',    label: 'Active' },
              { value: 'suspended', label: 'Suspended' },
              { value: 'pending',   label: 'Pending' },
            ],
          })
        )
      )
    ),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      React.createElement('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Permissions'),
      React.createElement('div', { className: 'space-y-2' },
        React.createElement(CheckboxInput, { id: 'perm-products', label: 'Can manage products', checked: permProducts, onChange: function(ev) { setPermProducts(ev.target.checked); } }),
        React.createElement(CheckboxInput, { id: 'perm-orders',   label: 'Can manage orders',   checked: permOrders,   onChange: function(ev) { setPermOrders(ev.target.checked); }   }),
        React.createElement(CheckboxInput, { id: 'perm-reports',  label: 'Can view reports',    checked: permReports,  onChange: function(ev) { setPermReports(ev.target.checked); }  }),
        React.createElement(CheckboxInput, { id: 'perm-users',    label: 'Can manage users',    checked: permUsers,    onChange: function(ev) { setPermUsers(ev.target.checked); }    })
      )
    ),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      React.createElement('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Account Notes'),
      React.createElement(TextInput, {
        id: 'admin-notes',
        label: 'Internal notes',
        value: notes,
        onChange: function(ev) { setNotes(ev.target.value); },
        hint: 'Visible to admins only. Describe any special circumstances for this account.',
      })
    ),

    React.createElement('div', { className: 'flex gap-3 flex-wrap' },
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Save Changes'),
      React.createElement(DangerButton,  { onClick: function() {} }, 'Suspend Account'),
      React.createElement(LinkButton,    { onClick: function() { window.history.back(); } }, 'Cancel')
    )
  );
};

window.AdminUsersForm = AdminUsersForm;
