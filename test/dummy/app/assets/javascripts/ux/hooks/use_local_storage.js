// hooks/use_local_storage.js
// State hook that persists to localStorage. Falls back gracefully if unavailable.
// No import/export — globals only.

function useLocalStorage(key, initialValue) {
  var pair = React.useState(function() {
    try {
      var item = window.localStorage.getItem(key);
      return item !== null ? JSON.parse(item) : initialValue;
    } catch(e) {
      return initialValue;
    }
  });
  var storedValue = pair[0];
  var setStoredValue = pair[1];

  var setValue = function(value) {
    try {
      var next = typeof value === 'function' ? value(storedValue) : value;
      setStoredValue(next);
      window.localStorage.setItem(key, JSON.stringify(next));
    } catch(e) {
      console.warn('useLocalStorage: could not write key "' + key + '"', e);
    }
  };

  var removeValue = function() {
    try { window.localStorage.removeItem(key); } catch(e) {}
    setStoredValue(initialValue);
  };

  return [storedValue, setValue, removeValue];
}
