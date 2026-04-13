var AuthLogin = function() {
  var e = React.createElement;

  var _email    = React.useState('');
  var _password = React.useState('');
  var _remember = React.useState(false);

  var email    = _email[0];    var setEmail    = _email[1];
  var password = _password[0]; var setPassword = _password[1];
  var remember = _remember[0]; var setRemember = _remember[1];

  var handleSubmit = function(evt) {
    evt.preventDefault();
    alert('Sign in attempted for: ' + email);
  };

  return e('div', { className: 'min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4' },
    e('div', { className: 'max-w-md w-full mx-auto' },

      e('div', { className: 'text-center mb-8' },
        e('div', { className: 'w-16 h-16 bg-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4' },
          e('span', { className: 'text-white text-2xl font-bold' }, 'RM')
        ),
        e('h1', { className: 'text-2xl font-bold text-gray-900' }, 'Sign in to your account'),
        e('p', { className: 'text-gray-500 text-sm mt-1' }, 'Welcome back! Please enter your details.')
      ),

      e('div', { className: 'bg-white border border-gray-200 rounded-xl p-8 shadow-sm' },
        e('form', { onSubmit: handleSubmit, className: 'space-y-5' },

          e(TextInput, {
            id: 'login-email',
            label: 'Email address',
            type: 'email',
            value: email,
            onChange: function(ev) { setEmail(ev.target.value); },
          }),

          e(TextInput, {
            id: 'login-password',
            label: 'Password',
            type: 'password',
            value: password,
            onChange: function(ev) { setPassword(ev.target.value); },
          }),

          e('div', { className: 'flex items-center justify-between' },
            e(CheckboxInput, {
              id: 'remember-me',
              label: 'Remember me',
              checked: remember,
              onChange: function(ev) { setRemember(ev.target.checked); },
            }),
            e(LinkButton, { onClick: function() {} }, 'Forgot password?')
          ),

          e('div', { className: 'pt-2' },
            e('button', {
              type: 'submit',
              className: 'w-full bg-blue-600 text-white py-2.5 px-4 rounded-lg font-semibold hover:bg-blue-700 transition-colors',
            }, 'Sign In')
          )
        )
      ),

      e('p', { className: 'text-center text-sm text-gray-600 mt-6' },
        "Don't have an account? ",
        e('a', { href: '/register', className: 'font-medium text-blue-600 hover:text-blue-500' }, 'Register')
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'AuthLogin') {
    ReactDOM.createRoot(container).render(React.createElement(AuthLogin));
  }
});
