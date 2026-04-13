// lib/format_date.js
// Date formatting utilities. No import/export — globals only.

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
}

function formatDateTime(d) {
  if (!d) return '—';
  return new Date(d).toLocaleString('en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function formatRelative(d) {
  if (!d) return '—';
  var seconds = Math.floor((Date.now() - new Date(d).getTime()) / 1000);
  if (seconds < 60) return 'just now';
  var intervals = [
    [31536000, 'year'], [2592000, 'month'], [86400, 'day'],
    [3600, 'hour'], [60, 'minute'],
  ];
  for (var i = 0; i < intervals.length; i++) {
    var count = Math.floor(seconds / intervals[i][0]);
    if (count >= 1) return count + ' ' + intervals[i][1] + (count !== 1 ? 's' : '') + ' ago';
  }
  return 'just now';
}

function formatDateRange(start, end) {
  if (!start && !end) return '—';
  if (!end) return formatDate(start) + ' – present';
  if (!start) return 'until ' + formatDate(end);
  var s = new Date(start);
  var e = new Date(end);
  if (s.getFullYear() === e.getFullYear() && s.getMonth() === e.getMonth()) {
    return s.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) +
      ' – ' + e.getDate() + ', ' + e.getFullYear();
  }
  return formatDate(start) + ' – ' + formatDate(end);
}
