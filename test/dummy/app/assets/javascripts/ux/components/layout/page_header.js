// components/layout/page_header.js
// Page title bar with optional subtitle, breadcrumbs, and action buttons.
// No JSX — uses React.createElement. No import/export — globals only.

var PageHeader = function(props) {
  var e = React.createElement;
  var breadcrumbs = props.breadcrumbs || [];

  return e('div', { className: 'mb-6' },
    breadcrumbs.length > 0 ? e('nav', { className: 'flex items-center gap-2 text-sm text-gray-500 mb-2', 'aria-label': 'Breadcrumb' },
      breadcrumbs.map(function(crumb, i) {
        var isLast = i === breadcrumbs.length - 1;
        return e(React.Fragment, { key: i },
          isLast
            ? e('span', { className: 'text-gray-700 font-medium', 'aria-current': 'page' }, crumb.label)
            : e('a', { href: crumb.href, className: 'hover:text-gray-700 hover:underline' }, crumb.label),
          !isLast ? e('span', { 'aria-hidden': 'true', className: 'mx-1' }, '/') : null
        );
      })
    ) : null,
    e('div', { className: 'flex items-start justify-between gap-4' },
      e('div', null,
        e('h1', { className: 'text-2xl font-bold text-gray-900' }, props.title),
        props.subtitle ? e('p', { className: 'mt-1 text-sm text-gray-500' }, props.subtitle) : null
      ),
      props.actions ? e('div', { className: 'flex items-center gap-2 flex-shrink-0' }, props.actions) : null
    )
  );
};
