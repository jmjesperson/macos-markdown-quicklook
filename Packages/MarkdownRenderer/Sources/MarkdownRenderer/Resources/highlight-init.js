// Highlights fenced blocks whose language highlight.js knows; others stay plain monospaced text.
(function () {
  hljs.configure({ ignoreUnescapedHTML: true });
  document.querySelectorAll('pre > code[class^="language-"]').forEach(function (el) {
    var lang = el.className.slice('language-'.length);
    if (hljs.getLanguage(lang)) { hljs.highlightElement(el); }
  });
})();
