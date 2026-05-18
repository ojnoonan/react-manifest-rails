const useFetch = (url) => {
  const [data, setData] = React.useState(null);
  const [loading, setLoading] = React.useState(true);

  React.useEffect(() => {
    fetch(url).then(r => r.json()).then(d => {
      setData(d);
      setLoading(false);
    });
  }, [url]);

  return { data, loading };
};
