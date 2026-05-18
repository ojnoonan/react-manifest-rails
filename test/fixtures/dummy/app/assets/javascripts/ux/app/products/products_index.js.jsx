var ProductsIndex = function(props) {
  var prefetched = usePrefetch('/api/products');
  var label = pluralizeWords(props.count, 'product');
  var DynamicButton = props.useAltButton ? IconButton : PrimaryButton;

  return React.createElement('section', { className: 'products-index' },
    React.createElement('h1', null, label),
    React.createElement(StatusBadge, { active: prefetched.started, label: 'ready' }),
    React.createElement(PrimaryButton, null, 'Add Product'),
    React.createElement(DynamicButton, null, 'Dynamic')
  );
};
