// components/buttons/primary_button.js
// Blue primary action button. Props: children, onClick, disabled, loading, size ('sm'|'md'|'lg').
// No JSX — uses React.createElement. No import/export — globals only.

const PrimaryButton = (props) => {
  const sizeClasses = { sm: 'px-3 py-1.5 text-sm', md: 'px-4 py-2 text-sm', lg: 'px-6 py-3 text-base' };
  const size = sizeClasses[props.size || 'md'] || sizeClasses.md;
  const disabled = props.disabled || props.loading;
  const cls = [
    'inline-flex items-center gap-2 font-medium rounded-md transition-colors',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
    disabled
      ? 'bg-blue-300 text-white cursor-not-allowed'
      : 'bg-blue-600 text-white hover:bg-blue-700',
    size,
  ].join(' ');

  return React.createElement('button', {
    type: props.type || 'button',
    className: cls,
    onClick: props.onClick,
    disabled: disabled,
  },
    props.loading ? React.createElement(Spinner, { size: 'sm' }) : null,
    props.children || props.label
  );
};
