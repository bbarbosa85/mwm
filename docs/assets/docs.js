// Docs page: search, copy buttons and the contents highlight.
(function () {
  // Search: keep the sections that contain every word, highlight the words.
  var input = document.getElementById('q'), status = document.getElementById('status'), bar = document.getElementById('searchbar');
  var sections = Array.prototype.slice.call(document.querySelectorAll('.doc'));
  var links = {};
  Array.prototype.forEach.call(document.querySelectorAll('#toc a'), function (a) { links[a.getAttribute('href').slice(1)] = a; });

  function addCopyButtons(root) {
    Array.prototype.forEach.call((root || document).querySelectorAll('.doc pre'), function (pre) {
      if (pre.querySelector('.copy')) return;
      var b = document.createElement('button'); b.className = 'copy'; b.type = 'button'; b.textContent = 'Copy'; pre.appendChild(b);
    });
  }
  addCopyButtons();
  sections.forEach(function (s) { s.dataset.html = s.innerHTML; s.dataset.text = (s.dataset.title + ' ' + s.textContent).toLowerCase(); });

  function highlight(root, terms) {
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null), nodes = [], n;
    while ((n = walker.nextNode())) { var p = n.parentNode.nodeName; if (p !== 'SCRIPT' && p !== 'MARK' && p !== 'STYLE') nodes.push(n); }
    var pattern = new RegExp('(' + terms.map(function (t) { return t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }).join('|') + ')', 'ig');
    nodes.forEach(function (node) {
      if (!pattern.test(node.nodeValue)) return;
      pattern.lastIndex = 0;
      var span = document.createElement('span');
      span.innerHTML = node.nodeValue.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(pattern, '<mark>$1</mark>');
      node.parentNode.replaceChild(span, node);
    });
  }

  function filter(raw) {
    var terms = raw.trim().toLowerCase().split(/\s+/).filter(Boolean), shown = 0;
    bar.classList.toggle('active', terms.length > 0);
    sections.forEach(function (s) {
      s.innerHTML = s.dataset.html;
      var match = terms.every(function (t) { return s.dataset.text.indexOf(t) !== -1; });
      s.hidden = !match;
      if (links[s.id]) links[s.id].classList.toggle('none', !match);
      if (match) {
        shown++;
        if (terms.length) { Array.prototype.forEach.call(s.querySelectorAll('details'), function (d) { d.open = true; }); highlight(s, terms); }
      }
    });
    document.getElementById('empty').style.display = (terms.length && shown === 0) ? 'block' : 'none';
    status.textContent = terms.length ? (shown + (shown === 1 ? ' section matches' : ' sections match') + ' “' + raw.trim() + '”') : '';
    if (history.replaceState) history.replaceState(null, '', terms.length ? '?q=' + encodeURIComponent(raw.trim()) + location.hash : location.pathname + location.hash);
  }
  input.addEventListener('input', function () { filter(input.value); });
  function clear() { input.value = ''; filter(''); input.focus(); }
  document.getElementById('clear').addEventListener('click', clear);
  document.getElementById('empty-clear').addEventListener('click', function (e) { e.preventDefault(); clear(); });
  document.addEventListener('keydown', function (e) {
    var typing = /INPUT|TEXTAREA/.test(document.activeElement.nodeName);
    if (e.key === '/' && !typing) { e.preventDefault(); input.focus(); input.select(); }
    if (e.key === 'Escape' && document.activeElement === input) { if (input.value) clear(); else input.blur(); }
  });
  document.addEventListener('click', function (e) {
    if (!e.target.classList || !e.target.classList.contains('copy')) return;
    var code = e.target.parentNode.querySelector('code'), text = code ? code.textContent : '';
    if (navigator.clipboard) navigator.clipboard.writeText(text);
    var b = e.target; b.textContent = 'Copied'; setTimeout(function () { b.textContent = 'Copy'; }, 1200);
  });

  if ('IntersectionObserver' in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) { if (en.isIntersecting && links[en.target.id]) { Object.keys(links).forEach(function (k) { links[k].classList.remove('on'); }); links[en.target.id].classList.add('on'); } });
    }, { rootMargin: '-20% 0px -70% 0px' });
    sections.forEach(function (s) { observer.observe(s); });
  }
  var initial = new URLSearchParams(location.search).get('q');
  if (initial) { input.value = initial; filter(initial); }
})();
