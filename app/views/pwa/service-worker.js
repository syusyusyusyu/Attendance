self.addEventListener("push", (event) => {
  if (!event.data) return
  const payload = event.data.json()
  const title = payload.title || "通知"
  const options = payload.options || {}

  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const targetPath = event.notification.data && event.notification.data.path
  if (!targetPath) return
  const targetUrl = new URL(targetPath, self.location.origin)
  const targetPathname = targetUrl.pathname

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        const clientPath = new URL(client.url).pathname
        if (clientPath === targetPathname && "focus" in client) {
          return client.focus()
        }
      }

      if (clients.openWindow) {
        return clients.openWindow(targetUrl.href)
      }
    })
  )
})
