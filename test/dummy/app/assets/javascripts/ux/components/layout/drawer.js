// components/layout/drawer.js
// Slide-in panel from the right. Props: isOpen, onClose, title, children.
// No JSX — uses React.createElement. No import/export — globals only.

var Drawer = function(props) {
  var e = React.createElement;

  React.useEffect(function() {
    if (!props.isOpen) return;
    var handler = function(ev) { if (ev.key === 'Escape' && props.onClose) props.onClose(); };
    document.addEventListener('keydown', handler);
    return function() { document.removeEventListener('keydown', handler); };
  }, [props.isOpen]);

  if (!props.isOpen) return null;

  return e('div', { className: 'fixed inset-0 z-50 flex justify-end' },
    e('div', {
      className: 'fixed inset-0 bg-black/40',
      onClick: props.onClose,
      'aria-hidden': 'true',
    }),
    e('div', {
      className: 'relative flex flex-col w-full max-w-md bg-white shadow-2xl h-full',
      role: 'dialog',
      'aria-modal': 'true',
    },
      e('div', { className: 'flex items-center justify-between px-6 py-4 border-b border-gray-200' },
        e('h2', { className: 'text-lg font-semibold text-gray-900' }, props.title),
        e(IconButton, { icon: '×', label: 'Close', onClick: props.onClose })
      ),
      e('div', { className: 'flex-1 overflow-y-auto px-6 py-4' }, props.children)
    )
  );
};
