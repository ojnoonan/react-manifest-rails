const ReportsIndex = () => {
  const { useState } = React;
  const _dateFrom = useState('2026-03-01');
  const dateFrom = _dateFrom[0];
  const setDateFrom = _dateFrom[1];

  const _dateTo = useState('2026-03-31');
  const dateTo = _dateTo[0];
  const setDateTo = _dateTo[1];

  const reportCards = [
    {
      id: 'sales',
      title: 'Sales Summary',
      chartEmoji: '📊',
      chartColor: 'bg-blue-100',
      metric: formatCurrency(84523),
      metricLabel: 'Total Revenue',
      detail: '1,204 orders · avg $70.20/order',
    },
    {
      id: 'users',
      title: 'User Growth',
      chartEmoji: '📈',
      chartColor: 'bg-green-100',
      metric: '1,243',
      metricLabel: 'Total Users',
      detail: '+84 this month · 91% retention',
    },
    {
      id: 'inventory',
      title: 'Inventory Status',
      chartEmoji: '🥧',
      chartColor: 'bg-orange-100',
      metric: '94',
      metricLabel: 'Active Products',
      detail: '12 low stock · 3 out of stock',
    },
  ];

  return React.createElement('div', { className: 'p-6 max-w-6xl mx-auto' },

    React.createElement('div', { className: 'flex flex-wrap items-end justify-between gap-4 mb-8' },
      React.createElement(PageHeader, { title: 'Reports' }),
      React.createElement('div', { className: 'flex items-end gap-3' },
        React.createElement(DatePicker, {
          id: 'report-from',
          label: 'From',
          value: dateFrom,
          onChange: function(evt) { setDateFrom(evt.target.value); },
        }),
        React.createElement(DatePicker, {
          id: 'report-to',
          label: 'To',
          value: dateTo,
          onChange: function(evt) { setDateTo(evt.target.value); },
        }),
        React.createElement(PrimaryButton, { onClick: function() {} }, 'Apply')
      )
    ),

    React.createElement('div', { className: 'grid grid-cols-1 md:grid-cols-3 gap-6' },
      reportCards.map(function(card) {
        return React.createElement('div', { key: card.id, className: 'bg-white border border-gray-200 rounded-lg overflow-hidden' },

          React.createElement('div', { className: card.chartColor + ' flex items-center justify-center py-12 text-6xl' },
            card.chartEmoji
          ),

          React.createElement('div', { className: 'p-5' },
            React.createElement('h3', { className: 'font-semibold text-gray-800 mb-1' }, card.title),
            React.createElement('p', { className: 'text-3xl font-bold text-gray-900 mb-1' }, card.metric),
            React.createElement('p', { className: 'text-xs text-gray-500 mb-1' }, card.metricLabel),
            React.createElement('p', { className: 'text-sm text-gray-600 mb-4' }, card.detail),
            React.createElement(LinkButton, { onClick: function() {} }, 'Export CSV')
          )
        );
      })
    )
  );
};

window.ReportsIndex = ReportsIndex;
