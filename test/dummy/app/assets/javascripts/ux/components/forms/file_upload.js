// components/forms/file_upload.js
// Drag-and-drop file upload area. Props: label, accept, onChange, hint.
// No JSX — uses React.createElement. No import/export — globals only.

var FileUpload = function(props) {
  var e = React.createElement;
  var id = props.id || 'file-upload';
  var filePair = React.useState(null);
  var fileName = filePair[0];
  var setFileName = filePair[1];
  var draggingPair = React.useState(false);
  var isDragging = draggingPair[0];
  var setIsDragging = draggingPair[1];

  var handleChange = function(ev) {
    var file = ev.target.files && ev.target.files[0];
    setFileName(file ? file.name : null);
    if (props.onChange) props.onChange(ev);
  };

  var handleDrop = function(ev) {
    ev.preventDefault();
    setIsDragging(false);
    var file = ev.dataTransfer.files && ev.dataTransfer.files[0];
    if (file) {
      setFileName(file.name);
      if (props.onChange) {
        var fakeEvent = { target: { files: ev.dataTransfer.files } };
        props.onChange(fakeEvent);
      }
    }
  };

  var dropZoneCls = [
    'border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-colors',
    isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400 bg-gray-50',
  ].join(' ');

  return e('div', { className: 'mb-4' },
    props.label ? e('label', { className: 'block text-sm font-medium text-gray-700 mb-1' }, props.label) : null,
    e('div', {
      className: dropZoneCls,
      onDragOver: function(ev) { ev.preventDefault(); setIsDragging(true); },
      onDragLeave: function() { setIsDragging(false); },
      onDrop: handleDrop,
      onClick: function() { document.getElementById(id).click(); },
    },
      e('div', { className: 'text-3xl mb-2' }, '📎'),
      fileName
        ? e('p', { className: 'text-sm font-medium text-gray-700' }, fileName)
        : e('div', null,
            e('p', { className: 'text-sm text-gray-600' }, 'Drop a file here, or click to browse'),
            props.hint ? e('p', { className: 'text-xs text-gray-400 mt-1' }, props.hint) : null
          )
    ),
    e('input', {
      id: id,
      type: 'file',
      accept: props.accept,
      onChange: handleChange,
      disabled: props.disabled,
      className: 'hidden',
    }),
    props.error ? e('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
