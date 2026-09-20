const COLORS = Object.freeze({
  background: "F7F8FA",
  surface: "FFFFFF",
  text: "20262E",
  muted: "66717E",
  methodology: "0B6670",
  security: "B93A3A",
  performance: "C47B12",
  verified: "2F7D4A",
  line: "D9DEE5",
  dark: "152027",
  paleTeal: "E8F2F3",
  paleRed: "F8EAEA",
  paleAmber: "FBF1DF",
  paleGreen: "E9F3ED"
});

const FONTS = Object.freeze({
  face: "Arial",
  title: 30,
  subtitle: 20,
  body: 20,
  small: 14,
  metric: 30
});

const LAYOUT = Object.freeze({
  width: 13.333,
  height: 7.5,
  marginX: 0.68,
  contentTop: 1.28,
  contentBottom: 6.92
});

function sectionColor(section) {
  if (section === "Method") return COLORS.methodology;
  if (section === "Results") return COLORS.performance;
  if (section === "Comparison") return COLORS.security;
  if (section === "Future Work") return COLORS.performance;
  if (section === "Synthesis" || section === "Closing") return COLORS.verified;
  return COLORS.text;
}

module.exports = { COLORS, FONTS, LAYOUT, sectionColor };
