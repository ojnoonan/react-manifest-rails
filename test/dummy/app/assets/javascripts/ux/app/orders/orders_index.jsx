// app/orders/orders_index.js
// Orders list with status filter. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const OrdersIndex = () => {
  const { useState } = React;
  const ALL_ORDERS = [
    { id: 1, number: '1089', customer: 'Sarah Chen',      total: 498.00,  status: 'pending',   date: '2026-04-13' },
    { id: 2, number: '1088', customer: 'Marcus Johnson',  total: 129.99,  status: 'paid',      date: '2026-04-12' },
    { id: 3, number: '1087', customer: 'Priya Patel',     total: 849.00,  status: 'paid',      date: '2026-04-11' },
    { id: 4, number: '1086', customer: 'Tyler Brooks',    total: 34.95,   status: 'cancelled', date: '2026-04-10' },
    { id: 5, number: '1085', customer: 'Emma Wilson',     total: 2340.00, status: 'paid',      date: '2026-04-09' },
    { id: 6, number: '1084', customer: 'James Rodriguez', total: 189.00,  status: 'shipped',   date: '2026-04-08' },
  ];

  const statusPair = useState('');
  const statusFilter = statusPair[0];
  const setStatusFilter = statusPair[1];

  const sortPair = useState({ key: 'date', direction: 'desc' });
  const sort = sortPair[0];
  const setSort = sortPair[1];

  const statusVariant = (s) => {
    return { pending: 'warning', paid: 'success', cancelled: 'danger', shipped: 'info' }[s] || 'gray';
  };

  const filtered = ALL_ORDERS.filter(function(o) {
    return !statusFilter || o.status === statusFilter;
  });

  const columns = [
    { key: 'number',   label: 'Order #',  sortable: true, render: function(v) { return React.createElement('span', { className: 'font-mono font-medium' }, '#' + v); } },
    { key: 'customer', label: 'Customer', sortable: true },
    { key: 'total',    label: 'Total',    sortable: true, render: function(v) { return React.createElement('span', { className: 'font-semibold' }, formatCurrency(v)); } },
    { key: 'status',   label: 'Status',   render: function(v) { return React.createElement(Badge, { variant: statusVariant(v) }, v); } },
    { key: 'date',     label: 'Date',     sortable: true, render: function(v) { return formatDate(v); } },
    { key: 'id',       label: 'Actions',  render: function(id) { return React.createElement(LinkButton, { href: '/orders/' + id }, 'View'); } },
  ];

  return React.createElement('div', { className: 'p-6 max-w-7xl mx-auto' },
    React.createElement(PageHeader, {
      title: 'Orders',
      subtitle: ALL_ORDERS.length + ' total orders',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Orders' }],
      actions: React.createElement(PrimaryButton, { onClick: function() { window.location = '/orders/new'; } }, '+ New Order'),
    }),

    React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 overflow-hidden' },
      React.createElement('div', { className: 'p-4 border-b border-gray-100 flex gap-4 items-end' },
        React.createElement('div', { className: 'w-48' },
          React.createElement(SelectInput, {
            label: 'Status',
            value: statusFilter,
            onChange: function(ev) { setStatusFilter(ev.target.value); },
            placeholder: 'All statuses',
            options: [
              { value: 'pending', label: 'Pending' },
              { value: 'paid', label: 'Paid' },
              { value: 'shipped', label: 'Shipped' },
              { value: 'cancelled', label: 'Cancelled' },
            ],
          })
        ),
        statusFilter ? React.createElement(LinkButton, { onClick: function() { setStatusFilter(''); } }, 'Clear filter') : null
      ),
      React.createElement(DataTable, {
        columns: columns,
        rows: filtered,
        sort: sort,
        onSort: setSort,
        emptyMessage: 'No orders match the selected filter.',
      }),
      React.createElement('div', { className: 'px-4 py-3 border-t border-gray-100 text-sm text-gray-500' },
        'Showing ' + filtered.length + ' of ' + ALL_ORDERS.length + ' orders'
      )
    )
  );
};

window.OrdersIndex = OrdersIndex;
