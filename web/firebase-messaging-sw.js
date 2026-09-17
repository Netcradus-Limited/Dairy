/* eslint-disable no-undef */
// Firebase Cloud Messaging Service Worker for Flutter Web
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Initialize Firebase with the project's web configuration
firebase.initializeApp({
  apiKey: "AIzaSyCHV_tWBg53-HsR5DDFL7WQfJrL56qvBaI",
  authDomain: "sawariya-7efd4.firebaseapp.com",
  projectId: "sawariya-7efd4",
  storageBucket: "sawariya-7efd4.firebasestorage.app",
  messagingSenderId: "325042169664",
  appId: "1:325042169664:web:78b972a71a1775611d7ca5",
  measurementId: "G-9KE6MVLHXW"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  const notificationTitle = payload?.notification?.title || payload?.data?.title || 'Sawariya Dairy';
  const notificationOptions = {
    body: payload?.notification?.body || payload?.data?.body || '',
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: payload?.data || {}
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click to bring app window to focus or open it
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const urlToOpen = new URL('/', self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});
