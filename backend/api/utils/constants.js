"use strict";

const VALID_BILL_TYPES = new Set([
  "s", "hr", "hconres", "hjres", "hres", "sconres", "sjres", "sres",
]);

module.exports = { VALID_BILL_TYPES };
