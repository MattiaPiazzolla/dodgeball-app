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
        class="max-w-md mx-4 sm:mx-auto mt-6 sm:mt-16 bg-white p-6 sm:p-8 card-grunge mobile-fade-in"
    >
        <div class="text-center mb-8 border-b-2 border-black pb-4">
            <h1 class="text-3xl sm:text-4xl font-impact uppercase tracking-widest text-black">
                Admin
            </h1>
            <p class="text-secondary font-bold mt-2 uppercase tracking-wide">
                Gestisci squadre, gironi e incontri.
            </p>
        </div>
        <form @submit.prevent="handleLogin" class="space-y-6">
            <div>
                <label class="block text-xs font-impact uppercase tracking-widest text-secondary"
                    >Email</label
                >
                <input
                    v-model="email"
                    type="email"
                    required
                    class="mt-1 w-full px-4 py-3 bg-white border-4 border-black focus:border-primary outline-none font-impact tracking-widest text-lg uppercase transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                />
            </div>
            <div>
                <label class="block text-xs font-impact uppercase tracking-widest text-secondary"
                    >Password</label
                >
                <input
                    v-model="password"
                    type="password"
                    required
                    class="mt-1 w-full px-4 py-3 bg-white border-4 border-black focus:border-primary outline-none font-impact tracking-widest text-lg transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                />
            </div>
            <p
                v-if="message"
                :class="isError ? 'text-primary' : 'text-green-600'"
                class="text-sm font-impact tracking-widest uppercase"
            >
                {{ message }}
            </p>
            <button
                type="submit"
                class="btn-skewed w-full text-xl"
            >
                <span class="btn-skewed-content">Accedi</span>
            </button>
        </form>
    </div>
</template>
