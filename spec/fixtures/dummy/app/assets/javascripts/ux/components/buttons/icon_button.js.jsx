const IconButton = (props) => {
  return React.createElement('button', { className: 'btn btn-icon' },
    React.createElement('span', { className: props.icon }),
    props.label
  );
};
