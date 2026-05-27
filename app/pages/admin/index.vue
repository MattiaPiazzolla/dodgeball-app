// app/pages/admin/index.vue
<script setup lang="ts">
definePageMeta({ middleware: ["admin"] });
const client = useSupabaseClient();

const teams = ref<any[]>([]);
const matches = ref<any[]>([]);
const topMvpPlayers = ref<any[]>([]);
const registrationsOpen = ref(true);
const isLoading = ref(true);

const mvpSearchQuery = ref("");
const mvpTeamFilter = ref("");
const isConfirmingReset = ref(false);
const isMvpPodiumOpen = ref(false);
const isTeamsAccordionOpen = ref(false);
let playerSubscription: any = null;

const fetchAll = async () => {
    const [
        { data: teamsData },
        { data: matchesData },
        { data: mvpData },
        { data: settingsData },
    ] = await Promise.all([
            client
                .from("teams")
                .select("*")
                .order("created_at", { ascending: false }),
            client
                .from("matches")
                .select("*")
                .order("start_time", { ascending: true }),
            client
                .from("players")
                .select(
                    "id, name, jersey_number, photo_url, mvp_votes, team_id",
                )
                .order("mvp_votes", { ascending: false })
                .order("name", { ascending: true }),
            client
                .from("app_settings")
                .select("registrations_open")
                .eq("id", 1)
                .single(),
        ]);
    teams.value = teamsData || [];
    matches.value = matchesData || [];
    topMvpPlayers.value = mvpData || [];
    registrationsOpen.value = settingsData?.registrations_open ?? true;
    isLoading.value = false;
};

const refetchMvp = async () => {
    const { data } = await client
        .from("players")
        .select("id, name, jersey_number, photo_url, mvp_votes, team_id")
        .order("mvp_votes", { ascending: false })
        .order("name", { ascending: true });
    topMvpPlayers.value = data || [];
};

const filteredMvpPlayers = computed(() => {
    return topMvpPlayers.value.filter((player) => {
        const matchesSearch = !mvpSearchQuery.value ||
            player.name.toLowerCase().includes(mvpSearchQuery.value.toLowerCase()) ||
            (player.nickname && player.nickname.toLowerCase().includes(mvpSearchQuery.value.toLowerCase()));
        const matchesTeam = !mvpTeamFilter.value || player.team_id === mvpTeamFilter.value;
        return matchesSearch && matchesTeam;
    });
});

const resetMvpVotes = async () => {
    const { error } = await client
        .from("players")
        .update({ mvp_votes: 0 })
        .gt("mvp_votes", 0);
    if (error) {
        alert("Impossibile azzerare i voti MVP: " + error.message);
    } else {
        isConfirmingReset.value = false;
        await refetchMvp();
    }
};

const approvedTeams = computed(() =>
    teams.value.filter((t) => t.status === "approved"),
);
const pendingTeams = computed(() =>
    teams.value.filter((t) => t.status === "pending"),
);
const rejectedTeams = computed(() =>
    teams.value.filter((t) => t.status === "rejected"),
);

// Stats
const totalMatches = computed(() => matches.value.length);
const completedMatches = computed(
    () => matches.value.filter((m) => m.status === "completed").length,
);
const pendingMatches = computed(
    () => matches.value.filter((m) => m.status === "pending").length,
);

// Knockout Stage Check
const isGroupStageComplete = computed(() => {
    if (matches.value.length === 0) return false;
    const groupMatches = matches.value.filter((m) => m.match_type === "group");
    if (groupMatches.length === 0) return false;
    // Check if every single group match is either completed or retired
    return groupMatches.every((m) =>
        ["completed", "retired"].includes(m.status),
    );
});

const hasKnockoutMatches = computed(() => {
    return matches.value.some((m) => m.match_type === "knockout");
});

// Next match: first pending match with a start_time
const nextMatch = computed(
    () =>
        matches.value.find((m) => m.status === "pending" && m.start_time) ||
        null,
);

const getTeamName = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.name || (id ? "Unknown" : "TBD");
const getTeamLogo = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.logo_url || null;

const formatTime = (t: string | null) => {
    if (!t) return "TBD";
    return t.slice(0, 5);
};

const setStatus = async (
    id: string,
    status: "approved" | "rejected" | "pending",
) => {
    await client
        .from("teams")
        .update({ status, is_approved: status === "approved" })
        .eq("id", id);
    await fetchAll();
};

const confirmingDeleteId = ref<string | null>(null);

const subscribeToMvpChanges = () => {
    playerSubscription = client
        .channel("admin_live_mvp")
        .on(
            "postgres_changes",
            { event: "*", schema: "public", table: "players" },
            () => {
                refetchMvp();
            }
        )
        .subscribe();
};

onMounted(async () => {
    await fetchAll();
    subscribeToMvpChanges();
});

onBeforeUnmount(() => {
    if (playerSubscription) {
        client.removeChannel(playerSubscription);
    }
});

const toggleRegistrations = async () => {
    const nextValue = !registrationsOpen.value;
    registrationsOpen.value = nextValue;

    const { error } = await client
        .from("app_settings")
        .update({ registrations_open: nextValue })
        .eq("id", 1);

    if (error) {
        registrationsOpen.value = !nextValue;
        alert("Impossibile aggiornare le iscrizioni: " + error.message);
    }
};

const translateStage = (stage: string) => {
    if (!stage) return "";
    const lower = stage.toLowerCase();
    if (lower === "group") return "Girone";
    if (lower === "knockout") return "Eliminazione Diretta";
    return stage;
};
</script>
<template>
    <div class="max-w-6xl mx-auto px-4 py-5 sm:py-8 space-y-6 sm:space-y-10 mobile-fade-in">
        <div
            v-if="isLoading"
            class="flex items-center justify-center py-24 text-primary"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <section
                v-if="isGroupStageComplete && !hasKnockoutMatches"
                class="animate-in fade-in slide-in-from-bottom-4 duration-500"
            >
                <div
                    class="card-grunge !bg-primary border-4 border-black p-8 sm:p-10 relative overflow-hidden flex flex-col md:flex-row items-center justify-between gap-8"
                >
                    <Icon
                        name="mdi:tournament"
                        class="absolute -right-8 -bottom-12 text-[200px] text-white opacity-10 pointer-events-none"
                    />

                    <div
                        class="relative z-10 text-center md:text-left text-white space-y-3"
                    >
                        <div
                            class="flex items-center justify-center md:justify-start gap-2 text-yellow-300 font-impact uppercase tracking-widest text-sm"
                        >
                            <Icon name="mdi:check-decagram" class="text-lg" />
                            Fase a Gironi Completata
                        </div>
                        <h2
                            class="text-3xl sm:text-5xl font-impact uppercase tracking-widest leading-none text-white"
                        >
                            Pronto per il Sorteggio
                        </h2>
                        <p class="text-gray-200 font-bold uppercase tracking-wider max-w-md text-sm leading-normal">
                            Tutti gli incontri della fase a gironi sono stati risolti. Ora puoi
                            generare il tabellone a eliminazione diretta.
                        </p>
                    </div>

                    <div class="relative z-10 w-full md:w-auto">
                        <NuxtLink
                            to="/admin/matches"
                            class="flex items-center justify-center gap-3 w-full md:w-auto px-8 py-5 bg-white text-primary border-4 border-black font-impact uppercase tracking-widest hover:bg-black hover:text-white hover:border-white transition-all shadow-[6px_6px_0px_rgba(0,0,0,1)] hover:-translate-y-1 transform -skew-x-6 active:scale-95"
                        >
                            <Icon name="mdi:whistle" class="text-xl transform skew-x-6 block" />
                            <span class="transform skew-x-6 block">Genera Tabellone</span>
                        </NuxtLink>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-lg font-impact uppercase tracking-widest text-secondary mb-4 border-b-4 border-black inline-block pr-4"
                >
                    Pannello di Controllo
                </h2>
                <div class="grid grid-cols-1 min-[420px]:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
                    <div
                        class="card-grunge bg-white p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-impact uppercase tracking-widest text-secondary"
                            >Squadre Approvate</span
                        >
                        <span class="text-5xl font-impact text-black">{{
                            approvedTeams.length
                        }}</span>
                    </div>
                    <div
                        class="card-grunge bg-white p-5 flex flex-col gap-1 relative overflow-hidden"
                    >
                        <span
                            class="text-xs font-impact uppercase tracking-widest text-secondary"
                            >Richieste in Sospeso</span
                        >
                        <span
                            class="text-5xl font-impact"
                            :class="
                                pendingTeams.length > 0
                                    ? 'text-primary'
                                    : 'text-black'
                            "
                            >{{ pendingTeams.length }}</span
                        >
                        <div
                            v-if="pendingTeams.length > 0"
                            class="absolute top-3 right-3 w-3 h-3 bg-primary animate-ping"
                        ></div>
                        <div
                            v-if="pendingTeams.length > 0"
                            class="absolute top-3 right-3 w-3 h-3 bg-primary border-2 border-black"
                        ></div>
                    </div>
                    <div
                        class="card-grunge bg-white p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-impact uppercase tracking-widest text-secondary"
                            >Incontri Totali</span
                        >
                        <span class="text-5xl font-impact text-black">{{
                            totalMatches
                        }}</span>
                        <span class="text-xs text-secondary font-bold uppercase tracking-widest"
                            >{{ completedMatches }} completati</span
                        >
                    </div>
                    <div
                        class="card-grunge bg-white p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-impact uppercase tracking-widest text-secondary"
                            >Incontri Programmati</span
                        >
                        <span class="text-5xl font-impact text-black">{{
                            pendingMatches
                        }}</span>
                        <span class="text-xs text-secondary font-bold uppercase tracking-widest"
                            >in attesa</span
                        >
                    </div>
                </div>
            </section>

            <section>
                <div
                    class="card-grunge bg-white p-5 sm:p-8 flex flex-col sm:flex-row sm:items-center justify-between gap-6"
                >
                    <div>
                        <h2
                            class="text-lg font-impact uppercase tracking-widest text-secondary mb-2"
                        >
                            Iscrizioni capitani
                        </h2>
                        <p class="text-2xl font-impact text-black uppercase mt-1">
                            {{
                                registrationsOpen
                                    ? "NUOVI ACCOUNT APERTI"
                                    : "NUOVI ACCOUNT CHIUSI"
                            }}
                        </p>
                        <p class="text-sm text-secondary font-bold uppercase tracking-widest mt-2">
                            Quando sono chiuse, il pulsante di registrazione non
                            appare nel portale capitano.
                        </p>
                    </div>
                    <button
                        @click="toggleRegistrations"
                        class="relative w-20 h-10 border-4 border-black transition-colors shrink-0 active:scale-[0.98] shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                        :class="registrationsOpen ? 'bg-green-400' : 'bg-gray-200'"
                        :aria-pressed="registrationsOpen"
                        title="Apri o chiudi iscrizioni"
                    >
                        <span
                            class="absolute top-[2px] w-7 h-7 bg-white border-[3px] border-black transition-transform"
                            :class="
                                registrationsOpen
                                    ? 'translate-x-10 left-1'
                                    : 'translate-x-0 left-1'
                            "
                        ></span>
                    </button>
                </div>
            </section>

            <section v-if="nextMatch">
                <h2
                    class="text-lg font-impact uppercase tracking-widest text-secondary mb-4 border-b-4 border-black inline-block pr-4"
                >
                    Prossimo Incontro
                </h2>
                <div
                    class="card-grunge bg-black text-white p-5 sm:p-8 grid grid-cols-1 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center justify-between gap-5 sm:gap-6"
                >
                    <div class="flex items-center gap-4 min-w-0 w-full">
                        <div class="w-16 h-16 bg-white border-4 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                            <img
                                v-if="getTeamLogo(nextMatch.team1_id)"
                                :src="getTeamLogo(nextMatch.team1_id)"
                                class="w-full h-full object-cover"
                            />
                            <Icon
                                v-else
                                name="mdi:shield"
                                class="text-3xl text-secondary"
                            />
                        </div>
                        <span
                            class="text-xl sm:text-3xl font-impact uppercase tracking-widest truncate"
                            >{{ getTeamName(nextMatch.team1_id) }}</span
                        >
                    </div>
                    <div class="flex flex-col items-center gap-2 flex-shrink-0">
                        <span class="text-4xl font-impact text-primary">VS</span>
                        <span
                            class="text-sm font-impact text-white uppercase tracking-widest"
                            >{{ formatTime(nextMatch.start_time) }}</span
                        >
                        <span
                            class="text-xs font-impact px-3 py-1 uppercase tracking-widest border-2 border-white"
                            :class="
                                nextMatch.match_type === 'knockout'
                                    ? 'bg-primary text-white'
                                    : 'bg-secondary text-white'
                            "
                        >
                            {{ translateStage(nextMatch.match_type) }}
                        </span>
                    </div>
                    <div class="flex items-center gap-4 min-w-0 w-full justify-end">
                        <span
                            class="text-xl sm:text-3xl font-impact uppercase tracking-widest text-right truncate"
                            >{{
                                getTeamName(nextMatch.team2_id)
                            }}</span
                        >
                        <div class="w-16 h-16 bg-white border-4 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                            <img
                                v-if="getTeamLogo(nextMatch.team2_id)"
                                :src="getTeamLogo(nextMatch.team2_id)"
                                class="w-full h-full object-cover"
                            />
                            <Icon
                                v-else
                                name="mdi:shield"
                                class="text-3xl text-secondary"
                            />
                        </div>
                    </div>
                </div>
            </section>

            <section v-if="!registrationsOpen">
                <!-- Title & Conditional Reset Flex Header -->
                <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-4">
                    <h2
                        class="text-lg font-impact uppercase tracking-widest text-secondary border-b-4 border-black inline-block pr-4 self-start"
                    >
                        Classifica MVP in Diretta (Voti Tempo Reale)
                    </h2>
                    
                    <!-- Reset Button - Only appears when group stage is completed -->
                    <div v-if="isGroupStageComplete" class="flex items-center gap-2 shrink-0">
                        <template v-if="isConfirmingReset">
                            <span class="text-xs font-impact text-red-600 uppercase tracking-widest animate-pulse">Sei sicuro?</span>
                            <button
                                @click="resetMvpVotes"
                                class="btn-skewed px-3 py-1.5 !text-xs !bg-red-600"
                            >
                                <span class="btn-skewed-content">Sì, Azzera Voti</span>
                            </button>
                            <button
                                @click="isConfirmingReset = false"
                                class="btn-skewed-secondary px-3 py-1.5 !text-xs"
                            >
                                <span class="btn-skewed-content">Annulla</span>
                            </button>
                        </template>
                        <template v-else>
                            <button
                                @click="isConfirmingReset = true"
                                class="btn-skewed-secondary !border-red-600 !text-red-600 hover:!bg-red-600 hover:!text-white px-3 py-1.5 !text-xs flex items-center gap-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                                title="Azzera tutti i voti MVP dei giocatori"
                            >
                                <Icon name="mdi:refresh" class="text-sm" />
                                <span class="btn-skewed-content">Azzera Voti per Eliminatorie</span>
                            </button>
                        </template>
                    </div>
                </div>

                <!-- Grunge Filters Panel -->
                <div class="card-grunge bg-zinc-100 p-4 mb-6 flex flex-col md:flex-row gap-4 border-4 border-black">
                    <div class="flex-1 relative">
                        <span class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <Icon name="mdi:magnify" class="text-zinc-500 text-xl" />
                        </span>
                        <input
                            v-model="mvpSearchQuery"
                            type="text"
                            placeholder="CERCA GIOCATORE..."
                            class="w-full pl-10 pr-4 py-2 border-2 border-black bg-white font-impact uppercase tracking-widest text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-black transition-all"
                        />
                    </div>
                    <div class="w-full md:w-64 relative">
                        <span class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                            <Icon name="mdi:filter-outline" class="text-zinc-500 text-xl" />
                        </span>
                        <select
                            v-model="mvpTeamFilter"
                            class="w-full pl-10 pr-10 py-2 border-2 border-black bg-white font-impact uppercase tracking-widest text-sm focus:outline-none focus:ring-2 focus:ring-primary focus:border-black appearance-none transition-all cursor-pointer"
                        >
                            <option value="">TUTTE LE SQUADRE</option>
                            <option v-for="team in approvedTeams" :key="team.id" :value="team.id">
                                {{ team.name.toUpperCase() }}
                            </option>
                        </select>
                        <span class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                            <Icon name="mdi:chevron-down" class="text-zinc-500 text-xl" />
                        </span>
                    </div>
                </div>

                <!-- Ranking Roster Card -->
                <div
                    class="card-grunge bg-white p-6 min-[520px]:p-8 overflow-hidden"
                >
                    <div
                        v-if="filteredMvpPlayers.length === 0"
                        class="py-12 text-center text-gray-400 font-impact uppercase tracking-widest text-lg"
                    >
                        Nessun candidato trovato con i filtri attuali.
                    </div>
                    <div v-else>
                        <!-- Scrollable Container Wrapper with Custom Scrollbar -->
                        <div class="max-h-[500px] overflow-y-auto pr-2 space-y-3 custom-scrollbar">
                            <div
                                v-for="(player, idx) in filteredMvpPlayers"
                                :key="player.id"
                                class="card-grunge bg-white flex flex-col sm:flex-row sm:items-center justify-between gap-4 px-4 sm:px-6 py-4 hover:-translate-y-0.5 transition-transform mb-4 border-4 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                            >
                                <div class="flex items-center gap-3 sm:gap-4 min-w-0">
                                    <!-- Position Badge -->
                                    <span
                                        class="font-impact text-2xl w-10 h-10 flex items-center justify-center border-2 border-black shrink-0 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                                        :class="{
                                            'bg-yellow-400 text-black': idx === 0,
                                            'bg-slate-300 text-black': idx === 1,
                                            'bg-amber-600 text-white': idx === 2,
                                            'bg-zinc-100 text-zinc-500': idx > 2
                                        }"
                                    >
                                        {{ idx + 1 }}
                                    </span>
                                    
                                    <!-- Player Photo / Grunge Shield Fallback -->
                                    <div class="relative flex-shrink-0">
                                        <img
                                            v-if="player.photo_url"
                                            :src="player.photo_url"
                                            class="w-14 h-14 rounded-none object-cover border-2 border-black bg-white flex-shrink-0"
                                        />
                                        <div
                                            v-else
                                            class="w-14 h-14 rounded-none bg-zinc-200 border-2 border-black flex items-center justify-center flex-shrink-0 relative overflow-hidden"
                                        >
                                            <div class="absolute inset-0 opacity-10 bg-[radial-gradient(#000_1px,transparent_1px)] [background-size:8px_8px]"></div>
                                            <span class="font-impact text-zinc-600 text-lg uppercase tracking-wider">
                                                {{ player.name.slice(0, 2) }}
                                            </span>
                                        </div>
                                        
                                        <!-- Dynamic Miniature Team Logo Indicator -->
                                        <div 
                                            v-if="getTeamLogo(player.team_id)"
                                            class="absolute -bottom-1 -right-1 w-6 h-6 border-2 border-black bg-white flex items-center justify-center overflow-hidden shadow-[1px_1px_0px_rgba(0,0,0,1)]"
                                            :title="getTeamName(player.team_id)"
                                        >
                                            <img :src="getTeamLogo(player.team_id)" class="w-full h-full object-cover" />
                                        </div>
                                    </div>
                                    
                                    <div class="min-w-0">
                                        <div class="flex flex-wrap items-baseline gap-2 min-w-0">
                                            <span
                                                class="font-impact uppercase tracking-widest text-black text-xl truncate"
                                                >{{ player.name }}</span
                                            >
                                            <span
                                                v-if="player.nickname"
                                                class="text-xs text-primary font-bold italic"
                                                >"{{ player.nickname }}"</span
                                            >
                                        </div>
                                        <span
                                            class="text-xs text-zinc-600 font-impact uppercase tracking-wider block mt-0.5"
                                        >
                                            N°{{ player.jersey_number || "00" }} —
                                            {{ getTeamName(player.team_id) }}
                                        </span>
                                    </div>
                                </div>

                                <!-- Read-only Vote Display Badge -->
                                <div
                                    class="bg-black px-4 py-2 border-2 border-black font-impact text-white text-base flex items-center gap-2 shadow-[3px_3px_0px_rgba(0,0,0,1)] min-w-[110px] justify-center shrink-0 self-end sm:self-auto"
                                >
                                    <Icon
                                        name="mdi:thumb-up"
                                        class="text-primary text-sm animate-pulse"
                                    />
                                    <span>{{ player.mvp_votes }} {{ player.mvp_votes === 1 ? 'VOTO' : 'VOTI' }}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- MVP Podium Video Generator Accordion (Only when group stage is complete) -->
                <div v-if="isGroupStageComplete && filteredMvpPlayers.length >= 3" class="mt-6">
                    <div class="border-4 border-black bg-cement shadow-[6px_6px_0px_rgba(211,47,47,1)] overflow-hidden">
                        <button
                            type="button"
                            @click="isMvpPodiumOpen = !isMvpPodiumOpen"
                            class="w-full px-5 py-4 flex items-center justify-between gap-4 bg-primary hover:bg-[#8E1515] transition-all duration-300 ease-out text-left border-b-0"
                            :class="{ 'border-b-4 border-black': isMvpPodiumOpen }"
                        >
                            <span class="font-impact text-xl uppercase tracking-widest text-white flex items-center gap-3 min-w-0">
                                <Icon name="mdi:movie-open-star" class="text-2xl flex-shrink-0 text-white" />
                                <span class="truncate">Generatore Video Podio MVP</span>
                                <span class="hidden md:inline-flex text-[10px] bg-black text-white border-2 border-black px-2 py-1 tracking-widest">
                                    DODGEBALL XL STYLE
                                </span>
                            </span>
                            <Icon
                                name="mdi:chevron-down"
                                class="text-3xl text-white transition-transform duration-500 ease-out"
                                :class="{ 'rotate-180': isMvpPodiumOpen }"
                            />
                        </button>

                        <div 
                            class="grid transition-all duration-700 ease-in-out bg-cement border-black"
                            :class="isMvpPodiumOpen ? 'grid-rows-[1fr] border-t-4' : 'grid-rows-[0fr]'"
                        >
                            <div class="overflow-hidden">
                                <div class="p-4 md:p-6 bg-cement">
                                    <AdminMvpPodiumTeaser
                                        :top-players="filteredMvpPlayers"
                                        :teams="teams"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            <!-- Teams Management Accordion Wrapper -->
            <div :class="{
                'mt-12 card-grunge bg-white border-4 border-black p-0 overflow-hidden mb-12': !registrationsOpen,
                'space-y-12': registrationsOpen
            }">
                <button 
                    v-if="!registrationsOpen"
                    @click="isTeamsAccordionOpen = !isTeamsAccordionOpen"
                    class="w-full p-4 md:p-6 flex items-center justify-between bg-black hover:bg-gray-900 transition-colors group"
                >
                    <h2 class="text-xl md:text-2xl font-impact uppercase tracking-widest text-white flex items-center gap-3">
                        <Icon name="mdi:shield-account" class="text-2xl md:text-3xl text-primary" />
                        Gestione Squadre (Chiuse)
                    </h2>
                    <Icon 
                        :name="isTeamsAccordionOpen ? 'mdi:chevron-up' : 'mdi:chevron-down'" 
                        class="text-3xl text-white group-hover:text-primary transition-colors"
                    />
                </button>

                <div 
                    :class="{
                        'grid transition-all duration-700 ease-in-out bg-cement border-black': !registrationsOpen,
                        'grid-rows-[1fr] border-t-4': !registrationsOpen && isTeamsAccordionOpen,
                        'grid-rows-[0fr]': !registrationsOpen && !isTeamsAccordionOpen,
                        'block': registrationsOpen
                    }"
                >
                    <div :class="{'overflow-hidden': !registrationsOpen}">
                        <div :class="{'p-4 md:p-6 bg-cement space-y-8': !registrationsOpen, 'space-y-8': registrationsOpen}">
                            <section>
                                <h2
                                    class="text-lg font-impact uppercase tracking-widest text-secondary mb-4 border-b-4 border-black inline-block pr-4"
                                >
                                    Richieste di Registrazione
                    <span
                        class="ml-2"
                        :class="
                            pendingTeams.length > 0
                                ? 'text-primary'
                                : 'text-gray-400'
                        "
                        >({{ pendingTeams.length }})</span
                    >
                </h2>
                <div class="space-y-4">
                    <div
                        v-if="pendingTeams.length === 0"
                        class="py-12 text-center text-gray-400 font-impact uppercase tracking-widest text-lg card-grunge bg-white"
                    >
                        Nessuna richiesta in sospeso.
                    </div>
                    <div
                        v-for="(team, i) in pendingTeams"
                        :key="team.id"
                        class="card-grunge bg-white flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:-translate-y-0.5 transition-transform mb-4"
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-12 h-12 rounded-none object-cover border-2 border-black bg-white flex-shrink-0"
                            />
                            <div
                                v-else
                                class="w-12 h-12 rounded-none bg-cement border-2 border-black flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400 text-xl"
                                />
                            </div>
                            <div class="min-w-0">
                                <span
                                    class="font-impact uppercase tracking-widest text-black block truncate text-lg"
                                    >{{ team.name }}</span
                                >
                                <span class="text-xs text-secondary font-bold uppercase tracking-widest"
                                    >Richiesta il
                                    {{
                                        new Date(
                                            team.created_at,
                                        ).toLocaleDateString()
                                    }}</span
                                >
                            </div>
                        </div>
                        <div class="flex gap-3 w-full min-[520px]:w-auto">
                            <button
                                @click="setStatus(team.id, 'approved')"
                                class="btn-skewed flex-1 min-[520px]:flex-none px-4 py-2 !text-xs !bg-green-700"
                            >
                                <span class="btn-skewed-content">Approva</span>
                            </button>
                            <button
                                @click="setStatus(team.id, 'rejected')"
                                class="btn-skewed-secondary flex-1 min-[520px]:flex-none !border-red-600 !text-red-600 hover:!bg-red-600 hover:!text-white px-4 py-2 !text-xs"
                            >
                                <span class="btn-skewed-content">Rifiuta</span>
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-lg font-impact uppercase tracking-widest text-secondary mb-4 border-b-4 border-black inline-block pr-4"
                >
                    Squadre Approvate
                    <span class="ml-2 text-gray-500"
                        >({{ approvedTeams.length }})</span
                    >
                </h2>
                <div
                    class="space-y-4"
                >
                    <div
                        v-if="approvedTeams.length === 0"
                        class="py-12 text-center text-gray-400 font-medium bg-white rounded-2xl border border-gray-100 shadow-sm"
                    >
                        Nessuna squadra ancora approvata.
                    </div>
                    <div
                        v-for="(team, i) in approvedTeams"
                        :key="team.id"
                        class="card-grunge bg-white flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:-translate-y-0.5 transition-transform mb-4"
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <span
                                class="text-sm font-impact text-gray-400 w-5"
                                >{{ i + 1 }}</span
                            >
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-12 h-12 rounded-none object-cover border-2 border-black bg-white flex-shrink-0"
                            />
                            <div
                                v-else
                                class="w-12 h-12 rounded-none bg-cement border-2 border-black flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400 text-xl"
                                />
                            </div>
                            <span
                                class="font-impact uppercase tracking-widest text-black text-lg truncate"
                                >{{ team.name }}</span
                            >
                        </div>
                        <div class="flex flex-wrap items-center gap-3 w-full min-[520px]:w-auto justify-end">
                            <template v-if="confirmingDeleteId === team.id">
                                <span
                                    class="text-xs font-impact text-red-600 uppercase tracking-widest"
                                    >Rifiutare la squadra?</span
                                >
                                <button
                                    @click="
                                        setStatus(team.id, 'rejected');
                                        confirmingDeleteId = null;
                                    "
                                    class="btn-skewed px-4 py-2 !text-xs !bg-red-600"
                                >
                                    <span class="btn-skewed-content">Sì</span>
                                </button>
                                <button
                                    @click="confirmingDeleteId = null"
                                    class="btn-skewed-secondary px-4 py-2 !text-xs"
                                >
                                    <span class="btn-skewed-content">Annulla</span>
                                </button>
                            </template>
                            <template v-else>
                                <button
                                    @click="confirmingDeleteId = team.id"
                                    class="btn-skewed-secondary !border-red-600 !text-red-600 hover:!bg-red-600 hover:!text-white px-4 py-2 !text-xs"
                                >
                                    <span class="btn-skewed-content">Rimuovi</span>
                                </button>
                                <NuxtLink
                                    :to="`/admin/teams/${team.id}`"
                                    class="btn-skewed px-4 py-2 !text-xs !bg-black"
                                >
                                    <span class="btn-skewed-content">Gestisci</span>
                                </NuxtLink>
                            </template>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-lg font-impact uppercase tracking-widest text-secondary mb-4 border-b-4 border-black inline-block pr-4"
                >
                    Rifiutate
                    <span class="ml-2 text-gray-500"
                        >({{ rejectedTeams.length }})</span
                    >
                </h2>
                <div
                    class="space-y-4"
                >
                    <div
                        v-for="(team, i) in rejectedTeams"
                        :key="team.id"
                        class="card-grunge bg-gray-100 flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 transition-transform mb-4 grayscale opacity-70"
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-12 h-12 rounded-none object-cover border-2 border-black bg-white flex-shrink-0"
                            />
                            <div
                                v-else
                                class="w-12 h-12 rounded-none bg-gray-200 border-2 border-black flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400 text-xl"
                                />
                            </div>
                            <span
                                class="font-impact uppercase tracking-widest text-gray-500 line-through truncate text-lg"
                                >{{ team.name }}</span
                            >
                        </div>
                        <button
                            @click="setStatus(team.id, 'pending')"
                            class="btn-skewed-secondary !border-gray-500 !text-gray-600 hover:!bg-black hover:!text-white hover:!border-black px-4 py-2 !text-xs"
                        >
                            <span class="btn-skewed-content">Ripristina</span>
                        </button>
                    </div>
                </div>
            </section>
                        </div>
                    </div>
                </div>
            </div>
        </template>
    </div>
</template>
