// app/middleware/admin.ts
export default defineNuxtRouteMiddleware(async (to, from) => {
  const client = useSupabaseClient();
  const {
    data: { session },
  } = await client.auth.getSession();

  if (!session) return navigateTo("/admin/login");

  const { data } = await client
    .from("users")
    .select("role")
    .eq("id", session.user.id)
    .single();

  if (data?.role !== "admin") return navigateTo("/");
});
