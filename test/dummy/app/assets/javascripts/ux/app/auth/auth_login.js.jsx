const AuthLogin = () => {
  const { useState } = React;
  const _email    = useState('');
  const _password = useState('');
  const _remember = useState(false);

  const email    = _email[0];    const setEmail    = _email[1];
  const password = _password[0]; const setPassword = _password[1];
  const remember = _remember[0]; const setRemember = _remember[1];

  const handleSubmit = (evt) => {
    evt.preventDefault();
    alert('Sign in attempted for: ' + email);
  };

  return React.createElement('div', { className: 'min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4' },
    React.createElement('div', { className: 'max-w-md w-full mx-auto' },

      React.createElement('div', { className: 'text-center mb-8' },
        React.createElement('div', { className: 'w-16 h-16 bg-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4' },
          React.createElement('span', { className: 'text-white text-2xl font-bold' }, 'RM')
        ),
        React.createElement('h1', { className: 'text-2xl font-bold text-gray-900' }, 'Sign in to your account'),
        React.createElement('p', { className: 'text-gray-500 text-sm mt-1' }, 'Welcome back! Please enter your details.')
      ),

      React.createElement('div', { className: 'bg-white border border-gray-200 rounded-xl p-8 shadow-sm' },
        React.createElement('form', { onSubmit: handleSubmit, className: 'space-y-5' },

          React.createElement(TextInput, {
            id: 'login-email',
            label: 'Email address',
            type: 'email',
            value: email,
            onChange: function(ev) { setEmail(ev.target.value); },
          }),

          React.createElement(TextInput, {
            id: 'login-password',
            label: 'Password',
            type: 'password',
            value: password,
            onChange: function(ev) { setPassword(ev.target.value); },
          }),

          React.createElement('div', { className: 'flex items-center justify-between' },
            React.createElement(CheckboxInput, {
              id: 'remember-me',
              label: 'Remember me',
              checked: remember,
              onChange: function(ev) { setRemember(ev.target.checked); },
            }),
            React.createElement(LinkButton, { onClick: function() {} }, 'Forgot password?')
          ),

          React.createElement('div', { className: 'pt-2' },
            React.createElement('button', {
              type: 'submit',
              className: 'w-full bg-blue-600 text-white py-2.5 px-4 rounded-lg font-semibold hover:bg-blue-700 transition-colors',
            }, 'Sign In')
          )
        )
      ),

      React.createElement('p', { className: 'text-center text-sm text-gray-600 mt-6' },
        "Don't have an account? ",
        React.createElement('a', { href: '/register', className: 'font-medium text-blue-600 hover:text-blue-500' }, 'Register')
      )
    )
  );
};

window.AuthLogin = AuthLogin;
