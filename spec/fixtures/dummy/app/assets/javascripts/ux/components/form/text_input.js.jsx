const TextInput = (props) => {
  return React.createElement('input', {
    type: 'text',
    className: 'form-control',
    value: props.value,
    onChange: props.onChange,
    placeholder: props.placeholder
  });
};
