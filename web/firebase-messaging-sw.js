importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

// Initialize Firebase in the service worker with the web app options
firebase.initializeApp({
  apiKey: "AIzaSyC69cQ-RIeGSm6JFT-EShESlnMDgwpWsFc",
  authDomain: "kabad-8fbc6.firebaseapp.com",
  projectId: "kabad-8fbc6",
  storageBucket: "kabad-8fbc6.firebasestorage.app",
  messagingSenderId: "124131366432",
  appId: "1:124131366432:web:024f3059245b3d23954e45",
  measurementId: "G-BRCWTTMLFW"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message: ", payload);
  const notificationTitle = payload.notification?.title || "ScrapWell Update";
  const notificationOptions = {
    body: payload.notification?.body || "Your order has been updated.",
    icon: "/favicon.png"
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
