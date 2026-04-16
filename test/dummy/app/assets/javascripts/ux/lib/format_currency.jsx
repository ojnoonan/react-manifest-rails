// lib/format_currency.js
// Currency and compact number formatting utilities. No import/export — globals only.

function formatCurrency(amount, currency) {
  if (amount == null || isNaN(amount)) return '—';
  const code = currency || 'USD';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: code,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

function formatCompact(n) {
  if (n == null || isNaN(n)) return '—';
  const abs = Math.abs(n);
  if (abs >= 1e9) return (n / 1e9).toFixed(1).replace(/\.0$/, '') + 'B';
  if (abs >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M';
  if (abs >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'k';
  return String(n);
}

function formatPercent(value, decimals) {
  if (value == null || isNaN(value)) return '—';
  return value.toFixed(decimals != null ? decimals : 1) + '%';
}

function formatNumber(n) {
  if (n == null || isNaN(n)) return '—';
  return new Intl.NumberFormat('en-US').format(n);
}
