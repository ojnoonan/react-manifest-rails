// app/users/users_edit.js
// User edit form with validation. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const UsersEdit = () => {
  const { useState } = React;
  const INITIAL = { name: 'Priya Patel', email: 'priya.patel@startupxyz.io', role: 'moderator', department: 'Product', notifications: true, bio: 'Product-focused moderator.' };

  const validate = (values) => {
    const errs = {};
    const nameResult = Validators.required(values.name);
    if (!nameResult.valid) errs.name = nameResult.message;
    const emailReq = Validators.required(values.email);
    if (!emailReq.valid) { errs.email = emailReq.message; }
    else {
      const emailFmt = Validators.email(values.email);
      if (!emailFmt.valid) errs.email = emailFmt.message;
    }
    return errs;
  };

  const form = useForm(INITIAL, validate);

  const savedPair = useState(false);
  const saved = savedPair[0];
  const setSaved = savedPair[1];

  const handleSave = form.handleSubmit(function(values) {
    return new Promise(function(resolve) {
      setTimeout(function() { setSaved(true); resolve(); }, 800);
    });
  });

  return React.createElement('div', { className: 'p-6 max-w-2xl mx-auto' },
    React.createElement(PageHeader, {
      title: 'Edit User',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users', href: '/users' }, { label: INITIAL.name, href: '/users/3' }, { label: 'Edit' }],
    }),

    saved ? React.createElement(Alert, { variant: 'success', title: 'Saved!', onDismiss: function() { setSaved(false); } }, 'User profile updated successfully.') : null,

    React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-6' },
      React.createElement('form', { onSubmit: handleSave, noValidate: true },
        React.createElement('div', { className: 'grid grid-cols-1 sm:grid-cols-2 gap-x-4' },
          React.createElement(TextInput, {
            label: 'Full Name', required: true,
            value: form.values.name,
            onChange: form.handleChange('name'),
            onBlur: form.handleBlur('name'),
            error: form.touched.name && form.errors.name,
          }),
          React.createElement(TextInput, {
            label: 'Email Address', type: 'email', required: true,
            value: form.values.email,
            onChange: form.handleChange('email'),
            onBlur: form.handleBlur('email'),
            error: form.touched.email && form.errors.email,
          }),
          React.createElement(SelectInput, {
            label: 'Role',
            value: form.values.role,
            onChange: form.handleChange('role'),
            options: [
              { value: 'user', label: 'User' },
              { value: 'moderator', label: 'Moderator' },
              { value: 'admin', label: 'Admin' },
            ],
          }),
          React.createElement(SelectInput, {
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
        React.createElement(TextInput, {
          label: 'Bio', hint: 'A short description of this user.',
          value: form.values.bio,
          onChange: form.handleChange('bio'),
        }),
        React.createElement(CheckboxInput, {
          label: 'Email notifications enabled',
          hint: 'User will receive updates via email.',
          checked: form.values.notifications,
          onChange: form.handleChange('notifications'),
        }),
        React.createElement('div', { className: 'flex gap-3 mt-6 pt-4 border-t border-gray-100' },
          React.createElement(PrimaryButton, { type: 'submit', loading: form.isSubmitting }, 'Save Changes'),
          React.createElement(LinkButton, { href: '/users/3' }, 'Cancel')
        )
      )
    )
  );
};

window.UsersEdit = UsersEdit;
