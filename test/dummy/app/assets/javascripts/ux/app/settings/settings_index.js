var SettingsShow = function() {
  var e = React.createElement;

  var _activeTab = React.useState('profile');
  var activeTab = _activeTab[0];
  var setActiveTab = _activeTab[1];

  var tabs = [
    { id: 'profile',       label: 'Profile' },
    { id: 'security',      label: 'Security' },
    { id: 'notifications', label: 'Notifications' },
    { id: 'billing',       label: 'Billing' },
  ];

  // Profile tab state
  var _firstName      = React.useState('Sarah');
  var _lastName       = React.useState('Chen');
  var _email          = React.useState('sarah@example.com');
  var _jobTitle       = React.useState('Product Manager');
  var _department     = React.useState('Product');
  var _timezone       = React.useState('America/Los_Angeles');

  var firstName      = _firstName[0];  var setFirstName      = _firstName[1];
  var lastName       = _lastName[0];   var setLastName       = _lastName[1];
  var profileEmail   = _email[0];      var setProfileEmail   = _email[1];
  var jobTitle       = _jobTitle[0];   var setJobTitle       = _jobTitle[1];
  var department     = _department[0]; var setDepartment     = _department[1];
  var timezone       = _timezone[0];   var setTimezone       = _timezone[1];

  // Security tab state
  var _currentPw  = React.useState('');
  var _newPw      = React.useState('');
  var _confirmPw  = React.useState('');
  var _twoFa      = React.useState(false);
  var currentPw   = _currentPw[0];  var setCurrentPw  = _currentPw[1];
  var newPw       = _newPw[0];      var setNewPw      = _newPw[1];
  var confirmPw   = _confirmPw[0];  var setConfirmPw  = _confirmPw[1];
  var twoFa       = _twoFa[0];      var setTwoFa      = _twoFa[1];

  // Notification prefs
  var _emailOrders    = React.useState(true);
  var _emailPayments  = React.useState(true);
  var _emailMarketing = React.useState(false);
  var _smsOrders      = React.useState(true);
  var _smsPayments    = React.useState(false);
  var _browserAll     = React.useState(true);

  var emailOrders    = _emailOrders[0];    var setEmailOrders    = _emailOrders[1];
  var emailPayments  = _emailPayments[0];  var setEmailPayments  = _emailPayments[1];
  var emailMarketing = _emailMarketing[0]; var setEmailMarketing = _emailMarketing[1];
  var smsOrders      = _smsOrders[0];      var setSmsOrders      = _smsOrders[1];
  var smsPayments    = _smsPayments[0];    var setSmsPayments    = _smsPayments[1];
  var browserAll     = _browserAll[0];     var setBrowserAll     = _browserAll[1];

  var tabBar = e('div', { className: 'flex border-b border-gray-200 mb-8' },
    tabs.map(function(tab) {
      return e('button', {
        key: tab.id,
        onClick: function() { setActiveTab(tab.id); },
        className: [
          'px-5 py-3 text-sm font-medium border-b-2 -mb-px transition-colors',
          activeTab === tab.id
            ? 'border-blue-600 text-blue-600'
            : 'border-transparent text-gray-500 hover:text-gray-700',
        ].join(' '),
      }, tab.label);
    })
  );

  var profileTab = e('div', { className: 'max-w-lg space-y-4' },
    e('div', { className: 'grid grid-cols-2 gap-4' },
      e(TextInput, { id: 'first-name', label: 'First Name', value: firstName, onChange: function(ev) { setFirstName(ev.target.value); } }),
      e(TextInput, { id: 'last-name',  label: 'Last Name',  value: lastName,  onChange: function(ev) { setLastName(ev.target.value); } })
    ),
    e(TextInput, { id: 'profile-email', label: 'Email', value: profileEmail, onChange: function(ev) { setProfileEmail(ev.target.value); } }),
    e(TextInput, { id: 'job-title', label: 'Job Title', value: jobTitle, onChange: function(ev) { setJobTitle(ev.target.value); } }),
    e(TextInput, { id: 'department', label: 'Department', value: department, onChange: function(ev) { setDepartment(ev.target.value); } }),
    e(SelectInput, {
      id: 'timezone',
      label: 'Timezone',
      value: timezone,
      onChange: function(ev) { setTimezone(ev.target.value); },
      options: [
        { value: 'America/Los_Angeles', label: 'Pacific Time (PT)' },
        { value: 'America/Denver',      label: 'Mountain Time (MT)' },
        { value: 'America/Chicago',     label: 'Central Time (CT)' },
        { value: 'America/New_York',    label: 'Eastern Time (ET)' },
        { value: 'UTC',                 label: 'UTC' },
      ],
    }),
    e('div', { className: 'pt-2' },
      e(PrimaryButton, { onClick: function() {} }, 'Save Changes')
    )
  );

  var securityTab = e('div', { className: 'max-w-lg' },
    e('h3', { className: 'font-semibold text-gray-800 mb-4' }, 'Change Password'),
    e('div', { className: 'space-y-4 mb-8' },
      e(TextInput, { id: 'current-pw', label: 'Current Password', type: 'password', value: currentPw, onChange: function(ev) { setCurrentPw(ev.target.value); } }),
      e(TextInput, { id: 'new-pw',     label: 'New Password',     type: 'password', value: newPw,     onChange: function(ev) { setNewPw(ev.target.value); } }),
      e(TextInput, { id: 'confirm-pw', label: 'Confirm New Password', type: 'password', value: confirmPw, onChange: function(ev) { setConfirmPw(ev.target.value); } }),
      e(PrimaryButton, { onClick: function() {} }, 'Update Password')
    ),
    e('hr', { className: 'border-gray-200 mb-6' }),
    e('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Two-Factor Authentication'),
    e('p', { className: 'text-sm text-gray-600 mb-4' }, 'Add an extra layer of security to your account by enabling 2FA.'),
    e(CheckboxInput, {
      id: 'two-fa',
      label: 'Enable two-factor authentication',
      checked: twoFa,
      onChange: function(ev) { setTwoFa(ev.target.checked); },
    })
  );

  var notificationsTab = e('div', { className: 'max-w-lg' },
    e('div', { className: 'mb-6' },
      e('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Email Notifications'),
      e('div', { className: 'space-y-2' },
        e(CheckboxInput, { id: 'email-orders',    label: 'Order updates',   checked: emailOrders,    onChange: function(ev) { setEmailOrders(ev.target.checked); } }),
        e(CheckboxInput, { id: 'email-payments',  label: 'Payment receipts', checked: emailPayments,  onChange: function(ev) { setEmailPayments(ev.target.checked); } }),
        e(CheckboxInput, { id: 'email-marketing', label: 'Marketing & promotions', checked: emailMarketing, onChange: function(ev) { setEmailMarketing(ev.target.checked); } })
      )
    ),
    e('div', { className: 'mb-6' },
      e('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'SMS Notifications'),
      e('div', { className: 'space-y-2' },
        e(CheckboxInput, { id: 'sms-orders',   label: 'Order shipped / delivered', checked: smsOrders,   onChange: function(ev) { setSmsOrders(ev.target.checked); } }),
        e(CheckboxInput, { id: 'sms-payments', label: 'Payment confirmations',     checked: smsPayments, onChange: function(ev) { setSmsPayments(ev.target.checked); } })
      )
    ),
    e('div', { className: 'mb-6' },
      e('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Browser Notifications'),
      e(CheckboxInput, { id: 'browser-all', label: 'Enable browser push notifications', checked: browserAll, onChange: function(ev) { setBrowserAll(ev.target.checked); } })
    ),
    e(PrimaryButton, { onClick: function() {} }, 'Save Preferences')
  );

  var billingTab = e('div', { className: 'max-w-lg' },
    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      e('div', { className: 'flex items-center justify-between mb-2' },
        e('h3', { className: 'text-lg font-semibold text-gray-900' }, 'Pro'),
        e(Badge, { color: 'blue' }, 'Current Plan')
      ),
      e('p', { className: 'text-3xl font-bold text-gray-900 mb-1' }, '$49'),
      e('p', { className: 'text-sm text-gray-500 mb-4' }, 'per month, billed monthly'),
      e('ul', { className: 'space-y-1 text-sm text-gray-700 mb-6' },
        e('li', null, '✓ Unlimited orders'),
        e('li', null, '✓ Up to 10 team members'),
        e('li', null, '✓ Advanced reports'),
        e('li', null, '✓ Priority support')
      ),
      e(PrimaryButton, { onClick: function() {} }, 'Upgrade to Enterprise')
    ),
    e('p', { className: 'text-sm text-gray-500' },
      'Next billing date: May 13, 2026 — ',
      e(LinkButton, { onClick: function() {} }, 'View invoices')
    )
  );

  var activeContent = {
    profile:       profileTab,
    security:      securityTab,
    notifications: notificationsTab,
    billing:       billingTab,
  }[activeTab];

  return e('div', { className: 'p-6 max-w-4xl mx-auto' },
    e(PageHeader, { title: 'Settings' }),
    tabBar,
    activeContent
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'SettingsShow') {
    ReactDOM.createRoot(container).render(React.createElement(SettingsShow));
  }
});
