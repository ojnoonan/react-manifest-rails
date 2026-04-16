// components/forms/text_input.js
// Labeled text input. Props: label, value, onChange, error, placeholder, type, required, hint.
// No JSX — uses React.createElement. No import/export — globals only.

const TextInput = (props) => {
  const id = props.id || ('input-' + (props.label || '').toLowerCase().replace(/\s+/g, '-'));
  const inputCls = [
    'block w-full rounded-md border px-3 py-2 text-sm shadow-sm',
    'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500',
    props.error
      ? 'border-red-400 bg-red-50 text-red-900 placeholder-red-400'
      : 'border-gray-300 bg-white text-gray-900 placeholder-gray-400',
    props.disabled ? 'bg-gray-50 cursor-not-allowed text-gray-500' : '',
  ].join(' ');

  return React.createElement('div', { className: 'mb-4' },
    props.label ? React.createElement('label', { htmlFor: id, className: 'block text-sm font-medium text-gray-700 mb-1' },
      props.label,
      props.required ? React.createElement('span', { className: 'text-red-500 ml-1' }, '*') : null
    ) : null,
    React.createElement('input', {
      id: id,
      type: props.type || 'text',
      className: inputCls,
      value: props.value != null ? props.value : '',
      placeholder: props.placeholder || '',
      onChange: props.onChange,
      onBlur: props.onBlur,
      disabled: props.disabled,
      readOnly: props.readOnly,
    }),
    props.hint && !props.error ? React.createElement('p', { className: 'mt-1 text-xs text-gray-500' }, props.hint) : null,
    props.error ? React.createElement('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
