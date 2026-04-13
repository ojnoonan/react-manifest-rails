// app/products/products_index.js
// Products grid with filter bar. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

var ProductsIndex = function() {
  var e = React.createElement;

  var ALL_PRODUCTS = [
    { id: 1, name: 'Wireless Noise-Cancelling Headphones', price: 249.99, category: 'Electronics', stock: 3,  sku: 'EL-001', active: true },
    { id: 2, name: 'Ergonomic Office Chair',               price: 599.00, category: 'Furniture',   stock: 12, sku: 'FN-007', active: true },
    { id: 3, name: 'Stainless Steel Water Bottle',         price: 34.95,  category: 'Lifestyle',   stock: 87, sku: 'LS-042', active: true },
    { id: 4, name: 'Portable Bluetooth Speaker',           price: 129.00, category: 'Electronics', stock: 24, sku: 'EL-009', active: true },
    { id: 5, name: 'Organic Cotton T-Shirt',               price: 29.99,  category: 'Apparel',     stock: 0,  sku: 'AP-101', active: false },
    { id: 6, name: 'Mechanical Keyboard',                  price: 189.00, category: 'Electronics', stock: 8,  sku: 'EL-015', active: true },
  ];

  var CATEGORIES = ['All', 'Electronics', 'Furniture', 'Lifestyle', 'Apparel'];

  var searchPair = React.useState('');
  var search = searchPair[0];
  var setSearch = searchPair[1];
  var debouncedSearch = useDebounce(search, 300);

  var categoryPair = React.useState('All');
  var category = categoryPair[0];
  var setCategory = categoryPair[1];

  var filtered = ALL_PRODUCTS.filter(function(p) {
    var matchCat = category === 'All' || p.category === category;
    var matchQ = !debouncedSearch || p.name.toLowerCase().includes(debouncedSearch.toLowerCase());
    return matchCat && matchQ;
  });

  var stockBadge = function(stock) {
    if (stock === 0) return e(Badge, { variant: 'danger' }, 'Out of stock');
    if (stock <= 5) return e(Badge, { variant: 'warning' }, 'Low: ' + stock + ' left');
    return e(Badge, { variant: 'success' }, 'In stock (' + stock + ')');
  };

  return e('div', { className: 'p-6 max-w-7xl mx-auto' },
    e(PageHeader, {
      title: 'Products',
      subtitle: ALL_PRODUCTS.length + ' products in catalog',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Products' }],
      actions: e(PrimaryButton, { onClick: function() {} }, '+ Add Product'),
    }),

    e('div', { className: 'flex flex-wrap gap-3 mb-6 items-center' },
      e('div', { className: 'flex-1 min-w-48' },
        e(TextInput, { placeholder: 'Search products…', value: search, onChange: function(ev) { setSearch(ev.target.value); } })
      ),
      e('div', { className: 'flex gap-2 flex-wrap' },
        CATEGORIES.map(function(cat) {
          return e('button', {
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
      ? e(EmptyState, { icon: '🛍', title: 'No products found', message: 'Try adjusting your filters.' })
      : e('div', { className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4' },
          filtered.map(function(product) {
            return e('div', { key: product.id, className: 'bg-white rounded-xl border border-gray-200 overflow-hidden hover:shadow-md transition-shadow' },
              e('div', { className: 'bg-gradient-to-br from-gray-100 to-gray-200 h-40 flex items-center justify-center text-5xl' }, '📦'),
              e('div', { className: 'p-4' },
                e('div', { className: 'flex items-start justify-between gap-2 mb-1' },
                  e('h3', { className: 'text-sm font-semibold text-gray-900 leading-tight' }, product.name),
                  e(Badge, { variant: product.active ? 'success' : 'gray' }, product.active ? 'Active' : 'Inactive')
                ),
                e('p', { className: 'text-xs text-gray-400 mb-3' }, product.sku + ' · ' + product.category),
                e('div', { className: 'flex items-center justify-between' },
                  e('span', { className: 'text-lg font-bold text-gray-900' }, formatCurrency(product.price)),
                  stockBadge(product.stock)
                ),
                e('div', { className: 'mt-3 flex gap-2' },
                  e(LinkButton, { href: '/products/' + product.id }, 'View'),
                  e(PrimaryButton, { size: 'sm', onClick: function() {} }, 'Edit')
                )
              )
            );
          })
        )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'ProductsIndex') {
    ReactDOM.createRoot(container).render(React.createElement(ProductsIndex));
  }
});
