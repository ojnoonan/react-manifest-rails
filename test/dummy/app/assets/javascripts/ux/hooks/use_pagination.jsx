// hooks/use_pagination.js
// Paginates an array of items in memory. No import/export — globals only.

function usePagination(items, pageSize) {
  const { useEffect, useState } = React;
  const size = pageSize || 10;
  const pagePair = useState(1);
  const page = pagePair[0];
  const setPage = pagePair[1];

  const allItems = items || [];
  const totalPages = Math.max(1, Math.ceil(allItems.length / size));
  const safePage = Math.min(page, totalPages);

  const start = (safePage - 1) * size;
  const currentItems = allItems.slice(start, start + size);

  const goToPage = (n) => {
    setPage(Math.max(1, Math.min(n, totalPages)));
  };

  const nextPage = () => { goToPage(safePage + 1); };
  const prevPage = () => { goToPage(safePage - 1); };

  // Reset to page 1 if items list changes length significantly
  useEffect(function() {
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
