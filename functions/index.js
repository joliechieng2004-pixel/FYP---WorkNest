const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // 1. Security Check: Is the person calling this logged in?
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Login required.");
  }

  const uidToDelete = data.uid;

  try {
    // 2. Delete from Firebase Authentication (Frees up the email!)
    await admin.auth().deleteUser(uidToDelete);
    
    return { success: true, message: "User deleted from Auth." };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});