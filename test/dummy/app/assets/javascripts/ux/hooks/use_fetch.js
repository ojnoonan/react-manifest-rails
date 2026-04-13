// hooks/use_fetch.js
// Data-fetching hook using apiFetch. Returns {data, loading, error, refetch}.
// No import/export — globals only.

function useFetch(url, options) {
  var dataPair = React.useState(null);
  var data = dataPair[0];
  var setData = dataPair[1];

  var loadingPair = React.useState(true);
  var loading = loadingPair[0];
  var setLoading = loadingPair[1];

  var errorPair = React.useState(null);
  var error = errorPair[0];
  var setError = errorPair[1];

  var fetchData = function() {
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

  React.useEffect(function() {
    var cancelled = false;
    setLoading(true);
    setError(null);
    apiGet(url, options && options.params)
      .then(function(json) { if (!cancelled) { setData(json); setLoading(false); } })
      .catch(function(err) { if (!cancelled) { setError(err); setLoading(false); } });
    return function() { cancelled = true; };
  }, [url]);

  return { data: data, loading: loading, error: error, refetch: fetchData };
}
