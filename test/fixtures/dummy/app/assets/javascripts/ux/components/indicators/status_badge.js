export default function StatusBadge(props) {
  var state = props.active ? 'active' : 'idle';
  return React.createElement('span', { className: 'status-badge ' + state }, props.label || state);
}
