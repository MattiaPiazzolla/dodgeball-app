// app/composables/useAuth.ts
export const useAuth = () => {
  const client = useSupabaseClient();
  const user = useSupabaseUser();
  const role = useState<string | null>("user-role", () => null);

  const fetchRole = async () => {
    // Use getSession() directly — the reactive `user` ref may not be
    // populated yet when this is called from a plugin or early in the lifecycle.
    const { data: { session } } = await client.auth.getSession();

    if (!session?.user?.id) {
      role.value = null;
      return;
    }

    const { data, error } = await client
      .from("users")
      .select("role")
      .eq("id", session.user.id)
      .single();

    if (error) {
      console.error("[useAuth] fetchRole error:", error.message);
      role.value = null;
      return;
    }

    role.value = data?.role ?? null;
  };

  const logout = async () => {
    await client.auth.signOut();
    role.value = null;
    navigateTo("/");
  };

  return {
    user,
    role,
    fetchRole,
    logout,
  };
};
