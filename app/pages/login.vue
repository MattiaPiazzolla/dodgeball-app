// app/pages/login.vue
<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useSupabaseClient } from "#imports";

definePageMeta({
    middleware: async () => {
        const client = useSupabaseClient();
        const { data } = await client
            .from("app_settings")
            .select("registrations_open")
            .eq("id", 1)
            .single();

        if (data?.registrations_open === false) {
            return navigateTo("/");
        }
    },
});

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
    if (!registrationsOpen.value) {
        await navigateTo("/");
        return;
    }
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
    <div class="min-h-[80vh] flex items-center justify-center bg-cement py-12 px-4 sm:px-6 lg:px-8">
        <div
            class="max-w-md w-full card-grunge bg-white p-6 sm:p-8 space-y-6 sm:space-y-8 mobile-fade-in"
        >
            <div class="text-center space-y-3">
                <h1 class="font-impact text-3xl sm:text-4xl text-secondary leading-none">
                    {{ isSignUp ? "Crea account" : "Area capitano" }}
                </h1>
                <p class="text-gray-500 text-sm font-medium mt-2">
                    {{
                        isSignUp
                            ? "Registrati per creare la tua squadra."
                            : "Accedi per gestire logo e rosa."
                    }}
                </p>
                <div class="w-12 h-0.5 bg-primary mx-auto"></div>
                <p
                    v-if="!loadingSettings && !registrationsOpen"
                    class="mt-4 text-xs font-impact tracking-widest text-white bg-primary border-2 border-black rounded-none px-4 py-2 uppercase shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                >
                    Nuove iscrizioni chiuse
                </p>
            </div>
            
            <form @submit.prevent="handleAuth" class="space-y-5">
                <div class="space-y-1">
                    <label class="block text-xs font-impact tracking-wider text-secondary uppercase"
                        >Email</label
                    >
                    <input
                        v-model="email"
                        type="email"
                        required
                        class="w-full px-4 py-3 bg-white border-2 border-black rounded-none focus:bg-gray-50 focus:border-primary outline-none transition-all font-body"
                    />
                </div>
                <div class="space-y-1">
                    <label class="block text-xs font-impact tracking-wider text-secondary uppercase"
                        >Password</label
                    >
                    <input
                        v-model="password"
                        type="password"
                        required
                        class="w-full px-4 py-3 bg-white border-2 border-black rounded-none focus:bg-gray-50 focus:border-primary outline-none transition-all font-body"
                    />
                </div>
                
                <p v-if="errorMsg" class="text-primary text-xs font-impact tracking-widest uppercase">
                    ⚠ {{ errorMsg }}
                </p>
                
                <div class="pt-2">
                    <button
                        type="submit"
                        class="btn-skewed w-full"
                    >
                        <span class="btn-skewed-content">{{ isSignUp ? "Registrati" : "Accedi" }}</span>
                    </button>
                </div>
            </form>
            
            <button
                v-if="registrationsOpen"
                @click="isSignUp = !isSignUp"
                class="mt-4 text-xs font-impact tracking-widest text-secondary hover:text-primary w-full text-center uppercase transition-colors"
            >
                {{
                    isSignUp
                        ? "[ Hai già un account? Accedi ]"
                        : "[ Nuovo capitano? Crea account ]"
                }}
            </button>
        </div>
    </div>
</template>
