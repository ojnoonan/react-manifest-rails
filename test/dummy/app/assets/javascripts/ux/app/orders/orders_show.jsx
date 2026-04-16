const OrdersShow = () => {
  const lineItems = [
    { id: 1, name: 'Wireless Headphones', sku: 'SKU-001', qty: 1, unit: 249.00, total: 249.00 },
    { id: 2, name: 'USB-C Cable (2m)',    sku: 'SKU-042', qty: 2, unit:   9.50, total:  19.00 },
    { id: 3, name: 'Phone Stand',         sku: 'SKU-017', qty: 1, unit:  35.00, total:  35.00 },
  ];

  const subtotal = 303.00;
  const shipping =   9.99;
  const tax      =  24.24;
  const total    = 337.23;

  return React.createElement('div', { className: 'p-6 max-w-4xl mx-auto' },

    React.createElement(Breadcrumbs, {
      items: [
        { label: 'Home',   href: '/' },
        { label: 'Orders', href: '/orders' },
        { label: '#1089',  href: '/orders/1089' },
      ]
    }),

    React.createElement(PageHeader, {
      title: 'Order #1089',
      subtitle: 'Placed 2 hours ago',
    }),

    React.createElement('div', { className: 'flex items-center gap-3 mb-6' },
      React.createElement(Badge, { color: 'yellow' }, 'Processing')
    ),

    React.createElement('div', { className: 'grid grid-cols-1 md:grid-cols-2 gap-6 mb-8' },

      React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-5' },
        React.createElement('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Customer'),
        React.createElement('p', { className: 'font-medium text-gray-900' }, 'Sarah Chen'),
        React.createElement('p', { className: 'text-gray-600 text-sm' }, 'sarah@example.com'),
        React.createElement('p', { className: 'text-gray-600 text-sm mt-1' }, '123 Main St'),
        React.createElement('p', { className: 'text-gray-600 text-sm' }, 'San Francisco, CA 94105')
      ),

      React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-5' },
        React.createElement('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Shipping Address'),
        React.createElement('p', { className: 'font-medium text-gray-900' }, 'Sarah Chen'),
        React.createElement('p', { className: 'text-gray-600 text-sm' }, '123 Main St'),
        React.createElement('p', { className: 'text-gray-600 text-sm' }, 'San Francisco, CA 94105'),
        React.createElement('p', { className: 'text-gray-600 text-sm' }, 'United States')
      )
    ),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg mb-8 overflow-hidden' },
      React.createElement('div', { className: 'px-5 py-4 border-b border-gray-100' },
        React.createElement('h2', { className: 'font-semibold text-gray-800' }, 'Line Items')
      ),
      React.createElement('table', { className: 'w-full text-sm' },
        React.createElement('thead', null,
          React.createElement('tr', { className: 'bg-gray-50 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide' },
            React.createElement('th', { className: 'px-5 py-3' }, 'Product'),
            React.createElement('th', { className: 'px-5 py-3' }, 'SKU'),
            React.createElement('th', { className: 'px-5 py-3 text-right' }, 'Qty'),
            React.createElement('th', { className: 'px-5 py-3 text-right' }, 'Unit Price'),
            React.createElement('th', { className: 'px-5 py-3 text-right' }, 'Total')
          )
        ),
        React.createElement('tbody', { className: 'divide-y divide-gray-100' },
          lineItems.map(function(item) {
            return React.createElement('tr', { key: item.id, className: 'hover:bg-gray-50' },
              React.createElement('td', { className: 'px-5 py-3 font-medium text-gray-900' }, item.name),
              React.createElement('td', { className: 'px-5 py-3 text-gray-500' }, item.sku),
              React.createElement('td', { className: 'px-5 py-3 text-right text-gray-700' }, item.qty),
              React.createElement('td', { className: 'px-5 py-3 text-right text-gray-700' }, formatCurrency(item.unit)),
              React.createElement('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' }, formatCurrency(item.total))
            );
          })
        )
      ),

      React.createElement('div', { className: 'px-5 py-4 border-t border-gray-100 bg-gray-50' },
        React.createElement('div', { className: 'ml-auto w-full max-w-xs space-y-1 text-sm' },
          React.createElement('div', { className: 'flex justify-between text-gray-600' },
            React.createElement('span', null, 'Subtotal'), React.createElement('span', null, formatCurrency(subtotal))
          ),
          React.createElement('div', { className: 'flex justify-between text-gray-600' },
            React.createElement('span', null, 'Shipping'), React.createElement('span', null, formatCurrency(shipping))
          ),
          React.createElement('div', { className: 'flex justify-between text-gray-600' },
            React.createElement('span', null, 'Tax'), React.createElement('span', null, formatCurrency(tax))
          ),
          React.createElement('div', { className: 'flex justify-between font-semibold text-gray-900 text-base border-t border-gray-200 pt-2 mt-2' },
            React.createElement('span', null, 'Total'), React.createElement('span', null, formatCurrency(total))
          )
        )
      )
    ),

    React.createElement('div', { className: 'flex gap-3' },
      React.createElement(PrimaryButton, { onClick: function() {} }, 'Mark Shipped'),
      React.createElement(DangerButton,  { onClick: function() {} }, 'Cancel Order')
    )
  );
};

window.OrdersShow = OrdersShow;
