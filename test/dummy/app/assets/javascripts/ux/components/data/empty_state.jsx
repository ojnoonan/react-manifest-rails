// components/data/empty_state.js
// Centered empty state illustration. Props: icon, title, message, action (ReactElement).
// No JSX — uses React.createElement. No import/export — globals only.

const EmptyState = (props) => {

  return React.createElement('div', { className: 'flex flex-col items-center justify-center py-16 text-center' },
    props.icon ? React.createElement('div', { className: 'text-5xl mb-4', 'aria-hidden': 'true' }, props.icon) : null,
    props.title ? React.createElement('h3', { className: 'text-lg font-semibold text-gray-900 mb-1' }, props.title) : null,
    React.createElement('p', { className: 'text-sm text-gray-500 max-w-xs' }, props.message || 'Nothing here yet.'),
    props.action ? React.createElement('div', { className: 'mt-4' }, props.action) : null
  );
};
