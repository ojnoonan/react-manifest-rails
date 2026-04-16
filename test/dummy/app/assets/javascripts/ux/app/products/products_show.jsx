// app/products/products_show.js
// Product detail page. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const ProductsShow = () => {
  const PRODUCT = {
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

  return React.createElement('div', { className: 'p-6 max-w-5xl mx-auto' },
    React.createElement(PageHeader, {
      title: PRODUCT.name,
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Products', href: '/products' }, { label: PRODUCT.name }],
      actions: React.createElement(React.Fragment, null,
        React.createElement(PrimaryButton, { onClick: function() {} }, 'Edit Product'),
        React.createElement(DangerButton, { onClick: function() {} }, 'Archive')
      ),
    }),

    React.createElement('div', { className: 'grid grid-cols-1 md:grid-cols-5 gap-6' },
      React.createElement('div', { className: 'md:col-span-2' },
        React.createElement('div', { className: 'bg-gradient-to-br from-blue-50 to-indigo-100 rounded-xl h-64 flex items-center justify-center text-8xl mb-4' }, '🎧'),
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-4' },
          React.createElement('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Specifications'),
          React.createElement('dl', { className: 'space-y-2' },
            PRODUCT.specs.map(function(spec) {
              return React.createElement('div', { key: spec.label, className: 'flex justify-between text-sm' },
                React.createElement('dt', { className: 'text-gray-500' }, spec.label),
                React.createElement('dd', { className: 'font-medium text-gray-900' }, spec.value)
              );
            })
          )
        )
      ),

      React.createElement('div', { className: 'md:col-span-3 space-y-4' },
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          React.createElement('div', { className: 'flex items-center justify-between mb-4' },
            React.createElement('span', { className: 'text-3xl font-bold text-gray-900' }, formatCurrency(PRODUCT.price)),
            React.createElement('div', { className: 'flex gap-2' },
              React.createElement(Badge, { variant: PRODUCT.active ? 'success' : 'gray' }, PRODUCT.active ? 'Active' : 'Inactive'),
              PRODUCT.stock <= 5 ? React.createElement(Badge, { variant: 'warning' }, 'Low stock') : null
            )
          ),
          React.createElement('dl', { className: 'grid grid-cols-2 gap-3 text-sm' },
            React.createElement('div', null, React.createElement('dt', { className: 'text-gray-500' }, 'SKU'), React.createElement('dd', { className: 'font-medium text-gray-900' }, PRODUCT.sku)),
            React.createElement('div', null, React.createElement('dt', { className: 'text-gray-500' }, 'Category'), React.createElement('dd', { className: 'font-medium text-gray-900' }, PRODUCT.category)),
            React.createElement('div', null, React.createElement('dt', { className: 'text-gray-500' }, 'Stock'), React.createElement('dd', { className: 'font-medium text-gray-900' }, PRODUCT.stock + ' units')),
            React.createElement('div', null, React.createElement('dt', { className: 'text-gray-500' }, 'Added'), React.createElement('dd', { className: 'font-medium text-gray-900' }, formatDate(PRODUCT.created)))
          )
        ),
        React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 p-5' },
          React.createElement('h3', { className: 'text-sm font-semibold text-gray-700 mb-2 uppercase tracking-wide' }, 'Description'),
          React.createElement('p', { className: 'text-sm text-gray-600 leading-relaxed' }, PRODUCT.description)
        )
      )
    )
  );
};

window.ProductsShow = ProductsShow;
