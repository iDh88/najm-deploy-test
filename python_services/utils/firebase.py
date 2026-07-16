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


def initialize_firebase():
    global _initialized
    if _initialized:
        return
    try:
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if cred_path:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred, {
                "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", "cip-najm.appspot.com")
            })
        else:
            # Use Application Default Credentials (Cloud Run)
            firebase_admin.initialize_app(options={
                "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", "cip-najm.appspot.com")
            })
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
