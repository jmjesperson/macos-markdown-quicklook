// Renders each mermaid block in place, after the text has painted. A block that fails shows its error
// and source; the others still render.
(function () {
  var nonce = document.currentScript && document.currentScript.nonce;
  var dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  mermaid.initialize({ startOnLoad: false, theme: dark ? 'dark' : 'default', securityLevel: 'strict', suppressErrorRendering: true });
  var blocks = Array.prototype.slice.call(document.querySelectorAll('.mermaid-diagram'));

  function place(block, svgText) {
    // Parse as HTML, not XML: Mermaid writes a <br/> in a label as an unclosed <br>, which the XML parser
    // rejects, returning its error page instead of throwing. Template content is inert until inserted.
    var template = document.createElement('template');
    template.innerHTML = svgText;
    var svg = template.content.querySelector('svg');
    if (!svg) { throw new Error('Mermaid returned no SVG'); }
    // The page's Content Security Policy only admits styles carrying its nonce.
    Array.prototype.forEach.call(svg.querySelectorAll('style'), function (s) { if (nonce) s.setAttribute('nonce', nonce); });
    var node = document.importNode(svg, true);
    var vb = node.viewBox && node.viewBox.baseVal;
    if (vb && vb.width) { node.style.maxWidth = vb.width + 'px'; }
    block.replaceChildren(node);
  }

  function showError(block, error) {
    var message = document.createElement('p');
    message.className = 'mermaid-error';
    message.textContent = 'Unable to render diagram: ' + (error && error.message ? error.message : String(error));
    block.insertBefore(message, block.firstChild);
  }

  async function renderAll() {
    for (var i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      var source = block.querySelector('pre').textContent;
      try {
        var result = await mermaid.render('mermaid-svg-' + i, source);
        place(block, result.svg);
        block.dataset.state = 'rendered';
      } catch (error) {
        block.dataset.state = 'error';
        showError(block, error);
      }
    }
    document.documentElement.dataset.diagrams = 'done';
  }

  // Two animation frames: the first lets layout happen, the second runs after the text has painted.
  requestAnimationFrame(function () { requestAnimationFrame(renderAll); });
})();
