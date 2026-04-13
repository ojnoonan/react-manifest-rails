// app/products/products_show.js
// Product detail page. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

var ProductsShow = function() {
  var e = React.createElement;

  var PRODUCT = {
    id: 1, name: 'Wireless Noise-Cancelling Headphones',
    sku: 'EL-001', price: 249.99, stock: 3,
    category: 'Electronics', active: true,
    description: 'Industry-leading noise cancellation lets you immerse yourself in music, no matter where you are. With 30-hour battery life and quick-charge, you can listen all day. Premium drivers deliver crisp highs and deep, powerful bass for an immersive listening experience.',
    specs: [
      { label: 'Battery Life', value: '30 hours' },
      { label: 'Connectivity', value: 'Bluetooth 5.0' },
      { label: 'Weight', value: '250g' },
      { label: 'Warranty', value: '2 years' },
    ],
    created: '2023-08-20',
  };

  return e('div', { className: 'p-6 max-w-5xl mx-auto' },
    e(PageHeader, {
      title: PRODUCT.name,
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Products', href: '/products' }, { label: PRODUCT.name }],
      actions: React.createElement(React.Fragment, null,
        e(PrimaryButton, { onClick: function() {} }, 'Edit Product'),
        e(DangerButton, { onClick: function() {} }, 'Archive')
      ),
    }),

    e('div', { className: 'grid grid-cols-1 md:grid-cols-5 gap-6' },
      e('div', { className: 'md:col-span-2' },
        e('div', { className: 'bg-gradient-to-br from-blue-50 to-indigo-100 rounded-xl h-64 flex items-center justify-center text-8xl mb-4' }, '🎧'),
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-4' },
          e('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Specifications'),
          e('dl', { className: 'space-y-2' },
            PRODUCT.specs.map(function(spec) {
              return e('div', { key: spec.label, className: 'flex justify-between text-sm' },
                e('dt', { className: 'text-gray-500' }, spec.label),
                e('dd', { className: 'font-medium text-gray-900' }, spec.value)
              );
            })
          )
        )
      ),

      e('div', { className: 'md:col-span-3 space-y-4' },
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          e('div', { className: 'flex items-center justify-between mb-4' },
            e('span', { className: 'text-3xl font-bold text-gray-900' }, formatCurrency(PRODUCT.price)),
            e('div', { className: 'flex gap-2' },
              e(Badge, { variant: PRODUCT.active ? 'success' : 'gray' }, PRODUCT.active ? 'Active' : 'Inactive'),
              PRODUCT.stock <= 5 ? e(Badge, { variant: 'warning' }, 'Low stock') : null
            )
          ),
          e('dl', { className: 'grid grid-cols-2 gap-3 text-sm' },
            e('div', null, e('dt', { className: 'text-gray-500' }, 'SKU'), e('dd', { className: 'font-medium text-gray-900' }, PRODUCT.sku)),
            e('div', null, e('dt', { className: 'text-gray-500' }, 'Category'), e('dd', { className: 'font-medium text-gray-900' }, PRODUCT.category)),
            e('div', null, e('dt', { className: 'text-gray-500' }, 'Stock'), e('dd', { className: 'font-medium text-gray-900' }, PRODUCT.stock + ' units')),
            e('div', null, e('dt', { className: 'text-gray-500' }, 'Added'), e('dd', { className: 'font-medium text-gray-900' }, formatDate(PRODUCT.created)))
          )
        ),
        e('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          e('h3', { className: 'text-sm font-semibold text-gray-700 mb-2 uppercase tracking-wide' }, 'Description'),
          e('p', { className: 'text-sm text-gray-600 leading-relaxed' }, PRODUCT.description)
        )
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'ProductsShow') {
    ReactDOM.createRoot(container).render(React.createElement(ProductsShow));
  }
});
