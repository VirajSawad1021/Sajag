// Picks up screenshots that the service worker stored after an Android "Share to Sajag".
const SHARE_CACHE = "sajag-share";

export function registerServiceWorker(): void {
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("/sw.js").catch(() => {
      /* PWA features are optional; the app works without them */
    });
  }
}

export async function takeSharedItems(): Promise<{ text: string; files: File[] } | null> {
  if (!new URLSearchParams(location.search).has("shared") || !("caches" in window)) return null;
  history.replaceState(null, "", "/");
  const cache = await caches.open(SHARE_CACHE);
  const manifestRes = await cache.match("/shared/manifest");
  if (!manifestRes) return null;
  const manifest: { text: string; files: { key: string; name: string; type: string }[] } =
    await manifestRes.json();
  const files: File[] = [];
  for (const f of manifest.files) {
    const res = await cache.match(f.key);
    if (res) files.push(new File([await res.blob()], f.name || "shared.png", { type: f.type }));
  }
  await caches.delete(SHARE_CACHE);
  return { text: manifest.text, files };
}
