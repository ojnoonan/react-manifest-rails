// components/data/pagination.js
// Page number nav. Props: page, totalPages, onNext, onPrev, onPage.
// No JSX — uses React.createElement. No import/export — globals only.

const Pagination = (props) => {
  const page = props.page || 1;
  const totalPages = props.totalPages || 1;

  if (totalPages <= 1) return null;

  const btnCls = (active, disabled) => {
    return [
      'px-3 py-1.5 text-sm rounded-md transition-colors',
      disabled ? 'text-gray-300 cursor-not-allowed' : 'cursor-pointer',
      active ? 'bg-blue-600 text-white font-semibold' : (disabled ? '' : 'text-gray-600 hover:bg-gray-100'),
    ].join(' ');
  };

  const windowStart = Math.max(1, page - 2);
  const windowEnd = Math.min(totalPages, page + 2);
  const pageNumbers = [];
  for (let n = windowStart; n <= windowEnd; n++) { pageNumbers.push(n); }

  const items = [];

  items.push(React.createElement('button', {
    key: 'prev', type: 'button',
    className: btnCls(false, page <= 1),
    onClick: function() { if (props.onPrev) props.onPrev(); else if (props.onPage) props.onPage(page - 1); },
    disabled: page <= 1,
  }, '← Prev'));

  if (windowStart > 1) {
    items.push(React.createElement('button', { key: 1, type: 'button', className: btnCls(false, false), onClick: function() { if(props.onPage) props.onPage(1); } }, '1'));
    if (windowStart > 2) items.push(React.createElement('span', { key: 'dots1', className: 'px-1 text-gray-400' }, '…'));
  }

  pageNumbers.forEach(function(p) {
    const capturedP = p;
    items.push(React.createElement('button', {
      key: capturedP, type: 'button',
      className: btnCls(capturedP === page, false),
      onClick: function() { if (props.onPage) props.onPage(capturedP); },
    }, String(capturedP)));
  });

  if (windowEnd < totalPages) {
    if (windowEnd < totalPages - 1) items.push(React.createElement('span', { key: 'dots2', className: 'px-1 text-gray-400' }, '…'));
    items.push(React.createElement('button', { key: totalPages, type: 'button', className: btnCls(false, false), onClick: function() { if(props.onPage) props.onPage(totalPages); } }, String(totalPages)));
  }

  items.push(React.createElement('button', {
    key: 'next', type: 'button',
    className: btnCls(false, page >= totalPages),
    onClick: function() { if (props.onNext) props.onNext(); else if (props.onPage) props.onPage(page + 1); },
    disabled: page >= totalPages,
  }, 'Next →'));

  return React.createElement('nav', { className: 'flex items-center justify-center gap-1 mt-4', 'aria-label': 'Pagination' }, items);
};
