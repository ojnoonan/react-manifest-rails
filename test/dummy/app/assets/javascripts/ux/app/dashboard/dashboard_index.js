// app/dashboard/dashboard_index.js
// Main dashboard page. Mounted on #react-app by DOMContentLoaded.
// No JSX — uses React.createElement. No import/export — globals only.

var DashboardIndex = function() {
  var e = React.createElement;

  var STATS = [
    { label: 'Total Users',          value: '1,243',   change: '+12%', up: true,  icon: '👥', color: 'bg-blue-50 border-blue-200' },
    { label: 'Monthly Revenue',      value: '$84,523',  change: '+8.3%', up: true, icon: '💰', color: 'bg-green-50 border-green-200' },
    { label: 'Orders This Month',    value: '328',      change: '-2.1%', up: false, icon: '📦', color: 'bg-purple-50 border-purple-200' },
    { label: 'Products',             value: '94',       change: '+5',   up: true,  icon: '🛍', color: 'bg-orange-50 border-orange-200' },
  ];

  var ACTIVITY = [
    { id: 1, type: 'order',   icon: '📦', text: 'New order #1089 placed by Sarah Chen', time: '2 minutes ago',  color: 'text-blue-600' },
    { id: 2, type: 'user',    icon: '👤', text: 'New user registration: marcus@example.com', time: '14 minutes ago', color: 'text-green-600' },
    { id: 3, type: 'payment', icon: '💳', text: 'Payment of $2,340 received for order #1085', time: '1 hour ago', color: 'text-purple-600' },
    { id: 4, type: 'alert',   icon: '⚠️', text: 'Stock low alert: Wireless Headphones (3 left)', time: '3 hours ago', color: 'text-yellow-600' },
    { id: 5, type: 'user',    icon: '✏️', text: 'User profile updated: james.wilson@acme.co', time: '5 hours ago', color: 'text-gray-600' },
  ];

  var QUICK_ACTIONS = [
    { label: 'Manage Users',    href: '/users',    icon: '👥', desc: 'Add, edit, or remove users' },
    { label: 'View Products',   href: '/products', icon: '🛍', desc: 'Manage your product catalog' },
    { label: 'Process Orders',  href: '/orders',   icon: '📦', desc: 'Review and fulfill orders' },
  ];

  var StatCard = function(stat) {
    return e('div', { key: stat.label, className: 'bg-white rounded-xl border p-5 ' + stat.color },
      e('div', { className: 'flex items-center justify-between mb-3' },
        e('span', { className: 'text-2xl' }, stat.icon),
        e('span', { className: 'text-xs font-medium px-2 py-1 rounded-full ' + (stat.up ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700') }, stat.change)
      ),
      e('p', { className: 'text-2xl font-bold text-gray-900' }, stat.value),
      e('p', { className: 'text-sm text-gray-500 mt-1' }, stat.label)
    );
  };

  return e('div', { className: 'p-6 max-w-7xl mx-auto' },
    e(PageHeader, {
      title: 'Dashboard',
      subtitle: 'Welcome back! Here\'s what\'s happening.',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Dashboard' }],
    }),

    e('div', { className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8' },
      STATS.map(StatCard)
    ),

    e('div', { className: 'grid grid-cols-1 lg:grid-cols-3 gap-6' },
      e('div', { className: 'lg:col-span-2 bg-white rounded-xl border border-gray-200 p-5' },
        e('h2', { className: 'text-lg font-semibold text-gray-900 mb-4' }, 'Recent Activity'),
        e('ul', { className: 'space-y-3' },
          ACTIVITY.map(function(item) {
            return e('li', { key: item.id, className: 'flex items-start gap-3 py-2 border-b border-gray-50 last:border-0' },
              e('span', { className: 'text-xl mt-0.5 flex-shrink-0' }, item.icon),
              e('div', { className: 'flex-1 min-w-0' },
                e('p', { className: 'text-sm text-gray-800' }, item.text),
                e('p', { className: 'text-xs text-gray-400 mt-0.5' }, item.time)
              )
            );
          })
        )
      ),

      e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
        e('h2', { className: 'text-lg font-semibold text-gray-900 mb-4' }, 'Quick Actions'),
        e('div', { className: 'space-y-3' },
          QUICK_ACTIONS.map(function(action) {
            return e('a', {
              key: action.label,
              href: action.href,
              className: 'flex items-center gap-3 p-3 rounded-lg border border-gray-200 hover:bg-gray-50 hover:border-blue-300 transition-colors group',
            },
              e('span', { className: 'text-2xl' }, action.icon),
              e('div', null,
                e('p', { className: 'text-sm font-medium text-gray-900 group-hover:text-blue-700' }, action.label),
                e('p', { className: 'text-xs text-gray-500' }, action.desc)
              ),
              e('span', { className: 'ml-auto text-gray-300 group-hover:text-blue-400' }, '→')
            );
          })
        )
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'DashboardIndex') {
    ReactDOM.createRoot(container).render(React.createElement(DashboardIndex));
  }
});
