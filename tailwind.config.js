/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./app/**/*.{vue,js,ts,jsx,tsx}",
    "./components/**/*.{vue,js,ts,jsx,tsx}",
    "./layouts/**/*.vue",
    "./pages/**/*.vue",
    "./plugins/**/*.{js,ts}",
    "./app.vue",
  ],
  theme: {
    extend: {
      colors: {
        primary: "#D32F2F",       // Rosso Corsa / Dodgeball Red
        secondary: "#1A1A1A",     // Nero Profondo / Charcoal
        accent: "#E65100",        // Arancione Street
        "bg-page": "#F4F4F2",      // Grigio Chiaro / Cemento Sfumato
        "bg-dark": "#111111",      // Variante Dark per Hero
        surface: "#FFFFFF",
        brandtext: {
          main: "#111111",
          inverse: "#FFFFFF",
          muted: "#666666",
        }
      },
      fontFamily: {
        heading: ["Impact", "Barlow Condensed", "Arial Black", "sans-serif"],
        body: ["'Helvetica Neue'", "Helvetica", "Arial", "sans-serif"],
      },
    },
  },
  plugins: [],
}
