// app/pages/admin/login.vue
<script setup lang="ts">
const email = ref("");
const password = ref("");
const isError = ref(false);
const message = ref("");

const client = useSupabaseClient();
const router = useRouter();
const { fetchRole } = useAuth();

const handleLogin = async () => {
    message.value = "Accesso in corso...";
    isError.value = false;

    const { data: authData, error: authError } =
        await client.auth.signInWithPassword({
            email: email.value,
            password: password.value,
        });

    if (authError) {
        isError.value = true;
        message.value = authError.message;
        return;
    }

    if (authData.user) {
        const { data: userData, error: userError } = await client
            .from("users")
            .select("role")
            .eq("id", authData.user.id)
            .single();

        if (userError || userData?.role !== "admin") {
            await client.auth.signOut();
            isError.value = true;
            message.value = "Accesso negato: solo per amministratori.";
            return;
        }

        // Populate the shared role state so the Navbar updates immediately
        await fetchRole();
        router.push("/admin");
    }
};
</script>

<template>
    <div
        class="max-w-md mx-4 sm:mx-auto mt-6 sm:mt-16 bg-white p-6 sm:p-8 border border-gray-100 rounded-3xl shadow-sm mobile-fade-in"
    >
        <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-black uppercase tracking-tight text-gray-900">
                Admin
            </h1>
            <p class="text-gray-500 font-medium mt-2">
                Gestisci squadre, gironi e incontri.
            </p>
        </div>
        <form @submit.prevent="handleLogin" class="space-y-4">
            <div>
                <label class="block text-xs font-black uppercase tracking-wide text-gray-500"
                    >Email</label
                >
                <input
                    v-model="email"
                    type="email"
                    required
                    class="mt-1 w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl focus:bg-white focus:ring-4 focus:ring-gray-100 focus:border-black outline-none transition-all"
                />
            </div>
            <div>
                <label class="block text-xs font-black uppercase tracking-wide text-gray-500"
                    >Password</label
                >
                <input
                    v-model="password"
                    type="password"
                    required
                    class="mt-1 w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl focus:bg-white focus:ring-4 focus:ring-gray-100 focus:border-black outline-none transition-all"
                />
            </div>
            <p
                v-if="message"
                :class="isError ? 'text-red-500' : 'text-green-500'"
                class="text-sm font-bold"
            >
                {{ message }}
            </p>
            <button
                type="submit"
                class="w-full bg-black text-white px-4 py-3 rounded-2xl hover:bg-gray-800 font-black uppercase tracking-wide transition-all active:scale-[0.98]"
            >
                Accedi
            </button>
        </form>
    </div>
</template>
