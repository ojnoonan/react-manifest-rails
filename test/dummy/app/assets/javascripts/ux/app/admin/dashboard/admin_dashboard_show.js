var AdminDashboardShow = function() {
  var e = React.createElement;

  var metrics = [
    { label: 'Requests / min',  value: '1,240',  icon: '⚡' },
    { label: 'Error Rate',      value: '0.02%',  icon: '🔴' },
    { label: 'p95 Latency',     value: '142 ms', icon: '⏱' },
    { label: 'Active Sessions', value: '384',    icon: '👥' },
  ];

  var topPages = [
    { path: '/dashboard',        views: 18420, avgTime: '2m 14s', bounceRate: '12%' },
    { path: '/orders',           views: 14310, avgTime: '3m 02s', bounceRate: '8%'  },
    { path: '/products',         views: 10230, avgTime: '2m 48s', bounceRate: '18%' },
    { path: '/settings',         views:  6710, avgTime: '1m 57s', bounceRate: '22%' },
    { path: '/admin/dashboard',  views:  4890, avgTime: '4m 35s', bounceRate: '5%'  },
  ];

  return e('div', { className: 'p-6 max-w-5xl mx-auto' },

    e(Breadcrumbs, {
      items: [
        { label: 'Admin',     href: '/admin' },
        { label: 'Dashboard', href: '/admin/dashboard' },
        { label: 'Analytics' },
      ],
    }),

    e(PageHeader, { title: 'Analytics Detail', subtitle: 'Real-time system performance metrics' }),

    e('div', { className: 'grid grid-cols-2 md:grid-cols-4 gap-4 mb-10' },
      metrics.map(function(m, i) {
        return e('div', { key: i, className: 'bg-white border border-gray-200 rounded-lg p-5' },
          e('div', { className: 'text-xl mb-2' }, m.icon),
          e('p', { className: 'text-2xl font-bold text-gray-900' }, m.value),
          e('p', { className: 'text-sm text-gray-500 mt-1' }, m.label)
        );
      })
    ),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden' },
      e('div', { className: 'px-5 py-4 border-b border-gray-100' },
        e('h2', { className: 'font-semibold text-gray-800' }, 'Top Pages')
      ),
      e(DataTable, {
        columns: [
          { key: 'path',       label: 'Page Path' },
          { key: 'views',      label: 'Page Views', render: function(v) { return v.toLocaleString(); } },
          { key: 'avgTime',    label: 'Avg. Time on Page' },
          { key: 'bounceRate', label: 'Bounce Rate' },
        ],
        rows: topPages,
        emptyMessage: 'No page data.',
      })
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'AdminDashboardShow') {
    ReactDOM.createRoot(container).render(React.createElement(AdminDashboardShow));
  }
});
