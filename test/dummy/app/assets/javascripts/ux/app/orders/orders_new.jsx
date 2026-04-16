const OrdersNew = () => {
  const { useState } = React;
  const _useState = useState(1);
  const step = _useState[0];
  const setStep = _useState[1];

  const _useFormState = useState({
    customerName: '',
    email: '',
    address: '',
    city: '',
    state: '',
    zip: '',
  });
  const formValues = _useFormState[0];
  const setFormValues = _useFormState[1];

  const products = [
    { id: 1, name: 'Wireless Headphones', price: 249.00 },
    { id: 2, name: 'USB-C Cable (2m)',    price:   9.50 },
    { id: 3, name: 'Phone Stand',         price:  35.00 },
  ];

  const _useQtyState = useState({ 1: 1, 2: 1, 3: 1 });
  const quantities = _useQtyState[0];
  const setQuantities = _useQtyState[1];

  const runningTotal = products.reduce(function(sum, p) {
    return sum + (quantities[p.id] || 0) * p.price;
  }, 0);

  const handleFieldChange = (field) => {
    return function(evt) {
      const val = evt && evt.target ? evt.target.value : evt;
      setFormValues(function(prev) {
        const next = {};
        Object.keys(prev).forEach(function(k) { next[k] = prev[k]; });
        next[field] = val;
        return next;
      });
    };
  };

  const handleQtyChange = (productId) => {
    return function(evt) {
      const val = parseInt(evt.target.value, 10) || 0;
      setQuantities(function(prev) {
        const next = {};
        Object.keys(prev).forEach(function(k) { next[k] = prev[k]; });
        next[productId] = val;
        return next;
      });
    };
  };

  const progressBar = React.createElement('div', { className: 'mb-8' },
    React.createElement('div', { className: 'flex items-center justify-between mb-2' },
      React.createElement('span', { className: 'text-sm font-medium text-gray-700' }, 'Step ' + step + ' of 3'),
      React.createElement('span', { className: 'text-sm text-gray-500' },
        step === 1 ? 'Customer Info' : step === 2 ? 'Select Items' : 'Review & Submit'
      )
    ),
    React.createElement('div', { className: 'w-full bg-gray-200 rounded-full h-2' },
      React.createElement('div', {
        className: 'bg-blue-600 h-2 rounded-full transition-all',
        style: { width: (step / 3 * 100) + '%' }
      })
    )
  );

  const step1 = React.createElement('div', { className: 'space-y-4' },
    React.createElement('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Customer Information'),
    React.createElement(TextInput, {
      id: 'customer-name',
      label: 'Full Name',
      value: formValues.customerName,
      onChange: handleFieldChange('customerName'),
    }),
    React.createElement(TextInput, {
      id: 'customer-email',
      label: 'Email Address',
      value: formValues.email,
      onChange: handleFieldChange('email'),
    }),
    React.createElement(TextInput, {
      id: 'customer-address',
      label: 'Street Address',
      value: formValues.address,
      onChange: handleFieldChange('address'),
    }),
    React.createElement('div', { className: 'grid grid-cols-3 gap-4' },
      React.createElement(TextInput, {
        id: 'customer-city',
        label: 'City',
        value: formValues.city,
        onChange: handleFieldChange('city'),
      }),
      React.createElement(TextInput, {
        id: 'customer-state',
        label: 'State',
        value: formValues.state,
        onChange: handleFieldChange('state'),
      }),
      React.createElement(TextInput, {
        id: 'customer-zip',
        label: 'ZIP Code',
        value: formValues.zip,
        onChange: handleFieldChange('zip'),
      })
    ),
    React.createElement('div', { className: 'flex justify-end mt-6' },
      React.createElement(PrimaryButton, { onClick: function() { setStep(2); } }, 'Next: Select Items')
    )
  );

  const step2 = React.createElement('div', null,
    React.createElement('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Select Items'),
    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden mb-6' },
      React.createElement('table', { className: 'w-full text-sm' },
        React.createElement('thead', null,
          React.createElement('tr', { className: 'bg-gray-50 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide' },
            React.createElement('th', { className: 'px-5 py-3' }, 'Product'),
            React.createElement('th', { className: 'px-5 py-3 text-right' }, 'Unit Price'),
            React.createElement('th', { className: 'px-5 py-3 text-center' }, 'Qty'),
            React.createElement('th', { className: 'px-5 py-3 text-right' }, 'Subtotal')
          )
        ),
        React.createElement('tbody', { className: 'divide-y divide-gray-100' },
          products.map(function(p) {
            const qty = quantities[p.id] || 0;
            return React.createElement('tr', { key: p.id },
              React.createElement('td', { className: 'px-5 py-3 font-medium text-gray-900' }, p.name),
              React.createElement('td', { className: 'px-5 py-3 text-right text-gray-700' }, formatCurrency(p.price)),
              React.createElement('td', { className: 'px-5 py-3 text-center' },
                React.createElement('input', {
                  type: 'number',
                  min: '0',
                  value: qty,
                  onChange: handleQtyChange(p.id),
                  className: 'w-16 text-center border border-gray-300 rounded px-2 py-1 text-sm'
                })
              ),
              React.createElement('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' },
                formatCurrency(qty * p.price)
              )
            );
          })
        )
      )
    ),
    React.createElement('div', { className: 'flex justify-between items-center bg-gray-50 rounded-lg px-5 py-4 mb-6' },
      React.createElement('span', { className: 'font-semibold text-gray-700' }, 'Running Total'),
      React.createElement('span', { className: 'text-xl font-bold text-gray-900' }, formatCurrency(runningTotal))
    ),
    React.createElement('div', { className: 'flex gap-3 justify-between' },
      React.createElement(LinkButton, { onClick: function() { setStep(1); } }, 'Back'),
      React.createElement(PrimaryButton, { onClick: function() { setStep(3); } }, 'Next: Review Order')
    )
  );

  const step3 = React.createElement('div', null,
    React.createElement('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Review & Submit'),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg p-5 mb-4' },
      React.createElement('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Customer'),
      React.createElement('p', { className: 'text-gray-900 font-medium' }, formValues.customerName || '—'),
      React.createElement('p', { className: 'text-gray-600 text-sm' }, formValues.email),
      React.createElement('p', { className: 'text-gray-600 text-sm' }, formValues.address),
      React.createElement('p', { className: 'text-gray-600 text-sm' },
        [formValues.city, formValues.state, formValues.zip].filter(Boolean).join(', ')
      )
    ),

    React.createElement('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden mb-4' },
      React.createElement('div', { className: 'px-5 py-3 border-b border-gray-100' },
        React.createElement('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide' }, 'Items')
      ),
      React.createElement('table', { className: 'w-full text-sm' },
        React.createElement('tbody', { className: 'divide-y divide-gray-100' },
          products.filter(function(p) { return (quantities[p.id] || 0) > 0; }).map(function(p) {
            const qty = quantities[p.id];
            return React.createElement('tr', { key: p.id },
              React.createElement('td', { className: 'px-5 py-3 text-gray-900' }, p.name),
              React.createElement('td', { className: 'px-5 py-3 text-gray-600' }, qty + ' x ' + formatCurrency(p.price)),
              React.createElement('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' }, formatCurrency(qty * p.price))
            );
          })
        )
      ),
      React.createElement('div', { className: 'px-5 py-3 border-t border-gray-100 bg-gray-50 flex justify-between font-semibold text-gray-900' },
        React.createElement('span', null, 'Total'),
        React.createElement('span', null, formatCurrency(runningTotal))
      )
    ),

    React.createElement('div', { className: 'flex gap-3 justify-between' },
      React.createElement(LinkButton, { onClick: function() { setStep(2); } }, 'Back'),
      React.createElement(PrimaryButton, { onClick: function() { alert('Order submitted!'); } }, 'Submit Order')
    )
  );

  return React.createElement('div', { className: 'p-6 max-w-3xl mx-auto' },
    React.createElement(PageHeader, { title: 'New Order', subtitle: 'Create a new customer order' }),
    progressBar,
    step === 1 ? step1 : step === 2 ? step2 : step3
  );
};

window.OrdersNew = OrdersNew;
