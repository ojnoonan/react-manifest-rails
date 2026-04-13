// hooks/use_debounce.js
// Debounces a rapidly-changing value, only updating after `delay` ms of silence.
// No import/export — globals only.

function useDebounce(value, delay) {
  var pair = React.useState(value);
  var debouncedValue = pair[0];
  var setDebouncedValue = pair[1];

  React.useEffect(function() {
    var timer = setTimeout(function() {
      setDebouncedValue(value);
    }, delay != null ? delay : 300);
    return function() { clearTimeout(timer); };
  }, [value, delay]);

  return debouncedValue;
}
