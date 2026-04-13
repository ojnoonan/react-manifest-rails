// components/feedback/badge.js
// Colored status badge. Props: variant ('success'|'warning'|'danger'|'info'|'gray'), children.
// No JSX — uses React.createElement. No import/export — globals only.

var Badge = function(props) {
  var e = React.createElement;
  var variantClasses = {
    success: 'bg-green-100 text-green-800',
    warning: 'bg-yellow-100 text-yellow-800',
    danger:  'bg-red-100 text-red-800',
    info:    'bg-blue-100 text-blue-800',
    gray:    'bg-gray-100 text-gray-700',
    purple:  'bg-purple-100 text-purple-800',
    orange:  'bg-orange-100 text-orange-800',
  };
  var variant = props.variant || 'gray';
  var cls = 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ' +
    (variantClasses[variant] || variantClasses.gray);

  return e('span', { className: cls }, props.children || props.label || '');
};
