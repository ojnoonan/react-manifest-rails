// lib/api_helpers.js
// Fetch wrappers that add CSRF token + JSON headers automatically.
// No import/export — globals only.

function apiFetch(path, opts) {
  opts = opts || {};
  const meta = document.querySelector('meta[name="csrf-token"]');
  const csrfToken = meta ? meta.getAttribute('content') : '';
  const headers = Object.assign({
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-CSRF-Token': csrfToken,
  }, opts.headers || {});
  return fetch(path, Object.assign({}, opts, { headers: headers }))
    .then(function(res) {
      if (res.status === 204) return null;
      return res.json().then(function(data) {
        if (!res.ok) {
          const err = new Error((data && data.error) || 'Request failed (' + res.status + ')');
          err.status = res.status;
          err.data = data;
          throw err;
        }
        return data;
      });
    });
}

function apiGet(path, params) {
  const qs = params ? ('?' + new URLSearchParams(params).toString()) : '';
  return apiFetch(path + qs, { method: 'GET' });
}

function apiPost(path, body) {
  return apiFetch(path, { method: 'POST', body: JSON.stringify(body) });
}

function apiPatch(path, body) {
  return apiFetch(path, { method: 'PATCH', body: JSON.stringify(body) });
}

function apiDelete(path) {
  return apiFetch(path, { method: 'DELETE' });
}
