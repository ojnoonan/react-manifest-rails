// components/feedback/alert.js
// Dismissible alert banner. Props: variant, title, children, onDismiss.
// No JSX — uses React.createElement. No import/export — globals only.

var Alert = function(props) {
  var e = React.createElement;
  var dismissedPair = React.useState(false);
  var dismissed = dismissedPair[0];
  var setDismissed = dismissedPair[1];

  if (dismissed) return null;

  var variantConfig = {
    success: { bg: 'bg-green-50 border-green-400', text: 'text-green-800', icon: '✓' },
    warning: { bg: 'bg-yellow-50 border-yellow-400', text: 'text-yellow-800', icon: '⚠' },
    danger:  { bg: 'bg-red-50 border-red-400',    text: 'text-red-800',   icon: '✕' },
    info:    { bg: 'bg-blue-50 border-blue-400',   text: 'text-blue-800',  icon: 'ℹ' },
  };
  var cfg = variantConfig[props.variant || 'info'] || variantConfig.info;

  return e('div', {
    role: 'alert',
    className: 'flex items-start gap-3 border-l-4 rounded p-4 ' + cfg.bg,
  },
    e('span', { className: 'text-lg font-bold ' + cfg.text, 'aria-hidden': 'true' }, cfg.icon),
    e('div', { className: 'flex-1' },
      props.title ? e('p', { className: 'font-semibold ' + cfg.text }, props.title) : null,
      e('p', { className: cfg.text }, props.children)
    ),
    props.onDismiss ? e('button', {
      type: 'button',
      onClick: function() { setDismissed(true); props.onDismiss(); },
      className: 'ml-auto text-lg font-bold opacity-50 hover:opacity-100 ' + cfg.text,
      'aria-label': 'Dismiss',
    }, '×') : null
  );
};
