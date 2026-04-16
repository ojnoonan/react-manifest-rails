// components/forms/file_upload.js
// Drag-and-drop file upload area. Props: label, accept, onChange, hint.
// No JSX — uses React.createElement. No import/export — globals only.

const FileUpload = (props) => {
  const { useState } = React;
  const id = props.id || 'file-upload';
  const filePair = useState(null);
  const fileName = filePair[0];
  const setFileName = filePair[1];
  const draggingPair = useState(false);
  const isDragging = draggingPair[0];
  const setIsDragging = draggingPair[1];

  const handleChange = (ev) => {
    const file = ev.target.files && ev.target.files[0];
    setFileName(file ? file.name : null);
    if (props.onChange) props.onChange(ev);
  };

  const handleDrop = (ev) => {
    ev.preventDefault();
    setIsDragging(false);
    const file = ev.dataTransfer.files && ev.dataTransfer.files[0];
    if (file) {
      setFileName(file.name);
      if (props.onChange) {
        const fakeEvent = { target: { files: ev.dataTransfer.files } };
        props.onChange(fakeEvent);
      }
    }
  };

  const dropZoneCls = [
    'border-2 border-dashed rounded-lg p-6 text-center cursor-pointer transition-colors',
    isDragging ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400 bg-gray-50',
  ].join(' ');

  return React.createElement('div', { className: 'mb-4' },
    props.label ? React.createElement('label', { className: 'block text-sm font-medium text-gray-700 mb-1' }, props.label) : null,
    React.createElement('div', {
      className: dropZoneCls,
      onDragOver: function(ev) { ev.preventDefault(); setIsDragging(true); },
      onDragLeave: function() { setIsDragging(false); },
      onDrop: handleDrop,
      onClick: function() { document.getElementById(id).click(); },
    },
      React.createElement('div', { className: 'text-3xl mb-2' }, '📎'),
      fileName
        ? React.createElement('p', { className: 'text-sm font-medium text-gray-700' }, fileName)
        : React.createElement('div', null,
            React.createElement('p', { className: 'text-sm text-gray-600' }, 'Drop a file here, or click to browse'),
            props.hint ? React.createElement('p', { className: 'text-xs text-gray-400 mt-1' }, props.hint) : null
          )
    ),
    React.createElement('input', {
      id: id,
      type: 'file',
      accept: props.accept,
      onChange: handleChange,
      disabled: props.disabled,
      className: 'hidden',
    }),
    props.error ? React.createElement('p', { className: 'mt-1 text-xs text-red-600' }, props.error) : null
  );
};
