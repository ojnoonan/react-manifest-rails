// components/data/empty_state.js
// Centered empty state illustration. Props: icon, title, message, action (ReactElement).
// No JSX — uses React.createElement. No import/export — globals only.

var EmptyState = function(props) {
  var e = React.createElement;

  return e('div', { className: 'flex flex-col items-center justify-center py-16 text-center' },
    props.icon ? e('div', { className: 'text-5xl mb-4', 'aria-hidden': 'true' }, props.icon) : null,
    props.title ? e('h3', { className: 'text-lg font-semibold text-gray-900 mb-1' }, props.title) : null,
    e('p', { className: 'text-sm text-gray-500 max-w-xs' }, props.message || 'Nothing here yet.'),
    props.action ? e('div', { className: 'mt-4' }, props.action) : null
  );
};
