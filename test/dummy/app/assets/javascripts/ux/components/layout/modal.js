// components/layout/modal.js
// Centered dialog with backdrop. Props: isOpen, onClose, title, children, footer.
// No JSX — uses React.createElement. No import/export — globals only.

var Modal = function(props) {
  var e = React.createElement;

  React.useEffect(function() {
    if (props.isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return function() { document.body.style.overflow = ''; };
  }, [props.isOpen]);

  React.useEffect(function() {
    if (!props.isOpen) return;
    var handler = function(ev) { if (ev.key === 'Escape' && props.onClose) props.onClose(); };
    document.addEventListener('keydown', handler);
    return function() { document.removeEventListener('keydown', handler); };
  }, [props.isOpen]);

  if (!props.isOpen) return null;

  return e('div', {
    className: 'fixed inset-0 z-50 flex items-center justify-center p-4',
  },
    e('div', {
      className: 'fixed inset-0 bg-black/50 transition-opacity',
      onClick: props.onClose,
      'aria-hidden': 'true',
    }),
    e('div', {
      className: 'relative bg-white rounded-xl shadow-2xl w-full max-w-lg max-h-[90vh] flex flex-col',
      role: 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': 'modal-title',
      onClick: function(ev) { ev.stopPropagation(); },
    },
      e('div', { className: 'flex items-center justify-between px-6 py-4 border-b border-gray-200' },
        e('h2', { id: 'modal-title', className: 'text-lg font-semibold text-gray-900' }, props.title),
        e(IconButton, { icon: '×', label: 'Close', onClick: props.onClose })
      ),
      e('div', { className: 'flex-1 overflow-y-auto px-6 py-4' }, props.children),
      props.footer ? e('div', { className: 'flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-200' }, props.footer) : null
    )
  );
};
