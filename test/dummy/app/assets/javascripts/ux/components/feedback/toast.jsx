// components/feedback/toast.js
// Toast notification system. Provides useToast() hook + ToastContainer component.
// No JSX — uses React.createElement. No import/export — globals only.

const _Toast = (props) => {
  const { useEffect } = React;
  const variantClasses = {
    success: 'bg-green-600',
    warning: 'bg-yellow-500',
    danger:  'bg-red-600',
    info:    'bg-blue-600',
  };
  const bg = variantClasses[props.variant || 'info'] || variantClasses.info;
  const icons = { success: '✓', warning: '⚠', danger: '✕', info: 'ℹ' };
  const icon = icons[props.variant || 'info'];

  useEffect(function() {
    const duration = props.duration != null ? props.duration : 4000;
    if (!duration) return;
    const t = setTimeout(function() { if (props.onRemove) props.onRemove(); }, duration);
    return function() { clearTimeout(t); };
  }, []);

  return React.createElement('div', {
    className: 'flex items-center gap-3 ' + bg + ' text-white px-4 py-3 rounded-lg shadow-lg min-w-64 max-w-sm',
    role: 'alert',
  },
    React.createElement('span', { className: 'text-lg font-bold', 'aria-hidden': 'true' }, icon),
    React.createElement('p', { className: 'flex-1 text-sm font-medium' }, props.message),
    React.createElement('button', {
      type: 'button',
      onClick: props.onRemove,
      className: 'ml-2 text-white/70 hover:text-white text-lg leading-none',
      'aria-label': 'Dismiss',
    }, '×')
  );
};

const ToastContainer = (props) => {
  const toasts = props.toasts || [];
  return React.createElement('div', {
    className: 'fixed bottom-4 right-4 flex flex-col gap-2 z-50',
    'aria-live': 'polite',
  },
    toasts.map(function(t) {
      return React.createElement(_Toast, {
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
  const { useRef, useState } = React;
  const pair = useState([]);
  const toasts = pair[0];
  const setToasts = pair[1];
  const nextId = useRef(1);

  const addToast = (message, variant, duration) => {
    const id = nextId.current++;
    setToasts(function(prev) {
      return prev.concat([{ id: id, message: message, variant: variant || 'info', duration: duration }]);
    });
  };

  const removeToast = (id) => {
    setToasts(function(prev) { return prev.filter(function(t) { return t.id !== id; }); });
  };

  return { toasts: toasts, addToast: addToast, removeToast: removeToast };
}
