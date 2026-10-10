// Sajag service worker: receives screenshots shared from other apps (Android share sheet).
// Shared files are held in a local cache only until the page picks them up, then deleted.
const SHARE_CACHE = "sajag-share";

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method === "POST" && url.pathname === "/share-target") {
    event.respondWith(handleShare(event.request));
  }
});

async function handleShare(request) {
  const form = await request.formData();
  const cache = await caches.open(SHARE_CACHE);
  const files = form.getAll("images").filter((f) => f instanceof File);
  const text = [form.get("title"), form.get("text"), form.get("url")].filter(Boolean).join("\n");

  const manifest = { text, files: [] };
  for (let i = 0; i < files.length; i++) {
    const key = `/shared/${i}`;
    await cache.put(key, new Response(files[i], { headers: { "content-type": files[i].type } }));
    manifest.files.push({ key, name: files[i].name, type: files[i].type });
  }
  await cache.put("/shared/manifest", new Response(JSON.stringify(manifest)));
  return Response.redirect("/?shared=1", 303);
}
