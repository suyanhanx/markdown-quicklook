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
  const main = document.querySelector('main');
  if (typeof window.previewHTML === 'string') {
    if (!window.DOMPurify) throw new Error('HTML 清理组件缺失');
    DOMPurify.addHook('afterSanitizeAttributes', node => {
      if (node.nodeName === 'INPUT') {
        if (node.getAttribute('type') !== 'checkbox') node.remove();
        else node.setAttribute('disabled', '');
      }
    });
    main.innerHTML = DOMPurify.sanitize(decodeTex(window.previewHTML), {
      USE_PROFILES: {html:true},
      FORBID_TAGS: ['style', 'script', 'iframe', 'object', 'embed', 'form', 'button', 'video', 'audio', 'source', 'link', 'meta'],
      FORBID_ATTR: ['style', 'srcset', 'formaction', 'ping', 'background']
    });
    if (DOMPurify.removed.length) {
      const note = document.createElement('p'); note.className = 'html-notice';
      note.textContent = '已移除 HTML 中的脚本、事件或不支持的元素。'; main.prepend(note);
    }
    delete window.previewHTML;
  }
  document.querySelectorAll('img').forEach(img => {
    const fail = () => {
      if (!img.isConnected) return;
      const note = document.createElement('span'); note.className = 'image-notice';
      note.textContent = `图片加载失败：${img.alt || img.getAttribute('src')}`;
      img.replaceWith(note);
    };
    img.addEventListener('error', fail, {once:true});
    if (img.complete && img.naturalWidth === 0) fail();
  });
  const titles = {NOTE:'Note',TIP:'Tip',IMPORTANT:'Important',WARNING:'Warning',CAUTION:'Caution'};
  document.querySelectorAll('blockquote').forEach(quote => {
    const paragraph = quote.firstElementChild;
    const text = paragraph?.firstChild;
    if (paragraph?.tagName !== 'P' || text?.nodeType !== Node.TEXT_NODE) return;
    const match = text.data.match(/^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](?:\r?\n|$)/);
    if (!match) return;
    text.data = text.data.slice(match[0].length);
    quote.classList.add('markdown-alert', `alert-${match[1].toLowerCase()}`);
    const title = document.createElement('p'); title.className = 'alert-title'; title.textContent = titles[match[1]];
    quote.prepend(title);
    if (!paragraph.textContent.trim()) paragraph.remove();
  });
  const mathItems = [];
  document.querySelectorAll('.math-expression').forEach(node => {
    try { mathItems.push({node, source:decodeTex(node.dataset.tex), display:node.dataset.display === 'block'}); }
    catch (error) { renderError(node, '公式', node.textContent, error); }
  });
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
  const reserved = new Set(Array.from(main.querySelectorAll('[id]:not(h1):not(h2):not(h3):not(h4):not(h5):not(h6)')).map(x=>x.id));
  const headings = Array.from(main.querySelectorAll('h1,h2,h3,h4,h5,h6'));
  headings.forEach(heading => {
    const base = heading.textContent.trim().toLowerCase().replace(/[^\p{L}\p{N}\p{M} _-]/gu, '').replace(/ /g, '-') || 'section';
    let id = heading.id || base, index = 0;
    while (reserved.has(id)) id = `${base}-${++index}`;
    reserved.add(id); heading.id = id;
    const anchor = document.createElement('a'); anchor.className = 'heading-anchor'; anchor.href = `#${encodeURIComponent(id)}`;
    anchor.textContent = '#'; anchor.setAttribute('aria-label', `跳转到 ${heading.textContent}`); heading.append(anchor);
  });
  const markers = Array.from(main.querySelectorAll('p')).filter(p => ['[TOC]', '[[TOC]]'].includes(p.textContent.trim().toUpperCase()));
  if ((document.body.dataset.toc === 'true' || markers.length) && headings.length) {
    function makeTOC() {
      const toc = document.createElement('nav'); toc.className = 'document-toc'; toc.setAttribute('aria-label', '文档目录');
      const title = document.createElement('strong'); title.textContent = '目录'; toc.append(title);
      headings.forEach(heading => {
        const link = document.createElement('a'); link.href = `#${encodeURIComponent(heading.id)}`;
        link.textContent = heading.textContent.slice(0,-1); link.style.paddingLeft = `${(Number(heading.tagName[1])-1)*12}px`; toc.append(link);
      }); return toc;
    }
    if (markers.length) markers.forEach(marker => marker.replaceWith(makeTOC()));
    else main.prepend(makeTOC());
  }
  document.documentElement.dataset.renderComplete = 'true';
  return window.previewRenderState;
})().catch(error => {
  const node = document.createElement('span'); document.querySelector('main').prepend(node);
  renderError(node, '预览', '', error);
  document.documentElement.dataset.renderComplete = 'true';
  return window.previewRenderState;
});
