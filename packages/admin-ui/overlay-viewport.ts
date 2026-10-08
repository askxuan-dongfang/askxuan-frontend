/** Shared visual viewport for dialogs and drawers, including mobile keyboards. */
export function initOverlayViewport() {
  const viewport = window.visualViewport;
  let frame = 0;
  const update = () => {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      const values = { top: viewport?.offsetTop ?? 0, left: viewport?.offsetLeft ?? 0,
        width: viewport?.width ?? innerWidth, height: viewport?.height ?? innerHeight };
      for (const [name, value] of Object.entries(values)) document.documentElement.style.setProperty(`--ax-overlay-${name}`, `${value}px`);
    });
  };
  update();
  viewport?.addEventListener('resize', update);
  viewport?.addEventListener('scroll', update);
  window.addEventListener('resize', update);
}
