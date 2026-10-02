/* Offline rendering. Every failure is visible beside its original source. */
window.previewRenderState = {math: 0, mermaid: 0, errors: []};
function renderError(target, kind, source, error) {
  const box = document.createElement('span');
  box.className = 'render-error';
  box.setAttribute('role', 'alert');
  const label = document.createElement('strong');
  label.textContent = `${kind} 渲染失败：${error.message || String(error)}`;
  const code = document.createElement('code');
  code.textContent = source;
  box.append(label, code);
  target.replaceWith(box);
  window.previewRenderState.errors.push({kind, message: label.textContent});
}
function decodeTex(base64) {
  return new TextDecoder().decode(Uint8Array.from(atob(base64), c => c.charCodeAt(0)));
}
window.previewRenderPromise = (async () => {
  const mathItems = Array.from(document.querySelectorAll('.math-expression')).map(node => ({node, source: decodeTex(node.dataset.tex), display: node.dataset.display === 'block'}));
  document.querySelectorAll('pre > code.language-math').forEach(code => {
    const node = document.createElement('div'); node.className = 'math-expression math-block';
    const source = code.textContent; code.parentElement.replaceWith(node);
    mathItems.push({node, source, display: true});
  });
  if (mathItems.length) {
    try {
      if (!window.MathJax?.startup?.promise) throw new Error('MathJax 资源未能启动');
      await MathJax.startup.promise;
      for (const item of mathItems) {
        try {
          const result = MathJax.tex2svg(item.source, {display: item.display});
          const errorNode = result.querySelector('[data-mjx-error]');
          if (errorNode) throw new Error(errorNode.getAttribute('data-mjx-error'));
          item.node.replaceChildren(result);
          item.node.setAttribute('aria-label', item.source);
          window.previewRenderState.math++;
        } catch (error) { renderError(item.node, '公式', item.source, error); }
      }
    } catch (error) { mathItems.forEach(item => renderError(item.node, '公式', item.source, error)); }
  }
  const diagrams = Array.from(document.querySelectorAll('pre > code.language-mermaid'));
  if (diagrams.length) {
    try {
      if (!window.mermaid) throw new Error('Mermaid 资源未能启动');
      const theme = document.documentElement.dataset.theme;
      const dark = theme === 'dark' || (theme === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches);
      mermaid.initialize({startOnLoad:false, securityLevel:'strict', theme:dark ? 'dark' : 'default', suppressErrorRendering:true, maxTextSize:100000, flowchart:{htmlLabels:false}});
      for (let i = 0; i < diagrams.length; i++) {
        const code = diagrams[i], source = code.textContent;
        const target = document.createElement('div'); target.className = 'mermaid-diagram';
        code.parentElement.replaceWith(target);
        try {
          // Parse first so invalid input never leaves Mermaid's temporary error SVG behind.
          await mermaid.parse(source);
          const {svg} = await mermaid.render(`diagram-${i}`, source);
          target.innerHTML = svg;
          window.previewRenderState.mermaid++;
        } catch (error) { renderError(target, 'Mermaid', source, error); }
      }
    } catch (error) { diagrams.forEach(code => renderError(code.parentElement, 'Mermaid', code.textContent, error)); }
  }
  document.querySelectorAll('pre > code:not(.language-mermaid):not(.language-math)').forEach(code => hljs.highlightElement(code));
  document.documentElement.dataset.renderComplete = 'true';
  return window.previewRenderState;
})();
