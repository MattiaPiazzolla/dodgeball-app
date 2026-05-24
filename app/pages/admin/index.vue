// app/pages/admin/index.vue
<script setup lang="ts">
definePageMeta({ middleware: ["admin"] });
const client = useSupabaseClient();

const teams = ref<any[]>([]);
const matches = ref<any[]>([]);
const topMvpPlayers = ref<any[]>([]);
const registrationsOpen = ref(true);
const isLoading = ref(true);

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
                    "id, name, nickname, jersey_number, photo_url, mvp_votes, team_id",
                )
                .gt("mvp_votes", 0)
                .order("mvp_votes", { ascending: false })
                .limit(5),
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

onMounted(fetchAll);

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
            class="flex items-center justify-center py-24 text-red-500"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <section
                v-if="isGroupStageComplete"
                class="animate-in fade-in slide-in-from-bottom-4 duration-500"
            >
                <div
                    class="bg-gradient-to-r from-red-600 to-red-800 rounded-3xl p-8 sm:p-10 shadow-2xl relative overflow-hidden flex flex-col md:flex-row items-center justify-between gap-8"
                >
                    <Icon
                        name="mdi:tournament"
                        class="absolute -right-8 -bottom-12 text-[200px] text-white opacity-10 pointer-events-none"
                    />

                    <div
                        class="relative z-10 text-center md:text-left text-white space-y-3"
                    >
                        <div
                            class="flex items-center justify-center md:justify-start gap-2 text-yellow-300 font-bold uppercase tracking-widest text-xs"
                        >
                            <Icon name="mdi:check-decagram" class="text-lg" />
                            Fase a Gironi Completata
                        </div>
                        <h2
                            class="text-3xl sm:text-4xl font-black uppercase tracking-tight leading-none"
                        >
                            Pronto per il Sorteggio
                        </h2>
                        <p class="text-white/80 font-medium max-w-md">
                            Tutti gli incontri della fase a gironi sono stati risolti. Ora puoi
                            generare il tabellone a eliminazione diretta.
                        </p>
                    </div>

                    <div class="relative z-10 w-full md:w-auto">
                        <NuxtLink
                            to="/admin/matches"
                            class="flex items-center justify-center gap-3 w-full md:w-auto px-8 py-5 bg-white text-red-600 rounded-2xl font-black uppercase tracking-widest hover:bg-yellow-400 hover:text-black transition-all hover:-translate-y-1 hover:shadow-xl"
                        >
                            <Icon name="mdi:whistle" class="text-xl" />
                            Genera Tabellone
                        </NuxtLink>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Pannello di Controllo
                </h2>
                <div class="grid grid-cols-1 min-[420px]:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                    <div
                        class="interactive-card bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1 hover:shadow-md"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Squadre Approvate</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            approvedTeams.length
                        }}</span>
                    </div>
                    <div
                        class="interactive-card bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1 relative overflow-hidden hover:shadow-md"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Richieste in Sospeso</span
                        >
                        <span
                            class="text-4xl font-black"
                            :class="
                                pendingTeams.length > 0
                                    ? 'text-red-600'
                                    : 'text-black'
                            "
                            >{{ pendingTeams.length }}</span
                        >
                        <div
                            v-if="pendingTeams.length > 0"
                            class="absolute top-3 right-3 w-2.5 h-2.5 rounded-full bg-red-500 animate-ping"
                        ></div>
                        <div
                            v-if="pendingTeams.length > 0"
                            class="absolute top-3 right-3 w-2.5 h-2.5 rounded-full bg-red-500"
                        ></div>
                    </div>
                    <div
                        class="interactive-card bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1 hover:shadow-md"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Incontri Totali</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            totalMatches
                        }}</span>
                        <span class="text-xs text-gray-400 font-medium"
                            >{{ completedMatches }} completati</span
                        >
                    </div>
                    <div
                        class="interactive-card bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1 hover:shadow-md"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Incontri Programmati</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            pendingMatches
                        }}</span>
                        <span class="text-xs text-gray-400 font-medium"
                            >in attesa di gioco</span
                        >
                    </div>
                </div>
            </section>

            <section>
                <div
                    class="interactive-card bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:shadow-md"
                >
                    <div>
                        <h2
                            class="text-xs font-black uppercase tracking-widest text-gray-400"
                        >
                            Iscrizioni capitani
                        </h2>
                        <p class="text-lg font-black text-black uppercase mt-1">
                            {{
                                registrationsOpen
                                    ? "Nuovi account aperti"
                                    : "Nuovi account chiusi"
                            }}
                        </p>
                        <p class="text-sm text-gray-500 font-medium mt-1">
                            Quando sono chiuse, il pulsante di registrazione non
                            appare nel portale capitano.
                        </p>
                    </div>
                    <button
                        @click="toggleRegistrations"
                        class="relative w-16 h-9 rounded-full transition-colors shrink-0 active:scale-[0.98]"
                        :class="registrationsOpen ? 'bg-green-500' : 'bg-gray-300'"
                        :aria-pressed="registrationsOpen"
                        title="Apri o chiudi iscrizioni"
                    >
                        <span
                            class="absolute top-1 w-7 h-7 rounded-full bg-white shadow transition-transform"
                            :class="
                                registrationsOpen
                                    ? 'translate-x-7 left-1'
                                    : 'translate-x-0 left-1'
                            "
                        ></span>
                    </button>
                </div>
            </section>

            <section v-if="nextMatch">
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Prossimo Incontro
                </h2>
                <div
                    class="bg-black text-white rounded-2xl p-5 sm:p-6 grid grid-cols-1 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center justify-between gap-5 sm:gap-6"
                >
                    <div class="flex items-center gap-4 min-w-0 w-full">
                        <img
                            v-if="getTeamLogo(nextMatch.team1_id)"
                            :src="getTeamLogo(nextMatch.team1_id)"
                            class="w-14 h-14 rounded-full object-cover border-2 border-white/20"
                        />
                        <div
                            v-else
                            class="w-14 h-14 rounded-full bg-white/10 flex items-center justify-center"
                        >
                            <Icon
                                name="mdi:shield"
                                class="text-2xl text-white/40"
                            />
                        </div>
                        <span
                            class="text-lg sm:text-xl font-black uppercase tracking-tight truncate"
                            >{{ getTeamName(nextMatch.team1_id) }}</span
                        >
                    </div>
                    <div class="flex flex-col items-center gap-1 flex-shrink-0">
                        <span class="text-3xl font-black text-red-500">VS</span>
                        <span
                            class="text-sm font-bold text-white/60 uppercase tracking-widest"
                            >{{ formatTime(nextMatch.start_time) }}</span
                        >
                        <span
                            class="text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wide"
                            :class="
                                nextMatch.match_type === 'knockout'
                                    ? 'bg-red-600 text-white'
                                    : 'bg-white/10 text-white/70'
                            "
                        >
                            {{ translateStage(nextMatch.match_type) }}
                        </span>
                    </div>
                    <div class="flex items-center gap-4 min-w-0 w-full justify-end">
                        <span
                            class="text-lg sm:text-xl font-black uppercase tracking-tight text-right truncate"
                            >{{
                                getTeamName(nextMatch.team2_id)
                            }}</span
                        >
                        <img
                            v-if="getTeamLogo(nextMatch.team2_id)"
                            :src="getTeamLogo(nextMatch.team2_id)"
                            class="w-14 h-14 rounded-full object-cover border-2 border-white/20"
                        />
                        <div
                            v-else
                            class="w-14 h-14 rounded-full bg-white/10 flex items-center justify-center"
                        >
                            <Icon
                                name="mdi:shield"
                                class="text-2xl text-white/40"
                            />
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Classifica MVP in Diretta (Migliori Candidati)
                </h2>
                <div
                    class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden"
                >
                    <div
                        v-if="topMvpPlayers.length === 0"
                        class="py-12 text-center text-gray-400 font-medium"
                    >
                        Nessun voto MVP ancora inviato.
                    </div>
                    <div v-else>
                        <div
                            v-for="(player, idx) in topMvpPlayers"
                            :key="player.id"
                            class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:bg-gray-50 transition-colors"
                            :class="
                                idx < topMvpPlayers.length - 1
                                    ? 'border-b border-gray-100'
                                    : ''
                            "
                        >
                            <div class="flex items-center gap-3 sm:gap-4 min-w-0">
                                <span
                                    class="font-black text-lg w-6"
                                    :class="
                                        idx === 0
                                            ? 'text-yellow-500'
                                            : idx === 1
                                              ? 'text-gray-400'
                                              : idx === 2
                                                ? 'text-amber-600'
                                                : 'text-gray-300'
                                    "
                                >
                                    #{{ idx + 1 }}
                                </span>
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-10 h-10 rounded-full object-cover border border-gray-100 bg-white flex-shrink-0"
                                />
                                <div
                                    v-else
                                    class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0"
                                >
                                    <Icon
                                        name="mdi:account-outline"
                                        class="text-gray-400"
                                    />
                                </div>
                                <div class="min-w-0">
                                    <div class="flex items-center gap-2 min-w-0">
                                        <span
                                            class="font-black uppercase tracking-tight text-black truncate"
                                            >{{ player.name }}</span
                                        >
                                        <span
                                            v-if="player.nickname"
                                            class="text-xs text-gray-400 font-bold"
                                            >"{{ player.nickname }}"</span
                                        >
                                    </div>
                                    <span
                                        class="text-xs text-red-600 font-black uppercase tracking-wider block"
                                    >
                                        #{{ player.jersey_number || "00" }} —
                                        {{ getTeamName(player.team_id) }}
                                    </span>
                                </div>
                            </div>

                            <div
                                class="bg-gray-50 px-4 py-2 rounded-xl border border-gray-100 font-black text-black text-sm shadow-inner flex items-center gap-2 self-end min-[520px]:self-auto"
                            >
                                <Icon
                                    name="mdi:thumb-up"
                                    class="text-red-500 text-xs"
                                />
                                <span>{{ player.mvp_votes }} Voti</span>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Richieste di Registrazione
                    <span
                        class="ml-2"
                        :class="
                            pendingTeams.length > 0
                                ? 'text-red-400'
                                : 'text-gray-300'
                        "
                        >({{ pendingTeams.length }})</span
                    >
                </h2>
                <div
                    class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden"
                >
                    <div
                        v-if="pendingTeams.length === 0"
                        class="py-12 text-center text-gray-400 font-medium"
                    >
                        Nessuna richiesta in sospeso.
                    </div>
                    <div
                        v-for="(team, i) in pendingTeams"
                        :key="team.id"
                        class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:bg-yellow-50/40 transition-colors"
                        :class="
                            i < pendingTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-10 h-10 rounded-full object-cover border border-gray-100 bg-white flex-shrink-0"
                            />
                            <div
                                v-else
                                class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400"
                                />
                            </div>
                            <div class="min-w-0">
                                <span
                                    class="font-black uppercase tracking-tight text-black block truncate"
                                    >{{ team.name }}</span
                                >
                                <span class="text-xs text-gray-400 font-medium"
                                    >Richiesta il
                                    {{
                                        new Date(
                                            team.created_at,
                                        ).toLocaleDateString()
                                    }}</span
                                >
                            </div>
                        </div>
                        <div class="flex gap-2 w-full min-[520px]:w-auto">
                            <button
                                @click="setStatus(team.id, 'approved')"
                                class="flex-1 min-[520px]:flex-none px-4 py-2 bg-green-100 text-green-700 hover:bg-green-200 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                            >
                                Approva
                            </button>
                            <button
                                @click="setStatus(team.id, 'rejected')"
                                class="flex-1 min-[520px]:flex-none px-4 py-2 bg-red-100 text-red-600 hover:bg-red-200 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                            >
                                Rifiuta
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Squadre Approvate
                    <span class="ml-2 text-gray-300"
                        >({{ approvedTeams.length }})</span
                    >
                </h2>
                <div
                    class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden"
                >
                    <div
                        v-if="approvedTeams.length === 0"
                        class="py-12 text-center text-gray-400 font-medium"
                    >
                        Nessuna squadra ancora approvata.
                    </div>
                    <div
                        v-for="(team, i) in approvedTeams"
                        :key="team.id"
                        class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:bg-gray-50 transition-colors"
                        :class="
                            i < approvedTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <span
                                class="text-xs font-black text-gray-300 w-5"
                                >{{ i + 1 }}</span
                            >
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-10 h-10 rounded-full object-cover border border-gray-100 bg-white flex-shrink-0"
                            />
                            <div
                                v-else
                                class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400"
                                />
                            </div>
                            <span
                                class="font-black uppercase tracking-tight text-black truncate"
                                >{{ team.name }}</span
                            >
                        </div>
                        <div class="flex flex-wrap items-center gap-2 w-full min-[520px]:w-auto justify-end">
                            <template v-if="confirmingDeleteId === team.id">
                                <span
                                    class="text-xs font-bold text-red-600 uppercase tracking-wide"
                                    >Rifiutare la squadra?</span
                                >
                                <button
                                    @click="
                                        setStatus(team.id, 'rejected');
                                        confirmingDeleteId = null;
                                    "
                                    class="px-4 py-2 bg-red-600 text-white hover:bg-red-700 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Sì
                                </button>
                                <button
                                    @click="confirmingDeleteId = null"
                                    class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Annulla
                                </button>
                            </template>
                            <template v-else>
                                <button
                                    @click="confirmingDeleteId = team.id"
                                    class="px-4 py-2 bg-red-50 text-red-500 hover:bg-red-100 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Rimuovi
                                </button>
                                <NuxtLink
                                    :to="`/admin/teams/${team.id}`"
                                    class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Gestisci
                                </NuxtLink>
                            </template>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Rifiutate
                    <span class="ml-2 text-gray-300"
                        >({{ rejectedTeams.length }})</span
                    >
                </h2>
                <div
                    class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden"
                >
                    <div
                        v-for="(team, i) in rejectedTeams"
                        :key="team.id"
                        class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3 px-4 sm:px-6 py-4 hover:bg-gray-50 transition-colors opacity-60"
                        :class="
                            i < rejectedTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-3 sm:gap-4 min-w-0 w-full">
                            <img
                                v-if="team.logo_url"
                                :src="team.logo_url"
                                class="w-10 h-10 rounded-full object-cover border border-gray-100 bg-white flex-shrink-0 grayscale"
                            />
                            <div
                                v-else
                                class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center flex-shrink-0"
                            >
                                <Icon
                                    name="mdi:shield-outline"
                                    class="text-gray-400"
                                />
                            </div>
                            <span
                                class="font-black uppercase tracking-tight text-gray-500 line-through truncate"
                                >{{ team.name }}</span
                            >
                        </div>
                        <button
                            @click="setStatus(team.id, 'pending')"
                            class="w-full min-[520px]:w-auto px-4 py-2 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                        >
                            Ripristina
                        </button>
                    </div>
                </div>
            </section>
        </template>
    </div>
</template>
