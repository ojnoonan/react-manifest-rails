// app/users/users_show.js
// User profile page. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

var UsersShow = function() {
  var e = React.createElement;

  var USER = {
    id: 3, name: 'Priya Patel', email: 'priya.patel@startupxyz.io',
    role: 'moderator', status: 'active', joined: '2023-05-10',
    lastActive: '2026-04-12T14:30:00Z',
    department: 'Product', location: 'San Francisco, CA',
    bio: 'Product-focused moderator helping keep the community healthy and engaged.',
    avatar: null,
  };

  var ACTIVITY = [
    { id: 1, icon: '✏️', text: 'Updated community guidelines post', time: '1 hour ago' },
    { id: 2, icon: '🚫', text: 'Suspended account: spammer99@test.com', time: '3 hours ago' },
    { id: 3, icon: '✅', text: 'Approved 12 pending product reviews', time: 'Yesterday' },
    { id: 4, icon: '💬', text: 'Replied to support thread #4421', time: '2 days ago' },
    { id: 5, icon: '📋', text: 'Exported monthly moderation report', time: '5 days ago' },
  ];

  var initials = USER.name.split(' ').map(function(n) { return n[0]; }).join('');

  return e('div', { className: 'p-6 max-w-4xl mx-auto' },
    e(PageHeader, {
      title: USER.name,
      subtitle: USER.department + ' · ' + USER.location,
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users', href: '/users' }, { label: USER.name }],
      actions: React.createElement(React.Fragment, null,
        e(PrimaryButton, { onClick: function() { window.location = '/users/' + USER.id + '/edit'; } }, 'Edit Profile'),
        e(DangerButton, { onClick: function() {} }, 'Suspend')
      ),
    }),

    e('div', { className: 'grid grid-cols-1 md:grid-cols-3 gap-6' },
      e('div', { className: 'md:col-span-1' },
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-6 text-center' },
          e('div', { className: 'w-20 h-20 rounded-full bg-blue-600 text-white text-2xl font-bold flex items-center justify-center mx-auto mb-3' }, initials),
          e('h2', { className: 'text-lg font-semibold text-gray-900' }, USER.name),
          e('p', { className: 'text-sm text-gray-500 mb-3' }, USER.email),
          e('div', { className: 'flex justify-center gap-2 flex-wrap' },
            e(Badge, { variant: 'warning' }, USER.role),
            e(Badge, { variant: 'success' }, USER.status)
          )
        ),
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5 mt-4' },
          e('h3', { className: 'text-sm font-semibold text-gray-700 mb-3 uppercase tracking-wide' }, 'Details'),
          e('dl', { className: 'space-y-2 text-sm' },
            e('div', { className: 'flex justify-between' }, e('dt', { className: 'text-gray-500' }, 'Joined'), e('dd', { className: 'text-gray-900 font-medium' }, formatDate(USER.joined))),
            e('div', { className: 'flex justify-between' }, e('dt', { className: 'text-gray-500' }, 'Last active'), e('dd', { className: 'text-gray-900 font-medium' }, formatRelative(USER.lastActive))),
            e('div', { className: 'flex justify-between' }, e('dt', { className: 'text-gray-500' }, 'Department'), e('dd', { className: 'text-gray-900 font-medium' }, USER.department))
          )
        )
      ),

      e('div', { className: 'md:col-span-2 space-y-4' },
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          e('h3', { className: 'text-sm font-semibold text-gray-700 mb-2 uppercase tracking-wide' }, 'About'),
          e('p', { className: 'text-sm text-gray-600' }, USER.bio)
        ),
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          e('h3', { className: 'text-sm font-semibold text-gray-700 mb-4 uppercase tracking-wide' }, 'Recent Activity'),
          e('ul', { className: 'space-y-3' },
            ACTIVITY.map(function(item) {
              return e('li', { key: item.id, className: 'flex items-start gap-3' },
                e('span', { className: 'text-lg flex-shrink-0' }, item.icon),
                e('div', null,
                  e('p', { className: 'text-sm text-gray-800' }, item.text),
                  e('p', { className: 'text-xs text-gray-400 mt-0.5' }, item.time)
                )
              );
            })
          )
        )
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'UsersShow') {
    ReactDOM.createRoot(container).render(React.createElement(UsersShow));
  }
});
