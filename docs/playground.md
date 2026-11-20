---
description: "Run Luau in the browser with Roblox APIs."
---

<style>
.page-content { padding: 0 !important; }
.page-content > .wrapper { padding: 0 !important; max-width: 100% !important; width: 100% !important; }
/* This page needs the full workspace, including Material's reserved sidebars. */
.md-grid { max-width: none; }
.md-main__inner { margin-top: 0; max-width: none; }
@media (min-width: 76.25em) { .md-main__inner > .md-sidebar--primary { display: none !important; } }
.md-main__inner > .md-sidebar--secondary { display: none !important; }
.md-content { flex: 1 1 auto; min-width: 0; width: 100%; max-width: none; margin: 0; }
/* Material's sidebar-aware margin rule outranks a plain reset, hence !important. */
.md-main__inner > .md-content > .md-content__inner { margin: 0 !important; padding: 0 !important; }
.md-content__inner::before { display: none; }
.md-footer { display: none; }
h1.post-title, h1 { display: none !important; }
/* Compact layout (the playground's toolbar toggle, phones only): the header becomes a thin blue
   bar, tapped to bring it back, and the playground takes the room. */
@media (max-width: 600px), (pointer: coarse) {
  html.pg-compact .md-header { height: .4rem; min-height: 0; overflow: hidden; box-shadow: none; cursor: pointer; }
  html.pg-compact .md-header__inner { visibility: hidden; }
  html.pg-compact #playground-frame { height: calc(100dvh - .4rem) !important; }
}
</style>
<iframe id="playground-frame" title="Luau playground" style="width:100%;height:calc(100dvh - 2.4rem);border:none;display:block;"></iframe>
<script>
  // Shrink the page above the phone keyboard (Android Chrome), so the editor's key bar stays visible.
  const viewport = document.querySelector('meta[name="viewport"]');
  if (viewport && !viewport.content.includes("interactive-widget")) viewport.content += ", interactive-widget=resizes-content";
  const frame = document.getElementById("playground-frame");
  frame.src = "../playground.html" + location.search;
  // The playground's compact toggle: applied before it loads (same saved setting), then on change.
  const setCompact = on => document.documentElement.classList.toggle("pg-compact", on);
  try { setCompact(localStorage.getItem("luau_compact_header") === "1"); } catch (e) { }
  window.addEventListener("message", event => {
    if (event.origin === location.origin && event.source === frame.contentWindow && event.data && event.data.type === "luwa-compact") setCompact(event.data.on === true);
  });
  // Tapping the thin bar brings the full header and buttons back.
  document.querySelector(".md-header")?.addEventListener("click", event => {
    if (!document.documentElement.classList.contains("pg-compact")) return;
    event.preventDefault();
    event.stopPropagation();
    frame.contentWindow.postMessage({ type: "luwa-expand" }, location.origin);
  }, true);
</script>
