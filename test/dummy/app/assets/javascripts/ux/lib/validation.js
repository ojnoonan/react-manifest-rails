// lib/validation.js
// Field-level validators. Each method returns {valid: bool, message: string}.
// No import/export — globals only.

var Validators = {
  required: function(v) {
    var ok = v !== null && v !== undefined && String(v).trim() !== '';
    return { valid: ok, message: ok ? '' : 'This field is required.' };
  },

  email: function(v) {
    if (!v) return { valid: true, message: '' };
    var ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v).trim());
    return { valid: ok, message: ok ? '' : 'Please enter a valid email address.' };
  },

  minLength: function(v, n) {
    if (!v) return { valid: true, message: '' };
    var ok = String(v).length >= n;
    return { valid: ok, message: ok ? '' : 'Must be at least ' + n + ' characters.' };
  },

  maxLength: function(v, n) {
    if (!v) return { valid: true, message: '' };
    var ok = String(v).length <= n;
    return { valid: ok, message: ok ? '' : 'Must be no more than ' + n + ' characters.' };
  },

  numeric: function(v) {
    if (!v) return { valid: true, message: '' };
    var ok = !isNaN(Number(v)) && String(v).trim() !== '';
    return { valid: ok, message: ok ? '' : 'Must be a valid number.' };
  },

  url: function(v) {
    if (!v) return { valid: true, message: '' };
    try { new URL(v); return { valid: true, message: '' }; }
    catch(e) { return { valid: false, message: 'Please enter a valid URL.' }; }
  },

  // Helper: run multiple validators, return first failure or null
  compose: function() {
    var fns = Array.prototype.slice.call(arguments);
    return function(v) {
      for (var i = 0; i < fns.length; i++) {
        var result = fns[i](v);
        if (!result.valid) return result;
      }
      return { valid: true, message: '' };
    };
  },
};
