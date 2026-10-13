"""
Parsing of the backend's answer to POST /api/v1/parkir/edge-entry.

Kept free of third-party imports (no cv2 / numpy / requests) so it can be unit
tested anywhere with the standard library only.

Response contract (every outcome, including the 400/401/403/404 deny paths):

    {
        "status": "success" | "error",
        "message": "...",
        "data": {
            "gate_action": "OPEN" | "DENY",
            "plate_text": "B1234XYZ",      # OPEN and some deny paths
            "owner": "...",                # OPEN only
            "parkiran": "...",             # OPEN only
            "slot_tersisa": 12,            # MASUK + OPEN only
            "ocr_confidence": 0.93
        }
    }

On a network or JSON error the edge client itself builds
{"gate_action": "DENY", "error": "<reason>"}.

The gate fails closed: it opens only for an explicit "OPEN". A DENY, a missing
or unknown value, a malformed body or an error dict all resolve to "DENY".
"""

GATE_OPEN = 'OPEN'
GATE_DENY = 'DENY'


def _pick(data, result, key, default=None):
    """Return key from data (nested) first, else from result (legacy top level)"""
    value = data.get(key)
    if value is not None:
        return value
    value = result.get(key)
    if value is not None:
        return value
    return default


def _to_float(value, default=0.0):
    """Best-effort float conversion; never raises"""
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def parse_server_result(result):
    """
    Normalise a server answer into
    {gate_action, message, plate_text, ocr_confidence, success}.

    Values are read from result['data'] when that is a dict, falling back to the
    top level of the response for the legacy flat shape. gate_action is always
    exactly 'OPEN' or 'DENY' and defaults to 'DENY'. success is True only for
    status == 'success' together with gate_action == 'OPEN'.
    """
    parsed = {
        'gate_action': GATE_DENY,
        'message': '',
        'plate_text': '',
        'ocr_confidence': 0.0,
        'success': False,
    }

    if not isinstance(result, dict):
        return parsed

    data = result.get('data')
    if not isinstance(data, dict):
        data = {}

    # Only an explicit, exact 'OPEN' opens the gate
    if _pick(data, result, 'gate_action') == GATE_OPEN:
        parsed['gate_action'] = GATE_OPEN

    message = _pick(data, result, 'message')
    if message is None:
        message = result.get('error')
    if message is not None:
        parsed['message'] = str(message)

    plate_text = _pick(data, result, 'plate_text')
    if plate_text is not None:
        parsed['plate_text'] = str(plate_text)

    confidence = _pick(data, result, 'ocr_confidence')
    if confidence is None:
        confidence = _pick(data, result, 'confidence')
    parsed['ocr_confidence'] = _to_float(confidence)

    parsed['success'] = (
        result.get('status') == 'success'
        and parsed['gate_action'] == GATE_OPEN
    )

    return parsed
