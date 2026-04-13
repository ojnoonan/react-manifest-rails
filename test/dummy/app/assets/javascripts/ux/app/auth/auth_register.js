var AuthRegister = function() {
  var e = React.createElement;

  var _firstName  = React.useState('');
  var _lastName   = React.useState('');
  var _email      = React.useState('');
  var _password   = React.useState('');
  var _confirm    = React.useState('');
  var _terms      = React.useState(false);

  var firstName  = _firstName[0];  var setFirstName  = _firstName[1];
  var lastName   = _lastName[0];   var setLastName   = _lastName[1];
  var email      = _email[0];      var setEmail      = _email[1];
  var password   = _password[0];   var setPassword   = _password[1];
  var confirm    = _confirm[0];    var setConfirm    = _confirm[1];
  var terms      = _terms[0];      var setTerms      = _terms[1];

  var handleSubmit = function(evt) {
    evt.preventDefault();
    if (password !== confirm) {
      alert('Passwords do not match.');
      return;
    }
    alert('Account created for: ' + email);
  };

  return e('div', { className: 'min-h-screen bg-gray-50 flex items-center justify-center py-12 px-4' },
    e('div', { className: 'max-w-md w-full mx-auto' },

      e('div', { className: 'text-center mb-8' },
        e('div', { className: 'w-16 h-16 bg-blue-600 rounded-xl flex items-center justify-center mx-auto mb-4' },
          e('span', { className: 'text-white text-2xl font-bold' }, 'RM')
        ),
        e('h1', { className: 'text-2xl font-bold text-gray-900' }, 'Create your account'),
        e('p', { className: 'text-gray-500 text-sm mt-1' }, 'Get started — it only takes a minute.')
      ),

      e('div', { className: 'bg-white border border-gray-200 rounded-xl p-8 shadow-sm' },
        e('form', { onSubmit: handleSubmit, className: 'space-y-4' },

          e('div', { className: 'grid grid-cols-2 gap-4' },
            e(TextInput, {
              id: 'reg-first-name',
              label: 'First Name',
              value: firstName,
              onChange: function(ev) { setFirstName(ev.target.value); },
            }),
            e(TextInput, {
              id: 'reg-last-name',
              label: 'Last Name',
              value: lastName,
              onChange: function(ev) { setLastName(ev.target.value); },
            })
          ),

          e(TextInput, {
            id: 'reg-email',
            label: 'Email address',
            type: 'email',
            value: email,
            onChange: function(ev) { setEmail(ev.target.value); },
          }),

          e(TextInput, {
            id: 'reg-password',
            label: 'Password',
            type: 'password',
            value: password,
            onChange: function(ev) { setPassword(ev.target.value); },
            hint: 'At least 8 characters',
          }),

          e(TextInput, {
            id: 'reg-confirm',
            label: 'Confirm Password',
            type: 'password',
            value: confirm,
            onChange: function(ev) { setConfirm(ev.target.value); },
          }),

          e(CheckboxInput, {
            id: 'reg-terms',
            label: 'I agree to the Terms of Service and Privacy Policy',
            checked: terms,
            onChange: function(ev) { setTerms(ev.target.checked); },
          }),

          e('div', { className: 'pt-2' },
            e('button', {
              type: 'submit',
              className: 'w-full bg-blue-600 text-white py-2.5 px-4 rounded-lg font-semibold hover:bg-blue-700 transition-colors',
            }, 'Create Account')
          )
        )
      ),

      e('p', { className: 'text-center text-sm text-gray-600 mt-6' },
        'Already have an account? ',
        e('a', { href: '/login', className: 'font-medium text-blue-600 hover:text-blue-500' }, 'Sign in')
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'AuthRegister') {
    ReactDOM.createRoot(container).render(React.createElement(AuthRegister));
  }
});
