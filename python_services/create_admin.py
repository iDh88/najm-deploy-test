from getpass import getpass
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import credentials, auth, firestore

email = input("Admin email: ").strip()
password = getpass("Admin password: ").strip()

if not email or not password:
    raise SystemExit("Email and password are required")

cred = credentials.Certificate("serviceAccountKey.json")
try:
    firebase_admin.initialize_app(cred)
except ValueError:
    pass

db = firestore.client()

try:
    user = auth.get_user_by_email(email)
    auth.update_user(user.uid, password=password, email_verified=True)
    print("Updated existing admin:", user.uid)
except auth.UserNotFoundError:
    user = auth.create_user(email=email, password=password, email_verified=True)
    print("Created new admin:", user.uid)

admin_profile = {
    "email": email,
    "name": "Najm Admin",
    "nameAr": "",
    "crewId": "ADMIN001",
    "rank": "YCA",
    "rankCode": "YCA",
    "baseStation": "JED",
    "admin": True,
    "superAdmin": True,
    "adminOnly": True,
    "accountStatus": "approved",
    "privileges": ["all"],
    "rankScope": ["all"],
    "createdAt": datetime.now(timezone.utc),
    "lastActiveAt": datetime.now(timezone.utc),
}

db.collection("admins").document(user.uid).set(admin_profile, merge=True)
db.collection("users").document(user.uid).set(admin_profile, merge=True)

auth.set_custom_user_claims(user.uid, {
    "admin": True,
    "superAdmin": True,
    "adminOnly": True,
    "accountStatus": "approved",
})

print("SUPER_ADMIN_READY")
print("Admin email:", email)
print("UID:", user.uid)
