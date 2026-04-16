// components/layout/breadcrumbs.js
// Breadcrumb nav. Props: items [{label, href}].
// No JSX — uses React.createElement. No import/export — globals only.

const Breadcrumbs = (props) => {
  const items = props.items || [];

  return React.createElement('nav', { 'aria-label': 'Breadcrumb', className: 'mb-4' },
    React.createElement('ol', { className: 'flex items-center flex-wrap gap-1 text-sm' },
      items.map(function(item, i) {
        const isLast = i === items.length - 1;
        return React.createElement('li', { key: i, className: 'flex items-center gap-1' },
          isLast
            ? React.createElement('span', { className: 'text-gray-700 font-medium', 'aria-current': 'page' }, item.label)
            : React.createElement('a', { href: item.href || '#', className: 'text-blue-600 hover:underline' }, item.label),
          !isLast ? React.createElement('span', { 'aria-hidden': 'true', className: 'text-gray-400' }, '›') : null
        );
      })
    )
  );
};
