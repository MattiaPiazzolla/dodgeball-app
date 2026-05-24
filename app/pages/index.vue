// pages/index.vue
<template>
    <div
        class="min-h-screen bg-[#f8f9fa] p-4 sm:p-8 font-sans pb-24 selection:bg-red-500 selection:text-white"
    >
        <div
            class="max-w-[1400px] mx-auto mb-8 flex flex-col md:flex-row md:items-end justify-between gap-4"
        >
            <div>
                <h1
                    class="text-4xl sm:text-5xl font-black uppercase tracking-tighter text-black leading-none"
                >
                    Dodgeball<br /><span class="text-red-600">Urbania</span>
                </h1>
            </div>
            <p
                class="text-gray-400 font-bold text-sm uppercase tracking-widest max-w-xs"
            >
                Il portale definitivo di gestione del torneo.
            </p>
        </div>

        <div
            v-if="pending"
            class="flex justify-center items-center py-32 text-red-500 animate-pulse"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <div
                class="max-w-[1400px] mx-auto grid grid-cols-1 lg:grid-cols-12 gap-6 items-start"
            >
                <div
                    class="lg:col-span-3 bg-white rounded-[2rem] p-6 shadow-sm border border-gray-100 flex flex-col gap-6"
                >
                    <h2
                        class="text-lg font-black uppercase tracking-tight text-gray-800 flex items-center gap-2"
                    >
                        <Icon
                            name="mdi:format-list-numbered"
                            class="text-red-500 text-xl"
                        />
                        Classifiche
                    </h2>

                    <div class="space-y-6">
                        <div
                            v-for="group in groups"
                            :key="group.id"
                            class="space-y-3"
                        >
                            <h3
                                class="text-xs font-bold text-gray-400 uppercase tracking-widest"
                            >
                                {{ group.name }}
                            </h3>
                            <div
                                class="bg-gray-50/80 rounded-2xl border border-gray-100 overflow-hidden"
                            >
                                <table class="w-full text-left text-xs">
                                    <thead
                                        class="bg-gray-100/50 text-gray-400 uppercase tracking-wider"
                                    >
                                        <tr>
                                            <th class="py-2.5 px-3 font-bold">
                                                Squadra
                                            </th>
                                            <th
                                                class="py-2.5 px-2 text-center font-bold"
                                            >
                                                V-P
                                            </th>
                                            <th
                                                class="py-2.5 px-3 text-right font-black text-black"
                                            >
                                                Pt
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-100">
                                        <tr
                                            v-for="gt in group.group_teams"
                                            :key="gt.id"
                                            class="transition-colors hover:bg-white"
                                        >
                                            <td
                                                class="py-2.5 px-3 font-black uppercase truncate max-w-[100px] text-gray-800"
                                                :title="gt.teams?.name"
                                            >
                                                {{ gt.teams?.name || "DA DEFINIRE" }}
                                            </td>
                                            <td
                                                class="py-2.5 px-2 text-center font-bold text-gray-500"
                                            >
                                                {{ gt.wins }}-{{ gt.losses }}
                                            </td>
                                            <td
                                                class="py-2.5 px-3 text-right font-black text-red-600"
                                            >
                                                {{ gt.points }}
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        <div
                            v-if="!groups.length"
                            class="text-xs text-gray-400 font-bold uppercase text-center py-8 bg-gray-50 rounded-2xl border border-dashed border-gray-200"
                        >
                            Nessun gruppo formato.
                        </div>
                    </div>
                </div>

                <div class="lg:col-span-6 flex flex-col gap-6">
                    <div
                        class="bg-white rounded-[2.5rem] p-8 sm:p-12 shadow-sm border-4 relative overflow-hidden transition-all duration-500 flex flex-col justify-center min-h-[420px]"
                        :class="
                            liveMatch
                                ? liveMatch.is_timer_running
                                    ? 'border-red-500 shadow-[0_10px_40px_rgba(220,38,38,0.15)]'
                                    : 'border-yellow-400'
                                : 'border-gray-100'
                        "
                    >
                        <template v-if="liveMatch">
                            <div
                                class="absolute top-0 left-0 right-0 text-xs font-black uppercase tracking-widest text-center py-2 transition-colors"
                                :class="
                                    liveMatch.is_timer_running
                                        ? 'bg-red-600 text-white animate-pulse'
                                        : 'bg-yellow-400 text-black'
                                "
                            >
                                {{
                                    liveMatch.is_timer_running
                                        ? "Partita in Diretta"
                                        : "Partita in Pausa"
                                }}
                            </div>

                            <div class="text-center mt-4 mb-10">
                                <span
                                    class="font-mono text-6xl sm:text-7xl font-black tracking-tighter drop-shadow-sm transition-colors"
                                    :class="
                                        liveMatch.is_timer_running
                                            ? 'text-red-600'
                                            : 'text-yellow-500'
                                    "
                                >
                                    {{ formattedTimer }}
                                </span>
                                <div
                                    class="text-gray-400 font-bold uppercase tracking-widest mt-2 text-xs"
                                >
                                    {{ translateStage(liveMatch.match_type) }}
                                </div>
                            </div>

                            <div
                                class="flex justify-between items-center gap-4 sm:gap-8"
                            >
                                <div class="flex-1 text-center">
                                    <img
                                        v-if="getTeamLogo(liveMatch.team1_id)"
                                        :src="getTeamLogo(liveMatch.team1_id)"
                                        class="w-16 h-16 sm:w-24 sm:h-24 mx-auto rounded-full object-cover shadow-sm mb-4 bg-gray-50"
                                    />
                                    <div
                                        class="text-xl sm:text-2xl font-black uppercase truncate text-black mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team1_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-6xl sm:text-8xl font-black text-gray-900 leading-none"
                                    >
                                        {{ liveMatch.team1_score || 0 }}
                                    </div>
                                </div>
                                <div
                                    class="px-4 py-3 bg-gray-100 rounded-2xl shadow-inner"
                                >
                                    <span
                                        class="text-gray-400 text-sm sm:text-xl font-black uppercase tracking-widest"
                                        >VS</span
                                    >
                                </div>
                                <div class="flex-1 text-center">
                                    <img
                                        v-if="getTeamLogo(liveMatch.team2_id)"
                                        :src="getTeamLogo(liveMatch.team2_id)"
                                        class="w-16 h-16 sm:w-24 sm:h-24 mx-auto rounded-full object-cover shadow-sm mb-4 bg-gray-50"
                                    />
                                    <div
                                        class="text-xl sm:text-2xl font-black uppercase truncate text-black mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team2_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-6xl sm:text-8xl font-black text-gray-900 leading-none"
                                    >
                                        {{ liveMatch.team2_score || 0 }}
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="upcomingMatches.length">
                            <div class="text-center mb-8">
                                <div
                                    class="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4"
                                >
                                    <Icon
                                        name="mdi:calendar-clock"
                                        class="text-2xl text-gray-400"
                                    />
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black"
                                >
                                    Prossimo Incontro
                                </h2>
                                <p
                                    class="text-red-500 font-bold uppercase tracking-widest text-sm mt-1"
                                >
                                    {{ upcomingMatches[0].start_time || "DA DEFINIRE" }}
                                </p>
                            </div>

                            <div
                                class="flex justify-between items-center gap-4"
                            >
                                <div class="flex-1 text-center">
                                    <img
                                        v-if="
                                            getTeamLogo(
                                                upcomingMatches[0].team1_id,
                                            )
                                        "
                                        :src="
                                            getTeamLogo(
                                                upcomingMatches[0].team1_id,
                                            )
                                        "
                                        class="w-20 h-20 mx-auto rounded-full object-cover shadow-sm mb-3"
                                    />
                                    <div
                                        class="text-xl font-black uppercase truncate text-black"
                                    >
                                        {{
                                            getTeamName(
                                                upcomingMatches[0].team1_id,
                                            ) || "DA DEFINIRE"
                                        }}
                                    </div>
                                </div>
                                <span
                                    class="text-gray-300 text-lg font-black uppercase tracking-widest"
                                    >VS</span
                                >
                                <div class="flex-1 text-center">
                                    <img
                                        v-if="
                                            getTeamLogo(
                                                upcomingMatches[0].team2_id,
                                            )
                                        "
                                        :src="
                                            getTeamLogo(
                                                upcomingMatches[0].team2_id,
                                            )
                                        "
                                        class="w-20 h-20 mx-auto rounded-full object-cover shadow-sm mb-3"
                                    />
                                    <div
                                        class="text-xl font-black uppercase truncate text-black"
                                    >
                                        {{
                                            getTeamName(
                                                upcomingMatches[0].team2_id,
                                            ) || "DA DEFINIRE"
                                        }}
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="showTournamentComplete">
                            <div class="text-center flex flex-col items-center">
                                <div
                                    class="w-24 h-24 bg-yellow-50 border border-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6 shadow-sm"
                                >
                                    <Icon
                                        name="mdi:trophy"
                                        class="text-4xl text-yellow-500"
                                    />
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black mb-2"
                                >
                                    Torneo Terminato
                                </h2>
                                <p
                                    class="text-gray-400 font-bold uppercase tracking-widest text-sm max-w-sm mx-auto"
                                >
                                    Tutti gli incontri sono terminati. Grazie per
                                    aver partecipato!
                                </p>
                            </div>
                        </template>

                        <template v-else-if="showKnockoutDrawHolding">
                            <div
                                class="text-center flex flex-col items-center animate-fade-in"
                            >
                                <div class="relative w-24 h-24 mb-6 mx-auto">
                                    <div
                                        class="absolute inset-0 bg-red-100 rounded-full animate-ping opacity-75"
                                    ></div>
                                    <div
                                        class="relative bg-white border border-red-100 w-24 h-24 rounded-full flex items-center justify-center shadow-md"
                                    >
                                        <Icon
                                            name="mdi:tournament"
                                            class="text-4xl text-red-500"
                                        />
                                    </div>
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black mb-3"
                                >
                                    Fase a Gironi Terminata
                                </h2>
                                <p
                                    class="text-gray-400 font-bold uppercase tracking-widest text-xs max-w-[250px] mx-auto leading-relaxed"
                                >
                                    I gironi sono conclusi. In attesa del
                                    sorteggio del tabellone a eliminazione diretta...
                                </p>
                            </div>
                        </template>

                        <template v-else>
                            <div class="text-center text-gray-400">
                                <Icon
                                    name="mdi:whistle"
                                    class="text-6xl text-gray-200 mb-4"
                                />
                                <p
                                    class="font-black text-xl uppercase tracking-widest"
                                >
                                    Nessuna Partita in Diretta
                                </p>
                            </div>
                        </template>
                    </div>

                    <div
                        v-if="recentMatches.length"
                        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
                    >
                        <div
                            v-for="match in recentMatches.slice(0, 3)"
                            :key="match.id"
                            class="bg-white rounded-3xl p-5 shadow-sm border border-gray-100"
                        >
                            <div
                                class="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3 flex justify-between"
                            >
                                <span>{{ translateStage(match.match_type) }}</span>
                                <span class="text-red-500">FINALE</span>
                            </div>
                            <div class="space-y-2">
                                <div class="flex justify-between items-center">
                                    <span
                                        class="font-black uppercase text-sm truncate pr-2"
                                        :class="
                                            match.winner_id === match.team1_id
                                                ? 'text-black'
                                                : 'text-gray-400'
                                        "
                                        >{{
                                            getTeamName(match.team1_id) || "DA DEFINIRE"
                                        }}</span
                                    >
                                    <span
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team1_id
                                                ? 'text-green-500'
                                                : 'text-gray-300'
                                        "
                                        >{{ match.team1_score || 0 }}</span
                                    >
                                </div>
                                <div class="flex justify-between items-center">
                                    <span
                                        class="font-black uppercase text-sm truncate pr-2"
                                        :class="
                                            match.winner_id === match.team2_id
                                                ? 'text-black'
                                                : 'text-gray-400'
                                        "
                                        >{{
                                            getTeamName(match.team2_id) || "DA DEFINIRE"
                                        }}</span
                                    >
                                    <span
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team2_id
                                                ? 'text-green-500'
                                                : 'text-gray-300'
                                        "
                                        >{{ match.team2_score || 0 }}</span
                                    >
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div
                    class="lg:col-span-3 bg-white rounded-[2rem] p-6 shadow-sm border border-gray-100 flex flex-col max-h-[600px]"
                >
                    <h2
                        class="text-lg font-black uppercase tracking-tight text-gray-800 mb-4 flex items-center gap-2"
                    >
                        <Icon name="mdi:star" class="text-yellow-400 text-xl" />
                        Votazione MVP
                    </h2>

                    <div class="relative mb-4">
                        <Icon
                            name="mdi:magnify"
                            class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-lg"
                        />
                        <input
                            v-model="searchQuery"
                            type="text"
                            placeholder="Cerca giocatori..."
                            class="w-full bg-gray-50 border border-gray-100 rounded-xl py-2.5 pl-10 pr-4 text-xs font-bold uppercase tracking-wide focus:outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all placeholder:text-gray-300"
                        />
                    </div>

                    <div
                        class="overflow-y-auto pr-1 space-y-3 flex-1 custom-scrollbar"
                    >
                        <div
                            v-for="player in filteredPlayers"
                            :key="player.id"
                            class="flex items-center justify-between p-3 bg-gray-50/80 rounded-2xl border border-gray-100 hover:border-gray-200 transition-colors group"
                        >
                            <div
                                class="flex items-center gap-3 overflow-hidden"
                            >
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-10 h-10 rounded-full object-cover shadow-sm bg-white border border-gray-100"
                                />
                                <div
                                    v-else
                                    class="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-gray-400 shrink-0"
                                >
                                    <Icon name="mdi:account" class="text-lg" />
                                </div>
                                <div class="min-w-0">
                                    <div
                                        class="font-black text-black uppercase text-xs truncate"
                                    >
                                        {{ player.name }}
                                    </div>
                                    <div
                                        class="text-[10px] text-gray-400 font-bold uppercase truncate"
                                    >
                                        {{ getTeamName(player.team_id) }}
                                    </div>
                                </div>
                            </div>

                            <div
                                class="flex flex-col items-center justify-center gap-0.5 shrink-0 pl-2"
                            >
                                <button
                                    @click="voteForPlayer(player.id)"
                                    :disabled="hasVoted(player.id)"
                                    class="w-8 h-8 rounded-full flex items-center justify-center transition-all shadow-sm border"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'bg-green-50 border-green-200 text-green-500 cursor-not-allowed'
                                            : 'bg-white border-gray-200 text-gray-300 hover:text-red-500 hover:border-red-200 hover:shadow-md'
                                    "
                                >
                                    <Icon
                                        :name="
                                            hasVoted(player.id)
                                                ? 'mdi:thumb-up'
                                                : 'mdi:thumb-up-outline'
                                        "
                                        class="text-sm"
                                    />
                                </button>
                                <span
                                    class="text-[9px] font-black uppercase tracking-widest"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'text-green-600'
                                            : 'text-gray-400'
                                    "
                                >
                                    {{ player.mvp_votes || 0 }}
                                </span>
                            </div>
                        </div>
                        <div
                            v-if="filteredPlayers.length === 0"
                            class="text-center py-8 text-gray-400 font-bold uppercase text-xs"
                        >
                            Nessun giocatore trovato.
                        </div>
                    </div>
                </div>
            </div>
        </template>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";

const translateStage = (stage: string) => {
    if (!stage) return "";
    const lower = stage.toLowerCase();
    if (lower === "group") return "Fase a Gironi";
    if (lower === "knockout") return "Fase a Eliminazione Diretta";
    return stage;
};

const supabase = useSupabaseClient();
const { subscribeToAllMatches, unsubscribe } = useMatchRealtime();

const matches = ref<any[]>([]);
const teams = ref<any[]>([]);
const groups = ref<any[]>([]);
const players = ref<any[]>([]);
const pending = ref(true);

const searchQuery = ref("");
const trackingVotes = ref<Record<string, boolean>>({});

let realtimeChannel: any = null;
const now = ref(Date.now());
let timerInterval: any = null;

const liveMatch = computed(() =>
    matches.value.find((m) => m.status === "in_progress"),
);

const upcomingMatches = computed(() =>
    matches.value
        .filter((m) => m.status === "pending")
        .sort((a, b) =>
            (a.start_time || "z").localeCompare(b.start_time || "z"),
        ),
);

const recentMatches = computed(() =>
    matches.value
        .filter((m) => ["completed", "retired"].includes(m.status))
        .sort((a, b) =>
            (b.start_time || b.id).localeCompare(a.start_time || a.id),
        ),
);

// Advanced Computed States
const showTournamentComplete = computed(() => {
    if (matches.value.length === 0) return false;
    const hasKnockouts = matches.value.some((m) => m.match_type !== "group");
    return (
        matches.value.every((m) =>
            ["completed", "retired"].includes(m.status),
        ) && hasKnockouts
    );
});

const showKnockoutDrawHolding = computed(() => {
    if (matches.value.length === 0) return false;
    const groupMatches = matches.value.filter((m) => m.match_type === "group");
    const hasKnockouts = matches.value.some((m) => m.match_type !== "group");
    const allGroupDone =
        groupMatches.length > 0 &&
        groupMatches.every((m) => ["completed", "retired"].includes(m.status));
    return allGroupDone && !hasKnockouts;
});

const filteredPlayers = computed(() => {
    let sorted = [...players.value].sort(
        (a, b) => (b.mvp_votes || 0) - (a.mvp_votes || 0),
    );
    if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase();
        sorted = sorted.filter(
            (p) =>
                p.name.toLowerCase().includes(query) ||
                (p.nickname && p.nickname.toLowerCase().includes(query)),
        );
    }
    return sorted;
});

const getTeamName = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.name;
const getTeamLogo = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.logo_url;

const totalElapsed = computed(() => {
    if (!liveMatch.value) return 0;
    let elapsed = liveMatch.value.elapsed_seconds || 0;
    if (liveMatch.value.is_timer_running && liveMatch.value.timer_started_at) {
        const start = new Date(liveMatch.value.timer_started_at).getTime();
        const diff = Math.floor((now.value - start) / 1000);
        if (diff > 0) elapsed += diff;
    }
    return elapsed;
});

const formattedTimer = computed(() => {
    const e = totalElapsed.value;
    const m = Math.floor(e / 60)
        .toString()
        .padStart(2, "0");
    const s = (e % 60).toString().padStart(2, "0");
    return `${m}:${s}`;
});

const loadGroupsAndStandings = async () => {
    const { data: gData } = await supabase
        .from("groups")
        .select(
            `id, name, group_teams ( id, team_id, points, wins, losses, teams ( name ) )`,
        )
        .order("name");

    if (gData) {
        gData.forEach((g) => {
            g.group_teams.sort(
                (a: any, b: any) => b.points - a.points || b.wins - a.wins,
            );
        });
        groups.value = gData;
    }
};

const loadData = async () => {
    pending.value = true;
    const [{ data: tData }, { data: mData }, { data: pData }] =
        await Promise.all([
            supabase
                .from("teams")
                .select("*")
                .eq("is_approved", true)
                .order("name"),
            supabase.from("matches").select("*"),
            supabase.from("players").select("*"),
        ]);

    if (tData) teams.value = tData;
    if (mData) matches.value = mData;
    if (pData) {
        players.value = pData;
        pData.forEach((p: any) => {
            trackingVotes.value[p.id] = !!localStorage.getItem(
                `voted_mvp_player_${p.id}`,
            );
        });
    }

    await loadGroupsAndStandings();

    realtimeChannel = subscribeToAllMatches((payload) => {
        const updatedMatch = payload.new;
        const index = matches.value.findIndex((m) => m.id === updatedMatch.id);
        const wasActiveNowFinished =
            index !== -1 &&
            matches.value[index].status === "in_progress" &&
            ["completed", "retired"].includes(updatedMatch.status);

        if (index !== -1) {
            matches.value[index] = { ...matches.value[index], ...updatedMatch };
        } else {
            matches.value.push(updatedMatch);
        }
        if (wasActiveNowFinished && updatedMatch.match_type === "group") {
            loadGroupsAndStandings();
        }
    });

    timerInterval = setInterval(() => {
        now.value = Date.now();
    }, 1000);
    pending.value = false;
};

const hasVoted = (playerId: string) => !!trackingVotes.value[playerId];

const voteForPlayer = async (playerId: string) => {
    if (hasVoted(playerId)) return;
    const player = players.value.find((p) => p.id === playerId);
    if (player) player.mvp_votes = (player.mvp_votes || 0) + 1;

    trackingVotes.value[playerId] = true;
    localStorage.setItem(`voted_mvp_player_${playerId}`, "true");
    await supabase.rpc("increment_player_votes", { player_uuid: playerId });
};

onMounted(loadData);
onUnmounted(() => {
    unsubscribe(realtimeChannel);
    if (timerInterval) clearInterval(timerInterval);
});
</script>

<style scoped>
/* Clean scrollbar for the voting list */
.custom-scrollbar::-webkit-scrollbar {
    width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: #e5e7eb;
    border-radius: 10px;
}
.custom-scrollbar:hover::-webkit-scrollbar-thumb {
    background: #d1d5db;
}

@keyframes fade-in {
    from {
        opacity: 0;
        transform: translateY(10px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}
.animate-fade-in {
    animation: fade-in 0.5s ease-out forwards;
}
</style>
