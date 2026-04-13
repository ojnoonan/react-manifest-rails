// hooks/use_pagination.js
// Paginates an array of items in memory. No import/export — globals only.

function usePagination(items, pageSize) {
  var size = pageSize || 10;
  var pagePair = React.useState(1);
  var page = pagePair[0];
  var setPage = pagePair[1];

  var allItems = items || [];
  var totalPages = Math.max(1, Math.ceil(allItems.length / size));
  var safePage = Math.min(page, totalPages);

  var start = (safePage - 1) * size;
  var currentItems = allItems.slice(start, start + size);

  var goToPage = function(n) {
    setPage(Math.max(1, Math.min(n, totalPages)));
  };

  var nextPage = function() { goToPage(safePage + 1); };
  var prevPage = function() { goToPage(safePage - 1); };

  // Reset to page 1 if items list changes length significantly
  React.useEffect(function() {
    setPage(1);
  }, [allItems.length]);

  return {
    page: safePage,
    totalPages: totalPages,
    currentItems: currentItems,
    nextPage: nextPage,
    prevPage: prevPage,
    goToPage: goToPage,
    hasNext: safePage < totalPages,
    hasPrev: safePage > 1,
  };
}
