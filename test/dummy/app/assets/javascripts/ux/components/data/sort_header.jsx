// components/data/sort_header.js
// Table column header with sort toggle. Props: label, sortKey, currentSort, onSort.
// No JSX — uses React.createElement. No import/export — globals only.

const SortHeader = (props) => {
  const currentSort = props.currentSort || {};
  const isActive = currentSort.key === props.sortKey;
  const direction = isActive ? currentSort.direction : null;

  const handleClick = () => {
    const next = isActive && direction === 'asc' ? 'desc' : 'asc';
    if (props.onSort) props.onSort({ key: props.sortKey, direction: next });
  };

  const indicator = isActive ? (direction === 'asc' ? ' ↑' : ' ↓') : ' ↕';

  return React.createElement('button', {
    type: 'button',
    onClick: handleClick,
    className: [
      'flex items-center gap-1 text-left font-semibold text-xs uppercase tracking-wide',
      isActive ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700',
    ].join(' '),
  },
    props.label,
    React.createElement('span', { className: 'text-xs', 'aria-hidden': 'true' }, indicator)
  );
};
