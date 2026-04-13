// hooks/use_modal.js
// Modal open/close state. Returns {isOpen, open, close, toggle}.
// No import/export — globals only.

function useModal(initialOpen) {
  var isOpenPair = React.useState(!!initialOpen);
  var isOpen = isOpenPair[0];
  var setIsOpen = isOpenPair[1];

  var open = function() { setIsOpen(true); };
  var close = function() { setIsOpen(false); };
  var toggle = function() { setIsOpen(function(prev) { return !prev; }); };

  return { isOpen: isOpen, open: open, close: close, toggle: toggle };
}
