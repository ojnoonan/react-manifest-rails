// hooks/use_local_storage.js
// State hook that persists to localStorage. Falls back gracefully if unavailable.
// No import/export — globals only.

function useLocalStorage(key, initialValue) {
  const { useState } = React;
  const pair = useState(function() {
    try {
      const item = window.localStorage.getItem(key);
      return item !== null ? JSON.parse(item) : initialValue;
    } catch(e) {
      return initialValue;
    }
  });
  const storedValue = pair[0];
  const setStoredValue = pair[1];

  const setValue = (value) => {
    try {
      const next = typeof value === 'function' ? value(storedValue) : value;
      setStoredValue(next);
      window.localStorage.setItem(key, JSON.stringify(next));
    } catch(e) {
      console.warn('useLocalStorage: could not write key "' + key + '"', e);
    }
  };

  const removeValue = () => {
    try { window.localStorage.removeItem(key); } catch(e) {}
    setStoredValue(initialValue);
  };

  return [storedValue, setValue, removeValue];
}
