// components/forms/date_picker.js
// Labeled date input. Props: label, value, onChange, error, min, max.
// No JSX — uses React.createElement. No import/export — globals only.

const DatePicker = (props) => {
  const id = props.id || ('date-' + (props.label || '').toLowerCase().replace(/\s+/g, '-'));
  const inputCls = [
    'block w-full rounded-md border px-3 py-2 text-sm shadow-sm',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500',
    props.error ? 'border-red-400 bg-red-50' : 'border-gray-300 bg-white',
    props.disabled ? 'bg-gray-50 cursor-not-allowed' : '',
  ].join(' ');

  return React.createElement('div', { className: 'mb-4' },
    props.label ? React.createElement('label', { htmlFor: id, className: 'block text-sm font-medium text-gray-700 mb-1' },
      props.label,
      props.required ? React.createElement('span', { className: 'text-red-500 ml-1' }, '*') : null
    ) : null,
    React.createElement('input', {
      id: id,
      type: 'date',
      className: inputCls,
      value: props.value || '',
      min: props.min,
      max: props.max,
      onChange: props.onChange,
      onBlur: props.onBlur,
      disabled: props.disabled,
    }),
    props.error ? React.createElement('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
