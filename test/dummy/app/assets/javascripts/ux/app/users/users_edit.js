// app/users/users_edit.js
// User edit form with validation. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

var UsersEdit = function() {
  var e = React.createElement;

  var INITIAL = { name: 'Priya Patel', email: 'priya.patel@startupxyz.io', role: 'moderator', department: 'Product', notifications: true, bio: 'Product-focused moderator.' };

  var validate = function(values) {
    var errs = {};
    var nameResult = Validators.required(values.name);
    if (!nameResult.valid) errs.name = nameResult.message;
    var emailReq = Validators.required(values.email);
    if (!emailReq.valid) { errs.email = emailReq.message; }
    else {
      var emailFmt = Validators.email(values.email);
      if (!emailFmt.valid) errs.email = emailFmt.message;
    }
    return errs;
  };

  var form = useForm(INITIAL, validate);

  var savedPair = React.useState(false);
  var saved = savedPair[0];
  var setSaved = savedPair[1];

  var handleSave = form.handleSubmit(function(values) {
    return new Promise(function(resolve) {
      setTimeout(function() { setSaved(true); resolve(); }, 800);
    });
  });

  return e('div', { className: 'p-6 max-w-2xl mx-auto' },
    e(PageHeader, {
      title: 'Edit User',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users', href: '/users' }, { label: INITIAL.name, href: '/users/3' }, { label: 'Edit' }],
    }),

    saved ? e(Alert, { variant: 'success', title: 'Saved!', onDismiss: function() { setSaved(false); } }, 'User profile updated successfully.') : null,

    e('div', { className: 'bg-white rounded-xl border border-gray-200 p-6' },
      e('form', { onSubmit: handleSave, noValidate: true },
        e('div', { className: 'grid grid-cols-1 sm:grid-cols-2 gap-x-4' },
          e(TextInput, {
            label: 'Full Name', required: true,
            value: form.values.name,
            onChange: form.handleChange('name'),
            onBlur: form.handleBlur('name'),
            error: form.touched.name && form.errors.name,
          }),
          e(TextInput, {
            label: 'Email Address', type: 'email', required: true,
            value: form.values.email,
            onChange: form.handleChange('email'),
            onBlur: form.handleBlur('email'),
            error: form.touched.email && form.errors.email,
          }),
          e(SelectInput, {
            label: 'Role',
            value: form.values.role,
            onChange: form.handleChange('role'),
            options: [
              { value: 'user', label: 'User' },
              { value: 'moderator', label: 'Moderator' },
              { value: 'admin', label: 'Admin' },
            ],
          }),
          e(SelectInput, {
            label: 'Department',
            value: form.values.department,
            onChange: form.handleChange('department'),
            options: [
              { value: 'Product', label: 'Product' },
              { value: 'Engineering', label: 'Engineering' },
              { value: 'Marketing', label: 'Marketing' },
              { value: 'Sales', label: 'Sales' },
            ],
          })
        ),
        e(TextInput, {
          label: 'Bio', hint: 'A short description of this user.',
          value: form.values.bio,
          onChange: form.handleChange('bio'),
        }),
        e(CheckboxInput, {
          label: 'Email notifications enabled',
          hint: 'User will receive updates via email.',
          checked: form.values.notifications,
          onChange: form.handleChange('notifications'),
        }),
        e('div', { className: 'flex gap-3 mt-6 pt-4 border-t border-gray-100' },
          e(PrimaryButton, { type: 'submit', loading: form.isSubmitting }, 'Save Changes'),
          e(LinkButton, { href: '/users/3' }, 'Cancel')
        )
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'UsersEdit') {
    ReactDOM.createRoot(container).render(React.createElement(UsersEdit));
  }
});
