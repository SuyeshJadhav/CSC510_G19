// import.js
const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');

// --- Configuration ---
const serviceAccountPath = './serviceAccountKey.json'; // IMPORTANT: Keep this file out of git!
const collectionKey = 'apl';
const csvFile = './apl.csv';
const BATCH_SIZE = 500; // Firestore max batch size is 500
const COMMIT_RETRIES = 3; // Number of retry attempts for batch commits
const RETRY_BASE_MS = 200; // Base backoff delay in milliseconds
const THROTTLE_MS = 100; // A small pause after each batch commit to be safe
// ---------------------

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  if (!/already exists/.test(error.message)) {
    console.error('Firebase initialization error:', error.stack);
    process.exit(1); // Exit if initialization fails
  }
}

const db = admin.firestore();
const collectionRef = db.collection(collectionKey);

let batch = db.batch();
let batchCount = 0;
let totalUploaded = 0;

// Helper function to create a delay
const sleep = (ms) => new Promise((res) => setTimeout(res, ms));

// Helper function to commit the current batch with retries and exponential backoff
async function commitBatchWithRetry(batchToCommit, attempt = 1) {
  try {
    await batchToCommit.commit();
  } catch (err) {
    if (attempt >= COMMIT_RETRIES) {
      console.error(`Batch commit failed after ${attempt} attempts:`, err);
      throw err; // Give up after max retries
    }
    const backoff = RETRY_BASE_MS * Math.pow(2, attempt - 1);
    console.warn(`Batch commit failed (attempt ${attempt}). Retrying in ${backoff}ms...`);
    await sleep(backoff);
    return commitBatchWithRetry(batchToCommit, attempt + 1);
  }
}

// Helper function to commit the batch when it's full or when the stream ends
async function flushBatchIfNeeded(force = false) {
  if (batchCount === 0 && !force) return;

  const currentBatch = batch;
  const uploadingCount = batchCount;
  
  // Reset for the next operations immediately
  batch = db.batch();
  batchCount = 0;

  await commitBatchWithRetry(currentBatch);
  totalUploaded += uploadingCount;
  console.log(`Uploaded ${totalUploaded} documents so far...`);
  
  // Throttle a bit to avoid overwhelming Firestore's write rate limits
  await sleep(THROTTLE_MS);
}

// Function to convert/normalize fields from the CSV before writing to Firestore
function normalizeRecord(record) {
  // Safe UPC trimming and basic validation
  const upc = (record.UPC || '').toString().trim();
  
  // Map fields from your specific CSV headers
  const name = (record['Product Description'] || '').toString().trim();
  const category = (record['Category Description'] || '').toString().trim();

  // Assume all items in the APL are eligible by default
  const eligible = true;

  return {
    upc,
    fields: {
      name,
      category,
      eligible,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }
  };
}

// Main function to stream the CSV and write to Firestore
(async () => {
  console.log(`Starting import of ${csvFile} into Firestore collection '${collectionKey}'...`);
  
  // This tells the parser to use the headers from the second line, skipping the first.
  const stream = fs.createReadStream(csvFile).pipe(csv({ skipLines: 1 }));

  stream.on('data', async (data) => {
    stream.pause(); // Pause stream while we process a record

    try {
      // Skip any rows that might be malformed or lack a UPC
      if (!data.UPC || data.UPC.toString().trim().toUpperCase() === 'UPC') {
        stream.resume();
        return;
      }

      const { upc, fields } = normalizeRecord(data);
      if (!upc) {
        console.warn('Skipping record with empty UPC:', data);
        stream.resume();
        return;
      }

      const docRef = collectionRef.doc(upc);
      batch.set(docRef, fields, { merge: true }); // Use merge to overwrite existing items
      batchCount++;

      if (batchCount >= BATCH_SIZE) {
        // Commit the current batch and reset
        await flushBatchIfNeeded(true);
      }
    } catch (err) {
      console.error('Error processing record:', err);
    } finally {
      stream.resume();
    }
  });

  stream.on('end', async () => {
    try {
      // Commit any remaining writes in the last batch
      await flushBatchIfNeeded(true);
      console.log(`\n✅ Import complete! Successfully uploaded a total of ${totalUploaded} documents to '${collectionKey}'.`);
    } catch (err) {
      console.error('Final batch commit failed:', err);
      process.exit(1);
    }
  });

  stream.on('error', (err) => {
    console.error('Error reading CSV file:', err);
    process.exit(1);
  });
})();
