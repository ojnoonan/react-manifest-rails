// lib/router_helpers.js
// URL construction helpers. No import/export — globals only.

function buildUrl(base, params) {
  if (!params || Object.keys(params).length === 0) return base;
  var qs = Object.keys(params)
    .filter(function(k) { return params[k] != null && params[k] !== ''; })
    .map(function(k) { return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]); })
    .join('&');
  return qs ? base + '?' + qs : base;
}

function parseQueryString() {
  var result = {};
  var search = window.location.search.slice(1);
  if (!search) return result;
  search.split('&').forEach(function(pair) {
    var parts = pair.split('=');
    if (parts[0]) result[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1] || '');
  });
  return result;
}

function navigate(path) {
  window.location.href = path;
}
