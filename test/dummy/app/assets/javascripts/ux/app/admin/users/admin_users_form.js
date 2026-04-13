var AdminUsersForm = function() {
  var e = React.createElement;

  var _firstName = React.useState('Marcus');
  var _lastName  = React.useState('Webb');
  var _email     = React.useState('marcus@globex.io');
  var _phone     = React.useState('+1 (415) 555-0192');
  var _role      = React.useState('user');
  var _status    = React.useState('active');
  var _notes     = React.useState('');

  var firstName = _firstName[0]; var setFirstName = _firstName[1];
  var lastName  = _lastName[0];  var setLastName  = _lastName[1];
  var email     = _email[0];     var setEmail     = _email[1];
  var phone     = _phone[0];     var setPhone     = _phone[1];
  var role      = _role[0];      var setRole      = _role[1];
  var status    = _status[0];    var setStatus    = _status[1];
  var notes     = _notes[0];     var setNotes     = _notes[1];

  var _permProducts = React.useState(false);
  var _permOrders   = React.useState(true);
  var _permReports  = React.useState(false);
  var _permUsers    = React.useState(false);

  var permProducts = _permProducts[0]; var setPermProducts = _permProducts[1];
  var permOrders   = _permOrders[0];   var setPermOrders   = _permOrders[1];
  var permReports  = _permReports[0];  var setPermReports  = _permReports[1];
  var permUsers    = _permUsers[0];    var setPermUsers    = _permUsers[1];

  return e('div', { className: 'p-6 max-w-2xl mx-auto' },

    e(Breadcrumbs, {
      items: [
        { label: 'Admin', href: '/admin' },
        { label: 'Users', href: '/admin/users' },
        { label: 'Edit' },
      ],
    }),

    e(PageHeader, { title: 'Edit User' }),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      e('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Account Details'),
      e('div', { className: 'grid grid-cols-2 gap-4 mb-4' },
        e(TextInput, { id: 'first-name', label: 'First Name', value: firstName, onChange: function(ev) { setFirstName(ev.target.value); } }),
        e(TextInput, { id: 'last-name',  label: 'Last Name',  value: lastName,  onChange: function(ev) { setLastName(ev.target.value); } })
      ),
      e('div', { className: 'space-y-4' },
        e(TextInput, { id: 'admin-email', label: 'Email', type: 'email', value: email, onChange: function(ev) { setEmail(ev.target.value); } }),
        e(TextInput, { id: 'admin-phone', label: 'Phone', value: phone, onChange: function(ev) { setPhone(ev.target.value); } }),
        e('div', { className: 'grid grid-cols-2 gap-4' },
          e(SelectInput, {
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
          e(SelectInput, {
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

    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      e('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Permissions'),
      e('div', { className: 'space-y-2' },
        e(CheckboxInput, { id: 'perm-products', label: 'Can manage products', checked: permProducts, onChange: function(ev) { setPermProducts(ev.target.checked); } }),
        e(CheckboxInput, { id: 'perm-orders',   label: 'Can manage orders',   checked: permOrders,   onChange: function(ev) { setPermOrders(ev.target.checked); }   }),
        e(CheckboxInput, { id: 'perm-reports',  label: 'Can view reports',    checked: permReports,  onChange: function(ev) { setPermReports(ev.target.checked); }  }),
        e(CheckboxInput, { id: 'perm-users',    label: 'Can manage users',    checked: permUsers,    onChange: function(ev) { setPermUsers(ev.target.checked); }    })
      )
    ),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      e('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4' }, 'Account Notes'),
      e(TextInput, {
        id: 'admin-notes',
        label: 'Internal notes',
        value: notes,
        onChange: function(ev) { setNotes(ev.target.value); },
        hint: 'Visible to admins only. Describe any special circumstances for this account.',
      })
    ),

    e('div', { className: 'flex gap-3 flex-wrap' },
      e(PrimaryButton, { onClick: function() {} }, 'Save Changes'),
      e(DangerButton,  { onClick: function() {} }, 'Suspend Account'),
      e(LinkButton,    { onClick: function() { window.history.back(); } }, 'Cancel')
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && (container.dataset.component === 'AdminUsersNew' || container.dataset.component === 'AdminUsersEdit')) {
    ReactDOM.createRoot(container).render(React.createElement(AdminUsersForm));
  }
});
