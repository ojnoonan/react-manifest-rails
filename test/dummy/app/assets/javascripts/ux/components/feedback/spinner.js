// components/feedback/spinner.js
// Animated SVG spinner. Props: size ('sm'|'md'|'lg'), label (string).
// No JSX — uses React.createElement. No import/export — globals only.

var Spinner = function(props) {
  var e = React.createElement;
  var sizeMap = { sm: 'w-4 h-4', md: 'w-8 h-8', lg: 'w-12 h-12' };
  var sizeClass = sizeMap[props.size || 'md'] || sizeMap.md;
  var label = props.label || 'Loading…';

  return e('span', { role: 'status', 'aria-label': label, className: 'inline-flex items-center justify-center' },
    e('svg', {
      className: sizeClass + ' animate-spin text-blue-600',
      xmlns: 'http://www.w3.org/2000/svg',
      fill: 'none',
      viewBox: '0 0 24 24',
      'aria-hidden': 'true',
    },
      e('circle', {
        className: 'opacity-25',
        cx: '12', cy: '12', r: '10',
        stroke: 'currentColor', strokeWidth: '4',
      }),
      e('path', {
        className: 'opacity-75',
        fill: 'currentColor',
        d: 'M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z',
      })
    ),
    e('span', { className: 'sr-only' }, label)
  );
};
