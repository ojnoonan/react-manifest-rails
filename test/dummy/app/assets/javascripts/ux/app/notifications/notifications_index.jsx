const NotificationsIndex = () => {
  const { useEffect, useState } = React;

  const seedNotifications = [
    {
      id: 1,
      icon: '📦',
      title: 'Order #1089 has shipped',
      body: 'Your order has been dispatched and is on its way. Estimated delivery in 2-3 business days.',
      time: new Date(Date.now() - 15 * 60 * 1000).toISOString(),
      type: 'order_update',
      read: false,
    },
    {
      id: 2,
      icon: '👤',
      title: 'New user registered',
      body: 'Marcus Webb (marcus@acme.com) created an account and is awaiting verification.',
      time: new Date(Date.now() - 42 * 60 * 1000).toISOString(),
      type: 'new_user',
      read: false,
    },
    {
      id: 3,
      icon: '💳',
      title: 'Payment received — $337.23',
      body: 'Invoice #INV-4402 has been paid in full by Sarah Chen.',
      time: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      type: 'payment_received',
      read: false,
    },
    {
      id: 4,
      icon: '⚠️',
      title: 'Low stock alert: USB-C Cable',
      body: 'USB-C Cable (SKU-042) has only 4 units remaining. Consider restocking soon.',
      time: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
      type: 'low_stock',
      read: true,
    },
    {
      id: 5,
      icon: '🔧',
      title: 'Scheduled maintenance complete',
      body: 'The database maintenance window concluded successfully. All systems are operating normally.',
      time: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      type: 'system_alert',
      read: true,
    },
    {
      id: 6,
      icon: '📊',
      title: 'Monthly report is ready',
      body: 'Your March 2026 sales report has been generated and is available for download.',
      time: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
      type: 'report_ready',
      read: true,
    },
  ];

  const notificationsState = useState(seedNotifications);
  const notifications = notificationsState[0];
  const setNotifications = notificationsState[1];

  const loadingState = useState(false);
  const loading = loadingState[0];
  const setLoading = loadingState[1];

  useEffect(function() {
    if (typeof axios === 'undefined') return;

    let active = true;
    setLoading(true);

    axios.get('/notifications.json', {
      headers: { Accept: 'application/json' },
      timeout: 1200,
    }).then(function(resp) {
      if (!active) return;
      if (Array.isArray(resp && resp.data) && resp.data.length > 0) {
        setNotifications(resp.data);
      }
    }).catch(function() {
      // Demo app fallback: keep seeded notifications when JSON endpoint is absent.
      if (active) setNotifications(seedNotifications);
    }).finally(function() {
      if (active) setLoading(false);
    });

    return function() { active = false; };
  }, []);

  return React.createElement('div', { className: 'p-6 max-w-3xl mx-auto' },

    React.createElement('div', { className: 'flex items-center justify-between mb-6' },
      React.createElement(PageHeader, { title: 'Notifications' }),
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Mark all read')
    ),

    loading
      ? React.createElement('div', { className: 'py-10 text-center text-sm text-gray-500' }, 'Loading notifications...')
      : React.createElement('div', { className: 'space-y-2' },
      notifications.map(function(n) {
        return React.createElement('div', {
          key: n.id,
          className: [
            'flex items-start gap-4 p-4 rounded-lg border',
            n.read
              ? 'bg-white border-gray-200'
              : 'bg-blue-50 border-l-4 border-l-blue-500 border-gray-200',
          ].join(' '),
        },
          React.createElement('span', { className: 'text-2xl flex-shrink-0 mt-0.5' }, n.icon),
          React.createElement('div', { className: 'flex-1 min-w-0' },
            React.createElement('div', { className: 'flex items-center justify-between gap-2' },
              React.createElement('p', { className: 'font-semibold text-gray-900 text-sm' }, n.title),
              React.createElement('span', { className: 'text-xs text-gray-400 flex-shrink-0' }, formatRelative(n.time))
            ),
            React.createElement('p', { className: 'text-sm text-gray-600 mt-1' }, n.body)
          )
        );
      })
    )
  );
};

window.NotificationsIndex = NotificationsIndex;
