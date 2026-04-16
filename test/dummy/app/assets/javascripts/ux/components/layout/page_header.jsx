// components/layout/page_header.js
// Page title bar with optional subtitle, breadcrumbs, and action buttons.
// No JSX — uses React.createElement. No import/export — globals only.

const PageHeader = (props) => {
  const breadcrumbs = props.breadcrumbs || [];

  return React.createElement('div', { className: 'mb-6' },
    breadcrumbs.length > 0 ? React.createElement('nav', { className: 'flex items-center gap-2 text-sm text-gray-500 mb-2', 'aria-label': 'Breadcrumb' },
      breadcrumbs.map(function(crumb, i) {
        const isLast = i === breadcrumbs.length - 1;
        return React.createElement(React.Fragment, { key: i },
          isLast
            ? React.createElement('span', { className: 'text-gray-700 font-medium', 'aria-current': 'page' }, crumb.label)
            : React.createElement('a', { href: crumb.href, className: 'hover:text-gray-700 hover:underline' }, crumb.label),
          !isLast ? React.createElement('span', { 'aria-hidden': 'true', className: 'mx-1' }, '/') : null
        );
      })
    ) : null,
    React.createElement('div', { className: 'flex items-start justify-between gap-4' },
      React.createElement('div', null,
        React.createElement('h1', { className: 'text-2xl font-bold text-gray-900' }, props.title),
        props.subtitle ? React.createElement('p', { className: 'mt-1 text-sm text-gray-500' }, props.subtitle) : null
      ),
      props.actions ? React.createElement('div', { className: 'flex items-center gap-2 flex-shrink-0' }, props.actions) : null
    )
  );
};
