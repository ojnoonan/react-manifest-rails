// app/products/products_index.js
// Products grid with filter bar. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const ProductsIndex = () => {
  const { useState } = React;
  const ALL_PRODUCTS = [
    { id: 1, name: 'Wireless Noise-Cancelling Headphones', price: 249.99, category: 'Electronics', stock: 3,  sku: 'EL-001', active: true },
    { id: 2, name: 'Ergonomic Office Chair',               price: 599.00, category: 'Furniture',   stock: 12, sku: 'FN-007', active: true },
    { id: 3, name: 'Stainless Steel Water Bottle',         price: 34.95,  category: 'Lifestyle',   stock: 87, sku: 'LS-042', active: true },
    { id: 4, name: 'Portable Bluetooth Speaker',           price: 129.00, category: 'Electronics', stock: 24, sku: 'EL-009', active: true },
    { id: 5, name: 'Organic Cotton T-Shirt',               price: 29.99,  category: 'Apparel',     stock: 0,  sku: 'AP-101', active: false },
    { id: 6, name: 'Mechanical Keyboard',                  price: 189.00, category: 'Electronics', stock: 8,  sku: 'EL-015', active: true },
  ];

  const CATEGORIES = ['All', 'Electronics', 'Furniture', 'Lifestyle', 'Apparel'];

  const searchPair = useState('');
  const search = searchPair[0];
  const setSearch = searchPair[1];
  const debouncedSearch = useDebounce(search, 300);

  const categoryPair = useState('All');
  const category = categoryPair[0];
  const setCategory = categoryPair[1];

  const filtered = ALL_PRODUCTS.filter(function(p) {
    const matchCat = category === 'All' || p.category === category;
    const matchQ = !debouncedSearch || p.name.toLowerCase().includes(debouncedSearch.toLowerCase());
    return matchCat && matchQ;
  });

  const stockBadge = (stock) => {
    if (stock === 0) return React.createElement(Badge, { variant: 'danger' }, 'Out of stock');
    if (stock <= 5) return React.createElement(Badge, { variant: 'warning' }, 'Low: ' + stock + ' left');
    return React.createElement(Badge, { variant: 'success' }, 'In stock (' + stock + ')');
  };

  return React.createElement('div', { className: 'p-6 max-w-7xl mx-auto' },
    React.createElement(PageHeader, {
      title: 'Products',
      subtitle: ALL_PRODUCTS.length + ' products in catalog',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Products' }],
      actions: React.createElement(PrimaryButton, { onClick: function() {} }, '+ Add Product'),
    }),

    React.createElement('div', { className: 'flex flex-wrap gap-3 mb-6 items-center' },
      React.createElement('div', { className: 'flex-1 min-w-48' },
        React.createElement(TextInput, { placeholder: 'Search products…', value: search, onChange: function(ev) { setSearch(ev.target.value); } })
      ),
      React.createElement('div', { className: 'flex gap-2 flex-wrap' },
        CATEGORIES.map(function(cat) {
          return React.createElement('button', {
            key: cat,
            type: 'button',
            onClick: function() { setCategory(cat); },
            className: [
              'px-3 py-1.5 text-sm rounded-full border transition-colors',
              cat === category
                ? 'bg-blue-600 text-white border-blue-600'
                : 'bg-white text-gray-600 border-gray-300 hover:border-blue-400',
            ].join(' '),
          }, cat);
        })
      )
    ),

    filtered.length === 0
      ? React.createElement(EmptyState, { icon: '🛍', title: 'No products found', message: 'Try adjusting your filters.' })
      : React.createElement('div', { className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4' },
          filtered.map(function(product) {
            return React.createElement('div', { key: product.id, className: 'bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-md transition-shadow' },
              React.createElement('div', { className: 'bg-gradient-to-br from-gray-100 to-gray-200 h-40 flex items-center justify-center text-5xl' }, '📦'),
              React.createElement('div', { className: 'p-4' },
                React.createElement('div', { className: 'flex items-start justify-between gap-2 mb-1' },
                  React.createElement('h3', { className: 'text-sm font-semibold text-gray-900 leading-tight' }, product.name),
                  React.createElement(Badge, { variant: product.active ? 'success' : 'gray' }, product.active ? 'Active' : 'Inactive')
                ),
                React.createElement('p', { className: 'text-xs text-gray-400 mb-3' }, product.sku + ' · ' + product.category),
                React.createElement('div', { className: 'flex items-center justify-between' },
                  React.createElement('span', { className: 'text-lg font-bold text-gray-900' }, formatCurrency(product.price)),
                  stockBadge(product.stock)
                ),
                React.createElement('div', { className: 'mt-3 flex gap-2' },
                  React.createElement(LinkButton, { href: '/products/' + product.id }, 'View'),
                  React.createElement(PrimaryButton, { size: 'sm', onClick: function() {} }, 'Edit')
                )
              )
            );
          })
        )
  );
};

window.ProductsIndex = ProductsIndex;
