// components/data/data_table.js
// Sortable data table. Props: columns [{key,label,render?,sortable?}], rows, loading, emptyMessage.
// No JSX — uses React.createElement. No import/export — globals only.

const DataTable = (props) => {
  const columns = props.columns || [];
  const rows = props.rows || [];

  if (props.loading) {
    return React.createElement('div', { className: 'flex justify-center py-12' }, React.createElement(Spinner, { size: 'lg' }));
  }

  if (rows.length === 0) {
    return React.createElement(EmptyState, {
      icon: '📭',
      title: 'No results',
      message: props.emptyMessage || 'No records found.',
    });
  }

  return React.createElement('div', { className: 'overflow-x-auto rounded-lg border border-gray-200' },
    React.createElement('table', { className: 'min-w-full divide-y divide-gray-200 text-sm' },
      React.createElement('thead', { className: 'bg-gray-50' },
        React.createElement('tr', null,
          columns.map(function(col) {
            return React.createElement('th', {
              key: col.key,
              scope: 'col',
              className: 'px-4 py-3 text-left',
            },
              col.sortable
                ? React.createElement(SortHeader, {
                    label: col.label,
                    sortKey: col.key,
                    currentSort: props.sort,
                    onSort: props.onSort,
                  })
                : React.createElement('span', { className: 'text-xs font-semibold uppercase tracking-wide text-gray-500' }, col.label)
            );
          })
        )
      ),
      React.createElement('tbody', { className: 'bg-white divide-y divide-gray-100' },
        rows.map(function(row, i) {
          const capturedRow = row;
          return React.createElement('tr', {
            key: row.id != null ? row.id : i,
            className: 'hover:bg-gray-50 transition-colors' + (props.onRowClick ? ' cursor-pointer' : ''),
            onClick: props.onRowClick ? function() { props.onRowClick(capturedRow); } : undefined,
          },
            columns.map(function(col) {
              return React.createElement('td', {
                key: col.key,
                className: 'px-4 py-3 text-gray-700 whitespace-nowrap',
              },
                col.render ? col.render(row[col.key], row) : (row[col.key] != null ? row[col.key] : '—')
              );
            })
          );
        })
      )
    )
  );
};
