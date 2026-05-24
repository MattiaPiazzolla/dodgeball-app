// app/pages/login.vue
<script setup lang="ts">
const client = useSupabaseClient();
const email = ref("");
const password = ref("");
const isSignUp = ref(false);
const errorMsg = ref("");
const registrationsOpen = ref(true);
const loadingSettings = ref(true);

const loadRegistrationSettings = async () => {
    const { data } = await client
        .from("app_settings")
        .select("registrations_open")
        .eq("id", 1)
        .single();

    registrationsOpen.value = data?.registrations_open ?? true;
    if (!registrationsOpen.value) isSignUp.value = false;
    loadingSettings.value = false;
};

const handleAuth = async () => {
    errorMsg.value = "";
    try {
        if (isSignUp.value) {
            if (!registrationsOpen.value) {
                errorMsg.value = "Le iscrizioni sono chiuse.";
                isSignUp.value = false;
                return;
            }

            const { error } = await client.auth.signUp({
                email: email.value,
                password: password.value,
            });
            if (error) throw error;
            alert("Controlla la tua email per confermare la registrazione!");
        } else {
            const { error } = await client.auth.signInWithPassword({
                email: email.value,
                password: password.value,
            });
            if (error) throw error;
            navigateTo("/captain");
        }
    } catch (error: any) {
        errorMsg.value = error.message;
    }
};

onMounted(loadRegistrationSettings);
</script>

<template>
    <div
        class="max-w-md mx-4 sm:mx-auto mt-6 sm:mt-16 p-6 sm:p-8 bg-white rounded-3xl shadow-sm border border-gray-100 mobile-fade-in"
    >
        <div class="text-center mb-8">
            <h1 class="text-2xl sm:text-3xl font-black uppercase tracking-tight text-gray-900">
                {{ isSignUp ? "Crea account" : "Area capitano" }}
            </h1>
            <p class="text-gray-500 font-medium mt-2">
                {{
                    isSignUp
                        ? "Registrati per creare la tua squadra."
                        : "Accedi per gestire logo e rosa."
                }}
            </p>
            <p
                v-if="!loadingSettings && !registrationsOpen"
                class="mt-4 text-xs font-black uppercase tracking-widest text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3"
            >
                Nuove iscrizioni chiuse
            </p>
        </div>
        <form @submit.prevent="handleAuth" class="space-y-4">
            <div>
                <label class="block text-xs font-black uppercase tracking-wide text-gray-500"
                    >Email</label
                >
                <input
                    v-model="email"
                    type="email"
                    required
                    class="mt-1 w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl focus:bg-white focus:ring-4 focus:ring-red-50 focus:border-red-500 outline-none transition-all"
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
                    class="mt-1 w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl focus:bg-white focus:ring-4 focus:ring-red-50 focus:border-red-500 outline-none transition-all"
                />
            </div>
            <p v-if="errorMsg" class="text-red-500 text-sm font-semibold">
                {{ errorMsg }}
            </p>
            <button
                type="submit"
                class="w-full bg-red-600 text-white py-3 rounded-2xl hover:bg-red-700 font-black uppercase tracking-wide transition-all shadow-md shadow-red-200 active:scale-[0.98]"
            >
                {{ isSignUp ? "Registrati" : "Accedi" }}
            </button>
        </form>
        <button
            v-if="registrationsOpen"
            @click="isSignUp = !isSignUp"
            class="mt-5 text-sm text-gray-500 hover:text-red-600 w-full text-center font-bold transition-colors"
        >
            {{
                isSignUp
                    ? "Hai già un account? Accedi"
                    : "Nuovo capitano? Crea account"
            }}
        </button>
    </div>
</template>
