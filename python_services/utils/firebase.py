"""
utils/firebase.py — Firebase Admin SDK initialization and helpers
"""

import os
import logging
import firebase_admin
from firebase_admin import credentials, firestore, storage, auth
from functools import lru_cache

logger = logging.getLogger("cip.firebase")
_initialized = False


class _AnonymousCredentials(credentials.Base):
    """Firebase Admin credential for LOCAL emulator use only.

    firebase-admin resolves the app credential eagerly when it builds the
    Firestore/Storage client, which bypasses the emulator's own anonymous-auth
    detection and raises DefaultCredentialsError when no real credentials exist.
    Supplying anonymous credentials lets the SDK reach the emulators without any
    service-account key. Used ONLY when a *_EMULATOR_HOST is set (local dev).
    """

    def get_credential(self):
        import google.auth.credentials
        return google.auth.credentials.AnonymousCredentials()


def initialize_firebase():
    global _initialized
    if _initialized:
        return
    try:
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        emulator = (os.getenv("FIRESTORE_EMULATOR_HOST")
                    or os.getenv("FIREBASE_AUTH_EMULATOR_HOST")
                    or os.getenv("FIREBASE_STORAGE_EMULATOR_HOST"))
        bucket = os.getenv("FIREBASE_STORAGE_BUCKET", "cip-najm.appspot.com")
        if cred_path:
            # Explicit service-account key (local dev against a real project, or
            # against emulators using a real key).
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, {"storageBucket": bucket})
        elif emulator:
            # Local emulators — no real credentials required.
            project_id = (os.getenv("GOOGLE_CLOUD_PROJECT")
                          or os.getenv("GCLOUD_PROJECT") or "demo-najm")
            firebase_admin.initialize_app(_AnonymousCredentials(), {
                "projectId": project_id,
                "storageBucket": bucket,
            })
            logger.info("Firebase Admin initialized for LOCAL EMULATORS (project=%s)", project_id)
        else:
            # Application Default Credentials (Cloud Run runtime service account).
            firebase_admin.initialize_app(options={"storageBucket": bucket})
        _initialized = True
        logger.info("Firebase Admin SDK initialized")
    except Exception as e:
        logger.error(f"Firebase init failed: {e}", exc_info=True)
        raise


def get_firestore():
    return firestore.client()


def get_storage():
    return storage.bucket()


def verify_firebase_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return decoded claims.

    check_revoked=True forces a check against revoked refresh tokens so that a
    suspended/rejected user whose session was revoked (see suspendUser/rejectUser
    in Cloud Functions) is denied immediately rather than remaining valid until
    the ID token naturally expires. Remediation: P1-1.
    """
    try:
        decoded = auth.verify_id_token(id_token, check_revoked=True)
        return decoded
    except auth.RevokedIdTokenError:
        raise ValueError("Token has been revoked (account suspended or signed out).")
    except auth.UserDisabledError:
        raise ValueError("User account has been disabled.")
    except Exception as e:
        raise ValueError(f"Invalid token: {e}")
