var NotificationsShow = function() {
  var e = React.createElement;

  var notification = {
    id: 3,
    icon: '💳',
    title: 'Payment received — $337.23',
    body: 'Invoice #INV-4402 has been paid in full by Sarah Chen (sarah@example.com). The payment of $337.23 was processed via Stripe on April 13, 2026 at 10:42 AM. This payment covers Order #1089 including Wireless Headphones, USB-C Cable, and Phone Stand. A receipt has been emailed to the customer.',
    time: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    type: 'payment_received',
    read: false,
  };

  var typeColors = {
    payment_received: 'green',
    order_update:     'blue',
    new_user:         'purple',
    low_stock:        'yellow',
    system_alert:     'red',
    report_ready:     'gray',
  };

  var typeLabelMap = {
    payment_received: 'Payment',
    order_update:     'Order Update',
    new_user:         'New User',
    low_stock:        'Low Stock',
    system_alert:     'System',
    report_ready:     'Report',
  };

  return e('div', { className: 'p-6 max-w-3xl mx-auto' },

    e(Breadcrumbs, {
      items: [
        { label: 'Home',          href: '/' },
        { label: 'Notifications', href: '/notifications' },
        { label: notification.title },
      ]
    }),

    e(PageHeader, { title: notification.title }),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-6 mb-6' },
      e('div', { className: 'flex items-start gap-4 mb-4' },
        e('span', { className: 'text-4xl' }, notification.icon),
        e('div', { className: 'flex-1' },
          e('div', { className: 'flex items-center gap-3 mb-2' },
            e(Badge, { color: typeColors[notification.type] || 'gray' },
              typeLabelMap[notification.type] || notification.type
            ),
            e('span', { className: 'text-sm text-gray-500' }, formatDate(notification.time))
          ),
          e('p', { className: 'text-xs text-gray-400' }, formatRelative(notification.time))
        )
      ),
      e('hr', { className: 'border-gray-100 mb-4' }),
      e('p', { className: 'text-gray-700 leading-relaxed' }, notification.body)
    ),

    e('div', { className: 'flex gap-3' },
      e(PrimaryButton, { onClick: function() {} }, 'Mark as read'),
      e(DangerButton,  { onClick: function() {} }, 'Delete')
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'NotificationsShow') {
    ReactDOM.createRoot(container).render(React.createElement(NotificationsShow));
  }
});
