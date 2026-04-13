var OrdersShow = function() {
  var e = React.createElement;

  var lineItems = [
    { id: 1, name: 'Wireless Headphones', sku: 'SKU-001', qty: 1, unit: 249.00, total: 249.00 },
    { id: 2, name: 'USB-C Cable (2m)',    sku: 'SKU-042', qty: 2, unit:   9.50, total:  19.00 },
    { id: 3, name: 'Phone Stand',         sku: 'SKU-017', qty: 1, unit:  35.00, total:  35.00 },
  ];

  var subtotal = 303.00;
  var shipping =   9.99;
  var tax      =  24.24;
  var total    = 337.23;

  return e('div', { className: 'p-6 max-w-4xl mx-auto' },

    e(Breadcrumbs, {
      items: [
        { label: 'Home',   href: '/' },
        { label: 'Orders', href: '/orders' },
        { label: '#1089',  href: '/orders/1089' },
      ]
    }),

    e(PageHeader, {
      title: 'Order #1089',
      subtitle: 'Placed 2 hours ago',
    }),

    e('div', { className: 'flex items-center gap-3 mb-6' },
      e(Badge, { color: 'yellow' }, 'Processing')
    ),

    e('div', { className: 'grid grid-cols-1 md:grid-cols-2 gap-6 mb-8' },

      e('div', { className: 'bg-white border border-gray-200 rounded-lg p-5' },
        e('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Customer'),
        e('p', { className: 'font-medium text-gray-900' }, 'Sarah Chen'),
        e('p', { className: 'text-gray-600 text-sm' }, 'sarah@example.com'),
        e('p', { className: 'text-gray-600 text-sm mt-1' }, '123 Main St'),
        e('p', { className: 'text-gray-600 text-sm' }, 'San Francisco, CA 94105')
      ),

      e('div', { className: 'bg-white border border-gray-200 rounded-lg p-5' },
        e('h2', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Shipping Address'),
        e('p', { className: 'font-medium text-gray-900' }, 'Sarah Chen'),
        e('p', { className: 'text-gray-600 text-sm' }, '123 Main St'),
        e('p', { className: 'text-gray-600 text-sm' }, 'San Francisco, CA 94105'),
        e('p', { className: 'text-gray-600 text-sm' }, 'United States')
      )
    ),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg mb-8 overflow-hidden' },
      e('div', { className: 'px-5 py-4 border-b border-gray-100' },
        e('h2', { className: 'font-semibold text-gray-800' }, 'Line Items')
      ),
      e('table', { className: 'w-full text-sm' },
        e('thead', null,
          e('tr', { className: 'bg-gray-50 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide' },
            e('th', { className: 'px-5 py-3' }, 'Product'),
            e('th', { className: 'px-5 py-3' }, 'SKU'),
            e('th', { className: 'px-5 py-3 text-right' }, 'Qty'),
            e('th', { className: 'px-5 py-3 text-right' }, 'Unit Price'),
            e('th', { className: 'px-5 py-3 text-right' }, 'Total')
          )
        ),
        e('tbody', { className: 'divide-y divide-gray-100' },
          lineItems.map(function(item) {
            return e('tr', { key: item.id, className: 'hover:bg-gray-50' },
              e('td', { className: 'px-5 py-3 font-medium text-gray-900' }, item.name),
              e('td', { className: 'px-5 py-3 text-gray-500' }, item.sku),
              e('td', { className: 'px-5 py-3 text-right text-gray-700' }, item.qty),
              e('td', { className: 'px-5 py-3 text-right text-gray-700' }, formatCurrency(item.unit)),
              e('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' }, formatCurrency(item.total))
            );
          })
        )
      ),

      e('div', { className: 'px-5 py-4 border-t border-gray-100 bg-gray-50' },
        e('div', { className: 'ml-auto w-full max-w-xs space-y-1 text-sm' },
          e('div', { className: 'flex justify-between text-gray-600' },
            e('span', null, 'Subtotal'), e('span', null, formatCurrency(subtotal))
          ),
          e('div', { className: 'flex justify-between text-gray-600' },
            e('span', null, 'Shipping'), e('span', null, formatCurrency(shipping))
          ),
          e('div', { className: 'flex justify-between text-gray-600' },
            e('span', null, 'Tax'), e('span', null, formatCurrency(tax))
          ),
          e('div', { className: 'flex justify-between font-semibold text-gray-900 text-base border-t border-gray-200 pt-2 mt-2' },
            e('span', null, 'Total'), e('span', null, formatCurrency(total))
          )
        )
      )
    ),

    e('div', { className: 'flex gap-3' },
      e(PrimaryButton, { onClick: function() {} }, 'Mark Shipped'),
      e(DangerButton,  { onClick: function() {} }, 'Cancel Order')
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'OrdersShow') {
    ReactDOM.createRoot(container).render(React.createElement(OrdersShow));
  }
});
