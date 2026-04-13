var ReportsIndex = function() {
  var e = React.createElement;

  var _dateFrom = React.useState('2026-03-01');
  var dateFrom = _dateFrom[0];
  var setDateFrom = _dateFrom[1];

  var _dateTo = React.useState('2026-03-31');
  var dateTo = _dateTo[0];
  var setDateTo = _dateTo[1];

  var reportCards = [
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

  return e('div', { className: 'p-6 max-w-6xl mx-auto' },

    e('div', { className: 'flex flex-wrap items-end justify-between gap-4 mb-8' },
      e(PageHeader, { title: 'Reports' }),
      e('div', { className: 'flex items-end gap-3' },
        e(DatePicker, {
          id: 'report-from',
          label: 'From',
          value: dateFrom,
          onChange: function(evt) { setDateFrom(evt.target.value); },
        }),
        e(DatePicker, {
          id: 'report-to',
          label: 'To',
          value: dateTo,
          onChange: function(evt) { setDateTo(evt.target.value); },
        }),
        e(PrimaryButton, { onClick: function() {} }, 'Apply')
      )
    ),

    e('div', { className: 'grid grid-cols-1 md:grid-cols-3 gap-6' },
      reportCards.map(function(card) {
        return e('div', { key: card.id, className: 'bg-white border border-gray-200 rounded-lg overflow-hidden' },

          e('div', { className: card.chartColor + ' flex items-center justify-center py-12 text-6xl' },
            card.chartEmoji
          ),

          e('div', { className: 'p-5' },
            e('h3', { className: 'font-semibold text-gray-800 mb-1' }, card.title),
            e('p', { className: 'text-3xl font-bold text-gray-900 mb-1' }, card.metric),
            e('p', { className: 'text-xs text-gray-500 mb-1' }, card.metricLabel),
            e('p', { className: 'text-sm text-gray-600 mb-4' }, card.detail),
            e(LinkButton, { onClick: function() {} }, 'Export CSV')
          )
        );
      })
    )
  );
};

document.addEventListener('DOMContentLoaded', function() {
  var container = document.getElementById('react-app');
  if (container && container.dataset.component === 'ReportsIndex') {
    ReactDOM.createRoot(container).render(React.createElement(ReportsIndex));
  }
});
