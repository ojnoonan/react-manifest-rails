// components/buttons/danger_button.js
// Red destructive action button. Props: children, onClick, disabled, loading.
// No JSX — uses React.createElement. No import/export — globals only.

var DangerButton = function(props) {
  var e = React.createElement;
  var disabled = props.disabled || props.loading;
  var cls = [
    'inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-colors',
    'focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2',
    disabled
      ? 'bg-red-300 text-white cursor-not-allowed'
      : 'bg-red-600 text-white hover:bg-red-700',
  ].join(' ');

  return e('button', {
    type: props.type || 'button',
    className: cls,
    onClick: props.onClick,
    disabled: disabled,
  },
    props.loading ? e(Spinner, { size: 'sm' }) : null,
    props.children || props.label
  );
};
