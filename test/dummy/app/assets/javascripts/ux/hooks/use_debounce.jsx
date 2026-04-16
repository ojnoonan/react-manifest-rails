// hooks/use_debounce.js
// Debounces a rapidly-changing value, only updating after `delay` ms of silence.
// No import/export — globals only.

function useDebounce(value, delay) {
  const { useEffect, useState } = React;
  const pair = useState(value);
  const debouncedValue = pair[0];
  const setDebouncedValue = pair[1];

  useEffect(function() {
    const timer = setTimeout(function() {
      setDebouncedValue(value);
    }, delay != null ? delay : 300);
    return function() { clearTimeout(timer); };
  }, [value, delay]);

  return debouncedValue;
}
