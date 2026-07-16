class RevokedIdTokenError(Exception): pass
class UserDisabledError(Exception): pass
class InvalidIdTokenError(Exception): pass
class ExpiredIdTokenError(Exception): pass
def verify_id_token(token, check_revoked=False, app=None):
    raise InvalidIdTokenError("offline shim: verify_id_token — tests must patch")
def revoke_refresh_tokens(uid, app=None):
    raise RuntimeError("offline shim")
def get_user(uid, app=None):
    raise RuntimeError("offline shim")
