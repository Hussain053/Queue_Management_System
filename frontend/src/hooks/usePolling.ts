import { useEffect, useState } from 'react';
export function usePolling<T>(load: () => Promise<T>, dependencies: unknown[] = [], interval = 5000) {
  const [data, setData] = useState<T | null>(null); const [error, setError] = useState(''); const [loading, setLoading] = useState(true); const [tick, setTick] = useState(0);
  useEffect(() => { let active = true; let timer: number | undefined;
    const run = async () => { if (document.visibilityState === 'visible') { try { const value = await load(); if (active) { setData(value); setError(''); } } catch (e) { if (active) setError(e instanceof Error ? e.message : 'Unable to load data'); } finally { if (active) setLoading(false); } } if (active) timer = window.setTimeout(run, interval); };
    const onVisibility = () => { if (document.visibilityState === 'visible') setTick(x => x + 1); }; document.addEventListener('visibilitychange', onVisibility); void run();
    return () => { active = false; if (timer) clearTimeout(timer); document.removeEventListener('visibilitychange', onVisibility); };
  // tick causes a fresh read when returning to the tab.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...dependencies, tick, interval]);
  return { data, error, loading, refresh: () => setTick(x => x + 1) };
}
