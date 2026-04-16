// app/users/users_index.js
// Users list page with search, sort, and pagination. Mounted on #react-app.
// No JSX — uses React.createElement. No import/export — globals only.

const UsersIndex = () => {
  const { useState, useMemo } = React;
  const ALL_USERS = [
    { id: 1,  name: 'Sarah Chen',       email: 'sarah.chen@example.com',      role: 'admin',     status: 'active',   joined: '2023-01-15' },
    { id: 2,  name: 'Marcus Johnson',   email: 'marcus.j@acmecorp.com',        role: 'user',      status: 'active',   joined: '2023-03-22' },
    { id: 3,  name: 'Priya Patel',      email: 'priya.patel@startupxyz.io',    role: 'moderator', status: 'active',   joined: '2023-05-10' },
    { id: 4,  name: 'Tyler Brooks',     email: 'tbrooks@freelance.me',         role: 'user',      status: 'inactive', joined: '2023-07-04' },
    { id: 5,  name: 'Emma Wilson',      email: 'emma.w@globaltech.com',        role: 'user',      status: 'active',   joined: '2023-08-19' },
    { id: 6,  name: 'James Rodriguez',  email: 'jrodriguez@mediahouse.co',     role: 'user',      status: 'active',   joined: '2023-09-01' },
    { id: 7,  name: 'Aisha Mohammed',   email: 'a.mohammed@researchlabs.org',  role: 'admin',     status: 'active',   joined: '2023-10-14' },
    { id: 8,  name: 'Chris Nakamura',   email: 'cnakamura@designstudio.net',   role: 'user',      status: 'suspended', joined: '2024-01-07' },
  ];

  const searchPair = useState('');
  const search = searchPair[0];
  const setSearch = searchPair[1];
  const debouncedSearch = useDebounce(search, 300);

  const sortPair = useState({ key: 'name', direction: 'asc' });
  const sort = sortPair[0];
  const setSort = sortPair[1];

  const deleteModalState = useModal();

  const searchable = useMemo(function() {
    if (typeof MiniSearch === 'undefined') return null;

    const index = new MiniSearch({
      fields: ['name', 'email', 'role', 'status'],
      storeFields: ['id', 'name', 'email', 'role', 'status', 'joined'],
      searchOptions: { prefix: true }
    });

    index.addAll(ALL_USERS);
    return index;
  }, []);

  const searched = !debouncedSearch
    ? ALL_USERS
    : searchable
      ? searchable.search(debouncedSearch, { prefix: true, fuzzy: 0.2 }).map(function(hit) {
          return {
            id: hit.id,
            name: hit.name,
            email: hit.email,
            role: hit.role,
            status: hit.status,
            joined: hit.joined,
          };
        })
      : ALL_USERS.filter(function(u) {
          const q = debouncedSearch.toLowerCase();
          return u.name.toLowerCase().includes(q) || u.email.toLowerCase().includes(q);
        });

  const filtered = searched.sort(function(a, b) {
    const valA = a[sort.key] || '';
    const valB = b[sort.key] || '';
    return sort.direction === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
  });

  const pager = usePagination(filtered, 5);

  const roleVariant = (role) => { return { admin: 'danger', moderator: 'warning', user: 'info' }[role] || 'gray'; };
  const statusVariant = (s) => { return { active: 'success', inactive: 'gray', suspended: 'danger' }[s] || 'gray'; };

  const columns = [
    { key: 'name',   label: 'Name',   sortable: true },
    { key: 'email',  label: 'Email',  sortable: true },
    { key: 'role',   label: 'Role',   render: function(v) { return React.createElement(Badge, { variant: roleVariant(v) }, v); } },
    { key: 'status', label: 'Status', render: function(v) { return React.createElement(Badge, { variant: statusVariant(v) }, v); } },
    { key: 'joined', label: 'Joined', render: function(v) { return formatDate(v); } },
    { key: 'id',     label: 'Actions', render: function(id, row) {
      return React.createElement('div', { className: 'flex gap-2' },
        React.createElement(LinkButton, { href: '/users/' + id }, 'View'),
        React.createElement(LinkButton, { href: '/users/' + id + '/edit' }, 'Edit')
      );
    }},
  ];

  return React.createElement('div', { className: 'p-6 max-w-7xl mx-auto' },
    React.createElement(PageHeader, {
      title: 'Users',
      subtitle: ALL_USERS.length + ' total users',
      breadcrumbs: [{ label: 'Home', href: '/' }, { label: 'Users' }],
      actions: React.createElement(PrimaryButton, { onClick: function() {} }, '+ New User'),
    }),
    React.createElement('div', { className: 'bg-white rounded-xl border border-gray-200 overflow-hidden' },
      React.createElement('div', { className: 'p-4 border-b border-gray-100' },
        React.createElement(TextInput, {
          placeholder: 'Search by name or email…',
          value: search,
          onChange: function(ev) { setSearch(ev.target.value); },
        })
      ),
      React.createElement(DataTable, {
        columns: columns,
        rows: pager.currentItems,
        sort: sort,
        onSort: setSort,
        emptyMessage: 'No users match your search.',
      }),
      React.createElement('div', { className: 'px-4 py-3 border-t border-gray-100 flex items-center justify-between text-sm text-gray-500' },
        React.createElement('span', null, 'Showing ' + pager.currentItems.length + ' of ' + filtered.length + ' users'),
        React.createElement(Pagination, { page: pager.page, totalPages: pager.totalPages, onPage: pager.goToPage, onNext: pager.nextPage, onPrev: pager.prevPage })
      )
    )
  );
};

window.UsersIndex = UsersIndex;
