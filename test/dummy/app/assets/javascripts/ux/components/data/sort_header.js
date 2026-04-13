// components/data/sort_header.js
// Table column header with sort toggle. Props: label, sortKey, currentSort, onSort.
// No JSX — uses React.createElement. No import/export — globals only.

var SortHeader = function(props) {
  var e = React.createElement;
  var currentSort = props.currentSort || {};
  var isActive = currentSort.key === props.sortKey;
  var direction = isActive ? currentSort.direction : null;

  var handleClick = function() {
    var next = isActive && direction === 'asc' ? 'desc' : 'asc';
    if (props.onSort) props.onSort({ key: props.sortKey, direction: next });
  };

  var indicator = isActive ? (direction === 'asc' ? ' ↑' : ' ↓') : ' ↕';

  return e('button', {
    type: 'button',
    onClick: handleClick,
    className: [
      'flex items-center gap-1 text-left font-semibold text-xs uppercase tracking-wide',
      isActive ? 'text-blue-600' : 'text-gray-500 hover:text-gray-700',
    ].join(' '),
  },
    props.label,
    e('span', { className: 'text-xs', 'aria-hidden': 'true' }, indicator)
  );
};
