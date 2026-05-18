var UsersIndex = function(props) {
  return React.createElement('div', { className: 'users' },
    React.createElement('h1', null, 'Users'),
    React.createElement(TextInput, {
      placeholder: 'Search users...',
      value: props.query,
      onChange: props.onQueryChange
    }),
    React.createElement(PrimaryButton, null, 'Add User')
  );
};
