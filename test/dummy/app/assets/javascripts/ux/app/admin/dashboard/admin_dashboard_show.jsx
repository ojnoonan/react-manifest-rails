const AdminDashboardShow = () => {
  const metrics = [
    { label: 'Requests / min',  value: '1,240',  icon: '⚡' },
    { label: 'Error Rate',      value: '0.02%',  icon: '🔴' },
    { label: 'p95 Latency',     value: '142 ms', icon: '⏱' },
    { label: 'Active Sessions', value: '384',    icon: '👥' },
  ];

  const topPages = [
    { path: '/dashboard',        views: 18420, avgTime: '2m 14s', bounceRate: '12%' },
    { path: '/orders',           views: 14310, avgTime: '3m 02s', bounceRate: '8%'  },
    { path: '/products',         views: 10230, avgTime: '2m 48s', bounceRate: '18%' },
    { path: '/settings',         views:  6710, avgTime: '1m 57s', bounceRate: '22%' },
    { path: '/admin/dashboard',  views:  4890, avgTime: '4m 35s', bounceRate: '5%'  },
  ];

  return React.createElement('div', { className: 'p-6 max-w-5xl mx-auto' },

    React.createElement(Breadcrumbs, {
      items: [
        { label: 'Admin',     href: '/admin' },
        { label: 'Dashboard', href: '/admin/dashboard' },
        { label: 'Analytics' },
      ],
    }),

    React.createElement(PageHeader, { title: 'Analytics Detail', subtitle: 'Real-time system performance metrics' }),

    React.createElement('div', { className: 'grid grid-cols-2 md:grid-cols-4 gap-4 mb-10' },
      metrics.map(function(m, i) {
        return React.createElement('div', { key: i, className: 'bg-white border border-gray-200 rounded-lg p-5' },
          React.createElement('div', { className: 'text-xl mb-2' }, m.icon),
          React.createElement('p', { className: 'text-2xl font-bold text-gray-900' }, m.value),
          React.createElement('p', { className: 'text-sm text-gray-500 mt-1' }, m.label)
        );
      })
    ),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden' },
      React.createElement('div', { className: 'px-5 py-4 border-b border-gray-100' },
        React.createElement('h2', { className: 'font-semibold text-gray-800' }, 'Top Pages')
      ),
      React.createElement(DataTable, {
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

window.AdminDashboardShow = AdminDashboardShow;
