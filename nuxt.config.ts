// nuxt.config.ts
export default defineNuxtConfig({
  compatibilityDate: "2025-07-15",
  devtools: { enabled: true },
  modules: ["@nuxtjs/tailwindcss", "@nuxt/icon", "@nuxtjs/supabase"],
  supabase: {
    redirect: false,
    cookieOptions: {
      secure: process.env.NODE_ENV === "production",
    },
  },
});
