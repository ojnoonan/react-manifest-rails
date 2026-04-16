// components/buttons/link_button.js
// Text link styled button. Props: children, href, onClick.
// No JSX — uses React.createElement. No import/export — globals only.

const LinkButton = (props) => {
  const cls = 'text-blue-600 hover:text-blue-800 hover:underline text-sm font-medium focus:outline-none focus:underline transition-colors disabled:opacity-40 disabled:cursor-not-allowed';

  if (props.href) {
    return React.createElement('a', {
      href: props.href,
      className: cls,
      onClick: props.onClick,
    }, props.children || props.label);
  }

  return React.createElement('button', {
    type: 'button',
    className: cls,
    onClick: props.onClick,
    disabled: props.disabled,
  }, props.children || props.label);
};
