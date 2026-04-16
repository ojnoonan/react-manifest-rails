const NotificationsShow = () => {
  const notification = {
    id: 3,
    icon: '💳',
    title: 'Payment received — $337.23',
    body: 'Invoice #INV-4402 has been paid in full by Sarah Chen (sarah@example.com). The payment of $337.23 was processed via Stripe on April 13, 2026 at 10:42 AM. This payment covers Order #1089 including Wireless Headphones, USB-C Cable, and Phone Stand. A receipt has been emailed to the customer.',
    time: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    type: 'payment_received',
    read: false,
  };

  const typeColors = {
    payment_received: 'green',
    order_update:     'blue',
    new_user:         'purple',
    low_stock:        'yellow',
    system_alert:     'red',
    report_ready:     'gray',
  };

  const typeLabelMap = {
    payment_received: 'Payment',
    order_update:     'Order Update',
    new_user:         'New User',
    low_stock:        'Low Stock',
    system_alert:     'System',
    report_ready:     'Report',
  };

  return React.createElement('div', { className: 'p-6 max-w-3xl mx-auto' },

    React.createElement(Breadcrumbs, {
      items: [
        { label: 'Home',          href: '/' },
        { label: 'Notifications', href: '/notifications' },
        { label: notification.title },
      ]
    }),

    React.createElement(PageHeader, { title: notification.title }),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      React.createElement('div', { className: 'flex items-start gap-4 mb-4' },
        React.createElement('span', { className: 'text-4xl' }, notification.icon),
        React.createElement('div', { className: 'flex-1' },
          React.createElement('div', { className: 'flex items-center gap-3 mb-2' },
            React.createElement(Badge, { color: typeColors[notification.type] || 'gray' },
              typeLabelMap[notification.type] || notification.type
            ),
            React.createElement('span', { className: 'text-sm text-gray-500' }, formatDate(notification.time))
          ),
          React.createElement('p', { className: 'text-xs text-gray-400' }, formatRelative(notification.time))
        )
      ),
      React.createElement('hr', { className: 'border-gray-100 mb-4' }),
      React.createElement('p', { className: 'text-gray-700 leading-relaxed' }, notification.body)
    ),

    React.createElement('div', { className: 'flex gap-3' },
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Mark as read'),
      React.createElement(DangerButton,  { onClick: function() {} }, 'Delete')
    )
  );
};

window.NotificationsShow = NotificationsShow;
