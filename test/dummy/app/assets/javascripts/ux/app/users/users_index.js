// app/users/users_index.js
// Users list page with search, sort, and pagination. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

var UsersIndex = function() {
  var e = React.createElement;

  var ALL_USERS = [
    { id: 1,  name: 'Sarah Chen',       email: 'sarah.chen@example.com',      role: 'admin',     status: 'active',   joined: '2023-01-15' },
    { id: 2,  name: 'Marcus Johnson',   email: 'marcus.j@acmecorp.com',        role: 'user',      status: 'active',   joined: '2023-03-22' },
    { id: 3,  name: 'Priya Patel',      email: 'priya.patel@startupxyz.io',    role: 'moderator', status: 'active',   joined: '2023-05-10' },
    { id: 4,  name: 'Tyler Brooks',     email: 'tbrooks@freelance.me',         role: 'user',      status: 'inactive', joined: '2023-07-04' },
    { id: 5,  name: 'Emma Wilson',      email: 'emma.w@globaltech.com',        role: 'user',      status: 'active',   joined: '2023-08-19' },
    { id: 6,  name: 'James Rodriguez',  email: 'jrodriguez@mediahouse.co',     role: 'user',      status: 'active',   joined: '2023-09-01' },
    { id: 7,  name: 'Aisha Mohammed',   email: 'a.mohammed@researchlabs.org',  role: 'admin',     status: 'active',   joined: '2023-10-14' },
    { id: 8,  name: 'Chris Nakamura',   email: 'cnakamura@designstudio.net',   role: 'user',      status: 'suspended', joined: '2024-01-07' },
  ];

  var searchPair = React.useState('');
  var search = searchPair[0];
  var setSearch = searchPair[1];
  var debouncedSearch = useDebounce(search, 300);

  var sortPair = React.useState({ key: 'name', direction: 'asc' });
  var sort = sortPair[0];
  var setSort = sortPair[1];

  var deleteModalState = useModal();

  var filtered = ALL_USERS.filter(function(u) {
    if (!debouncedSearch) return true;
    var q = debouncedSearch.toLowerCase();
    return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
  }).sort(function(a, b) {
    var valA = a[sort.key] || '';
    var valB = b[sort.key] || '';
    return sort.direction === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
  });

  var pager = usePagination(filtered, 5);

  var roleVariant = function(role) { return { admin: 'danger', moderator: 'warning', user: 'info' }[role] || 'gray'; };
  var statusVariant = function(s) { return { active: 'success', inactive: 'gray', suspended: 'danger' }[s] || 'gray'; };

  var columns = [
    { key: 'name',   label: 'Name',   sortable: true },
    { key: 'email',  label: 'Email',  sortable: true },
    { key: 'role',   label: 'Role',   render: function(v) { return e(Badge, { variant: roleVariant(v) }, v); } },
    { key: 'status', label: 'Status', render: function(v) { return e(Badge, { variant: statusVariant(v) }, v); } },
    { key: 'joined', label: 'Joined', render: function(v) { return formatDate(v); } },
    { key: 'id',     label: 'Actions', render: function(id, row) {
      return e('div', { className: 'flex gap-2' },
        e(LinkButton, { href: '/users/' + id }, 'View'),
        e(LinkButton, { href: '/users/' + id + '/edit' }, 'Edit')
      );
    }},
  ];

  return e('div', { className: 'p-6 max-w-7xl mx-auto' },
    e(PageHeader, {
      title: 'Users',
      subtitle: ALL_USERS.length + ' total users',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users' }],
      actions: e(PrimaryButton, { onClick: function() {} }, '+ New User'),
    }),
    e('div', { className: 'bg-white rounded-xl border border-gray-200 overflow-hidden' },
      e('div', { className: 'p-4 border-b border-gray-100' },
        e(TextInput, {
          placeholder: 'Search by name or email…',
          value: search,
          onChange: function(ev) { setSearch(ev.target.value); },
        })
      ),
      e(DataTable, {
        columns: columns,
        rows: pager.currentItems,
        sort: sort,
        onSort: setSort,
        emptyMessage: 'No users match your search.',
      }),
      e('div', { className: 'px-4 py-3 border-t border-gray-100 flex items-center justify-between text-sm text-gray-500' },
        e('span', null, 'Showing ' + pager.currentItems.length + ' of ' + filtered.length + ' users'),
        e(Pagination, { page: pager.page, totalPages: pager.totalPages, onPage: pager.goToPage, onNext: pager.nextPage, onPrev: pager.prevPage })
      )
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'UsersIndex') {
    ReactDOM.createRoot(container).render(React.createElement(UsersIndex));
  }
});
