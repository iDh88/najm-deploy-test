# UI Component Specification
## Crew Intelligence Platform — Design System Reference

---

## Design Tokens

### Colors
```
Primary:       #1B4F8A  (Saudi Navy)
Secondary:     #C8A84B  (Saudi Gold)
Gold Light:    #E8C86B

Legal Green:   #2ECC71  Background: #E8FAF0
Warning Amber: #F39C12  Background: #FEF9E7
Violation Red: #E74C3C  Background: #FDECEB

Money Mode:    #27AE60
Rest Mode:     #2980B9
Balanced Mode: #8E44AD

Grey 50:  #F8F9FA   Grey 100: #F1F3F5
Grey 200: #E9ECEF   Grey 300: #DEE2E6
Grey 500: #ADB5BD   Grey 700: #495057
Grey 900: #212529

Dark Background: #0F1923
Dark Surface:    #1A2740
Dark Card:       #1E2E44
Dark Border:     #2A3F5F
```

### Typography
```
Arabic:  NotoSansArabic (Regular 400, Medium 500, Bold 700)
Latin:   Inter (Regular 400, Medium 500, SemiBold 600, Bold 700)

Display Large:   32px / Bold   — Page titles
Display Medium:  28px / Bold   — Section headers
Headline Large:  22px / SemiBold
Headline Medium: 20px / SemiBold — Card titles
Title Large:     16px / SemiBold — List headers
Title Medium:    15px / Medium  — Subtitle text
Body Large:      16px / Regular — Primary content
Body Medium:     14px / Regular — Secondary content
Body Small:      12px / Regular — Captions, metadata
Label Large:     14px / SemiBold — Buttons
Label Small:     10px / Medium  — Chips, tags
```

### Spacing & Layout
```
Page Horizontal Padding: 16px
Card Border Radius:      12px
Button Border Radius:    12px
Bottom Sheet Radius:     20px (top corners only)
Card Elevation:          0 (border-only design)
Border Width:            1px standard, 1.5px focused, 2px violation alert
Animation Duration:      200ms standard, 300ms page transitions
```

---

## Component Library

---

### 1. LineCard

**Purpose:** Displays a flight line in the browse list with score, key stats, and bid CTA.

**Variants:** Default · Ranked (shows #N badge) · Compact

**Props:**
| Prop | Type | Required | Description |
|---|---|---|---|
| `line` | FlightLine | ✅ | The flight line data |
| `rank` | int | ✅ | Ranking position (1-based) |
| `userMode` | UserMode | ✅ | Active optimization mode |
| `onTap` | VoidCallback | ✅ | Navigate to detail |

**Layout:**
```
┌─────────────────────────────────────────────┐
│ [#1]  Line 411                    [🛡 Legal] │
│       RUH · LHR · CDG · AMS                 │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓░░  Match: 87/100             │
│ ⏱ 89h duty  ✈ 12 legs  🏨 3 layovers SAR 12,400 │
└─────────────────────────────────────────────┘
```

**Rank Badge:** Gold background for top 3, grey for others.
**Score Bar:** Color matches active UserMode (green/blue/navy).
**Legality Badge:** Always shown; green shield / amber / red × .

---

### 2. LegalityBadge

**Purpose:** Compact pill showing legality status of a leg or line.

**Variants:** Legal (green) · Warning (amber) · Violation (red)

**Props:**
| Prop | Type | Required | Description |
|---|---|---|---|
| `hasViolations` | bool | ✅ | Red state |
| `hasWarnings` | bool | ✅ | Amber state |
| `violations` | List\<LegalityViolation\> | — | For tooltip/panel |
| `onTap` | VoidCallback? | — | Opens LegalityPanel |

**States:**
```
✅ [🛡 Legal]      — green bg + text
⚠️ [🛡 Warning]    — amber bg + text
❌ [🛡 Violation]   — red bg + text + blocks action
```

---

### 3. LegalityPanel

**Purpose:** Expandable detail panel showing all legality check results.

**Behaviour:** Collapsed by default; tap to expand. Non-expandable if all passed.

**Content when expanded:**
- Per-violation row: icon + Arabic description + English description + actual vs required values
- Affected flight numbers highlighted
- Rule reference ID shown

---

### 4. DutyTimelineWidget

**Purpose:** Horizontal scrollable Gantt-style view of a full month's schedule.

**Layout:**
```
← scroll →
[Rest 24h] [SV100 RUH→LHR 7h] [Rest 36h🏨] [SV101 LHR→RUH 7h] [Rest 16h] ...
```

**Block color coding:**
- Domestic leg: #3498DB (blue)
- International leg: #2ECC71 (green)
- Layover leg: #F39C12 (amber)
- Violation: #E74C3C border (red)

**Block width:** Proportional to block hours (30px/hour, min 60px, max 200px)
**Rest gap width:** Proportional to rest hours (8px/hour, min 20px, max 80px)
**Rest gap label:** Shows hours when >4h; shows violation warning if below minimum

---

### 5. ModeSwitcher

**Purpose:** Compact 3-button mode selector. Shows active mode with color coding.

**Placement:** Top of Lines screen, below AppBar.

**States:**
```
[💰 Money] [😴 Rest] [⚖️ Balanced]
                     ^^^^^^^^^^^^ active (highlighted border + bg tint)
```

**Behaviour:** Tap switches global mode immediately; all scores recompute.
Shows brief animation (200ms) on switch.

---

### 6. NajmFilterBar

**Purpose:** Persistent natural language filter input at top of Lines screen.

**Icon:** ⭐ (gold) on left side — signals AI capability.
**Clear button:** Appears when text is present.
**Mic button:** Opens AssistantScreen with voice input active.

**Behaviour:**
- Short queries (1-2 words): client-side text filter on line number / destination
- Longer queries (3+ words or contains spaces): routes to AI assistant for NLP parsing
- Arabic input: fully supported; RTL layout

---

### 7. BidPriorityList

**Purpose:** Drag-to-reorder list of submitted bids by priority.

**Props:**
| Prop | Type | Description |
|---|---|---|
| `bids` | List\<Bid\> | Current bids sorted by priority |
| `onReorder` | Function | Called with new order on drag end |
| `onWithdraw` | Function | Called when withdraw is tapped |

**Each item:**
```
┌──────────────────────────────────────────┐
│ ⣿ #1  Line 411  [Submitted]  SAR 12,400 │
│       3 bids · Estimated salary ↑        │
│                              [Withdraw]  │
└──────────────────────────────────────────┘
```

**Drag handle:** Left side ⣿ icon.
**Status badge:** Color-coded (submitted=navy, awarded=green, rejected=red).

---

### 8. TradeCard

**Purpose:** Side-by-side display of offered and requested legs in a trade post.

**Layout:**
```
┌─────────────────────────────────────────────┐
│ OFFERED              ⇄   REQUESTED          │
│ SV100 RUH→LHR            SV201 JED→RUH     │
│ 15 Jun 09:00             18 Jun 14:00       │
│ 7h block · Intl          1.5h · Domestic    │
│                                             │
│ [🛡 Legal ✓]           Expires: 48h        │
│                          [Accept Trade]     │
└─────────────────────────────────────────────┘
```

**Anonymous mode:** Replaces name with rank + base (e.g. "Purser · RUH").
**Legality badge:** Green if pre-checked legal; amber if unchecked; red if violation.

---

### 9. SkeletonLoader

**Purpose:** Animated placeholder while content loads. **Never use spinners.**

**Variants:** Card (height prop) · Line · Circle · Text block

**Animation:** Opacity pulse 0.4→1.0, 1.2s duration, infinite repeat.

**Usage rules:**
- Every async data screen must show skeletons, never a blank area
- Match skeleton dimensions approximately to real content
- Show 3-5 skeleton cards in list views

---

### 10. AssistantBubble / UserBubble

**Purpose:** Chat message bubbles in the Najm assistant screen.

**UserBubble:**
- Alignment: Left (RTL — appears on left for Arabic, right for English)
- Background: Saudi Navy (#1B4F8A)
- Text: White
- Corner: Full radius except bottom-left (tail)

**AssistantBubble:**
- Alignment: Right (RTL)
- Background: White with grey border
- Header: ⭐ gold avatar (28×28)
- Rich content cards appear below text in same bubble group

**TypingIndicator:** Animated skeleton in AssistantBubble shape.

---

### 11. StatCard (Dashboard)

**Purpose:** Quick summary number card on home dashboard.

**Layout:**
```
┌────────────────────┐
│ ساعات الواجب       │  ← Arabic label
│ 89          h      │  ← value + unit (colored)
│ Duty Hours         │  ← English sublabel
└────────────────────┘
```

**Size:** Equal-width, 3 per row. Min height 80px.

---

### 12. ModeChip (AppBar)

**Purpose:** Small pill in AppBar showing current optimization mode.

**Variants:** Money (green) · Rest (blue) · Balanced (purple)

```
[💰 Money]   — green tint background, green text
[😴 Rest]    — blue tint
[⚖️ Balanced] — purple tint
```

---

## Screen-Level UX Rules

### Loading States
- **All async screens:** Skeletons on first load
- **Refresh:** Pull-to-refresh on all list screens
- **Error:** Specific error message with retry button — never "Something went wrong"
- **Empty:** Illustrated empty state with contextual action button

### Navigation
- **Back button:** Always present on detail screens
- **Deep links:** All routes support deep linking from push notifications
- **Bottom nav:** Active state uses primary color icon + label

### Accessibility
- **Contrast:** WCAG AA minimum (4.5:1) for all text on backgrounds
- **Touch targets:** Minimum 44×44px for all interactive elements
- **Screen reader:** All interactive elements have semantic labels in Arabic
- **Text scaling:** Layout supports up to 1.3× text scale without breaking

### RTL / Bidirectional
- **Layout direction:** RTL by default (Arabic primary)
- **Icons:** Mirrored where directional (back arrows, chevrons)
- **Text:** Arabic uses NotoSansArabic; English uses Inter
- **Numbers:** Western Arabic numerals (0-9) used throughout for consistency
- **Dates:** Gregorian primary; Hijri available as secondary display

### Haptic Feedback
| Action | Feedback |
|---|---|
| Tap navigation | Light |
| Submit bid | Medium |
| Bid awarded notification | Heavy |
| Legality violation | Heavy + error tone |
| Trade confirmed | Medium + success tone |
| Drag reorder | Selection (continuous) |

### Error Handling
- **Network error:** "تحقق من الاتصال · Check your connection" + retry
- **Auth error:** Redirect to sign-in with toast message
- **Server error:** "حدث خطأ · Something went wrong" + support link
- **Validation error:** Inline field-level error; never modal for form errors
- **Rate limit:** Friendly upgrade prompt, never a raw 429 error message

---

## Animation Guidelines

| Type | Duration | Curve | Usage |
|---|---|---|---|
| Page transition | 300ms | easeInOut | Route changes |
| Card appear | 200ms | easeOut | List items |
| Mode switch | 200ms | easeInOut | Mode color change |
| Badge state | 150ms | easeIn | Legality badge changes |
| Skeleton fade | 1200ms | easeInOut | Loading shimmer |
| Bottom sheet | 300ms | easeOutCubic | Sheet open/close |
| FAB scale | 200ms | elasticOut | FAB appearance |
