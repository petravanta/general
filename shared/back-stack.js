/* Back stack: the browser's and the phone's Back closes the view in front, not the app. See STANDARDS.md,
   "Back button".

   Before </body>, before hub-link.js:
     <script src="https://petravanta.github.io/general/shared/back-stack.js" defer></script>

   When a foreground view opens (a dialog, sheet, drawer, menu, close-up, or a detail screen over a list):
     var layer = BackStack.push(function (reason) { sheet.hidden = true; }, { esc: true });
   and everywhere the app closes it itself (Close button, Save, a tap outside):
     layer.close();

   - push() adds one history entry, so Back closes that view instead of leaving the app. Nothing is
     pushed at the app's root view, so Back there leaves the app as people expect.
   - The function given to push() runs exactly once, however the view goes away: Back ('back'), the
     app's own layer.close() ('close'), Esc with { esc: true } ('esc'), or a view beneath it closing
     ('parent'). It is safe for that function to call layer.close() itself.
   - layer.close() takes the view's history entry away again, so the history stays in step and the
     next Back doesn't land on a stale entry. Closing a view also closes every view opened on top of it.
   - For Back only, the function may return false to keep the view open (for example to ask
     "Discard changes?"); the entry is put back.
   - The URL never changes. Push only when the person opens something (a tap or a key), never on page
     load: browsers skip history entries that no one asked for.
   - After a reload with views open, the page steps back to its root entry, since the views are gone.

   Also: BackStack.depth() (views open), BackStack.closeAll(), and BackStack.top() (the front layer). */
(function () {
  if (window.BackStack) return;

  var KEY = 'backStack';
  var stack = [];       // open layers, front last
  var pushed = 0;       // how many of them have their history entry in place
  var waiting = 0;      // history.go() calls of ours still on their way to popstate
  var timer = null;

  function stateFor(depth) {
    var s = history.state, out = {};
    if (s && typeof s === 'object') for (var k in s) if (Object.prototype.hasOwnProperty.call(s, k)) out[k] = s[k];
    out[KEY] = depth;
    return out;
  }

  function depthOf(state) {
    return state && typeof state === 'object' && typeof state[KEY] === 'number' ? state[KEY] : 0;
  }

  // Give every open layer that still lacks one its history entry, unless we're waiting for history to settle.
  function flush() {
    if (waiting) return;
    while (pushed < stack.length) {
      pushed++;
      try { history.pushState(stateFor(pushed), ''); } catch (e) { /* sandboxed frame: Back just won't close it */ }
    }
  }

  // Take `n` of our entries off the history, then push whatever opened in the meantime.
  function goBack(n) {
    if (n <= 0) return flush();
    waiting++;
    pushed -= n;
    history.go(-n);
    clearTimeout(timer);
    // popstate normally arrives within a frame or two; don't hang if a browser never sends it.
    timer = setTimeout(function () { waiting = 0; flush(); }, 800);
  }

  function settle() {
    if (waiting > 0) waiting--;
    if (!waiting) { clearTimeout(timer); flush(); }
  }

  function run(layer, reason) {
    try { return layer.onClose(reason); } catch (e) { setTimeout(function () { throw e; }); }
  }

  // Remove layers from index `from` up, front first. Returns how many had history entries.
  function removeFrom(from, reason) {
    var hadEntries = Math.max(0, pushed - from);
    while (stack.length > from) {
      var layer = stack.pop();
      layer.open = false;
      run(layer, stack.length > from ? 'parent' : reason);
    }
    return hadEntries;
  }

  function Layer(onClose, opts) {
    this.onClose = typeof onClose === 'function' ? onClose : function () {};
    this.esc = !!(opts && opts.esc);
    this.open = true;
  }

  Layer.prototype.close = function (reason) {
    if (!this.open) return;
    var i = stack.indexOf(this);
    if (i < 0) { this.open = false; return; }
    // Front layers above this one close as 'parent'; this one closes with the given reason.
    var removed = Math.max(0, pushed - i);
    var above = stack.splice(i + 1);
    stack.pop();
    this.open = false;
    for (var j = above.length - 1; j >= 0; j--) { above[j].open = false; run(above[j], 'parent'); }
    run(this, reason || 'close');
    goBack(Math.min(removed, pushed));
  };

  window.addEventListener('popstate', function (e) {
    var target = depthOf(e.state);
    if (waiting) { settle(); return; }
    // The person pressed Back (or Forward to an entry whose view is gone). Close what's above the entry.
    if (target > pushed) return;
    pushed = target;
    while (stack.length > target) {
      var layer = stack[stack.length - 1];
      if (run(layer, 'back') === false) {
        // The view wants to stay: give it its entry back.
        pushed = stack.length;
        try { history.pushState(stateFor(pushed), ''); } catch (err) {}
        return;
      }
      layer.open = false;
      stack.pop();
      // A view beneath closes too only if Back skipped past it (history.go(-2), a long-press on Back).
      if (stack.length > target) {
        removeFrom(target, 'back');
      }
    }
  });

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape' || e.defaultPrevented || !stack.length) return;
    var top = stack[stack.length - 1];
    if (!top.esc) return;
    e.preventDefault();
    top.close('esc');
  });

  // A reload or a return without the back-forward cache: views opened before are gone, so step back to the root entry.
  var start = depthOf(history.state);
  if (start > 0) {
    waiting = 1;
    history.go(-start);
    timer = setTimeout(function () { waiting = 0; flush(); }, 800);
  }

  window.BackStack = {
    push: function (onClose, opts) {
      var layer = new Layer(onClose, opts);
      stack.push(layer);
      flush();
      return layer;
    },
    depth: function () { return stack.length; },
    top: function () { return stack[stack.length - 1] || null; },
    closeAll: function () { if (stack.length) stack[0].close(); }
  };
})();
