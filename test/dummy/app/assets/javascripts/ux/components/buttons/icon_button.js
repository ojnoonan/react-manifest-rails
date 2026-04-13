// components/buttons/icon_button.js
// Square icon-only button with tooltip. Props: icon (emoji/text), label, onClick, variant ('ghost'|'outline').
// No JSX — uses React.createElement. No import/export — globals only.

var IconButton = function(props) {
  var e = React.createElement;
  var variantClasses = {
    ghost:   'text-gray-500 hover:text-gray-700 hover:bg-gray-100',
    outline: 'border border-gray-300 text-gray-600 hover:bg-gray-50',
  };
  var variant = variantClasses[props.variant || 'ghost'] || variantClasses.ghost;
  var cls = [
    'inline-flex items-center justify-center w-8 h-8 rounded transition-colors',
    'focus:outline-none focus:ring-2 focus:ring-blue-500',
    props.disabled ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer',
    variant,
  ].join(' ');

  return e('button', {
    type: 'button',
    className: cls,
    onClick: props.onClick,
    disabled: props.disabled,
    title: props.label || props.title,
    'aria-label': props.label || props.title,
  },
    e('span', { 'aria-hidden': 'true', className: 'text-base leading-none' }, props.icon || '•')
  );
};
