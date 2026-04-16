/*
 * Dummy root-level asset used to verify migration preserves non-ux requires.
 */
(function(global) {
  var MiniSearch = {
    ready: true,
    index: function(items) {
      return Array.isArray(items) ? items.length : 0;
    }
  };

  global.MiniSearch = MiniSearch;
})(this);
