// hooks/use_fetch.js
// Data-fetching hook using apiFetch. Returns {data, loading, error, refetch}.
// No import/export — globals only.

function useFetch(url, options) {
  const { useEffect, useState } = React;
  const dataPair = useState(null);
  const data = dataPair[0];
  const setData = dataPair[1];

  const loadingPair = useState(true);
  const loading = loadingPair[0];
  const setLoading = loadingPair[1];

  const errorPair = useState(null);
  const error = errorPair[0];
  const setError = errorPair[1];

  const fetchData = () => {
    setLoading(true);
    setError(null);
    return apiGet(url, options && options.params)
      .then(function(json) {
        setData(json);
        setLoading(false);
      })
      .catch(function(err) {
        setError(err);
        setLoading(false);
      });
  };

  useEffect(function() {
    let cancelled = false;
    setLoading(true);
    setError(null);
    apiGet(url, options && options.params)
      .then(function(json) { if (!cancelled) { setData(json); setLoading(false); } })
      .catch(function(err) { if (!cancelled) { setError(err); setLoading(false); } });
    return function() { cancelled = true; };
  }, [url]);

  return { data: data, loading: loading, error: error, refetch: fetchData };
}
