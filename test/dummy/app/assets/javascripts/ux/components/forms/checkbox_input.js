// components/forms/checkbox_input.js
// Labeled checkbox. Props: label, checked, onChange, hint.
// No JSX — uses React.createElement. No import/export — globals only.

var CheckboxInput = function(props) {
  var e = React.createElement;
  var id = props.id || ('cb-' + (props.label || '').toLowerCase().replace(/\s+/g, '-'));

  return e('div', { className: 'mb-4 flex items-start gap-3' },
    e('input', {
      id: id,
      type: 'checkbox',
      className: 'mt-0.5 h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer',
      checked: !!props.checked,
      onChange: props.onChange,
      disabled: props.disabled,
    }),
    e('div', null,
      props.label ? e('label', { htmlFor: id, className: 'text-sm font-medium text-gray-700 cursor-pointer' }, props.label) : null,
      props.hint ? e('p', { className: 'text-xs text-gray-500 mt-0.5' }, props.hint) : null
    )
  );
};
