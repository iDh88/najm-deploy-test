"""
WhatsApp Outreach Workflow + Contact Memory
PRN → Phone → WhatsApp sequential send flow.
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
import uuid, logging

logger = logging.getLogger("cip.whatsapp")
router = APIRouter()


# ─── Models ───────────────────────────────────────────────────────
class ContactEntry(BaseModel):
    prn:         str
    phoneNumber: str
    name:        str = ""
    rank:        str = ""
    base:        str = ""
    addedAt:     str = ""
    lastUsedAt:  str = ""
    timesUsed:   int = 0


class OutreachRecipient(BaseModel):
    prn:         str
    lineNumber:  str
    matchId:     str
    phoneNumber: Optional[str] = None
    name:        str = ""
    status:      str = "pending"   # pending | sent | skipped | failed
    sentAt:      Optional[str] = None
    tradeScore:  float = 0.0


class OutreachSession(BaseModel):
    sessionId:    str = Field(default_factory=lambda: str(uuid.uuid4()))
    userId:       str
    recipients:   list[OutreachRecipient]
    messageText:  str
    createdAt:    str
    completedAt:  Optional[str] = None
    totalSent:    int = 0

    @property
    def is_complete(self) -> bool:
        return all(r.status != "pending" for r in self.recipients)

    @property
    def next_pending(self) -> Optional[OutreachRecipient]:
        return next((r for r in self.recipients if r.status == "pending"), None)


class SaveContactRequest(BaseModel):
    userId: str; prn: str; phoneNumber: str
    name: str = ""; rank: str = ""; base: str = ""


class CreateOutreachRequest(BaseModel):
    userId: str; matchIds: list[str]
    messageText: str; month: str


class UpdateRecipientRequest(BaseModel):
    sessionId: str; userId: str; prn: str
    status: str; phoneNumber: Optional[str] = None


class WhatsAppLinkRequest(BaseModel):
    phoneNumber: str; message: str


# ─── Contact Memory ───────────────────────────────────────────────
class ContactMemoryService:

    async def save(self, db, user_id: str, entry: ContactEntry) -> bool:
        try:
            clean = self._clean(entry.phoneNumber)
            if not clean: return False
            ref = (db.collection("contactMemory")
                   .document(user_id).collection("contacts")
                   .document(entry.prn))
            now = datetime.utcnow().isoformat()
            existing = ref.get()
            if existing.exists:
                ref.update({"phoneNumber": clean, "lastUsedAt": now,
                            "timesUsed": existing.to_dict().get("timesUsed", 0) + 1})
            else:
                ref.set({"prn": entry.prn, "phoneNumber": clean,
                         "name": entry.name, "rank": entry.rank,
                         "base": entry.base, "addedAt": now,
                         "lastUsedAt": now, "timesUsed": 1})
            return True
        except Exception as e:
            logger.error(f"Save contact: {e}"); return False

    async def lookup(self, db, user_id: str, prn: str) -> Optional[ContactEntry]:
        try:
            doc = (db.collection("contactMemory")
                   .document(user_id).collection("contacts")
                   .document(prn).get())
            return ContactEntry(**doc.to_dict()) if doc.exists else None
        except Exception: return None

    async def list_all(self, db, user_id: str) -> list[ContactEntry]:
        try:
            snap = (db.collection("contactMemory").document(user_id)
                    .collection("contacts")
                    .order_by("lastUsedAt", direction="DESCENDING").stream())
            return [ContactEntry(**d.to_dict()) for d in snap]
        except Exception: return []

    async def delete(self, db, user_id: str, prn: str) -> bool:
        try:
            (db.collection("contactMemory").document(user_id)
             .collection("contacts").document(prn).delete())
            return True
        except Exception: return False

    def _clean(self, phone: str) -> str:
        digits = ''.join(c for c in phone if c.isdigit() or c == '+')
        if not digits: return ""
        if not digits.startswith('+'):
            if digits.startswith('05') or digits.startswith('5'):
                digits = '+966' + digits.lstrip('0')
            elif digits.startswith('966'):
                digits = '+' + digits
            else:
                digits = '+' + digits
        return digits

    def whatsapp_url(self, phone: str, message: str) -> str:
        from urllib.parse import quote
        clean = self._clean(phone).replace('+', '').replace(' ', '')
        return f"https://wa.me/{clean}?text={quote(message)}"


# ─── Outreach Session ─────────────────────────────────────────────
class OutreachSessionService:

    async def create(self, db, req: CreateOutreachRequest) -> OutreachSession:
        svc = ContactMemoryService()
        recipients = []
        for mid in req.matchIds:
            try:
                doc = db.collection("tradeMatches").document(mid).get()
                if not doc.exists: continue
                d = doc.to_dict()
                prn = d.get('ownerPRN', '')
                if not prn: continue
                saved = await svc.lookup(db, req.userId, prn)
                recipients.append(OutreachRecipient(
                    prn=prn, lineNumber=d.get('lineNumber', ''),
                    matchId=mid,
                    phoneNumber=saved.phoneNumber if saved else None,
                    name=saved.name if saved else '',
                    tradeScore=d.get('tradeScore', {}).get('total', 0),
                ))
            except Exception: continue

        recipients.sort(key=lambda r: r.tradeScore, reverse=True)
        session = OutreachSession(
            userId=req.userId, recipients=recipients,
            messageText=req.messageText,
            createdAt=datetime.utcnow().isoformat())
        db.collection("tradeOutreach").document(session.sessionId).set(session.dict())
        return session

    async def update(self, db, req: UpdateRecipientRequest) -> OutreachSession:
        ref = db.collection("tradeOutreach").document(req.sessionId)
        doc = ref.get()
        if not doc.exists:
            raise ValueError(f"Session {req.sessionId} not found")
        session = OutreachSession(**doc.to_dict())
        for r in session.recipients:
            if r.prn == req.prn:
                r.status = req.status
                if req.status == 'sent':
                    r.sentAt = datetime.utcnow().isoformat()
                if req.phoneNumber and req.status == 'sent':
                    svc = ContactMemoryService()
                    await svc.save(db, req.userId, ContactEntry(
                        prn=req.prn, phoneNumber=req.phoneNumber, name=r.name))
                    r.phoneNumber = req.phoneNumber
                break
        session.totalSent = sum(1 for r in session.recipients if r.status == 'sent')
        if session.is_complete:
            session.completedAt = datetime.utcnow().isoformat()
        ref.update(session.dict())
        return session

    async def get(self, db, sid: str) -> Optional[OutreachSession]:
        doc = db.collection("tradeOutreach").document(sid).get()
        return OutreachSession(**doc.to_dict()) if doc.exists else None


# ─── Singletons ───────────────────────────────────────────────────
_contact = ContactMemoryService()
_outreach = OutreachSessionService()


# ─── Endpoints ────────────────────────────────────────────────────
@router.post("/contacts/save")
async def save_contact(req: SaveContactRequest):
    from utils.firebase import get_firestore
    db = get_firestore()
    ok = await _contact.save(db, req.userId, ContactEntry(
        prn=req.prn, phoneNumber=req.phoneNumber,
        name=req.name, rank=req.rank, base=req.base))
    if not ok:
        raise HTTPException(status_code=422, detail="Invalid phone number")
    return {"success": True}


@router.get("/contacts/{userId}")
async def list_contacts(userId: str):
    from utils.firebase import get_firestore
    contacts = await _contact.list_all(get_firestore(), userId)
    return {"contacts": [c.dict() for c in contacts]}


@router.get("/contacts/{userId}/{prn}")
async def lookup_contact(userId: str, prn: str):
    from utils.firebase import get_firestore
    entry = await _contact.lookup(get_firestore(), userId, prn)
    return {"found": bool(entry), "contact": entry.dict() if entry else None}


@router.delete("/contacts/{userId}/{prn}")
async def delete_contact(userId: str, prn: str):
    from utils.firebase import get_firestore
    await _contact.delete(get_firestore(), userId, prn)
    return {"success": True}


@router.post("/outreach/create")
async def create_outreach(req: CreateOutreachRequest):
    from utils.firebase import get_firestore
    session = await _outreach.create(get_firestore(), req)
    return session.dict()


@router.get("/outreach/{sessionId}")
async def get_outreach(sessionId: str):
    from utils.firebase import get_firestore
    session = await _outreach.get(get_firestore(), sessionId)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session.dict()


@router.post("/outreach/update")
async def update_recipient(req: UpdateRecipientRequest):
    from utils.firebase import get_firestore
    session = await _outreach.update(get_firestore(), req)
    return session.dict()


@router.post("/whatsapp-link")
async def whatsapp_link(req: WhatsAppLinkRequest):
    url = _contact.whatsapp_url(req.phoneNumber, req.message)
    return {"url": url}
