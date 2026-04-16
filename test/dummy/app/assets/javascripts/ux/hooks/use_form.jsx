// hooks/use_form.js
// Generic form state with per-field validation. No import/export — globals only.

function useForm(initialValues, validate) {
  const { useState } = React;
  const valuesPair = useState(initialValues || {});
  const values = valuesPair[0];
  const setValues = valuesPair[1];

  const errorsPair = useState({});
  const errors = errorsPair[0];
  const setErrors = errorsPair[1];

  const touchedPair = useState({});
  const touched = touchedPair[0];
  const setTouched = touchedPair[1];

  const submittingPair = useState(false);
  const isSubmitting = submittingPair[0];
  const setSubmitting = submittingPair[1];

  const runValidation = (vals) => {
    if (typeof validate !== 'function') return {};
    return validate(vals) || {};
  };

  const handleChange = (field) => {
    return function(e) {
      const val = e && e.target !== undefined
        ? (e.target.type === 'checkbox' ? e.target.checked : e.target.value)
        : e;
      setValues(function(prev) {
        const next = Object.assign({}, prev);
        next[field] = val;
        return next;
      });
    };
  };

  const handleBlur = (field) => {
    return function() {
      setTouched(function(prev) {
        const next = Object.assign({}, prev);
        next[field] = true;
        return next;
      });
    };
  };

  const handleSubmit = (onSubmit) => {
    return function(e) {
      if (e && e.preventDefault) e.preventDefault();
      // Mark all fields touched
      const allTouched = {};
      Object.keys(values).forEach(function(k) { allTouched[k] = true; });
      setTouched(allTouched);
      const errs = runValidation(values);
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

  const reset = () => {
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
