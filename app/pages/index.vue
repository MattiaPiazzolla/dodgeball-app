// app/pages/index.vue
<script setup lang="ts">
import { ref, computed, watch, onMounted, onBeforeUnmount, defineAsyncComponent } from "vue";
import { useRoute } from "vue-router";
import { useNavbarState } from "~/composables/useNavbarState";
import { useMatchRealtime } from "~/composables/useMatchRealtime";

const { activeSection, registrationsOpen, showNavbarTabs, hideNavbar } = useNavbarState();

const sections = [
    { id: "live", label: "LIVE IN CORSO", icon: "mdi:access-point" },
    { id: "schedule", label: "CALENDARIO GARE", icon: "mdi:calendar-clock" },
    { id: "teams", label: "SQUADRE ISCRITTE", icon: "mdi:shield-account" },
];

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
const { subscribeToAllMatches, unsubscribe } = useMatchRealtime();
const matches = ref<any[]>([]);
const teams = ref<any[]>([]);
let realtimeChannel: any = null;

const tournamentFinaleMatch = computed(() => {
    const knockoutMatches = matches.value.filter((m) => m.match_type === "knockout");
    if (knockoutMatches.length === 0) return null;
    const maxRound = Math.max(...knockoutMatches.map((m) => m.round || 0));
    const finales = knockoutMatches.filter(m => m.round === maxRound);
    return finales.length > 0 ? finales[0] : null;
});

const isFinaleLive = computed(() => {
    const finale = tournamentFinaleMatch.value;
    return finale && finale.status === "in_progress";
});

const isTournamentOver = computed(() => {
    const finale = tournamentFinaleMatch.value;
    return finale && (finale.status === 'completed' || finale.status === 'finished');
});

const tournamentWinner = computed(() => {
    const finale = tournamentFinaleMatch.value;
    if (!finale || !finale.winner_id) return null;
    return teams.value.find(t => t.id === finale.winner_id);
});

const winningPlayers = ref<any[]>([]);

watch(tournamentWinner, async (winner) => {
    if (winner) {
        const { data: pData } = await client
            .from("players")
            .select("*")
            .eq("team_id", winner.id)
            .order("jersey_number", { ascending: true });
        if (pData) {
            winningPlayers.value = pData;
        }
    }
}, { immediate: true });

watch(isTournamentOver, (isOver) => {
    if (isOver) {
        triggerFireworks();
    }
}, { immediate: true });

const winnerSectionRef = ref<HTMLElement | null>(null);
let winnerObserver: IntersectionObserver | null = null;

watch([registrationsOpen, isTournamentOver, tournamentWinner], ([regOpen, isOver, winner]) => {
    if (!(!regOpen && isOver && winner)) {
        hideNavbar.value = false;
    }
}, { immediate: true });

watch(winnerSectionRef, (el) => {
    if (typeof window === 'undefined' || !("IntersectionObserver" in window)) return;
    
    if (winnerObserver) {
        winnerObserver.disconnect();
    }
    
    if (el) {
        winnerObserver = new IntersectionObserver(
            ([entry]) => {
                hideNavbar.value = entry.isIntersecting;
            },
            { threshold: 0.1 }
        );
        winnerObserver.observe(el);
    }
}, { immediate: true });

onBeforeUnmount(() => {
    hideNavbar.value = false;
    if (winnerObserver) {
        winnerObserver.disconnect();
    }
});

const triggerFireworks = async () => {
    if (typeof window === 'undefined') return;
    const confettiModule = await import('canvas-confetti');
    const confetti = confettiModule.default || confettiModule;

    const duration = 15 * 1000;
    const animationEnd = Date.now() + duration;
    const defaults = { startVelocity: 30, spread: 360, ticks: 60, zIndex: 100 };

    const interval: any = setInterval(function() {
        const timeLeft = animationEnd - Date.now();
        if (timeLeft <= 0) return clearInterval(interval);
        const particleCount = 50 * (timeLeft / duration);
        confetti(Object.assign({}, defaults, { particleCount, origin: { x: Math.random(), y: Math.random() - 0.2 } }));
    }, 250);
};

const scatterX = [
    "clamp(-350px, -30vw, -80px)",
    "clamp(80px, 30vw, 350px)",
    "clamp(-280px, -25vw, -90px)",
    "clamp(90px, 25vw, 280px)",
    "clamp(-180px, -15vw, -50px)",
    "clamp(50px, 15vw, 180px)"
];
const scatterY = [
    "clamp(-200px, -20vw, -120px)",
    "clamp(-180px, -18vw, -100px)",
    "clamp(-20px, 0vw, 20px)",
    "clamp(-10px, 0vw, 30px)",
    "clamp(120px, 25vw, 250px)",
    "clamp(100px, 22vw, 220px)"
];
const scatterRot = [
    "-15deg", "12deg", "-8deg", "18deg", "-22deg", "10deg"
];

const tabsContainer = ref<HTMLElement | null>(null);
let observer: IntersectionObserver | null = null;

const fetchSettings = async () => {
    const { data } = await client.from("app_settings").select("registrations_open").eq("id", 1).single();
    if (data) {
        registrationsOpen.value = data.registrations_open;
    }
};

watch(tabsContainer, (newContainer) => {
    if (newContainer && typeof window !== "undefined" && "IntersectionObserver" in window) {
        if (observer) {
            observer.disconnect();
        }
        observer = new IntersectionObserver(
            ([entry]) => {
                if (window.innerWidth < 640 && !registrationsOpen.value) {
                    const isPast = !entry.isIntersecting && entry.boundingClientRect.top < 80;
                    showNavbarTabs.value = isPast;
                } else {
                    showNavbarTabs.value = false;
                }
            },
            {
                threshold: 0,
                rootMargin: "-72px 0px 0px 0px",
            }
        );
        observer.observe(newContainer);
    }
}, { immediate: true });

onMounted(async () => {
    fetchSettings();
    applyHash(window.location.hash);

    const { data: mData } = await client.from("matches").select("id, match_type, round, status, winner_id");
    if (mData) matches.value = mData;

    const { data: tData } = await client.from("teams").select("id, name, logo_url");
    if (tData) teams.value = tData;

    realtimeChannel = subscribeToAllMatches((payload) => {
        const changedMatch = payload.new || payload.old;
        if (!changedMatch?.id) return;
        if (payload.eventType === "DELETE") {
            matches.value = matches.value.filter((m) => m.id !== changedMatch.id);
        } else {
            const index = matches.value.findIndex((m) => m.id === changedMatch.id);
            if (index !== -1) matches.value[index] = { ...matches.value[index], ...changedMatch };
            else matches.value.push(changedMatch);
        }
    });
});

onBeforeUnmount(() => {
    if (observer) {
        observer.disconnect();
    }
    showNavbarTabs.value = false;
    if (realtimeChannel) unsubscribe(realtimeChannel);
});
</script>

<template>
    <div class="min-h-screen selection:bg-primary selection:text-white transition-colors duration-1000"
         :class="isFinaleLive ? 'bg-[#111111] text-gray-200' : 'bg-cement'">

        <!-- SECTION 1: HERO -->
        <section
            v-if="registrationsOpen"
            id="hero"
            class="relative bg-[#111111] text-white overflow-hidden min-h-[90vh] flex flex-col items-center justify-end pb-16 sm:pb-24"
        >
            <!-- Portrait: large, centered, fills upper portion -->
            <div class="absolute inset-0 flex items-center justify-center pointer-events-none" aria-hidden="true">
                <img
                    src="/dodgeballxl-logo.PNG"
                    alt=""
                    class="hero-portrait-img"
                />
            </div>

            <!-- Single gradient: transparent top → solid bottom, so text is always readable -->
            <div class="absolute inset-0 bg-gradient-to-t from-[#111111] via-[#111111]/80 to-transparent pointer-events-none z-[1]"></div>

            <!-- Text content: anchored to bottom -->
            <div class="relative z-10 w-full max-w-2xl mx-auto px-6 text-center space-y-4 mobile-fade-in">
                <p class="font-impact text-xs sm:text-sm tracking-[0.3em] text-primary uppercase">
                    Torneo Ufficiale 2026
                </p>

                <h1 class="font-impact leading-none select-none text-white hero-title">
                    DODGEBALL <span class="text-primary italic">XL</span>
                </h1>

                <p class="font-impact text-sm sm:text-xl text-gray-400 tracking-[0.22em]">
                    MEMORIAL LORIS PASSERI
                </p>

                <div class="pt-4 flex flex-col sm:flex-row items-center justify-center gap-3">
                    <NuxtLink to="/login" class="btn-skewed w-full sm:w-auto">
                        <span class="btn-skewed-content">Iscrivi la Squadra</span>
                    </NuxtLink>
                    <a href="#info_torneo" class="btn-outline-white w-full sm:w-auto">
                        <span class="btn-skewed-content">Scopri il Programma</span>
                    </a>
                </div>
            </div>
        </section>

        <!-- SECTION 2: INFO TORNEO (Theme: Light, Background: #F4F4F2) -->
        <section
            v-if="registrationsOpen"
            id="info_torneo"
            class="py-16 sm:py-24 px-4 transition-colors duration-1000"
            :class="isFinaleLive ? 'bg-zinc-900' : 'bg-cement'"
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

        <!-- TOURNAMENT WINNER SHOWCASE -->
        <section
            v-if="!registrationsOpen && isTournamentOver && tournamentWinner"
            id="winner-showcase"
            ref="winnerSectionRef"
            class="relative bg-black text-white overflow-hidden min-h-[70vh] flex flex-col items-center justify-center py-16 sm:py-24 border-b-4 border-yellow-400"
        >
            <div class="absolute inset-0 flex items-center justify-center pointer-events-none opacity-20" aria-hidden="true">
                <div class="w-full h-full bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-yellow-500/40 via-black to-black"></div>
            </div>

            <!-- Custom Brand Header for Winner Section -->
            <div class="absolute top-0 left-0 w-full p-6 sm:p-8 flex justify-center items-center z-50 animate-fade-in-down pointer-events-none">
                <div class="font-impact tracking-wider text-white flex items-center gap-3 select-none">
                    <img src="/dodgeballxl-logo.PNG" alt="Dodgeball XL Logo" class="h-8 sm:h-12 w-auto object-contain flex-shrink-0 drop-shadow-[0_0_15px_rgba(250,204,21,0.4)] filter brightness-0 invert" />
                    <span class="inline-block text-xl sm:text-3xl">
                        DODGEBALL <span class="bg-primary text-white px-2 py-0.5 border-2 border-yellow-400 inline-block transform -skew-x-12 shadow-[3px_3px_0px_rgba(250,204,21,1)] text-xs sm:text-lg relative -top-0.5">XL</span>
                    </span>
                </div>
            </div>

            <div class="relative z-10 w-full max-w-3xl mx-auto px-6 text-center space-y-8 animate-fade-in-up mt-12 sm:mt-0">
                <p class="font-impact text-xl sm:text-3xl tracking-[0.3em] text-yellow-400 uppercase drop-shadow-[0_0_10px_rgba(250,204,21,0.8)]">
                    I Campioni
                </p>

                <div class="flex flex-col items-center w-full">
                    <!-- Scattered Polaroid Layout -->
                    <div class="relative w-full min-h-[350px] sm:min-h-[700px] flex items-center justify-center mx-auto my-8">
                        <!-- Winner Logo in Center -->
                        <div class="absolute w-28 h-28 sm:w-64 sm:h-64 rounded-full bg-white border-4 border-yellow-400 flex items-center justify-center shadow-[0_0_40px_rgba(250,204,21,0.8)] sm:shadow-[0_0_60px_rgba(250,204,21,0.8)] overflow-hidden z-20 animate-pulse">
                            <img 
                                v-if="tournamentWinner.logo_url" 
                                :src="tournamentWinner.logo_url" 
                                class="w-full h-full object-cover" 
                            />
                            <div v-else class="w-full h-full bg-zinc-800 flex items-center justify-center">
                                <Icon name="mdi:trophy" class="text-5xl sm:text-8xl text-yellow-400 drop-shadow-md" />
                            </div>
                        </div>

                        <!-- Scattered Polaroids -->
                        <div v-if="winningPlayers.length" class="absolute inset-0 flex items-center justify-center">
                            <div 
                                v-for="(player, idx) in winningPlayers" 
                                :key="player.id"
                                class="absolute z-10 flex flex-col items-center bg-white p-1.5 sm:p-3 pb-3 sm:pb-6 shadow-[0_10px_20px_rgba(0,0,0,0.6)] sm:shadow-[0_15px_35px_rgba(0,0,0,0.6)] border border-zinc-200 cursor-pointer transition-transform duration-500 hover:scale-[1.4] sm:hover:scale-125 hover:z-50"
                                :style="{
                                    transform: `translate(${scatterX[idx % scatterX.length]}, ${scatterY[idx % scatterY.length]}) rotate(${scatterRot[idx % scatterRot.length]})`
                                }"
                            >
                                <div class="w-16 h-16 sm:w-40 sm:h-40 bg-zinc-200 overflow-hidden border border-zinc-300 flex items-center justify-center mb-1.5 sm:mb-4 shadow-inner">
                                    <img v-if="player.photo_url" :src="player.photo_url" class="w-full h-full object-cover grayscale-[20%] contrast-125" />
                                    <Icon v-else name="mdi:account" class="text-3xl sm:text-7xl text-zinc-400" />
                                </div>

                                <div class="flex flex-col items-center w-full px-1">
                                    <div class="text-black font-impact text-[11px] sm:text-xl tracking-widest uppercase text-center leading-none">
                                        {{ player.name }}
                                    </div>
                                    <div class="text-zinc-500 font-bold text-[9px] sm:text-base mt-0.5 sm:mt-1 font-mono">
                                        N° {{ player.jersey_number || '-' }}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <h2 class="font-impact leading-none text-5xl sm:text-8xl text-white uppercase break-words text-center w-full px-4 drop-shadow-[4px_4px_0_rgba(250,204,21,1)] mt-8 z-30 relative">
                        {{ tournamentWinner.name }}
                    </h2>
                </div>

                <div class="pt-8">
                    <button @click="triggerFireworks" class="bg-yellow-400 text-black font-impact text-lg px-8 py-3 transform -skew-x-6 hover:scale-105 transition-transform border-2 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]">
                        CELEBRA LA VITTORIA
                    </button>
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
                <div class="flex items-center justify-center gap-4 transition-colors duration-1000">
                    <div class="h-1 flex-grow" :class="isFinaleLive ? 'bg-yellow-400' : 'bg-black'"></div>
                    <div class="font-impact text-2xl sm:text-4xl px-4 tracking-widest whitespace-nowrap transition-all duration-1000"
                         :class="isFinaleLive ? 'bg-[#111111] text-yellow-400 text-3xl sm:text-5xl drop-shadow-[0_0_15px_rgba(250,204,21,0.5)] scale-110' : 'bg-cement text-black'">
                        {{ isFinaleLive ? 'LA GRANDE FINALE!' : 'LIVE & RISULTATI' }}
                    </div>
                    <div class="h-1 flex-grow" :class="isFinaleLive ? 'bg-yellow-400' : 'bg-black'"></div>
                </div>

                <!-- Redesigned Grunge Dashboard Tab Controls -->
                <div ref="tabsContainer" class="flex flex-col sm:flex-row justify-center items-stretch gap-2 w-full max-w-2xl mx-auto">
                    <button
                        v-for="section in sections"
                        :key="section.id"
                        type="button"
                        @click="scrollToSection(section.id)"
                        class="flex-1 flex items-center justify-center gap-2 py-3 px-4 text-xs font-impact tracking-widest transition-all cursor-pointer border-2"
                        :class="[
                            isFinaleLive ? 'border-yellow-400' : 'border-black',
                            activeSection === section.id
                                ? (isFinaleLive ? 'bg-yellow-400 text-black shadow-[3px_3px_0px_rgba(250,204,21,0.5)] -translate-y-0.5' : 'bg-black text-white shadow-[3px_3px_0px_rgba(0,0,0,1)] -translate-y-0.5')
                                : (isFinaleLive ? 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700 shadow-none' : 'bg-white text-secondary hover:bg-gray-100 shadow-[1px_1px_0px_rgba(0,0,0,1)]')
                        ]"
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

        <!-- SECTION 4: DETAILS FOOTER / EVENT BADGE -->
        <section
            v-if="registrationsOpen"
            id="details_footer"
            class="relative text-white text-center overflow-hidden"
        >
            <!-- Smooth gradient fade from cement page into dark footer -->
            <div class="h-24 sm:h-32 bg-gradient-to-b from-[#F4F4F2] to-secondary"></div>

            <!-- Main dark content area — same bg as layout footer -->
            <div class="bg-secondary px-4 pt-8 pb-8">
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

                    <!-- Contact Info -->
                    <div class="space-y-4 max-w-md mx-auto">
                        <div class="bg-primary/20 border-2 border-primary/50 py-3 px-6 transform skew-x-3 inline-block">
                            <span class="font-impact text-primary text-base sm:text-xl tracking-widest block">
                                INFO - ISMA
                            </span>
                        </div>
                        <div class="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-8">
                            <a href="tel:3466424053" class="flex items-center text-white hover:text-primary text-2xl sm:text-3xl font-bold">
                                <Icon name="mdi:phone" class="mr-2 text-3xl sm:text-4xl" /> Call
                            </a>
                            <a href="https://wa.me/3466424053" target="_blank" rel="noopener" class="flex items-center text-white hover:text-primary text-2xl sm:text-3xl font-bold">
                                <Icon name="mdi:whatsapp" class="mr-2 text-3xl sm:text-4xl" /> WhatsApp
                            </a>
                        </div>
                        <p class="text-xs uppercase text-gray-400 font-bold tracking-wider pt-2">
                            Contattaci su WhatsApp o telefonicamente per iscrivere singoli giocatori o squadre complete!
                        </p>
                    </div>
                </div>
            </div>
        </section>
    </div>
</template>

<style scoped>
/* Portrait — large, inverted to white, bottom edge fades into gradient */
.hero-portrait-img {
    height: 80vh;
    max-height: 640px;
    width: auto;
    object-fit: contain;
    filter: invert(1);
    opacity: 0.6;
    -webkit-mask-image: linear-gradient(to bottom, black 30%, black 55%, transparent 88%);
    mask-image: linear-gradient(to bottom, black 30%, black 55%, transparent 88%);
    pointer-events: none;
    user-select: none;
}

/* Hero title responsive size */
.hero-title {
    font-size: clamp(3.5rem, 10vw, 7rem);
    line-height: 0.95;
}

/* Panel transitions */
.public-panel-enter-active,
.public-panel-leave-active {
    transition:
        opacity 0.3s ease,
        transform 0.3s ease;
}
.public-panel-enter-from,
.public-panel-leave-to {
    opacity: 0;
    transform: translateY(10px);
}

</style>
