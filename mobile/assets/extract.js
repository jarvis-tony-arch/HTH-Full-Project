// HTH on-device review reader. Injected into a shopping page that the user's
// own phone loaded. It only READS what the page already shows. It never fills
// forms, never clicks sign-in or verification controls, and reports
// "blocked" so the app can hand the page to the user instead.
//
// Called as: __hth.run(<callId>, <action>, <platform config>, <options>)
// Replies through the HTH JavaScript channel: {"id":..,"result":..}
(function () {
  if (window.__hth) return;

  // "a, b@attr" -> list of [css, attr]. Splits on commas outside [...].
  function alts(spec) {
    if (!spec) return [];
    return spec.split(/,\s*(?![^\[]*\])/).map(function (s) {
      var at = s.lastIndexOf('@');
      if (at >= 0 && s.indexOf(']', at) < 0) return [s.slice(0, at).trim(), s.slice(at + 1).trim()];
      return [s.trim(), null];
    });
  }
  function clean(t) { return (t || '').replace(/\s+/g, ' ').trim(); }
  function valueOf(el, attr) {
    if (!el) return '';
    if (!attr) return clean(el.innerText || el.textContent);
    if (attr === 'id') return el.id || '';
    var v = el.getAttribute(attr) || '';
    if (attr === 'style') { var m = v.match(/url\(["']?([^"')]+)/); return m ? m[1] : ''; }
    if (attr === 'href' || attr === 'src') { try { return new URL(v, location.href).href; } catch (e) { return v; } }
    return clean(v);
  }
  function q(root, spec) {
    var a = alts(spec);
    for (var i = 0; i < a.length; i++) {
      if (a[i][0] === '') { var self = valueOf(root, a[i][1]); if (self) return self; continue; }
      try {
        var els = root.querySelectorAll(a[i][0]);
        for (var j = 0; j < els.length; j++) { var v = valueOf(els[j], a[i][1]); if (v) return v; }
      } catch (e) { /* bad selector in config: skip it */ }
    }
    return '';
  }
  function qa(root, spec) {
    var out = [], a = alts(spec);
    for (var i = 0; i < a.length; i++) {
      if (a[i][0] === '') { var sv = valueOf(root, a[i][1]); if (sv) return [sv]; continue; }
      try {
        var els = root.querySelectorAll(a[i][0]);
        for (var j = 0; j < els.length; j++) { var v = valueOf(els[j], a[i][1]); if (v) out.push(v); }
        if (out.length) return out;
      } catch (e) { }
    }
    return out;
  }
  function els(root, spec) {
    var a = alts(spec);
    for (var i = 0; i < a.length; i++) {
      try { var e = root.querySelectorAll(a[i][0]); if (e.length) return Array.prototype.slice.call(e); } catch (x) { }
    }
    return [];
  }
  function num(t) {
    var m = (t || '').replace(/,/g, '').match(/\d+(\.\d+)?/);
    return m ? parseFloat(m[0]) : null;
  }
  function stars(t) {
    // "4 out of 5 stars", "4.0", "3"
    var m = (t || '').match(/([1-5](?:\.\d)?)\s*(?:out of|\/)\s*5/i) || (t || '').match(/^\s*([1-5](?:\.\d)?)\b/);
    return m ? parseFloat(m[1]) : null;
  }
  function bodyText() { return document.body ? document.body.innerText || '' : ''; }

  function blocked(cfg) {
    var b = cfg.blocked || {}, href = location.href;
    for (var i = 0; i < (b.url_contains || []).length; i++) if (href.indexOf(b.url_contains[i]) >= 0) return 'url:' + b.url_contains[i];
    var txt = bodyText().slice(0, 4000);
    for (var k = 0; k < (b.text_contains || []).length; k++) if (txt.indexOf(b.text_contains[k]) >= 0) return 'text:' + b.text_contains[k];
    return null;
  }

  // ── Product identity ────────────────────────────────────────────────
  function jsonLdProduct() {
    var nodes = document.querySelectorAll('script[type="application/ld+json"]');
    for (var i = 0; i < nodes.length; i++) {
      try {
        var d = JSON.parse(nodes[i].textContent), list = Array.isArray(d) ? d : (d['@graph'] || [d]);
        for (var j = 0; j < list.length; j++) {
          var p = list[j];
          if (p && (p['@type'] === 'Product' || p.aggregateRating || p.offers) && p.name) return p;
        }
      } catch (e) { }
    }
    return null;
  }
  // "X Price in India - Buy X Online - boAt : Flipkart.com" -> "X"
  function docTitle() {
    var t = clean(document.title);
    t = t.split(/\s+(?:Reviews:|Price in India|- Buy|\| )/)[0];
    return clean(t.replace(/^(Buy|Review -)\s+/i, '').replace(/\s*[:|-]\s*(Amazon\.in|Flipkart\.com|Myntra)\s*$/i, ''));
  }
  function meta(cfg) {
    var m = cfg.meta || {}, out = {}, ld = jsonLdProduct();
    if (ld) {
      out.title = clean(ld.name);
      out.brand = clean(ld.brand && (ld.brand.name || ld.brand));
      var off = Array.isArray(ld.offers) ? ld.offers[0] : ld.offers;
      if (off && off.price != null) out.price = num(String(off.price));
      var img = Array.isArray(ld.image) ? ld.image[0] : ld.image;
      if (img) out.image = typeof img === 'string' ? img : img.url;
      if (ld.aggregateRating) {
        out.rating = num(String(ld.aggregateRating.ratingValue));
        out.rating_count = num(String(ld.aggregateRating.ratingCount || ld.aggregateRating.reviewCount));
      }
      if (ld.color) out.variant = clean(ld.color);
      if (ld.model && ld.model !== ld.sku) out.model = clean(typeof ld.model === 'string' ? ld.model : ld.model.name);
      if (ld.sku) out.sku = clean(ld.sku);
      if (ld.mpn && ld.mpn !== ld.sku) out.model = out.model || clean(ld.mpn);
    }
    if (!out.title) out.title = q(document, m.title) || docTitle();
    if (!out.brand && m.brand) out.brand = q(document, m.brand).replace(/^(Visit the|Brand:)\s*/i, '').replace(/\s*Store$/i, '');
    if (out.price == null && m.price) out.price = num(q(document, m.price));
    if (out.rating == null && m.rating) out.rating = stars(q(document, m.rating)) || num(q(document, m.rating));
    if (out.rating_count == null && m.rating_count) out.rating_count = num(q(document, m.rating_count));
    if (!out.image && m.image) out.image = q(document, m.image);
    if (m.specs) {
      var specs = {};
      els(document, m.specs).slice(0, 60).forEach(function (row) {
        var cells = row.querySelectorAll('th, td, span.a-text-bold, .a-list-item > span');
        var k = '', v = '';
        if (cells.length >= 2) { k = clean(cells[0].innerText); v = clean(cells[cells.length - 1].innerText); }
        if (k && v && k.length < 40 && v.length < 120 && k !== v) specs[k.replace(/[:‎‏]/g, '').trim()] = v.replace(/[‎‏]/g, '');
      });
      out.specs = specs;
      out.model = out.model || specs['Model Number'] || specs['Item model number'] || specs['Model Name'] || '';
      out.brand = out.brand || specs['Brand'] || '';
    }
    if (m.fit_summary) {
      var fs = bodyText().match(/WHAT CUSTOMERS SAID([\s\S]{0,300}?)(View Details|Customer Photos|Customer Reviews)/);
      if (fs) out.fit_summary = clean(fs[1]);
    }
    out.histogram = histogram(cfg);
    return out;
  }
  function histogram(cfg) {
    var h = {};
    if (cfg.meta && cfg.meta.histogram) {
      qa(document, cfg.meta.histogram).forEach(function (t) {
        var m = t.match(/(\d+)\s*percent of reviews have\s*([1-5])/i);
        if (m) h[m[2]] = parseInt(m[1], 10) / 100;
      });
    }
    if (!Object.keys(h).length && cfg.histogram_text) {
      var txt = bodyText(), re = new RegExp(cfg.histogram_text, 'g'), m2, counts = {};
      while ((m2 = re.exec(txt))) {
        if (m2.length === 3) counts[m2[1]] = parseInt(m2[2].replace(/,/g, ''), 10);
        else if (m2.length === 6) { for (var s = 5; s >= 1; s--) counts[s] = parseInt(m2[6 - s], 10); }
        if (!re.global) break;
      }
      var tot = 0; for (var k in counts) tot += counts[k];
      if (tot > 0) for (var k2 in counts) h[k2] = Math.round(counts[k2] / tot * 1000) / 1000;
    }
    return h;
  }

  // ── Reviews ─────────────────────────────────────────────────────────
  function cardReviews(cfg) {
    var r = cfg.review;
    return els(document, r.card).map(function (c) {
      var ratingTxt = q(c, r.rating);
      var title = q(c, r.title);
      if (/out of 5 stars/.test(title)) title = clean(title.replace(/[1-5](\.\d)? out of 5 stars/, ''));
      var help = q(c, r.helpful);
      var helpN = /^one person/i.test(help) ? 1 : (num(help) || 0);
      return {
        id: r.id ? q(c, r.id) : '',
        title: title,
        text: q(c, r.text).replace(/\s*Read more\s*$/i, ''),
        rating: stars(ratingTxt) || num(ratingTxt),
        date_raw: q(c, r.date),
        verified: r.verified ? !!q(c, r.verified) : null,
        variant: q(c, r.variant),
        helpful: helpN
      };
    });
  }
  // Flipkart: obfuscated class names, so read the visible text pieces of
  // each card in order. A card is the largest box holding one date line.
  function leafReviews(cfg) {
    var r = cfg.review, anchor = new RegExp(r.anchor), out = [];
    var leaves = Array.prototype.slice.call(document.querySelectorAll(r.leaf));
    var anchors = leaves.filter(function (e) { return anchor.test(clean(e.innerText)); });
    function count(el) { return Array.prototype.filter.call(el.querySelectorAll(r.leaf), function (e) { return anchor.test(clean(e.innerText)); }).length; }
    anchors.forEach(function (a) {
      var card = a;
      while (card.parentElement && count(card.parentElement) === 1) card = card.parentElement;
      var parts = Array.prototype.map.call(card.querySelectorAll(r.leaf), function (e) { return clean(e.innerText); });
      var ratingRe = new RegExp(r.rating), stop = new RegExp(r.stop), author = new RegExp(r.author_suffix), ver = new RegExp(r.verified);
      var start = -1;
      for (var i = parts.length - 2; i >= 0; i--) if (ratingRe.test(parts[i]) && parts[i + 1] === '•') { start = i; break; }
      if (start < 0) return;
      var rating = parseFloat(parts[start]), title = parts[start + 2] || '', i2 = start + 3, variant = '';
      if (parts[i2] && parts[i2].indexOf(r.variant_prefix) === 0) { variant = clean(parts[i2].slice(r.variant_prefix.length)); i2++; }
      var body = [];
      for (; i2 < parts.length; i2++) {
        var p = parts[i2];
        if (stop.test(p) || anchor.test(p)) break;
        if (parts[i2 + 1] !== undefined && author.test(parts[i2 + 1])) break; // reviewer name, then ", City"
        if (author.test(p)) break;
        if (p) body.push(p);
      }
      // If there is no ", City" line the last body line is the reviewer's name.
      var hasCity = parts.some(function (x) { return author.test(x); });
      if (!hasCity && body.length > 1) body.pop();
      var helpful = 0;
      for (var j = 0; j < parts.length; j++) if (/^Helpful$/.test(parts[j]) && /^\d+$/.test(parts[j + 1] || '')) helpful = parseInt(parts[j + 1], 10);
      out.push({
        id: '', title: title, text: body.join(' ').replace(/\s*(\.\.\.|…)\s*more$/i, '…'), rating: rating,
        date_raw: clean(a.innerText).replace(/^·\s*/, ''),
        verified: parts.some(function (x) { return ver.test(x); }),
        variant: variant, helpful: helpful
      });
    });
    return out;
  }
  function reviews(cfg) {
    var list = cfg.review.parser === 'leaves' ? leafReviews(cfg) : cardReviews(cfg);
    return list.filter(function (x) { return (x.text || x.title) && x.rating; });
  }

  // ── Search results (for finding the product on other sites) ─────────
  function search(scfg) {
    var skip = scfg.skip_text ? new RegExp(scfg.skip_text) : null;
    return els(document, scfg.card).slice(0, 12).map(function (c) {
      var txt = clean(c.innerText).replace(/\n/g, ' | ');
      var title = q(c, scfg.title);
      if (skip && skip.test(title)) title = clean(title.replace(skip, ''));
      var price = scfg.price ? num(q(c, scfg.price)) : null;
      if (price == null && scfg.price_regex) { var pm = (c.innerText || '').match(new RegExp(scfg.price_regex)); price = pm ? num(pm[1]) : null; }
      var rating = scfg.rating ? stars(q(c, scfg.rating)) : null;
      var count = null;
      if (rating == null && scfg.rating_regex) {
        var rm = (c.innerText || '').replace(/\n/g, ' | ').match(new RegExp(scfg.rating_regex));
        if (rm) { rating = parseFloat(rm[1]); if (rm[2]) count = /k$/i.test(rm[2]) ? Math.round(parseFloat(rm[2]) * 1000) : num(rm[2]); }
      }
      return {
        title: title, brand: scfg.brand ? q(c, scfg.brand) : '', url: q(c, scfg.link),
        price: price, rating: rating, rating_count: count, image: scfg.image ? q(c, scfg.image) : '',
        sponsored: /\bSponsored\b|\bAD\b/.test(txt.slice(0, 40))
      };
    }).filter(function (x) { return x.title && x.url; });
  }

  // ── Page actions ────────────────────────────────────────────────────
  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  async function clickSort(text) {
    var all = document.querySelectorAll('li, span, div, button, label');
    for (var i = 0; i < all.length; i++) {
      if (all[i].children.length === 0 && clean(all[i].innerText) === text) { all[i].click(); await sleep(2000); return true; }
    }
    return false;
  }
  // Scroll down the page in screen-sized steps (as a person would), then back up.
  async function scrollThrough() {
    var last = -1;
    for (var i = 0; i < 14; i++) {
      window.scrollBy(0, Math.max(400, window.innerHeight * 0.9));
      window.dispatchEvent(new Event('scroll'));
      await sleep(120);
      var y = Math.round(window.scrollY);
      if (y === last) break;
      last = y;
    }
    await sleep(400);
    window.scrollTo(0, 0);
  }

  async function scrollMore(cfg) {
    var cards = els(document, cfg.review.card), before = cards.length;
    if (cards.length) cards[cards.length - 1].scrollIntoView();
    window.scrollTo(0, document.body.scrollHeight);
    window.dispatchEvent(new Event('scroll'));
    for (var t = 0; t < 8; t++) { await sleep(400); if (els(document, cfg.review.card).length > before) break; }
    return els(document, cfg.review.card).length;
  }

  // Some stores load more reviews with a same-origin request as you scroll.
  // We make that same request from the page (the user's own session). Any
  // refusal is reported as blocked, never retried around.
  async function pageApi(cfg, opts) {
    var a = cfg.page_api, f = a.fields;
    var url = a.url.replace('{id}', encodeURIComponent(opts.id)).replace('{page}', String(opts.page || 1));
    var res = await fetch(url, { credentials: 'include', headers: { 'Accept': 'application/json' } });
    if (res.status === 401 || res.status === 403 || res.status === 429) return { blocked: 'http:' + res.status };
    if (!res.ok) return { blocked: null, reviews: [], status: res.status };
    var j = await res.json(), list = j[a.list] || [];
    return {
      blocked: null,
      reviews: list.map(function (x) {
        var v = x[f.variant];
        if (Array.isArray(v)) v = v.map(function (p) { return (p.name || '') + ': ' + (p.value || ''); }).join(', ');
        var ms = parseInt(x[f.date_ms], 10);
        return {
          id: String(x[f.id] || ''), title: '', text: clean(String(x[f.text] || '')),
          rating: parseFloat(x[f.rating]) || null,
          date_raw: ms ? new Date(ms).toISOString().slice(0, 10) : '',
          verified: null, variant: clean(String(v || '')), helpful: parseInt(x[f.helpful], 10) || 0
        };
      }).filter(function (r) { return r.text && r.rating; })
    };
  }

  async function run(id, action, cfg, opts) {
    var result;
    try {
      var b = blocked(cfg || {});
      if (action === 'extract') {
        // Some stores only draw review cards once they scroll into view.
        if (!b && opts && opts.scroll) await scrollThrough();
        result = b ? { blocked: b, url: location.href } :
          { blocked: null, url: location.href, meta: opts && opts.meta ? meta(cfg) : null, reviews: reviews(cfg) };
      } else if (action === 'sort') {
        result = { blocked: b, clicked: b ? false : await clickSort(cfg.sort_click_text) };
      } else if (action === 'scroll') {
        result = { blocked: b, count: b ? 0 : await scrollMore(cfg) };
      } else if (action === 'api') {
        result = b ? { blocked: b } : await pageApi(cfg, opts);
      } else if (action === 'search') {
        result = { blocked: b, url: location.href, results: b ? [] : search(cfg) };
      } else if (action === 'probe') {
        result = { blocked: b, url: location.href, ready: document.readyState };
      }
    } catch (e) {
      result = { error: String(e) };
    }
    var msg = JSON.stringify({ id: id, result: result });
    if (window.HTH && window.HTH.postMessage) window.HTH.postMessage(msg);
    return msg;
  }

  window.__hth = { run: run, _meta: meta, _reviews: reviews, _search: search, _blocked: blocked };
})();
