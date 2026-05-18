var OrdersIndex = function(props) {
  return React.createElement('section', { className: 'orders-index' },
    React.createElement('h1', null, 'Orders'),
    React.createElement(PrimaryButton, null, 'Create Order'),
    React.createElement('p', null, 'Total: ' + props.total)
  );
};
