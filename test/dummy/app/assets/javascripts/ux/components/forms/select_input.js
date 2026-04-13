// components/forms/select_input.js
// Labeled select dropdown. Props: label, value, onChange, options [{value,label}], error, placeholder.
// No JSX — uses React.createElement. No import/export — globals only.

var SelectInput = function(props) {
  var e = React.createElement;
  var id = props.id || ('select-' + (props.label || '').toLowerCase().replace(/\s+/g, '-'));
  var options = props.options || [];
  var selectCls = [
    'block w-full rounded-md border px-3 py-2 text-sm shadow-sm bg-white',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500',
    props.error ? 'border-red-400' : 'border-gray-300',
    props.disabled ? 'bg-gray-50 cursor-not-allowed text-gray-500' : 'text-gray-900',
  ].join(' ');

  var optionEls = options.map(function(opt) {
    var val = typeof opt === 'object' ? opt.value : opt;
    var lbl = typeof opt === 'object' ? opt.label : opt;
    return e('option', { key: val, value: val }, lbl);
  });

  if (props.placeholder) {
    optionEls = [e('option', { key: '__placeholder', value: '' }, props.placeholder)].concat(optionEls);
  }

  return e('div', { className: 'mb-4' },
    props.label ? e('label', { htmlFor: id, className: 'block text-sm font-medium text-gray-700 mb-1' },
      props.label,
      props.required ? e('span', { className: 'text-red-500 ml-1' }, '*') : null
    ) : null,
    e('select', {
      id: id,
      className: selectCls,
      value: props.value != null ? props.value : '',
      onChange: props.onChange,
      onBlur: props.onBlur,
      disabled: props.disabled,
    }, optionEls),
    props.error ? e('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
