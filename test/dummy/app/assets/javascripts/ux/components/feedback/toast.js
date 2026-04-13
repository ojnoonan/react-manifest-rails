// components/feedback/toast.js
// Toast notification system. Provides useToast() hook + ToastContainer component.
// No JSX — uses React.createElement. No import/export — globals only.

var _Toast = function(props) {
  var e = React.createElement;
  var variantClasses = {
    success: 'bg-green-600',
    warning: 'bg-yellow-500',
    danger:  'bg-red-600',
    info:    'bg-blue-600',
  };
  var bg = variantClasses[props.variant || 'info'] || variantClasses.info;
  var icons = { success: '✓', warning: '⚠', danger: '✕', info: 'ℹ' };
  var icon = icons[props.variant || 'info'];

  React.useEffect(function() {
    var duration = props.duration != null ? props.duration : 4000;
    if (!duration) return;
    var t = setTimeout(function() { if (props.onRemove) props.onRemove(); }, duration);
    return function() { clearTimeout(t); };
  }, []);

  return e('div', {
    className: 'flex items-center gap-3 ' + bg + ' text-white px-4 py-3 rounded-lg shadow-lg min-w-64 max-w-sm',
    role: 'alert',
  },
    e('span', { className: 'text-lg font-bold', 'aria-hidden': 'true' }, icon),
    e('p', { className: 'flex-1 text-sm font-medium' }, props.message),
    e('button', {
      type: 'button',
      onClick: props.onRemove,
      className: 'ml-2 text-white/70 hover:text-white text-lg leading-none',
      'aria-label': 'Dismiss',
    }, '×')
  );
};

var ToastContainer = function(props) {
  var e = React.createElement;
  var toasts = props.toasts || [];
  return e('div', {
    className: 'fixed bottom-4 right-4 flex flex-col gap-2 z-50',
    'aria-live': 'polite',
  },
    toasts.map(function(t) {
      return e(_Toast, {
        key: t.id,
        message: t.message,
        variant: t.variant,
        duration: t.duration,
        onRemove: function() { if (props.removeToast) props.removeToast(t.id); },
      });
    })
  );
};

function useToast() {
  var pair = React.useState([]);
  var toasts = pair[0];
  var setToasts = pair[1];
  var nextId = React.useRef(1);

  var addToast = function(message, variant, duration) {
    var id = nextId.current++;
    setToasts(function(prev) {
      return prev.concat([{ id: id, message: message, variant: variant || 'info', duration: duration }]);
    });
  };

  var removeToast = function(id) {
    setToasts(function(prev) { return prev.filter(function(t) { return t.id !== id; }); });
  };

  return { toasts: toasts, addToast: addToast, removeToast: removeToast };
}
