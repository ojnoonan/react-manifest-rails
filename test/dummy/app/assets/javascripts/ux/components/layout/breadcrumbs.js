// components/layout/breadcrumbs.js
// Breadcrumb nav. Props: items [{label, href}].
// No JSX — uses React.createElement. No import/export — globals only.

var Breadcrumbs = function(props) {
  var e = React.createElement;
  var items = props.items || [];

  return e('nav', { 'aria-label': 'Breadcrumb', className: 'mb-4' },
    e('ol', { className: 'flex items-center flex-wrap gap-1 text-sm' },
      items.map(function(item, i) {
        var isLast = i === items.length - 1;
        return e('li', { key: i, className: 'flex items-center gap-1' },
          isLast
            ? e('span', { className: 'text-gray-700 font-medium', 'aria-current': 'page' }, item.label)
            : e('a', { href: item.href || '#', className: 'text-blue-600 hover:underline' }, item.label),
          !isLast ? e('span', { 'aria-hidden': 'true', className: 'text-gray-400' }, '›') : null
        );
      })
    )
  );
};
