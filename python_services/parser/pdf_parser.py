"""
Saudi Airlines Lines of Time — PDF Parser
Parses the official eCrew PDF format from vpn.saudia.com/COBS
Extracts all line data per rank group (YCA JED 9Z, GD JED 9Z, etc.)
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, UploadFile, File, Form
from pydantic import BaseModel, Field
from typing import Optional
import pdfplumber
import re
import uuid
import logging
from datetime import datetime
import io

logger = logging.getLogger("cip.pdf_parser")
router = APIRouter()

# ─── Models ───────────────────────────────────────────────────────────────────

class LineDestination(BaseModel):
    iata: str
    layoverHours: float = 0.0

class ParsedPDFLine(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    lineNumber: int
    lineType: str           # TRNG, LINE, USLN, CHLN, HJLN, BYND, HYLN, HDLN, INDO, KULN, Reserve
    carryOver: str          # e.g. "2 Day C/O" or ""
    creditHours: float
    blockHours: float
    carryOverHours: float
    daysOff: int
    totalLegs: int
    fourLegCount: int
    expense: float          # SAR — EXPNSE from COBS
    allowance: float        # SAR — ALLWNCE from COBS
    income: float           # expense + allowance
    destinations: list[LineDestination]
    hasStarDays: bool       # has * (reserve/standby days)
    rawText: str            # original line text for debugging

class PDFParseResult(BaseModel):
    success: bool
    rank: str               # YCA, GD, PCA, etc.
    base: str               # JED, RUH, DMM
    category: str           # 9Z, 782, etc.
    month: str              # 2026-06
    totalLines: int
    linesData: list[ParsedPDFLine]
    errors: list[str]
    warnings: list[str]
    uploadedBy: str
    uploadedAt: str

# ─── PDF Parser ───────────────────────────────────────────────────────────────

class LinesPDFParser:

    LINE_TYPES = {
        'TRNG', 'LINE', 'USLN', 'CHLN', 'HJLN', 'BYND',
        'HYLN', 'HDLN', 'INDO', 'KULN', 'Reserve', 'USLN'
    }

    def __init__(self):
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def parse(self, pdf_bytes: bytes, rank: str, base: str,
              category: str, month: str, uploaded_by: str) -> PDFParseResult:

        try:
            lines_data = []
            with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
                full_text = ""
                for page in pdf.pages:
                    text = page.extract_text(x_tolerance=3, y_tolerance=3)
                    if text:
                        full_text += text + "\n"

            lines_data = self._parse_full_text(full_text, rank, base, category)

        except Exception as e:
            logger.error(f"PDF parse failed: {e}", exc_info=True)
            self.errors.append(f"PDF parsing error: {str(e)}")
            lines_data = []

        return PDFParseResult(
            success=len(self.errors) == 0,
            rank=rank,
            base=base,
            category=category,
            month=month,
            totalLines=len(lines_data),
            linesData=lines_data,
            errors=self.errors,
            warnings=self.warnings,
            uploadedBy=uploaded_by,
            uploadedAt=datetime.utcnow().isoformat(),
        )

    def _parse_full_text(self, text: str, rank: str, base: str,
                         category: str) -> list[ParsedPDFLine]:
        """
        Parse the full text extracted from the Lines of Time PDF.

        Each line block looks like:
        001 TRNG CRDT:72.05 BLK:64.05 C/O:08.42 EXPNSE:2,971 ALLWNCE:1,056
        [calendar row]
        BOM 28.10  AMS 49.55  KUL 35.00

        Or for a simpler line:
        001 LINE CRDT:68.30 BLK:65.10 C/O:00.00 EXPNSE:3,100 ALLWNCE:950
        """
        parsed_lines = []
        lines = text.split('\n')

        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if not line:
                i += 1
                continue

            # Detect start of a line block: starts with 3-digit number
            match = re.match(
                r'^(\d{3})\s+(\w+)\s+'
                r'CRDT:(\d+\.\d+)\s+'
                r'BLK:(\d+\.\d+)\s+'
                r'C/O:(\d+\.\d+)\s+'
                r'EXPNSE:([\d,]+)\s+'
                r'ALLWNCE:([\d,]+)',
                line
            )

            if match:
                line_no   = int(match.group(1))
                line_type = match.group(2)
                credit    = float(match.group(3))
                block     = float(match.group(4))
                carry_over= float(match.group(5))
                expense   = float(match.group(6).replace(',', ''))
                allowance = float(match.group(7).replace(',', ''))

                # Look for C/O label in subsequent line
                carry_label = ""
                days_off = 0
                total_legs = 0
                four_leg = 0
                destinations = []
                has_star = False

                # Scan next few lines for additional data
                j = i + 1
                while j < min(i + 6, len(lines)):
                    next_line = lines[j].strip()

                    # C/O label: "2 Day C/O" or "1 Day C/O"
                    co_match = re.search(r'(\d+)\s+Day\s+C/O', next_line)
                    if co_match:
                        carry_label = f"{co_match.group(1)} Day C/O"

                    # Stats row: "9  OFF  23  LEGS  0  4LEG"
                    stats_match = re.match(
                        r'(\d+)\s+OFF\s+(\d+)\s+LEGS\s+(\d+)\s+4LEG',
                        next_line
                    )
                    if stats_match:
                        days_off   = int(stats_match.group(1))
                        total_legs = int(stats_match.group(2))
                        four_leg   = int(stats_match.group(3))

                    # Star days indicator
                    if '* ' in next_line or next_line.startswith('*'):
                        has_star = True

                    # Destination row: "BOM 28.10  AMS 49.55  KUL 35.00"
                    dest_matches = re.findall(
                        r'([A-Z]{2,4})\s+(\d+\.\d+)',
                        next_line
                    )
                    for dest_code, dest_hrs in dest_matches:
                        # Filter out column headers that look like IATA
                        if dest_code not in ('OFF', 'LEG', 'BLK', 'C/O', 'SR',
                                             'MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'):
                            destinations.append(LineDestination(
                                iata=dest_code,
                                layoverHours=float(dest_hrs)
                            ))

                    # Stop if we hit the next line number
                    if re.match(r'^\d{3}\s+\w+\s+CRDT:', next_line):
                        break
                    j += 1

                income = expense + allowance

                parsed_lines.append(ParsedPDFLine(
                    lineNumber=line_no,
                    lineType=line_type,
                    carryOver=carry_label,
                    creditHours=credit,
                    blockHours=block,
                    carryOverHours=carry_over,
                    daysOff=days_off,
                    totalLegs=total_legs,
                    fourLegCount=four_leg,
                    expense=expense,
                    allowance=allowance,
                    income=income,
                    destinations=destinations,
                    hasStarDays=has_star,
                    rawText='\n'.join(lines[i:j]),
                ))

            i += 1

        if not parsed_lines:
            parsed_lines = self._parse_lines_of_time_v2(text, rank, base, category)

        if not parsed_lines:
            self.warnings.append(
                "No lines extracted. PDF may use a different format. "
                "Try uploading a text-based PDF (not scanned image)."
            )

        logger.info(f"Parsed {len(parsed_lines)} lines from PDF")
        return parsed_lines

    def _parse_lines_of_time_v2(self, text: str, rank: str, base: str,
                                category: str) -> list[ParsedPDFLine]:
        """Parse Saudi Lines Of Time PDFs that use LINE0001 / CR. / BLK format."""
        parsed_lines = []
        rows = text.splitlines()

        starts = []
        for idx, row in enumerate(rows):
            match = re.search(r'\bLINE\s*0*(\d{1,4})\b|\bLINE0*(\d{1,4})\b', row)
            if match and 'CR.' in row:
                starts.append(idx)

        for pos, start in enumerate(starts):
            end = starts[pos + 1] if pos + 1 < len(starts) else min(start + 8, len(rows))
            block_rows = rows[start:end]
            first = block_rows[0]

            line_match = re.search(r'\bLINE\s*0*(\d{1,4})\b|\bLINE0*(\d{1,4})\b', first)
            line_no = int((line_match.group(1) or line_match.group(2))) if line_match else 0

            credit_match = re.search(r'CR\.\s*(\d+(?:\.\d+)?)', first)
            credit = float(credit_match.group(1)) if credit_match else 0.0

            line_type = "LINE"
            block_hours = 0.0
            days_off = 0
            total_legs = 0
            carry_over = 0.0
            has_star = False
            destinations = []

            raw = "\n".join(block_rows)

            for row in block_rows[1:]:
                type_match = re.search(r'\b(TRNG|LINE|USLN|CHLN|HJLN|BYND|HYLN|HDLN|INDO|KULN|Reserve)\b', row)
                if type_match:
                    line_type = type_match.group(1)

                blk_match = re.search(r'\bBLK\s+(\d+(?:\.\d+)?)', row)
                if blk_match:
                    block_hours = float(blk_match.group(1))

                off_match = re.search(r'\bOFF\s+(\d+)\b', row)
                if off_match:
                    days_off = int(off_match.group(1))

                dp_match = re.search(r"NO\.\s*DP'?S\s+(\d+)", row)
                if dp_match:
                    total_legs = int(dp_match.group(1))

                co_match = re.search(r'C/O\s+(\d+(?:\.\d+)?)', row)
                if co_match:
                    carry_over = float(co_match.group(1))

                if '*' in row:
                    has_star = True

            # Destination summary is embedded in the duty rows. Capture airport codes,
            # excluding calendar/day and operational labels.
            ignore = {
                'LINE', 'TRNG', 'BLK', 'OFF', 'TAD', 'TAI', 'TAR', 'NO', 'DPS',
                'CR', 'WE', 'TH', 'FR', 'SA', 'SU', 'MO', 'TU', 'RT1', 'RT2', 'RT3',
                'RR1', 'RR2', 'RR3', 'JED'
            }
            seen = set()
            for code in re.findall(r'\b[A-Z]{3}\b', raw):
                if code not in ignore and code not in seen:
                    seen.add(code)
                    destinations.append(LineDestination(iata=code, layoverHours=0.0))

            parsed_lines.append(ParsedPDFLine(
                lineNumber=line_no,
                lineType=line_type,
                carryOver="",
                creditHours=credit,
                blockHours=block_hours,
                carryOverHours=carry_over,
                daysOff=days_off,
                totalLegs=total_legs,
                fourLegCount=0,
                expense=0.0,
                allowance=0.0,
                income=0.0,
                destinations=destinations,
                hasStarDays=has_star,
                rawText=raw,
            ))

        return parsed_lines


# ─── API Endpoints ────────────────────────────────────────────────────────────

@router.post("/upload-lines-pdf", response_model=PDFParseResult)
async def upload_lines_pdf(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    rank: str = Form(...),
    base: str = Form(...),
    category: str = Form("9Z"),
    month: str = Form(...),
    uploaded_by: str = Form(...),
):
    """
    Upload a Saudi Airlines Lines of Time PDF.
    Parses all lines and saves to Firestore under the correct rank/base/category.
    Only admins can call this endpoint.
    """
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=422, detail="Only PDF files are accepted")

    max_size = 50 * 1024 * 1024  # 50MB
    pdf_bytes = await file.read()
    if len(pdf_bytes) > max_size:
        raise HTTPException(status_code=422, detail="File too large. Maximum 50MB.")

    rank = rank.upper().strip()
    base = base.upper().strip()
    category = category.upper().strip()

    parser = LinesPDFParser()
    result = parser.parse(
        pdf_bytes=pdf_bytes,
        rank=rank,
        base=base,
        category=category,
        month=month,
        uploaded_by=uploaded_by,
    )

    if result.totalLines > 0:
        background_tasks.add_task(
            _save_lines_to_firestore,
            result=result,
            rank=rank,
            base=base,
            category=category,
            month=month,
        )

    return result


@router.get("/lines-status")
async def get_lines_status():
    """Check which rank/month combinations have been uploaded."""
    try:
        from utils.firebase import get_firestore
        db = get_firestore()
        uploads = db.collection("lineUploads").order_by(
            "uploadedAt", direction="DESCENDING"
        ).limit(50).stream()

        return {
            "uploads": [
                {
                    "id": doc.id,
                    **{k: v for k, v in doc.to_dict().items()
                       if k != "linesData"}
                }
                for doc in uploads
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─── Save to Firestore ────────────────────────────────────────────────────────

async def _save_lines_to_firestore(
    result: PDFParseResult,
    rank: str, base: str, category: str, month: str
):
    try:
        from utils.firebase import get_firestore
        db = get_firestore()

        upload_id = f"{base}_{rank}_{category}_{month}"

        # Save upload metadata
        db.collection("lineUploads").document(upload_id).set({
            "rank": rank,
            "base": base,
            "category": category,
            "month": month,
            "totalLines": result.totalLines,
            "uploadedBy": result.uploadedBy,
            "uploadedAt": datetime.utcnow(),
            "status": "complete",
        })

        # Save each line to flightLines collection
        batch = db.batch()
        count = 0

        for line in result.linesData:
            doc_id = f"{base}_{rank}_{category}_{month}_{line.lineNumber:04d}"
            ref = db.collection("flightLines").document(doc_id)

            batch.set(ref, {
                "id": doc_id,
                "lineNumber": str(line.lineNumber),
                "lineType": line.lineType,
                "carryOver": line.carryOver,
                "rank": rank,
                "base": base,
                "category": category,
                "month": month,
                "creditHours": line.creditHours,
                "blockHours": line.blockHours,
                "carryOverHours": line.carryOverHours,
                "daysOff": line.daysOff,
                "totalLegs": line.totalLegs,
                "fourLegCount": line.fourLegCount,
                "expense": line.expense,
                "allowance": line.allowance,
                "income": line.income,
                "destinations": [
                    {"iata": d.iata, "layoverHours": d.layoverHours}
                    for d in line.destinations
                ],
                "hasStarDays": line.hasStarDays,
                "isActive": True,
                "uploadedAt": datetime.utcnow(),
            })
            count += 1

            # Commit in batches of 400
            if count % 400 == 0:
                batch.commit()
                batch = db.batch()

        if count % 400 != 0:
            batch.commit()

        logger.info(
            f"Saved {count} lines for {base} {rank} {category} {month}"
        )

    except Exception as e:
        logger.error(f"Firestore save failed: {e}", exc_info=True)
