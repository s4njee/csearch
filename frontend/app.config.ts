// Nuxt UI theme configuration.
// `primary` points at the custom green palette defined in assets/css/main.css
// (anchored on the brand accent #008F11). `neutral` keeps the dark slate surface
// tone that matches the original design.
export default defineAppConfig({
  ui: {
    colors: {
      primary: 'csgreen',
      // Achromatic grey (no blue/colour bias) — pairs with the pure-black
      // page background and dark-grey card surfaces set in main.css.
      neutral: 'neutral',
    },
  },
})
