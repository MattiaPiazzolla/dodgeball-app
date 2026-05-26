// app/pages/index.vue
<script setup lang="ts">
import { ref, computed, watch, onMounted, defineAsyncComponent } from "vue";
import { useRoute } from "vue-router";

const sections = [
    { id: "live", label: "LIVE IN CORSO", icon: "mdi:access-point" },
    { id: "schedule", label: "CALENDARIO GARE", icon: "mdi:calendar-clock" },
    { id: "teams", label: "SQUADRE ISCRITTE", icon: "mdi:shield-account" },
];

const activeSection = ref("live");
const route = useRoute();

const sectionComponents = {
    live: defineAsyncComponent(
        () => import("~/components/public/PublicLive.vue"),
    ),
    schedule: defineAsyncComponent(
        () => import("~/components/public/PublicSchedule.vue"),
    ),
    teams: defineAsyncComponent(
        () => import("~/components/public/PublicTeams.vue"),
    ),
};

const activeComponent = computed(
    () =>
        sectionComponents[
            activeSection.value as keyof typeof sectionComponents
        ],
);

const scrollToSection = (id: string) => {
    activeSection.value = id;
    history.replaceState(null, "", `#${id}`);
    
    // Smooth scroll to dashboard
    const el = document.getElementById("torneo-dashboard");
    if (el) {
        el.scrollIntoView({ behavior: "smooth" });
    }
};

const applyHash = (hashValue: string) => {
    const hash = hashValue.replace("#", "");
    if (sections.some((section) => section.id === hash)) {
        activeSection.value = hash;
    }
};

watch(
    () => route.hash,
    (hash) => applyHash(hash),
);

const client = useSupabaseClient();
const registrationsOpen = ref(true);

const fetchSettings = async () => {
    const { data } = await client.from("app_settings").select("registrations_open").eq("id", 1).single();
    if (data) {
        registrationsOpen.value = data.registrations_open;
    }
};

onMounted(() => {
    fetchSettings();
    applyHash(window.location.hash);
});
</script>

<template>
    <div class="min-h-screen bg-cement pb-20 sm:pb-16 selection:bg-primary selection:text-white">
        <!-- SECTION 1: HERO (Theme: Dark, Background: #111111) -->
        <section
            v-if="registrationsOpen"
            id="hero"
            class="relative bg-[#111111] text-white py-20 sm:py-32 px-4 overflow-hidden border-b-8 border-black flex flex-col items-center justify-center min-h-[85vh] sm:min-h-[90vh]"
        >
            <!-- Visual Accent: Centered Red Sphere Glow -->
            <div class="absolute inset-0 flex items-center justify-center pointer-events-none overflow-hidden z-0">
                <div class="w-[300px] h-[300px] sm:w-[500px] sm:h-[500px] bg-radial from-primary/30 via-primary/5 to-transparent blur-3xl animate-pulse rounded-full"></div>
                <div class="absolute w-[220px] h-[220px] sm:w-[360px] sm:h-[360px] border-[3px] border-dashed border-primary/20 rounded-full animate-[spin_50s_linear_infinite]"></div>
                <div class="absolute w-[120px] h-[120px] sm:w-[200px] sm:h-[200px] bg-primary/10 rounded-full filter blur-2xl"></div>
            </div>

            <!-- Accent Background grid texture -->
            <div class="absolute inset-0 bg-[linear-gradient(to_right,rgba(255,255,255,0.03)_1px,transparent_1px),linear-gradient(to_bottom,rgba(255,255,255,0.03)_1px,transparent_1px)] bg-[size:24px_24px] pointer-events-none"></div>

            <div class="max-w-4xl mx-auto text-center relative z-10 space-y-6 sm:space-y-8 mobile-fade-in">
                <!-- Mini Badge -->
                <div class="inline-block bg-primary text-white font-impact tracking-widest text-xs sm:text-sm py-1.5 px-4 border-2 border-white transform -skew-x-6 uppercase shadow-[3px_3px_0px_rgba(0,0,0,1)]">
                    Torneo Ufficiale 2026
                </div>

                <div class="space-y-2 sm:space-y-4">
                    <h1 class="font-impact text-5xl sm:text-9xl tracking-tight leading-none text-white select-none">
                        DODGEBALL <span class="text-primary italic inline-block drop-shadow-[4px_4px_0px_rgba(0,0,0,1)]">XL</span>
                    </h1>
                    <p class="font-impact text-2xl sm:text-4xl text-gray-300 tracking-wider">
                        MEMORIAL LORIS PASSERI
                    </p>
                </div>

                <p class="text-gray-400 font-medium max-w-xl mx-auto text-sm sm:text-lg">
                    Il torneo di dodgeball più energetico dell'anno. Partite in diretta, classifiche in tempo reale e street food da urlo.
                </p>

                <!-- CTA Group -->
                <div class="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
                    <NuxtLink to="/login" class="btn-skewed w-full sm:w-auto">
                        <span class="btn-skewed-content">Iscrivi la Squadra</span>
                    </NuxtLink>
                    <a href="#info_torneo" class="btn-outline-white w-full sm:w-auto">
                        <span class="btn-skewed-content">Scopri il Programma</span>
                    </a>
                </div>
            </div>

            <!-- Visual Accent: Brush Stroke Bottom Paint Slash -->
            <div class="absolute bottom-0 left-0 right-0 h-6 bg-black transform skew-y-1 origin-bottom-left z-10"></div>
            <div class="absolute bottom-0 left-0 right-0 h-4 bg-primary transform -skew-y-1 origin-bottom-right opacity-80 z-10"></div>
        </section>

        <!-- SECTION 2: INFO TORNEO (Theme: Light, Background: #F4F4F2) -->
        <section
            v-if="registrationsOpen"
            id="info_torneo"
            class="py-16 sm:py-24 px-4 bg-cement"
        >
            <div class="max-w-4xl mx-auto space-y-10">
                <div class="text-center space-y-3">
                    <p class="font-impact text-primary text-sm sm:text-base tracking-widest">
                        TUTTI I BAMBINI E BAMBINE DAI 9 AI 13 ANNI
                    </p>
                    <h2 class="font-impact text-4xl sm:text-6xl text-secondary leading-none">
                        CATEGORIA RAGAZZI
                    </h2>
                    <div class="w-16 h-1 bg-primary mx-auto"></div>
                </div>

                <!-- Feature List Grunge Component -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-3xl mx-auto">
                    <div
                        v-for="(item, idx) in [
                            '4 VS 4 nel campo dedicato ai ragazzi',
                            'Max 6 ragazzi a squadra',
                            'Iscrizione 5€ compresa assicurazione',
                            'Iscrizione a squadre o singolarmente'
                        ]"
                        :key="idx"
                        class="flex items-center gap-5 bg-white border-2 border-black p-5 shadow-[4px_4px_0px_rgba(0,0,0,1)] transition-transform hover:-translate-y-1 cursor-default"
                    >
                        <div class="w-12 h-12 bg-primary border-2 border-black flex-shrink-0 flex items-center justify-center transform -skew-x-6 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                            <Icon name="mdi:check-bold" class="text-black font-black text-2xl transform skew-x-6" />
                        </div>
                        <span class="font-body font-bold text-sm sm:text-base text-black tracking-wide leading-tight">
                            {{ item }}
                        </span>
                    </div>
                </div>
            </div>
        </section>

        <!-- DYNAMIC TOURNAMENT DASHBOARD SECTION -->
        <section
            v-if="!registrationsOpen"
            id="torneo-dashboard"
            class="py-12 sm:py-20 px-4 scroll-mt-20"
        >
            <div class="space-y-8 max-w-[1400px] mx-auto">
                <!-- Separator line with athletic badge style -->
                <div class="flex items-center justify-center gap-4">
                    <div class="h-1 bg-black flex-grow"></div>
                    <div class="font-impact text-2xl sm:text-4xl text-black bg-cement px-4 tracking-widest whitespace-nowrap">
                        LIVE &amp; RISULTATI
                    </div>
                    <div class="h-1 bg-black flex-grow"></div>
                </div>

                <!-- Redesigned Grunge Dashboard Tab Controls -->
                <div class="flex flex-col sm:flex-row justify-center items-stretch gap-2 w-full max-w-2xl mx-auto">
                    <button
                        v-for="section in sections"
                        :key="section.id"
                        type="button"
                        @click="scrollToSection(section.id)"
                        class="flex-1 flex items-center justify-center gap-2 py-3 px-4 text-xs font-impact tracking-widest transition-all cursor-pointer border-2 border-black"
                        :class="
                            activeSection === section.id
                                ? 'bg-black text-white shadow-[3px_3px_0px_rgba(0,0,0,1)] -translate-y-0.5'
                                : 'bg-white text-secondary hover:bg-gray-100 shadow-[1px_1px_0px_rgba(0,0,0,1)]'
                        "
                    >
                        <Icon :name="section.icon" class="text-lg" />
                        {{ section.label }}
                    </button>
                </div>

                <!-- Tab Panel — full width, no box -->
                <div class="min-h-[550px] relative">
                    <Transition name="public-panel" mode="out-in">
                        <div :key="activeSection">
                            <component :is="activeComponent" />
                        </div>
                    </Transition>
                </div>
            </div>
        </section>

        <!-- SECTION 3: EXPERIENCE (Theme: Light) -->
        <section v-if="registrationsOpen" id="experience" class="py-12 sm:py-20 px-4 bg-cement border-t-4 border-black">
            <div class="max-w-5xl mx-auto">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-8 items-center">
                    
                    <!-- Left: Card Highlight -->
                    <div class="card-grunge p-6 sm:p-10 space-y-4">
                        <div class="inline-block bg-black text-white font-impact tracking-widest text-xs py-1 px-3 border-2 border-black transform -skew-x-6 uppercase">
                            Extra Experience
                        </div>
                        <h3 class="font-impact text-3xl sm:text-5xl text-black leading-none tracking-tight">
                            NON È SOLO DODGEBALL
                        </h3>
                        <p class="text-gray-600 font-medium text-sm sm:text-base leading-relaxed">
                            È un pomeriggio per correre, urlare, ridere e fare squadra tra partite, gonfiabili, musica e street food. L'evento perfetto per le famiglie e gli appassionati di sport.
                        </p>
                    </div>

                    <!-- Right: Sticker Food (Post-it Style) -->
                    <div class="flex items-center justify-center p-4">
                        <div class="sticker-yellow w-full max-w-md space-y-4">
                            <div class="flex items-center justify-between border-b-2 border-black pb-2">
                                <span class="text-sm tracking-wider font-bold text-gray-700">SPECIAL FOOD PARTNER</span>
                                <Icon name="mdi:silverware-fork-knife" class="text-2xl" />
                            </div>
                            <h4 class="text-4xl sm:text-5xl leading-none text-black select-none">
                                FOOD BY PANCEROS
                            </h4>
                            <p class="font-body text-xs sm:text-sm font-bold text-gray-800 leading-normal uppercase">
                                Piadine giganti, panzerotti caldi, bibite fresche e snack pronti sul posto per ricaricare le energie tra un match e l'altro!
                            </p>
                            <div class="bg-black/10 p-2 text-center text-xs font-bold border border-dashed border-black">
                                ORARIO APERTURA: 15:00 - FINE TORNEO
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </section>

        <!-- SECTION 4: DETAILS FOOTER / EVENT BADGE (Theme: Dark, Background: #1A1A1A) -->
        <section
            v-if="registrationsOpen"
            id="details_footer"
            class="bg-[#1A1A1A] text-white py-16 px-4 border-t-8 border-black text-center relative overflow-hidden"
        >
            <!-- Background accent lines -->
            <div class="absolute inset-0 bg-[linear-gradient(45deg,rgba(0,0,0,0.15)_25%,transparent_25%,transparent_50%,rgba(0,0,0,0.15)_50%,rgba(0,0,0,0.15)_75%,transparent_75%,transparent)] bg-[size:40px_40px] pointer-events-none"></div>

            <div class="max-w-4xl mx-auto space-y-8 relative z-10 mobile-fade-in">
                <!-- Large Event Badge -->
                <div class="bg-black border-4 border-primary p-6 sm:p-10 max-w-xl mx-auto inline-block text-center transform -skew-x-3 shadow-[8px_8px_0px_rgba(211,47,47,0.3)]">
                    <div class="font-impact text-primary text-5xl sm:text-7xl leading-none tracking-widest mb-2 select-none">
                        6 GIUGNO
                    </div>
                    <div class="font-impact text-white text-lg sm:text-2xl tracking-widest">
                        ZONA PRATI - DODGEBALL ARENA
                    </div>
                </div>

                <!-- Contact / Registration Info -->
                <div class="space-y-4 max-w-md mx-auto">
                    <div class="bg-primary/20 border-2 border-primary/50 py-3 px-6 transform skew-x-3 inline-block">
                        <span class="font-impact text-primary text-base sm:text-xl tracking-widest block">
                            INFO E ISCRIZIONI ISMA
                        </span>
                    </div>
                    <p class="font-impact text-2xl sm:text-4xl text-white tracking-widest animate-pulse mt-2">
                        📞 346 6424053
                    </p>
                    <p class="text-xs uppercase text-gray-400 font-bold tracking-wider pt-2">
                        Contattaci su WhatsApp o telefonicamente per iscrivere singoli giocatori o squadre complete!
                    </p>
                </div>
            </div>
        </section>
    </div>
</template>

<style scoped>
.public-panel-enter-active,
.public-panel-leave-active {
    transition:
        opacity 220ms var(--ease-organic),
        transform 220ms var(--ease-organic);
}

.public-panel-enter-from,
.public-panel-leave-to {
    opacity: 0;
    transform: translateY(8px) scale(0.99);
}
</style>
