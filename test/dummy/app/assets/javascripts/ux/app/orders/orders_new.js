var OrdersNew = function() {
  var e = React.createElement;

  var _useState = React.useState(1);
  var step = _useState[0];
  var setStep = _useState[1];

  var _useFormState = React.useState({
    customerName: '',
    email: '',
    address: '',
    city: '',
    state: '',
    zip: '',
  });
  var formValues = _useFormState[0];
  var setFormValues = _useFormState[1];

  var products = [
    { id: 1, name: 'Wireless Headphones', price: 249.00 },
    { id: 2, name: 'USB-C Cable (2m)',    price:   9.50 },
    { id: 3, name: 'Phone Stand',         price:  35.00 },
  ];

  var _useQtyState = React.useState({ 1: 1, 2: 1, 3: 1 });
  var quantities = _useQtyState[0];
  var setQuantities = _useQtyState[1];

  var runningTotal = products.reduce(function(sum, p) {
    return sum + (quantities[p.id] || 0) * p.price;
  }, 0);

  var handleFieldChange = function(field) {
    return function(evt) {
      var val = evt && evt.target ? evt.target.value : evt;
      setFormValues(function(prev) {
        var next = {};
        Object.keys(prev).forEach(function(k) { next[k] = prev[k]; });
        next[field] = val;
        return next;
      });
    };
  };

  var handleQtyChange = function(productId) {
    return function(evt) {
      var val = parseInt(evt.target.value, 10) || 0;
      setQuantities(function(prev) {
        var next = {};
        Object.keys(prev).forEach(function(k) { next[k] = prev[k]; });
        next[productId] = val;
        return next;
      });
    };
  };

  var progressBar = e('div', { className: 'mb-8' },
    e('div', { className: 'flex items-center justify-between mb-2' },
      e('span', { className: 'text-sm font-medium text-gray-700' }, 'Step ' + step + ' of 3'),
      e('span', { className: 'text-sm text-gray-500' },
        step === 1 ? 'Customer Info' : step === 2 ? 'Select Items' : 'Review & Submit'
      )
    ),
    e('div', { className: 'w-full bg-gray-200 rounded-full h-2' },
      e('div', {
        className: 'bg-blue-600 h-2 rounded-full transition-all',
        style: { width: (step / 3 * 100) + '%' }
      })
    )
  );

  var step1 = e('div', { className: 'space-y-4' },
    e('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Customer Information'),
    e(TextInput, {
      id: 'customer-name',
      label: 'Full Name',
      value: formValues.customerName,
      onChange: handleFieldChange('customerName'),
    }),
    e(TextInput, {
      id: 'customer-email',
      label: 'Email Address',
      value: formValues.email,
      onChange: handleFieldChange('email'),
    }),
    e(TextInput, {
      id: 'customer-address',
      label: 'Street Address',
      value: formValues.address,
      onChange: handleFieldChange('address'),
    }),
    e('div', { className: 'grid grid-cols-3 gap-4' },
      e(TextInput, {
        id: 'customer-city',
        label: 'City',
        value: formValues.city,
        onChange: handleFieldChange('city'),
      }),
      e(TextInput, {
        id: 'customer-state',
        label: 'State',
        value: formValues.state,
        onChange: handleFieldChange('state'),
      }),
      e(TextInput, {
        id: 'customer-zip',
        label: 'ZIP Code',
        value: formValues.zip,
        onChange: handleFieldChange('zip'),
      })
    ),
    e('div', { className: 'flex justify-end mt-6' },
      e(PrimaryButton, { onClick: function() { setStep(2); } }, 'Next: Select Items')
    )
  );

  var step2 = e('div', null,
    e('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Select Items'),
    e('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden mb-6' },
      e('table', { className: 'w-full text-sm' },
        e('thead', null,
          e('tr', { className: 'bg-gray-50 text-left text-xs font-semibold text-gray-500 uppercase tracking-wide' },
            e('th', { className: 'px-5 py-3' }, 'Product'),
            e('th', { className: 'px-5 py-3 text-right' }, 'Unit Price'),
            e('th', { className: 'px-5 py-3 text-center' }, 'Qty'),
            e('th', { className: 'px-5 py-3 text-right' }, 'Subtotal')
          )
        ),
        e('tbody', { className: 'divide-y divide-gray-100' },
          products.map(function(p) {
            var qty = quantities[p.id] || 0;
            return e('tr', { key: p.id },
              e('td', { className: 'px-5 py-3 font-medium text-gray-900' }, p.name),
              e('td', { className: 'px-5 py-3 text-right text-gray-700' }, formatCurrency(p.price)),
              e('td', { className: 'px-5 py-3 text-center' },
                e('input', {
                  type: 'number',
                  min: '0',
                  value: qty,
                  onChange: handleQtyChange(p.id),
                  className: 'w-16 text-center border border-gray-300 rounded px-2 py-1 text-sm'
                })
              ),
              e('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' },
                formatCurrency(qty * p.price)
              )
            );
          })
        )
      )
    ),
    e('div', { className: 'flex justify-between items-center bg-gray-50 rounded-lg px-5 py-4 mb-6' },
      e('span', { className: 'font-semibold text-gray-700' }, 'Running Total'),
      e('span', { className: 'text-xl font-bold text-gray-900' }, formatCurrency(runningTotal))
    ),
    e('div', { className: 'flex gap-3 justify-between' },
      e(LinkButton, { onClick: function() { setStep(1); } }, 'Back'),
      e(PrimaryButton, { onClick: function() { setStep(3); } }, 'Next: Review Order')
    )
  );

  var step3 = e('div', null,
    e('h2', { className: 'text-lg font-semibold text-gray-800 mb-4' }, 'Review & Submit'),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg p-5 mb-4' },
      e('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3' }, 'Customer'),
      e('p', { className: 'text-gray-900 font-medium' }, formValues.customerName || '—'),
      e('p', { className: 'text-gray-600 text-sm' }, formValues.email),
      e('p', { className: 'text-gray-600 text-sm' }, formValues.address),
      e('p', { className: 'text-gray-600 text-sm' },
        [formValues.city, formValues.state, formValues.zip].filter(Boolean).join(', ')
      )
    ),

    e('div', { className: 'bg-white border border-gray-200 rounded-lg overflow-hidden mb-4' },
      e('div', { className: 'px-5 py-3 border-b border-gray-100' },
        e('h3', { className: 'text-sm font-semibold text-gray-500 uppercase tracking-wide' }, 'Items')
      ),
      e('table', { className: 'w-full text-sm' },
        e('tbody', { className: 'divide-y divide-gray-100' },
          products.filter(function(p) { return (quantities[p.id] || 0) > 0; }).map(function(p) {
            var qty = quantities[p.id];
            return e('tr', { key: p.id },
              e('td', { className: 'px-5 py-3 text-gray-900' }, p.name),
              e('td', { className: 'px-5 py-3 text-gray-600' }, qty + ' x ' + formatCurrency(p.price)),
              e('td', { className: 'px-5 py-3 text-right font-medium text-gray-900' }, formatCurrency(qty * p.price))
            );
          })
        )
      ),
      e('div', { className: 'px-5 py-3 border-t border-gray-100 bg-gray-50 flex justify-between font-semibold text-gray-900' },
        e('span', null, 'Total'),
        e('span', null, formatCurrency(runningTotal))
      )
    ),

    e('div', { className: 'flex gap-3 justify-between' },
      e(LinkButton, { onClick: function() { setStep(2); } }, 'Back'),
      e(PrimaryButton, { onClick: function() { alert('Order submitted!'); } }, 'Submit Order')
    )
  );

  return e('div', { className: 'p-6 max-w-3xl mx-auto' },
    e(PageHeader, { title: 'New Order', subtitle: 'Create a new customer order' }),
    progressBar,
    step === 1 ? step1 : step === 2 ? step2 : step3
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'OrdersNew') {
    ReactDOM.createRoot(container).render(React.createElement(OrdersNew));
  }
});
