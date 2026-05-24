// app/plugins/auth.client.ts
// Runs once on the client when the app boots.
// Fetches the user role from the DB so it's available to every component
// (including the Navbar) before they mount — no more race conditions.
export default defineNuxtPlugin(async () => {
  const { fetchRole } = useAuth();
  // Always call — fetchRole reads the session directly from Supabase storage,
  // so it works even before the reactive user ref is populated.
  await fetchRole();
});
