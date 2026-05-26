// app/layouts/default.vue
<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useVotes } from '~/composables/useVotes';
import { useScrollLock } from '~/composables/useScrollLock';

const route = useRoute();
const supabase = useSupabaseClient();

const { showFirstVotePopup } = useVotes();
const { lock, unlock } = useScrollLock();

const registrationsOpen = ref(true);

const loadRegistrationSettings = async () => {
    const { data } = await supabase
        .from("app_settings")
        .select("registrations_open")
        .eq("id", 1)
        .single();

    if (data) {
        registrationsOpen.value = data.registrations_open;
    }
};

const shouldJoinFooter = computed(() => {
    return route.path === '/' && registrationsOpen.value;
});

watch(showFirstVotePopup, (isOpen) => {
    if (isOpen) {
        lock();
    } else {
        unlock();
    }
}, { immediate: true });

onMounted(() => {
    loadRegistrationSettings();
});
</script>

<template>
    <div class="min-h-dvh flex flex-col bg-cement text-black">
        <!-- First Vote Popup -->
        <div v-if="showFirstVotePopup" class="fixed inset-0 bg-black/80 z-[100] flex items-center justify-center p-4 mobile-fade-in">
            <div class="bg-white border-4 border-black p-6 sm:p-8 max-w-md w-full shadow-[8px_8px_0px_var(--primary)] text-center animate-fade-in">
                <Icon name="mdi:party-popper" class="text-5xl text-primary mb-4" />
                <h2 class="font-impact text-2xl sm:text-3xl mb-4 uppercase tracking-wider text-black">Primo Voto Registrato!</h2>
                <p class="font-bold text-gray-600 mb-6 text-sm sm:text-base leading-relaxed">
                    Ricorda: hai a disposizione un totale di <span class="text-black text-lg">5 voti</span> da distribuire in tutto il torneo! 
                    Puoi darli a giocatori diversi o tutti allo stesso giocatore. <br/><br/>
                    <span class="text-xs">Hai sbagliato? Nessun problema! Puoi rimuovere un voto in qualsiasi momento cliccando sul tasto <strong class="text-red-500 bg-red-100 px-1 rounded">-</strong> rosso.</span>
                </p>
                <button @click="showFirstVotePopup = false" class="btn-skewed w-full">
                    <span class="btn-skewed-content">Ho Capito!</span>
                </button>
            </div>
        </div>

        <Navbar />

        <main class="flex-grow">
            <slot />
        </main>

        <footer
            class="text-gray-400 px-4 py-8 pb-[calc(2rem+env(safe-area-inset-bottom))] text-center relative"
            :class="shouldJoinFooter ? 'bg-secondary' : 'bg-secondary border-t-4 border-black'"
        >
            <div class="max-w-7xl mx-auto space-y-4">
                <div class="font-impact text-xl sm:text-2xl tracking-widest text-primary">
                    DODGEBALL XL
                </div>
                <p class="text-xs uppercase font-bold tracking-wider opacity-60">
                    MEMORIAL LORIS PASSERI &bull; ZONA PRATI, ZONA SPORTIVA
                </p>
                <div class="h-[1px] bg-white/10 max-w-xs mx-auto"></div>
                
                <!-- MVP Rules Button -->
                <div class="flex justify-center my-4">
                    <button @click="showFirstVotePopup = true" class="text-[10px] font-impact tracking-widest text-white border-b border-dashed border-gray-500 hover:text-primary hover:border-primary transition-colors pb-0.5 uppercase flex items-center gap-1 cursor-pointer">
                        <Icon name="mdi:information-outline" class="text-sm" />
                        Regole Votazione MVP
                    </button>
                </div>

                <p class="text-[10px] uppercase font-bold tracking-widest opacity-40">
                    &copy; 2026 Dodgeball XL. All rights aggressive.
                </p>
            </div>
        </footer>
    </div>
</template>
