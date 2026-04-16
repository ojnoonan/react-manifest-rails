const AuthRegister = () => {
  const { useState } = React;
  const _firstName  = useState('');
  const _lastName   = useState('');
  const _email      = useState('');
  const _password   = useState('');
  const _confirm    = useState('');
  const _terms      = useState(false);

  const firstName  = _firstName[0];  const setFirstName  = _firstName[1];
  const lastName   = _lastName[0];   const setLastName   = _lastName[1];
  const email      = _email[0];      const setEmail      = _email[1];
  const password   = _password[0];   const setPassword   = _password[1];
  const confirm    = _confirm[0];    const setConfirm    = _confirm[1];
  const terms      = _terms[0];      const setTerms      = _terms[1];

  const handleSubmit = (evt) => {
    evt.preventDefault();
    if (password !== confirm) {
      alert('Passwords do not match.');
      return;
    }
    alert('Account created for: ' + email);
  };

  return React.createElement('div', { className: 'min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4' },
    React.createElement('div', { className: 'max-w-md w-full mx-auto' },

      React.createElement('div', { className: 'text-center mb-8' },
        React.createElement('div', { className: 'w-16 h-16 bg-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4' },
          React.createElement('span', { className: 'text-white text-2xl font-bold' }, 'RM')
        ),
        React.createElement('h1', { className: 'text-2xl font-bold text-gray-900' }, 'Create your account'),
        React.createElement('p', { className: 'text-gray-500 text-sm mt-1' }, 'Get started — it only takes a minute.')
      ),

      React.createElement('div', { className: 'bg-white border border-gray-200 rounded-xl p-8 shadow-sm' },
        React.createElement('form', { onSubmit: handleSubmit, className: 'space-y-4' },

          React.createElement('div', { className: 'grid grid-cols-2 gap-4' },
            React.createElement(TextInput, {
              id: 'reg-first-name',
              label: 'First Name',
              value: firstName,
              onChange: function(ev) { setFirstName(ev.target.value); },
            }),
            React.createElement(TextInput, {
              id: 'reg-last-name',
              label: 'Last Name',
              value: lastName,
              onChange: function(ev) { setLastName(ev.target.value); },
            })
          ),

          React.createElement(TextInput, {
            id: 'reg-email',
            label: 'Email address',
            type: 'email',
            value: email,
            onChange: function(ev) { setEmail(ev.target.value); },
          }),

          React.createElement(TextInput, {
            id: 'reg-password',
            label: 'Password',
            type: 'password',
            value: password,
            onChange: function(ev) { setPassword(ev.target.value); },
            hint: 'At least 8 characters',
          }),

          React.createElement(TextInput, {
            id: 'reg-confirm',
            label: 'Confirm Password',
            type: 'password',
            value: confirm,
            onChange: function(ev) { setConfirm(ev.target.value); },
          }),

          React.createElement(CheckboxInput, {
            id: 'reg-terms',
            label: 'I agree to the Terms of Service and Privacy Policy',
            checked: terms,
            onChange: function(ev) { setTerms(ev.target.checked); },
          }),

          React.createElement('div', { className: 'pt-2' },
            React.createElement('button', {
              type: 'submit',
              className: 'w-full bg-blue-600 text-white py-2.5 px-4 rounded-lg font-semibold hover:bg-blue-700 transition-colors',
            }, 'Create Account')
          )
        )
      ),

      React.createElement('p', { className: 'text-center text-sm text-gray-600 mt-6' },
        'Already have an account? ',
        React.createElement('a', { href: '/login', className: 'font-medium text-blue-600 hover:text-blue-500' }, 'Sign in')
      )
    )
  );
};

window.AuthRegister = AuthRegister;
