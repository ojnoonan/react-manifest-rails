// hooks/use_modal.js
// Modal open/close state. Returns {isOpen, open, close, toggle}.
// No import/export — globals only.

function useModal(initialOpen) {
  const { useState } = React;
  const isOpenPair = useState(!!initialOpen);
  const isOpen = isOpenPair[0];
  const setIsOpen = isOpenPair[1];

  const open = () => { setIsOpen(true); };
  const close = () => { setIsOpen(false); };
  const toggle = () => { setIsOpen(function(prev) { return !prev; }); };

  return { isOpen: isOpen, open: open, close: close, toggle: toggle };
}
