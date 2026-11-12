/* Pairr — pairr.lrvdlinden.app */
(function () {
  "use strict";
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Taalkeuze onthouden (cookie voor de server, localStorage voor het script op /)
  document.querySelectorAll(".lang a[data-lang]").forEach(function (a) {
    a.addEventListener("click", function () {
      var l = a.getAttribute("data-lang");
      try { localStorage.setItem("pairr.lang", l); } catch (e) {}
      document.cookie = "pairr_lang=" + l + "; path=/; max-age=31536000; samesite=lax" + (location.protocol === "https:" ? "; secure" : "");
    });
  });

  // Kopbalk krijgt een lijn na scrollen
  var top = document.querySelector(".top");
  if (top) {
    var onScroll = function () { top.classList.toggle("scrolled", window.scrollY > 8); };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  // Inschuiven bij scrollen
  var els = document.querySelectorAll(".reveal");
  if (reduce || !("IntersectionObserver" in window)) {
    els.forEach(function (e) { e.classList.add("in"); });
  } else {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    els.forEach(function (e) { io.observe(e); });
  }

  // Automatisch invullen: velden typen zich in als het blok in beeld komt
  var fill = document.getElementById("fill");
  if (fill) {
    var fields = fill.querySelectorAll("b[data-type]");
    var done = false;
    var typeAll = function () {
      if (done) return;
      done = true;
      if (reduce) { fields.forEach(function (b) { b.textContent = b.getAttribute("data-type"); }); return; }
      var i = 0;
      var next = function () {
        if (i >= fields.length) return;
        var b = fields[i++], txt = b.getAttribute("data-type"), n = 0;
        b.classList.add("typing");
        var t = setInterval(function () {
          b.textContent = txt.slice(0, ++n);
          if (n >= txt.length) { clearInterval(t); b.classList.remove("typing"); setTimeout(next, 180); }
        }, 45);
      };
      next();
    };
    if ("IntersectionObserver" in window) {
      var fo = new IntersectionObserver(function (en) { if (en[0].isIntersecting) { typeAll(); fo.disconnect(); } }, { threshold: 0.5 });
      fo.observe(fill);
    } else { typeAll(); }
  }

  // Telefoon in de hero: lijst → scannen → code gevonden → lijst
  var scan = document.getElementById("scan"), found = document.getElementById("found");
  if (scan && found && !reduce) {
    var cycle = function () {
      setTimeout(function () { scan.classList.add("on"); }, 2600);
      setTimeout(function () { found.classList.add("on"); }, 4600);
      setTimeout(function () { scan.classList.remove("on"); }, 5000);
      setTimeout(function () { found.classList.remove("on"); }, 8200);
    };
    cycle();
    setInterval(function () { if (!document.hidden) cycle(); }, 10000);
  }
})();
