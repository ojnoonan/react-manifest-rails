// app/users/users_show.js
// User profile page. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const UsersShow = () => {
  const USER = {
    id: 3, name: 'Priya Patel', email: 'priya.patel@startupxyz.io',
    role: 'moderator', status: 'active', joined: '2023-05-10',
    lastActive: '2026-04-12T14:30:00Z',
    department: 'Product', location: 'San Francisco, CA',
    bio: 'Product-focused moderator helping keep the community healthy and engaged.',
    avatar: null,
  };

  const ACTIVITY = [
    { id: 1, icon: '✏️', text: 'Updated community guidelines post', time: '1 hour ago' },
    { id: 2, icon: '🚫', text: 'Suspended account: spammer99@test.com', time: '3 hours ago' },
    { id: 3, icon: '✅', text: 'Approved 12 pending product reviews', time: 'Yesterday' },
    { id: 4, icon: '💬', text: 'Replied to support thread #4421', time: '2 days ago' },
    { id: 5, icon: '📋', text: 'Exported monthly moderation report', time: '5 days ago' },
  ];

  const initials = USER.name.split(' ').map(function(n) { return n[0]; }).join('');

  return React.createElement('div', { className: 'p-6 max-w-4xl mx-auto' },
    React.createElement(PageHeader, {
      title: USER.name,
      subtitle: USER.department + ' · ' + USER.location,
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users', href: '/users' }, { label: USER.name }],
      actions: React.createElement(React.Fragment, null,
        React.createElement(PrimaryButton, { onClick: function() { window.location = '/users/' + USER.id + '/edit'; } }, 'Edit Profile'),
        React.createElement(DangerButton, { onClick: function() {} }, 'Suspend')
      ),
    }),

    React.createElement('div', { className: 'grid grid-cols-1 md:grid-cols-3 gap-6' },
      React.createElement('div', { className: 'md:col-span-1' },
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-6 text-center' },
          React.createElement('div', { className: 'w-20 h-20 rounded-full bg-blue-600 text-white text-2xl font-bold flex items-center justify-center mx-auto mb-3' }, initials),
          React.createElement('h2', { className: 'text-lg font-semibold text-gray-900' }, USER.name),
          React.createElement('p', { className: 'text-sm text-gray-500 mb-3' }, USER.email),
          React.createElement('div', { className: 'flex justify-center gap-2 flex-wrap' },
            React.createElement(Badge, { variant: 'warning' }, USER.role),
            React.createElement(Badge, { variant: 'success' }, USER.status)
          )
        ),
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-5 mt-4' },
          React.createElement('h3', { className: 'text-sm font-semibold text-gray-700 mb-3 uppercase tracking-wide' }, 'Details'),
          React.createElement('dl', { className: 'space-y-2 text-sm' },
            React.createElement('div', { className: 'flex justify-between' }, React.createElement('dt', { className: 'text-gray-500' }, 'Joined'), React.createElement('dd', { className: 'text-gray-900 font-medium' }, formatDate(USER.joined))),
            React.createElement('div', { className: 'flex justify-between' }, React.createElement('dt', { className: 'text-gray-500' }, 'Last active'), React.createElement('dd', { className: 'text-gray-900 font-medium' }, formatRelative(USER.lastActive))),
            React.createElement('div', { className: 'flex justify-between' }, React.createElement('dt', { className: 'text-gray-500' }, 'Department'), React.createElement('dd', { className: 'text-gray-900 font-medium' }, USER.department))
          )
        )
      ),

      React.createElement('div', { className: 'md:col-span-2 space-y-4' },
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          React.createElement('h3', { className: 'text-sm font-semibold text-gray-700 mb-2 uppercase tracking-wide' }, 'About'),
          React.createElement('p', { className: 'text-sm text-gray-600' }, USER.bio)
        ),
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          React.createElement('h3', { className: 'text-sm font-semibold text-gray-700 mb-4 uppercase tracking-wide' }, 'Recent Activity'),
          React.createElement('ul', { className: 'space-y-3' },
            ACTIVITY.map(function(item) {
              return React.createElement('li', { key: item.id, className: 'flex items-start gap-3' },
                React.createElement('span', { className: 'text-lg flex-shrink-0' }, item.icon),
                React.createElement('div', null,
                  React.createElement('p', { className: 'text-sm text-gray-800' }, item.text),
                  React.createElement('p', { className: 'text-xs text-gray-400 mt-0.5' }, item.time)
                )
              );
            })
          )
        )
      )
    )
  );
};

window.UsersShow = UsersShow;
