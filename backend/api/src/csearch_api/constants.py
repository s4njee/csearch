VALID_BILL_TYPES = {
    "s",
    "hr",
    "hconres",
    "hjres",
    "hres",
    "sconres",
    "sjres",
    "sres",
}

# Identity mappings ("h": "h", "s": "s") normalize externally-supplied values
# that may already be in abbreviated form (e.g. from query params or the API).
CHAMBER_ABBREV = {
    "house": "h",
    "senate": "s",
    "h": "h",
    "s": "s",
}

MIN_FUZZY_QUERY_LENGTH = 3

