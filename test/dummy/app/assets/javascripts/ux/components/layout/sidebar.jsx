// components/layout/sidebar.js
// Navigation sidebar. Props: items [{label, icon, href, active}].
// No JSX — uses React.createElement. No import/export — globals only.

const Sidebar = (props) => {
  const items = props.items || [];

  return React.createElement('nav', { className: 'flex flex-col w-56 bg-gray-900 min-h-screen py-4', 'aria-label': 'Sidebar' },
    props.logo ? React.createElement('div', { className: 'px-4 mb-6' }, props.logo) : null,
    React.createElement('ul', { className: 'flex-1 px-2 space-y-1' },
      items.map(function(item) {
        const isActive = item.active || (window.location.pathname === item.href);
        const linkCls = [
          'flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors',
          isActive
            ? 'bg-gray-700 text-white'
            : 'text-gray-300 hover:bg-gray-800 hover:text-white',
        ].join(' ');

        return React.createElement('li', { key: item.href || item.label },
          React.createElement('a', { href: item.href || '#', className: linkCls },
            item.icon ? React.createElement('span', { className: 'text-lg w-5 text-center', 'aria-hidden': 'true' }, item.icon) : null,
            React.createElement('span', null, item.label),
            item.badge ? React.createElement(Badge, { variant: 'info', label: String(item.badge) }) : null
          )
        );
      })
    )
  );
};
