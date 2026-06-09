const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

try {
  // Try initializing with project ID. Locally, if authenticated via Firebase CLI,
  // it might require setting GOOGLE_APPLICATION_CREDENTIALS, but let's test.
  initializeApp({
    projectId: 'kabad-8fbc6'
  });
  const db = getFirestore();
  
  async function run() {
    console.log("=== PARTNERS ===");
    const partners = await db.collection('partners').get();
    console.log(`Found ${partners.size} partners:`);
    partners.forEach(doc => {
      const data = doc.data();
      console.log(`- ID: ${doc.id}`);
      console.log(`  Name: ${data.fullName} | Shop: ${data.shopName}`);
      console.log(`  Status: ${data.status} | Online: ${data.isOnline} | Available: ${data.isAvailable}`);
      console.log(`  Coordinates: shop(${data.shopLat}, ${data.shopLng}) | current(${data.currentLat}, ${data.currentLng})`);
      console.log(`  Categories: ${JSON.stringify(data.scrapCategories)}`);
      console.log(`  maxDistanceKm: ${data.maxDistanceKm} | FCM Token: ${data.fcmToken ? 'Present' : 'None'}`);
    });

    console.log("\n=== LIVE LOCATIONS ===");
    const liveLocs = await db.collection('live_locations').get();
    console.log(`Found ${liveLocs.size} live locations:`);
    liveLocs.forEach(doc => {
      const data = doc.data();
      console.log(`- ID: ${doc.id} => Online: ${data.isOnline} | Available: ${data.isAvailable} | Coords: (${data.latitude}, ${data.longitude})`);
    });

    console.log("\n=== ORDERS ===");
    const orders = await db.collection('orders').get();
    console.log(`Found ${orders.size} orders:`);
    orders.forEach(doc => {
      const data = doc.data();
      console.log(`- ID: ${doc.id}`);
      console.log(`  Customer: ${data.customerName} | Address: ${data.customerAddress}`);
      console.log(`  Status: ${data.status} | Type: ${data.pickupType}`);
      console.log(`  Coordinates: customer(${data.customerLat}, ${data.customerLng})`);
      console.log(`  Items: ${JSON.stringify(data.scrapItems)}`);
      console.log(`  Partner Assigned: ${data.partnerId} | Reserved: ${data.reservedPartnerId}`);
    });
  }
  
  run().catch(console.error);
} catch (e) {
  console.error("Initialization failed:", e);
}
