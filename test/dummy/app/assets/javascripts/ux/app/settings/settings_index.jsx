const SettingsShow = () => {
  const { useState } = React;
  const _activeTab = useState('profile');
  const activeTab = _activeTab[0];
  const setActiveTab = _activeTab[1];

  const tabs = [
    { id: 'profile',       label: 'Profile' },
    { id: 'security',      label: 'Security' },
    { id: 'notifications', label: 'Notifications' },
    { id: 'billing',       label: 'Billing' },
  ];

  // Profile tab state
  const _firstName      = useState('Sarah');
  const _lastName       = useState('Chen');
  const _email          = useState('sarah@example.com');
  const _jobTitle       = useState('Product Manager');
  const _department     = useState('Product');
  const _timezone       = useState('America/Los_Angeles');

  const firstName      = _firstName[0];  const setFirstName      = _firstName[1];
  const lastName       = _lastName[0];   const setLastName       = _lastName[1];
  const profileEmail   = _email[0];      const setProfileEmail   = _email[1];
  const jobTitle       = _jobTitle[0];   const setJobTitle       = _jobTitle[1];
  const department     = _department[0]; const setDepartment     = _department[1];
  const timezone       = _timezone[0];   const setTimezone       = _timezone[1];

  // Security tab state
  const _currentPw  = useState('');
  const _newPw      = useState('');
  const _confirmPw  = useState('');
  const _twoFa      = useState(false);
  const currentPw   = _currentPw[0];  const setCurrentPw  = _currentPw[1];
  const newPw       = _newPw[0];      const setNewPw      = _newPw[1];
  const confirmPw   = _confirmPw[0];  const setConfirmPw  = _confirmPw[1];
  const twoFa       = _twoFa[0];      const setTwoFa      = _twoFa[1];

  // Notification prefs
  const _emailOrders    = useState(true);
  const _emailPayments  = useState(true);
  const _emailMarketing = useState(false);
  const _smsOrders      = useState(true);
  const _smsPayments    = useState(false);
  const _browserAll     = useState(true);

  const emailOrders    = _emailOrders[0];    const setEmailOrders    = _emailOrders[1];
  const emailPayments  = _emailPayments[0];  const setEmailPayments  = _emailPayments[1];
  const emailMarketing = _emailMarketing[0]; const setEmailMarketing = _emailMarketing[1];
  const smsOrders      = _smsOrders[0];      const setSmsOrders      = _smsOrders[1];
  const smsPayments    = _smsPayments[0];    const setSmsPayments    = _smsPayments[1];
  const browserAll     = _browserAll[0];     const setBrowserAll     = _browserAll[1];

  const tabBar = React.createElement('div', { className: 'flex border-b border-gray-200 mb-8' },
    tabs.map(function(tab) {
      return React.createElement('button', {
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

  const profileTab = React.createElement('div', { className: 'max-w-lg space-y-4' },
    React.createElement('div', { className: 'grid grid-cols-2 gap-4' },
      React.createElement(TextInput, { id: 'first-name', label: 'First Name', value: firstName, onChange: function(ev) { setFirstName(ev.target.value); } }),
      React.createElement(TextInput, { id: 'last-name',  label: 'Last Name',  value: lastName,  onChange: function(ev) { setLastName(ev.target.value); } })
    ),
    React.createElement(TextInput, { id: 'profile-email', label: 'Email', value: profileEmail, onChange: function(ev) { setProfileEmail(ev.target.value); } }),
    React.createElement(TextInput, { id: 'job-title', label: 'Job Title', value: jobTitle, onChange: function(ev) { setJobTitle(ev.target.value); } }),
    React.createElement(TextInput, { id: 'department', label: 'Department', value: department, onChange: function(ev) { setDepartment(ev.target.value); } }),
    React.createElement(SelectInput, {
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
    React.createElement('div', { className: 'pt-2' },
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Save Changes')
    )
  );

  const securityTab = React.createElement('div', { className: 'max-w-lg' },
    React.createElement('h3', { className: 'font-semibold text-gray-800 mb-4' }, 'Change Password'),
    React.createElement('div', { className: 'space-y-4 mb-8' },
      React.createElement(TextInput, { id: 'current-pw', label: 'Current Password', type: 'password', value: currentPw, onChange: function(ev) { setCurrentPw(ev.target.value); } }),
      React.createElement(TextInput, { id: 'new-pw',     label: 'New Password',     type: 'password', value: newPw,     onChange: function(ev) { setNewPw(ev.target.value); } }),
      React.createElement(TextInput, { id: 'confirm-pw', label: 'Confirm New Password', type: 'password', value: confirmPw, onChange: function(ev) { setConfirmPw(ev.target.value); } }),
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Update Password')
    ),
    React.createElement('hr', { className: 'border-gray-200 mb-6' }),
    React.createElement('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Two-Factor Authentication'),
    React.createElement('p', { className: 'text-sm text-gray-600 mb-4' }, 'Add an extra layer of security to your account by enabling 2FA.'),
    React.createElement(CheckboxInput, {
      id: 'two-fa',
      label: 'Enable two-factor authentication',
      checked: twoFa,
      onChange: function(ev) { setTwoFa(ev.target.checked); },
    })
  );

  const notificationsTab = React.createElement('div', { className: 'max-w-lg' },
    React.createElement('div', { className: 'mb-6' },
      React.createElement('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Email Notifications'),
      React.createElement('div', { className: 'space-y-2' },
        React.createElement(CheckboxInput, { id: 'email-orders',    label: 'Order updates',   checked: emailOrders,    onChange: function(ev) { setEmailOrders(ev.target.checked); } }),
        React.createElement(CheckboxInput, { id: 'email-payments',  label: 'Payment receipts', checked: emailPayments,  onChange: function(ev) { setEmailPayments(ev.target.checked); } }),
        React.createElement(CheckboxInput, { id: 'email-marketing', label: 'Marketing & promotions', checked: emailMarketing, onChange: function(ev) { setEmailMarketing(ev.target.checked); } })
      )
    ),
    React.createElement('div', { className: 'mb-6' },
      React.createElement('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'SMS Notifications'),
      React.createElement('div', { className: 'space-y-2' },
        React.createElement(CheckboxInput, { id: 'sms-orders',   label: 'Order shipped / delivered', checked: smsOrders,   onChange: function(ev) { setSmsOrders(ev.target.checked); } }),
        React.createElement(CheckboxInput, { id: 'sms-payments', label: 'Payment confirmations',     checked: smsPayments, onChange: function(ev) { setSmsPayments(ev.target.checked); } })
      )
    ),
    React.createElement('div', { className: 'mb-6' },
      React.createElement('h3', { className: 'font-semibold text-gray-800 mb-3' }, 'Browser Notifications'),
      React.createElement(CheckboxInput, { id: 'browser-all', label: 'Enable browser push notifications', checked: browserAll, onChange: function(ev) { setBrowserAll(ev.target.checked); } })
    ),
    React.createElement(PrimaryButton, { onClick: function() {} }, 'Save Preferences')
  );

  const billingTab = React.createElement('div', { className: 'max-w-lg' },
    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      React.createElement('div', { className: 'flex items-center justify-between mb-2' },
        React.createElement('h3', { className: 'text-lg font-semibold text-gray-900' }, 'Pro'),
        React.createElement(Badge, { color: 'blue' }, 'Current Plan')
      ),
      React.createElement('p', { className: 'text-3xl font-bold text-gray-900 mb-1' }, '$49'),
      React.createElement('p', { className: 'text-sm text-gray-500 mb-4' }, 'per month, billed monthly'),
      React.createElement('ul', { className: 'space-y-1 text-sm text-gray-700 mb-6' },
        React.createElement('li', null, '✓ Unlimited orders'),
        React.createElement('li', null, '✓ Up to 10 team members'),
        React.createElement('li', null, '✓ Advanced reports'),
        React.createElement('li', null, '✓ Priority support')
      ),
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Upgrade to Enterprise')
    ),
    React.createElement('p', { className: 'text-sm text-gray-500' },
      'Next billing date: May 13, 2026 — ',
      React.createElement(LinkButton, { onClick: function() {} }, 'View invoices')
    )
  );

  const activeContent = {
    profile:       profileTab,
    security:      securityTab,
    notifications: notificationsTab,
    billing:       billingTab,
  }[activeTab];

  return React.createElement('div', { className: 'p-6 max-w-4xl mx-auto' },
    React.createElement(PageHeader, { title: 'Settings' }),
    tabBar,
    activeContent
  );
};

window.SettingsShow = SettingsShow;
