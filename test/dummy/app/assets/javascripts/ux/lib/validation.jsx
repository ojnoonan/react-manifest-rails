// lib/validation.js
// Field-level validators. Each method returns {valid: bool, message: string}.
// No import/export — globals only.

const Validators = {
  required: function(v) {
    const ok = v !== null && v !== undefined && String(v).trim() !== '';
    return { valid: ok, message: ok ? '' : 'This field is required.' };
  },

  email: function(v) {
    if (!v) return { valid: true, message: '' };
    const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v).trim());
    return { valid: ok, message: ok ? '' : 'Please enter a valid email address.' };
  },

  minLength: function(v, n) {
    if (!v) return { valid: true, message: '' };
    const ok = String(v).length >= n;
    return { valid: ok, message: ok ? '' : 'Must be at least ' + n + ' characters.' };
  },

  maxLength: function(v, n) {
    if (!v) return { valid: true, message: '' };
    const ok = String(v).length <= n;
    return { valid: ok, message: ok ? '' : 'Must be no more than ' + n + ' characters.' };
  },

  numeric: function(v) {
    if (!v) return { valid: true, message: '' };
    const ok = !isNaN(Number(v)) && String(v).trim() !== '';
    return { valid: ok, message: ok ? '' : 'Must be a valid number.' };
  },

  url: function(v) {
    if (!v) return { valid: true, message: '' };
    try { new URL(v); return { valid: true, message: '' }; }
    catch(e) { return { valid: false, message: 'Please enter a valid URL.' }; }
  },

  // Helper: run multiple validators, return first failure or null
  compose: function() {
    const fns = Array.prototype.slice.call(arguments);
    return function(v) {
      for (let i = 0; i < fns.length; i++) {
        const result = fns[i](v);
        if (!result.valid) return result;
      }
      return { valid: true, message: '' };
    };
  },
};
