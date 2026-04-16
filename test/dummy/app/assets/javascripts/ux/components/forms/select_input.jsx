// components/forms/select_input.js
// Labeled select dropdown. Props: label, value, onChange, options [{value,label}], error, placeholder.
// No JSX — uses React.createElement. No import/export — globals only.

const SelectInput = (props) => {
  const id = props.id || ('select-' + (props.label || '').toLowerCase().replace(/\s+/g, '-'));
  const options = props.options || [];
  const selectCls = [
    'block w-full rounded-md border px-3 py-2 text-sm shadow-sm bg-white',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500',
    props.error ? 'border-red-400' : 'border-gray-300',
    props.disabled ? 'bg-gray-50 cursor-not-allowed text-gray-500' : 'text-gray-900',
  ].join(' ');

  let optionEls = options.map(function(opt) {
    const val = typeof opt === 'object' ? opt.value : opt;
    const lbl = typeof opt === 'object' ? opt.label : opt;
    return React.createElement('option', { key: val, value: val }, lbl);
  });

  if (props.placeholder) {
    optionEls = [React.createElement('option', { key: '__placeholder', value: '' }, props.placeholder)].concat(optionEls);
  }

  return React.createElement('div', { className: 'mb-4' },
    props.label ? React.createElement('label', { htmlFor: id, className: 'block text-sm font-medium text-gray-700 mb-1' },
      props.label,
      props.required ? React.createElement('span', { className: 'text-red-500 ml-1' }, '*') : null
    ) : null,
    React.createElement('select', {
      id: id,
      className: selectCls,
      value: props.value != null ? props.value : '',
      onChange: props.onChange,
      onBlur: props.onBlur,
      disabled: props.disabled,
    }, optionEls),
    props.error ? React.createElement('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
