/** A single foreground job: no background traffic, overlapping runs or leaked
 * listeners. The caller checks current() before committing an awaited result. */
export function foregroundRefresh(task: (current: () => boolean) => Promise<void>, interval = 15000) {
  let active = true, running = false;
  const current = () => active;
  const refresh = async () => {
    if (!active || running || document.visibilityState !== 'visible' || !navigator.onLine) return;
    running = true;
    try { await task(current); } finally { running = false; }
  };
  const trigger = () => { void refresh().catch(() => {}); };
  const timer = window.setInterval(trigger, interval);
  document.addEventListener('visibilitychange', trigger);
  window.addEventListener('focus', trigger);
  window.addEventListener('online', trigger);
  window.addEventListener('askxuan:growth-changed', trigger);
  trigger();
  return () => {
    active = false;
    window.clearInterval(timer);
    document.removeEventListener('visibilitychange', trigger);
    window.removeEventListener('focus', trigger);
    window.removeEventListener('online', trigger);
    window.removeEventListener('askxuan:growth-changed', trigger);
  };
}
