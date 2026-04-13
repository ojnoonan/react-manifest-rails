// components/data/pagination.js
// Page number nav. Props: page, totalPages, onNext, onPrev, onPage.
// No JSX — uses React.createElement. No import/export — globals only.

var Pagination = function(props) {
  var e = React.createElement;
  var page = props.page || 1;
  var totalPages = props.totalPages || 1;

  if (totalPages <= 1) return null;

  var btnCls = function(active, disabled) {
    return [
      'px-3 py-1.5 text-sm rounded-md transition-colors',
      disabled ? 'text-gray-300 cursor-not-allowed' : 'cursor-pointer',
      active ? 'bg-blue-600 text-white font-semibold' : (disabled ? '' : 'text-gray-600 hover:bg-gray-100'),
    ].join(' ');
  };

  var windowStart = Math.max(1, page - 2);
  var windowEnd = Math.min(totalPages, page + 2);
  var pageNumbers = [];
  for (var n = windowStart; n <= windowEnd; n++) { pageNumbers.push(n); }

  var items = [];

  items.push(e('button', {
    key: 'prev', type: 'button',
    className: btnCls(false, page <= 1),
    onClick: function() { if (props.onPrev) props.onPrev(); else if (props.onPage) props.onPage(page - 1); },
    disabled: page <= 1,
  }, '← Prev'));

  if (windowStart > 1) {
    items.push(e('button', { key: 1, type: 'button', className: btnCls(false, false), onClick: function() { if(props.onPage) props.onPage(1); } }, '1'));
    if (windowStart > 2) items.push(e('span', { key: 'dots1', className: 'px-1 text-gray-400' }, '…'));
  }

  pageNumbers.forEach(function(p) {
    var capturedP = p;
    items.push(e('button', {
      key: capturedP, type: 'button',
      className: btnCls(capturedP === page, false),
      onClick: function() { if (props.onPage) props.onPage(capturedP); },
    }, String(capturedP)));
  });

  if (windowEnd < totalPages) {
    if (windowEnd < totalPages - 1) items.push(e('span', { key: 'dots2', className: 'px-1 text-gray-400' }, '…'));
    items.push(e('button', { key: totalPages, type: 'button', className: btnCls(false, false), onClick: function() { if(props.onPage) props.onPage(totalPages); } }, String(totalPages)));
  }

  items.push(e('button', {
    key: 'next', type: 'button',
    className: btnCls(false, page >= totalPages),
    onClick: function() { if (props.onNext) props.onNext(); else if (props.onPage) props.onPage(page + 1); },
    disabled: page >= totalPages,
  }, 'Next →'));

  return e('nav', { className: 'flex items-center justify-center gap-1 mt-4', 'aria-label': 'Pagination' }, items);
};
