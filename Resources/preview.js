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
  pendingRenders.delete(target);
  target.replaceWith(box);
  updateProgress();
  window.previewRenderState.errors.push({kind, message: label.textContent});
}
const pendingRenders = new Set();
const pendingSources = new WeakMap();
let renderTotal = 0;
function updateProgress() {
  const label = document.querySelector('.preview-progress-label');
  if (label) label.textContent = renderTotal ? `图表与公式：已处理 ${renderTotal - pendingRenders.size} / ${renderTotal}` : '正在处理代码…';
}
function skeleton(node, kind, inline = false, source = '') {
  node.classList.add('render-placeholder');
  if (inline) node.classList.add('placeholder-inline');
  node.setAttribute('aria-busy', 'true');
  const label = document.createElement('span'); label.className = 'placeholder-label'; label.textContent = `${kind} · 排队中`;
  const bars = document.createElement('span'); bars.className = 'placeholder-bars'; bars.setAttribute('aria-hidden', 'true');
  for (let i = 0; i < (inline ? 1 : 3); i++) bars.append(document.createElement('span'));
  node.replaceChildren(label, bars);
  node.dataset.renderKind = kind;
  pendingRenders.add(node); pendingSources.set(node, source); renderTotal++;
}
function activateSkeleton(node) {
  node.classList.add('placeholder-active');
  node.querySelector('.placeholder-label').textContent = `${node.dataset.renderKind} · 正在渲染…`;
}
function finishSkeleton(node) {
  pendingRenders.delete(node);
  node.classList.remove('render-placeholder', 'placeholder-inline', 'placeholder-active');
  node.removeAttribute('aria-busy'); delete node.dataset.renderKind;
  updateProgress();
}
function decodeTex(base64) {
  return new TextDecoder().decode(Uint8Array.from(atob(base64), c => c.charCodeAt(0)));
}
const previewControl = {cancelled:false, lastScroll:-Infinity};
window.cancelPreview = () => { previewControl.cancelled = true; };
addEventListener('pagehide', window.cancelPreview, {once:true});
addEventListener('scroll', () => { previewControl.lastScroll = performance.now(); }, {capture:true, passive:true});
async function checkpoint(budget) {
  await new Promise(resolve => setTimeout(resolve, 0));
  if (previewControl.cancelled) throw new Error('预览渲染已取消');
  const pausedAt = performance.now();
  while (performance.now() - previewControl.lastScroll < 160) {
    if (previewControl.cancelled) throw new Error('预览渲染已取消');
    await new Promise(resolve => setTimeout(resolve, 40));
  }
  if (budget) {
    budget.deadline += performance.now() - pausedAt;
    if (performance.now() > budget.deadline) throw new Error('本项渲染超过 30 秒，已停止');
  }
}
async function bounded(promise, milliseconds) {
  let timer, cancellationTimer;
  try {
    return await Promise.race([promise, new Promise((_, reject) => {
      cancellationTimer = setInterval(() => { if (previewControl.cancelled) reject(new Error('预览渲染已取消')); }, 50);
    }), new Promise((_, reject) => {
      timer = setTimeout(() => { previewControl.cancelled = true; reject(new Error('渲染等待超时，已停止后续处理')); }, milliseconds);
    })]);
  } finally { clearTimeout(timer); clearInterval(cancellationTimer); }
}
async function svgImage(svg, label) {
  const image = new Image();
  image.alt = label;
  image.decoding = 'async';
  // Self-contained SVG images retain vector zoom while removing their paths/text
  // from the page's live layout tree. Decode before replacing the placeholder.
  const serialized = new XMLSerializer().serializeToString(svg);
  const bytes = new TextEncoder().encode(serialized);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 32768) binary += String.fromCharCode(...bytes.subarray(i, i + 32768));
  image.src = `data:image/svg+xml;base64,${btoa(binary)}`;
  await bounded(image.decode(), 5000);
  if (!image.naturalWidth || !image.naturalHeight) throw new Error('图形图像解码失败');
  return image;
}
function diagramControls(target, svg, width, height) {
  const bar = document.createElement('div'); bar.className = 'diagram-toolbar'; bar.setAttribute('role', 'group'); bar.setAttribute('aria-label', '图表缩放');
  const viewport = document.createElement('div'); viewport.className = 'diagram-viewport'; viewport.tabIndex = 0; viewport.setAttribute('aria-label', '图表，可横向滚动');
  svg.removeAttribute('width'); svg.removeAttribute('height'); svg.style.maxWidth = 'none';
  viewport.append(svg); target.append(bar, viewport);
  let scale = 1, fit = true;
  const label = document.createElement('output'); label.setAttribute('aria-live', 'polite');
  function apply() {
    if (fit) scale = Math.min(1, Math.max(0.01, viewport.clientWidth / width));
    svg.style.width = `${width * scale}px`; svg.style.height = `${height * scale}px`;
    label.textContent = `${Math.round(scale * 100)}%`;
  }
  function button(text, action) { const b = document.createElement('button'); b.type = 'button'; b.textContent = text; b.addEventListener('click', action); bar.append(b); }
  button('缩小', () => { fit = false; scale = Math.max(.1, scale / 1.25); apply(); });
  button('放大', () => { fit = false; scale = Math.min(4, scale * 1.25); apply(); });
  button('实际大小', () => { fit = false; scale = 1; apply(); });
  button('适应宽度', () => { fit = true; apply(); });
  bar.append(label); new ResizeObserver(() => { if (fit) apply(); }).observe(viewport); apply();
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
  const progress = document.createElement('div'); progress.className = 'preview-progress';
  const cancel = document.createElement('button'); cancel.textContent = '取消渲染'; cancel.type = 'button'; cancel.addEventListener('click', window.cancelPreview);
  const progressLabel = document.createElement('span'); progressLabel.className = 'preview-progress-label';
  progressLabel.setAttribute('role', 'status');
  progress.append(progressLabel, cancel); main.prepend(progress);
  document.querySelectorAll('img').forEach(img => {
    const fail = () => {
      if (!img.isConnected) return;
      const note = document.createElement('span'); note.className = 'image-notice';
      note.textContent = `图片加载失败：${img.alt || img.getAttribute('src')}`;
      img.replaceWith(note);
    };
    const timer = setTimeout(fail, 15000);
    img.addEventListener('load', () => clearTimeout(timer), {once:true});
    img.addEventListener('error', () => {clearTimeout(timer); fail();}, {once:true});
    if (img.complete) clearTimeout(timer);
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
  mathItems.forEach(item => skeleton(item.node, '公式', !item.display, item.source));
  const diagrams = Array.from(document.querySelectorAll('pre > code.language-mermaid')).map(code => {
    const source = code.textContent;
    const target = document.createElement('div'); target.className = 'mermaid-diagram';
    code.parentElement.replaceWith(target); skeleton(target, '图表', false, source);
    return {source, target};
  });
  updateProgress();
  await checkpoint();
  if (mathItems.length) {
    try {
      if (!window.MathJax?.startup?.promise) throw new Error('MathJax 资源未能启动');
      await bounded(MathJax.startup.promise, 5000);
      for (const [index, item] of mathItems.entries()) {
        try {
          await checkpoint();
          activateSkeleton(item.node);
          const budget = {deadline:performance.now() + 30000};
          if (index >= 200 || item.source.length > 10000) throw new Error('公式超过限制：最多 200 项，单项 10000 字符');
          const result = MathJax.tex2svg(item.source, {display: item.display});
          const errorNode = result.querySelector('[data-mjx-error]');
          if (errorNode) throw new Error(errorNode.getAttribute('data-mjx-error'));
          const svg = result.querySelector('svg');
          if (!svg) throw new Error('公式缺少 SVG 图形');
          svg.style.color = getComputedStyle(item.node).color;
          const image = await svgImage(svg, item.source);
          image.className = 'math-image';
          image.style.width = svg.getAttribute('width');
          image.style.height = svg.getAttribute('height');
          image.style.verticalAlign = svg.style.verticalAlign;
          await checkpoint(budget);
          item.node.replaceChildren(image);
          finishSkeleton(item.node);
          item.node.setAttribute('aria-label', item.source);
          window.previewRenderState.math++;
        } catch (error) { renderError(item.node, '公式', item.source, error); }
      }
    } catch (error) { mathItems.forEach(item => renderError(item.node, '公式', item.source, error)); }
  }
  if (diagrams.length) {
    try {
      if (!window.mermaid) throw new Error('Mermaid 资源未能启动');
      const theme = document.documentElement.dataset.theme;
      const dark = theme === 'dark' || (theme === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches);
      mermaid.initialize({startOnLoad:false, securityLevel:'strict', secure:['securityLevel','maxTextSize','maxEdges','startOnLoad','suppressErrorRendering'], theme:dark ? 'dark' : 'default', suppressErrorRendering:true, maxTextSize:20000, maxEdges:200, flowchart:{htmlLabels:false}});
      for (let i = 0; i < diagrams.length; i++) {
        const {source, target} = diagrams[i];
        try {
          await checkpoint();
          activateSkeleton(target);
          // Paint before starting this item's clock. Queue and scroll waits are excluded.
          await new Promise(resolve => setTimeout(resolve, 16));
          await checkpoint();
          const budget = {deadline:performance.now() + 30000};
          if (i >= 20 || source.length > 20000 || source.split('\n').length > 400) throw new Error('图表超过限制：最多 20 张，单张 20000 字符、400 行、200 条边');
          // Parse first so invalid input never leaves Mermaid's temporary error SVG behind.
          await bounded(mermaid.parse(source), 5000);
          await checkpoint(budget);
          const {svg} = await bounded(mermaid.render(`diagram-${i}`, source), 5000);
          await checkpoint(budget);
          const parsed = new DOMParser().parseFromString(svg, 'image/svg+xml');
          const graphic = parsed.documentElement, view = graphic.viewBox?.baseVal;
          if (parsed.querySelector('parsererror') || !view?.width || !view?.height) throw new Error('图表缺少有效 SVG 尺寸');
          const width = view.width, height = view.height;
          const image = await svgImage(graphic, `图表 ${i + 1}：${Array.from(graphic.querySelectorAll('text')).map(x=>x.textContent).join('，')}`);
          image.className = 'diagram-image';
          await checkpoint(budget);
          target.replaceChildren(image);
          diagramControls(target, image, width, height);
          finishSkeleton(target);
          window.previewRenderState.mermaid++;
        } catch (error) { renderError(target, 'Mermaid', source, error); }
      }
    } catch (error) { diagrams.forEach(({target, source}) => { if (pendingRenders.has(target)) renderError(target, 'Mermaid', source, error); }); }
  }
  for (const code of document.querySelectorAll('pre > code:not(.language-mermaid):not(.language-math)')) {
    await checkpoint();
    if (code.textContent.length > 50000) {
      const note = document.createElement('p'); note.className = 'html-notice'; note.textContent = '代码超过 50000 字符，保留原文并跳过高亮。'; code.parentElement.before(note);
    } else hljs.highlightElement(code);
  }
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
  document.querySelector('.preview-progress')?.remove();
  document.documentElement.dataset.renderComplete = 'true';
  return window.previewRenderState;
})().catch(error => {
  for (const target of Array.from(pendingRenders)) renderError(target, target.dataset.renderKind || '内容', pendingSources.get(target) || '', error);
  const node = document.createElement('span'); document.querySelector('main').prepend(node);
  renderError(node, '预览', '', error);
  document.querySelector('.preview-progress')?.remove();
  document.documentElement.dataset.renderComplete = 'true';
  return window.previewRenderState;
});
