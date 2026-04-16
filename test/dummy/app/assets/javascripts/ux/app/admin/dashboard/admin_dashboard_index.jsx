const AdminDashboardIndex = () => {
  const stats = [
    { label: 'Total Revenue',            value: formatCurrency(284523), icon: '💰' },
    { label: 'Active Subscriptions',     value: '847',                  icon: '📋' },
    { label: 'Open Support Tickets',     value: '12',                   icon: '🎫' },
    { label: 'System Uptime',            value: '99.8%',                icon: '🟢' },
  ];

  const recentUsers = [
    { id: 1, name: 'Priya Sharma',    email: 'priya@acme.com',     role: 'admin',  joined: '2026-03-15' },
    { id: 2, name: 'Marcus Webb',     email: 'marcus@globex.io',   role: 'user',   joined: '2026-04-01' },
    { id: 3, name: 'Elena Voronova',  email: 'elena@initech.com',  role: 'user',   joined: '2026-04-07' },
    { id: 4, name: 'James Okafor',    email: 'james@umbrella.co',  role: 'moderator', joined: '2026-04-10' },
  ];

  const roleColors = { admin: 'red', moderator: 'yellow', user: 'gray' };

  const services = [
    { name: 'API Server',        status: 'healthy', icon: '✅', color: 'green' },
    { name: 'Database',          status: 'healthy', icon: '✅', color: 'green' },
    { name: 'Background Jobs',   status: '2 queued', icon: '⚠️', color: 'yellow' },
  ];

  const statusColors = { green: 'bg-green-100 text-green-800', yellow: 'bg-yellow-100 text-yellow-800' };

  return (
    <div className='p-6 max-w-6xl mx-auto'>
      <div className='flex items-center gap-3 mb-2'>
        <PageHeader title='Admin Dashboard' subtitle='System overview' />
        <Badge color='red'>Admin</Badge>
      </div>

      <div className='grid grid-cols-2 md:grid-cols-4 gap-4 mb-10'>
        {stats.map(function(s, i) {
          return (
            <div key={i} className='bg-white border border-gray-200 rounded-lg p-5'>
              <div className='text-2xl mb-2'>{s.icon}</div>
              <p className='text-2xl font-bold text-gray-900'>{s.value}</p>
              <p className='text-sm text-gray-500 mt-1'>{s.label}</p>
            </div>
          );
        })}
      </div>

      <div className='bg-white border border-gray-200 rounded-lg mb-8 overflow-hidden'>
        <div className='px-5 py-4 border-b border-gray-100'>
          <h2 className='font-semibold text-gray-800'>Recent Users</h2>
        </div>
        <DataTable
          columns={[
            { key: 'name', label: 'Name' },
            { key: 'email', label: 'Email' },
            {
              key: 'role',
              label: 'Role',
              render: function(val) {
                return <Badge color={roleColors[val] || 'gray'}>{val}</Badge>;
              },
            },
            {
              key: 'joined',
              label: 'Joined',
              render: function(val) { return formatDate(val); },
            },
          ]}
          rows={recentUsers}
          emptyMessage='No users.'
        />
      </div>

      <div className='bg-white border border-gray-200 rounded-lg overflow-hidden'>
        <div className='px-5 py-4 border-b border-gray-100'>
          <h2 className='font-semibold text-gray-800'>System Status</h2>
        </div>
        <div className='divide-y divide-gray-100'>
          {services.map(function(svc) {
            return (
              <div key={svc.name} className='flex items-center justify-between px-5 py-3'>
                <div className='flex items-center gap-3'>
                  <span className='text-lg'>{svc.icon}</span>
                  <span className='font-medium text-gray-800'>{svc.name}</span>
                </div>
                <span className={'text-xs font-semibold px-2.5 py-1 rounded-full ' + (statusColors[svc.color] || 'bg-gray-100 text-gray-700')}>
                  {svc.status}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

window.AdminDashboardIndex = AdminDashboardIndex;
