// app/composables/useAuth.ts
export const useAuth = () => {
  const client = useSupabaseClient();
  const user = useSupabaseUser();
  const role = useState<string | null>("user-role", () => null);

  const fetchRole = async () => {
    if (!user.value || !user.value.id) {
      role.value = null;
      return;
    }
    const { data } = await client
      .from("users")
      .select("role")
      .eq("id", user.value.id)
      .single();

    role.value = data?.role || "captain";
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
