export default defineNuxtRouteMiddleware(async () => {
    const client = useSupabaseClient();
    const user = useSupabaseUser();

    const { data } = await client
        .from("app_settings")
        .select("registrations_open")
        .eq("id", 1)
        .single();

    if (data?.registrations_open === false) {
        return navigateTo("/");
    }

    if (!user.value) {
        return navigateTo("/login");
    }
});
