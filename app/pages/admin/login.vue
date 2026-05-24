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
        class="max-w-md mx-auto mt-20 bg-white p-8 border rounded-lg shadow-sm"
    >
        <h1 class="text-2xl font-bold mb-6 text-center text-gray-800">
            Accesso Amministratore
        </h1>
        <form @submit.prevent="handleLogin" class="space-y-4">
            <div>
                <label class="block text-sm font-medium text-gray-700"
                    >Email</label
                >
                <input
                    v-model="email"
                    type="email"
                    required
                    class="mt-1 w-full p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
                />
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700"
                    >Password</label
                >
                <input
                    v-model="password"
                    type="password"
                    required
                    class="mt-1 w-full p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
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
                class="w-full bg-gray-900 text-white px-4 py-2 rounded hover:bg-gray-800 font-bold transition"
            >
                Accedi
            </button>
        </form>
    </div>
</template>
