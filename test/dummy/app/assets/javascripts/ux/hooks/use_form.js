// hooks/use_form.js
// Generic form state with per-field validation. No import/export — globals only.

function useForm(initialValues, validate) {
  var valuesPair = React.useState(initialValues || {});
  var values = valuesPair[0];
  var setValues = valuesPair[1];

  var errorsPair = React.useState({});
  var errors = errorsPair[0];
  var setErrors = errorsPair[1];

  var touchedPair = React.useState({});
  var touched = touchedPair[0];
  var setTouched = touchedPair[1];

  var submittingPair = React.useState(false);
  var isSubmitting = submittingPair[0];
  var setSubmitting = submittingPair[1];

  var runValidation = function(vals) {
    if (typeof validate !== 'function') return {};
    return validate(vals) || {};
  };

  var handleChange = function(field) {
    return function(e) {
      var val = e && e.target !== undefined
        ? (e.target.type === 'checkbox' ? e.target.checked : e.target.value)
        : e;
      setValues(function(prev) {
        var next = Object.assign({}, prev);
        next[field] = val;
        return next;
      });
    };
  };

  var handleBlur = function(field) {
    return function() {
      setTouched(function(prev) {
        var next = Object.assign({}, prev);
        next[field] = true;
        return next;
      });
    };
  };

  var handleSubmit = function(onSubmit) {
    return function(e) {
      if (e && e.preventDefault) e.preventDefault();
      // Mark all fields touched
      var allTouched = {};
      Object.keys(values).forEach(function(k) { allTouched[k] = true; });
      setTouched(allTouched);
      var errs = runValidation(values);
      setErrors(errs);
      if (Object.keys(errs).length === 0) {
        setSubmitting(true);
        Promise.resolve(onSubmit(values)).then(function() {
          setSubmitting(false);
        }).catch(function() {
          setSubmitting(false);
        });
      }
    };
  };

  var reset = function() {
    setValues(initialValues || {});
    setErrors({});
    setTouched({});
    setSubmitting(false);
  };

  return {
    values: values,
    errors: errors,
    touched: touched,
    isSubmitting: isSubmitting,
    handleChange: handleChange,
    handleBlur: handleBlur,
    handleSubmit: handleSubmit,
    reset: reset,
  };
}
