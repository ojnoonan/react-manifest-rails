// components/data/data_table.js
// Sortable data table. Props: columns [{key,label,render?,sortable?}], rows, loading, emptyMessage.
// No JSX — uses React.createElement. No import/export — globals only.

var DataTable = function(props) {
  var e = React.createElement;
  var columns = props.columns || [];
  var rows = props.rows || [];

  if (props.loading) {
    return e('div', { className: 'flex justify-center py-12' }, e(Spinner, { size: 'lg' }));
  }

  if (rows.length === 0) {
    return e(EmptyState, {
      icon: '📭',
      title: 'No results',
      message: props.emptyMessage || 'No records found.',
    });
  }

  return e('div', { className: 'overflow-x-auto rounded-lg border border-gray-200' },
    e('table', { className: 'min-w-full divide-y divide-gray-200 text-sm' },
      e('thead', { className: 'bg-gray-50' },
        e('tr', null,
          columns.map(function(col) {
            return e('th', {
              key: col.key,
              scope: 'col',
              className: 'px-4 py-3 text-left',
            },
              col.sortable
                ? e(SortHeader, {
                    label: col.label,
                    sortKey: col.key,
                    currentSort: props.sort,
                    onSort: props.onSort,
                  })
                : e('span', { className: 'text-xs font-semibold uppercase tracking-wide text-gray-500' }, col.label)
            );
          })
        )
      ),
      e('tbody', { className: 'bg-white divide-y divide-gray-100' },
        rows.map(function(row, i) {
          var capturedRow = row;
          return e('tr', {
            key: row.id != null ? row.id : i,
            className: 'hover:bg-gray-50 transition-colors' + (props.onRowClick ? ' cursor-pointer' : ''),
            onClick: props.onRowClick ? function() { props.onRowClick(capturedRow); } : undefined,
          },
            columns.map(function(col) {
              return e('td', {
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
