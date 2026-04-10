function apiPost(url, data) {
  return fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
}

function apiGet(url) {
  return fetch(url).then(function(r) { return r.json(); });
}
