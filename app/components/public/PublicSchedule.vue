// components/public/PublicSchedule.vue
<template>
    <div class="space-y-6 sm:space-y-8 relative">
        <div class="text-center space-y-3 mb-8 sm:mb-12 mobile-fade-in">
            <h1 class="text-3xl sm:text-4xl font-black uppercase tracking-tight text-black">
                Calendario del Torneo
            </h1>
            <p class="text-gray-500 font-medium">
                Orari, risultati e classifiche in un unico posto.
            </p>
        </div>

        <div
            v-if="pending"
            class="text-center text-gray-500 py-12 font-bold animate-pulse uppercase tracking-widest"
        >
            Caricamento Calendario...
        </div>

        <div
            v-else
            class="bg-white p-3 sm:p-8 rounded-3xl shadow-sm border border-gray-100 mobile-fade-in"
        >
            <!-- Tabs -->
            <div
                class="flex bg-gray-100 p-1 rounded-2xl w-full max-w-md mx-auto mb-8 sm:mb-10"
            >
                <button
                    @click="activeTab = 'group'"
                    :class="
                        activeTab === 'group'
                            ? 'bg-white text-black shadow-sm'
                            : 'text-gray-500'
                    "
                    class="flex-1 py-3 font-black uppercase tracking-wide text-xs sm:text-sm rounded-xl transition-all active:scale-[0.98]"
                >
                    Gironi
                </button>
                <button
                    @click="activeTab = 'knockout'"
                    :class="
                        activeTab === 'knockout'
                            ? 'bg-white text-black shadow-sm'
                            : 'text-gray-500'
                    "
                    class="flex-1 py-3 font-black uppercase tracking-wide text-xs sm:text-sm rounded-xl transition-all active:scale-[0.98]"
                >
                    Eliminazione
                </button>
            </div>

            <!-- GROUP STAGE -->
            <div v-if="activeTab === 'group'" class="space-y-5 sm:space-y-12">
                <div
                    v-if="groups.length === 0"
                    class="text-center text-gray-400 py-16 bg-gray-50 rounded-2xl border border-dashed border-gray-200 font-bold uppercase tracking-wide"
                >
                    La fase a gironi non è stata ancora sorteggiata.
                </div>

                <div
                    v-for="group in groups"
                    :key="group.id"
                    class="grid grid-cols-1 xl:grid-cols-2 gap-5 sm:gap-8 bg-gray-50 p-3 sm:p-6 rounded-3xl border border-gray-100"
                >
                    <!-- Standings -->
                    <div>
                        <h3
                            class="text-lg sm:text-xl font-black text-black uppercase tracking-tight mb-4"
                        >
                            Classifica {{ group.name }}
                        </h3>
                        <div
                            class="bg-white rounded-2xl border border-gray-100 overflow-hidden shadow-sm"
                        >
                            <table class="w-full table-fixed text-left text-xs sm:text-sm">
                                <thead
                                    class="bg-gray-50 border-b border-gray-100"
                                >
                                    <tr
                                        class="text-gray-400 font-bold uppercase tracking-wide text-xs"
                                    >
                                        <th class="w-[52%] p-3 sm:p-4">Squadra</th>
                                        <th class="w-[16%] p-3 sm:p-4 text-center">V</th>
                                        <th class="w-[16%] p-3 sm:p-4 text-center">P</th>
                                        <th class="w-[16%] p-3 sm:p-4 text-center text-black">
                                            Pt
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr
                                        v-for="gt in group.group_teams"
                                        :key="gt.id"
                                        class="border-b border-gray-50 last:border-0"
                                    >
                                        <td class="p-3 sm:p-4">
                                            <div class="flex items-center gap-2 min-w-0">
                                                <PublicTeamLogo
                                                    :src="gt.teams?.logo_url"
                                                    :alt="gt.teams?.name"
                                                    size-class="w-7 h-7"
                                                    icon-class="text-sm"
                                                />
                                                <span class="font-black text-black uppercase truncate">
                                                    {{ gt.teams?.name || "Unknown" }}
                                                </span>
                                            </div>
                                        </td>
                                        <td
                                            class="p-3 sm:p-4 text-center font-medium text-gray-600"
                                        >
                                            {{ gt.wins }}
                                        </td>
                                        <td
                                            class="p-3 sm:p-4 text-center font-medium text-gray-600"
                                        >
                                            {{ gt.losses }}
                                        </td>
                                        <td
                                            class="p-3 sm:p-4 text-center font-black text-red-600 text-base"
                                        >
                                            {{ gt.points }}
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Matches -->
                    <div>
                        <h3
                            class="text-lg sm:text-xl font-black text-black uppercase tracking-tight mb-4"
                        >
                            Partite
                        </h3>
                        <div class="space-y-4">
                            <div
                                v-for="match in groupedGroupMatches[group.id]"
                                :key="match.id"
                                class="interactive-card bg-white border border-gray-100 rounded-2xl p-3 sm:p-4 shadow-sm flex flex-col gap-2 relative overflow-hidden hover:-translate-y-0.5 hover:shadow-md"
                                :class="{
                                    'ring-2 ring-red-500':
                                        match.status === 'in_progress',
                                }"
                            >
                                <div
                                    v-if="match.status === 'in_progress'"
                                    class="absolute top-0 left-0 right-0 bg-red-500 text-white text-[10px] font-black uppercase tracking-widest text-center py-0.5 animate-pulse"
                                >
                                    ORA IN DIRETTA
                                </div>

                                <div
                                    class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center justify-between mt-2"
                                >
                                    <div
                                        class="min-w-0 text-right pr-2 sm:pr-4 font-black uppercase text-xs sm:text-sm flex flex-col items-end"
                                        :class="
                                            match.team1_id
                                                ? 'text-black'
                                                : 'text-gray-400'
                                        "
                                    >
                                        <div class="flex items-center justify-end gap-2 min-w-0 max-w-full">
                                            <span class="truncate">{{
                                                getTeamName(match.team1_id) || "DA DEFINIRE"
                                            }}</span>
                                            <PublicTeamLogo
                                                :src="getTeamLogo(match.team1_id)"
                                                :alt="getTeamName(match.team1_id)"
                                                size-class="w-8 h-8"
                                                icon-class="text-base"
                                            />
                                        </div>
                                        <span
                                            v-if="
                                                [
                                                    'in_progress',
                                                    'finished',
                                                    'retired',
                                                ].includes(match.status)
                                            "
                                            class="text-2xl mt-1"
                                            :class="
                                                match.winner_id ===
                                                match.team1_id
                                                    ? 'text-green-500'
                                                    : ''
                                            "
                                            >{{ match.team1_score || 0 }}</span
                                        >
                                    </div>

                                    <div
                                        class="flex flex-col items-center justify-center px-2 sm:px-4 border-x border-gray-100 min-w-[76px] sm:min-w-[100px]"
                                    >
                                        <span
                                            class="text-xs font-bold mb-1 uppercase"
                                            :class="
                                                match.start_time
                                                    ? 'text-red-600'
                                                    : 'text-gray-400'
                                            "
                                            >{{
                                                match.start_time || "DA DEFINIRE"
                                            }}</span
                                        >
                                        <span
                                            class="bg-gray-100 text-gray-500 text-[10px] font-black px-2 py-0.5 rounded-full uppercase"
                                            >VS</span
                                        >
                                    </div>

                                    <div
                                        class="min-w-0 text-left pl-2 sm:pl-4 font-black uppercase text-xs sm:text-sm flex flex-col"
                                        :class="
                                            match.team2_id
                                                ? 'text-black'
                                                : 'text-gray-400'
                                        "
                                    >
                                        <div class="flex items-center gap-2 min-w-0 max-w-full">
                                            <PublicTeamLogo
                                                :src="getTeamLogo(match.team2_id)"
                                                :alt="getTeamName(match.team2_id)"
                                                size-class="w-8 h-8"
                                                icon-class="text-base"
                                            />
                                            <span class="truncate">{{
                                                getTeamName(match.team2_id) || "DA DEFINIRE"
                                            }}</span>
                                        </div>
                                        <span
                                            v-if="
                                                [
                                                    'in_progress',
                                                    'finished',
                                                    'retired',
                                                ].includes(match.status)
                                            "
                                            class="text-2xl mt-1"
                                            :class="
                                                match.winner_id ===
                                                match.team2_id
                                                    ? 'text-green-500'
                                                    : ''
                                            "
                                            >{{ match.team2_score || 0 }}</span
                                        >
                                    </div>
                                </div>
                                <div class="text-center mt-1">
                                    <span
                                        v-if="
                                            match.status !== 'pending' &&
                                            match.status !== 'in_progress'
                                        "
                                        class="text-[10px] font-bold uppercase tracking-widest text-gray-400 bg-gray-50 px-2 py-1 rounded"
                                        >{{ translateStatus(match.status) }}</span
                                    >
                                </div>
                            </div>
                            <div
                                v-if="!groupedGroupMatches[group.id]?.length"
                                class="text-center text-gray-400 text-sm font-bold uppercase py-4"
                            >
                                Nessun incontro programmato
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- KNOCKOUT BRACKET -->
            <div v-if="activeTab === 'knockout'" class="overflow-x-auto pb-8 custom-scrollbar">
                <div
                    v-if="Object.keys(groupedKnockoutMatches).length"
                    class="flex gap-4 sm:gap-8 min-w-max mx-auto justify-start xl:justify-center"
                >
                    <div
                        v-for="(
                            roundMatches, roundNum
                        ) in groupedKnockoutMatches"
                        :key="roundNum"
                        class="flex flex-col gap-4 sm:gap-6 w-[82vw] max-w-72 sm:w-72"
                    >
                        <h3
                            class="text-sm font-black text-black text-center uppercase tracking-widest bg-gray-50 py-3 rounded-xl border border-gray-100"
                        >
                            Turno {{ roundNum }}
                        </h3>

                        <div
                            v-for="(match, mIndex) in roundMatches"
                            :key="match.id"
                            class="interactive-card bg-white border rounded-2xl shadow-sm p-4 relative group overflow-hidden hover:-translate-y-0.5 hover:shadow-md"
                            :class="
                                match.status === 'in_progress'
                                    ? 'border-red-500 ring-1 ring-red-500'
                                    : 'border-gray-100'
                            "
                        >
                            <div
                                v-if="match.status === 'in_progress'"
                                class="absolute top-0 left-0 right-0 bg-red-500 text-white text-[10px] font-black uppercase tracking-widest text-center py-0.5 animate-pulse z-10"
                            >
                                ORA IN DIRETTA
                            </div>

                            <div
                                class="absolute -top-1 -left-1 bg-black text-white text-[10px] font-black px-2 py-1 rounded-br-lg shadow-sm z-20"
                                :class="{
                                    'mt-4': match.status === 'in_progress',
                                }"
                            >
                                M{{ mIndex + 1 }}
                            </div>

                            <div
                                class="flex flex-col gap-2"
                                :class="{
                                    'mt-4': match.status === 'in_progress',
                                }"
                            >
                                <!-- Team 1 -->
                                <div
                                    class="flex justify-between items-center px-3 py-3 bg-gray-50 rounded-xl border border-gray-100"
                                >
                                    <div class="flex items-center gap-2 min-w-0">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team1_id)"
                                            :alt="getTeamName(match.team1_id)"
                                            size-class="w-8 h-8"
                                            icon-class="text-base"
                                        />
                                        <span
                                            class="truncate"
                                            :class="
                                                match.team1_id
                                                    ? 'font-black text-black uppercase text-sm'
                                                    : 'text-gray-400 font-medium text-xs uppercase'
                                            "
                                        >
                                            {{
                                                match.team1_id
                                                    ? getTeamName(match.team1_id)
                                                    : match.team1_placeholder ||
                                                      getPlaceholder(
                                                          roundNum,
                                                          mIndex,
                                                          false,
                                                      )
                                            }}
                                        </span>
                                    </div>
                                    <span
                                        v-if="
                                            [
                                                'in_progress',
                                                'finished',
                                                'retired',
                                            ].includes(match.status)
                                        "
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team1_id
                                                ? 'text-green-500'
                                                : 'text-gray-400'
                                        "
                                    >
                                        {{ match.team1_score || 0 }}
                                    </span>
                                </div>

                                <div
                                    class="flex justify-center -my-3 z-10 relative"
                                >
                                    <span
                                        class="bg-white text-gray-400 text-[10px] font-black px-2 py-0.5 rounded-full border border-gray-100 uppercase"
                                        >VS</span
                                    >
                                </div>

                                <!-- Team 2 -->
                                <div
                                    class="flex justify-between items-center px-3 py-3 bg-gray-50 rounded-xl border border-gray-100"
                                >
                                    <div class="flex items-center gap-2 min-w-0">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team2_id)"
                                            :alt="getTeamName(match.team2_id)"
                                            size-class="w-8 h-8"
                                            icon-class="text-base"
                                        />
                                        <span
                                            class="truncate"
                                            :class="
                                                match.team2_id
                                                    ? 'font-black text-black uppercase text-sm'
                                                    : 'text-gray-400 font-medium text-xs uppercase'
                                            "
                                        >
                                            {{
                                                match.team2_id
                                                    ? getTeamName(match.team2_id)
                                                    : match.team2_placeholder ||
                                                      getPlaceholder(
                                                          roundNum,
                                                          mIndex,
                                                          true,
                                                      )
                                            }}
                                        </span>
                                    </div>
                                    <span
                                        v-if="
                                            [
                                                'in_progress',
                                                'finished',
                                                'retired',
                                            ].includes(match.status)
                                        "
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team2_id
                                                ? 'text-green-500'
                                                : 'text-gray-400'
                                        "
                                    >
                                        {{ match.team2_score || 0 }}
                                    </span>
                                </div>
                            </div>

                            <div
                                class="mt-4 flex justify-between items-center px-1"
                            >
                                <span
                                    class="text-xs font-bold uppercase tracking-widest"
                                    :class="
                                        match.start_time
                                            ? 'text-red-600'
                                            : 'text-gray-400'
                                    "
                                >
                                    {{ match.start_time || "ORARIO DA DEFINIRE" }}
                                </span>
                                <span
                                    v-if="
                                        match.status !== 'pending' &&
                                        match.status !== 'in_progress'
                                    "
                                    class="text-[10px] font-bold uppercase tracking-widest text-gray-400 bg-gray-50 px-2 py-1 rounded"
                                >
                                    {{ translateStatus(match.status) }}
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
                <div
                    v-else
                    class="text-center text-gray-400 py-16 bg-gray-50 rounded-2xl border border-dashed border-gray-200 font-bold uppercase tracking-wide"
                >
                    Il tabellone a eliminazione diretta non è stato ancora generato.
                </div>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";

const translateStatus = (s: string) => {
    if (s === "pending") return "In attesa";
    if (s === "in_progress") return "In corso";
    if (s === "completed" || s === "finished") return "Completato";
    if (s === "retired") return "Ritirato";
    return s;
};

const supabase = useSupabaseClient();
const { subscribeToAllMatches, unsubscribe } = useMatchRealtime();

const activeTab = ref("group");
const teams = ref<any[]>([]);
const groups = ref<any[]>([]);
const matches = ref<any[]>([]);
const pending = ref(true);
let realtimeChannel: any = null;

const groupedKnockoutMatches = computed(() => {
    const sorted: Record<number, any[]> = {};
    matches.value
        .filter((m) => m.match_type === "knockout")
        .forEach((match) => {
            if (!sorted[match.round]) sorted[match.round] = [];
            sorted[match.round].push(match);
        });
    return sorted;
});

const groupedGroupMatches = computed(() => {
    const sorted: Record<string, any[]> = {};
    matches.value
        .filter((m) => m.match_type === "group")
        .forEach((match) => {
            if (!match.group_id) return;
            if (!sorted[match.group_id]) sorted[match.group_id] = [];
            sorted[match.group_id].push(match);
        });
    return sorted;
});

const loadGroupsAndStandings = async () => {
    const { data: gData } = await supabase
        .from("groups")
        .select(
            `id, name, group_teams ( id, team_id, points, wins, losses, teams ( name, logo_url ) )`,
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
    const { data: tData } = await supabase
        .from("teams")
        .select("id, name, logo_url")
        .eq("status", "approved");
    if (tData) teams.value = tData;

    await loadGroupsAndStandings();

    const { data: mData } = await supabase
        .from("matches")
        .select("*")
        .order("round")
        .order("id");
    if (mData) matches.value = mData;

    // Set up Realtime listener
    realtimeChannel = subscribeToAllMatches((payload) => {
        const updatedMatch = payload.new;
        const index = matches.value.findIndex((m) => m.id === updatedMatch.id);

        if (index !== -1) {
            // Update the match reactively
            matches.value[index] = { ...matches.value[index], ...updatedMatch };

            // Reload standings as soon as a group match is resolved.
            if (
                updatedMatch.match_type === "group" &&
                ["completed", "retired"].includes(updatedMatch.status)
            ) {
                loadGroupsAndStandings();
            }
        }
    });

    pending.value = false;
};

const getTeamName = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.name;
const getTeamLogo = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.logo_url || null;

const getPlaceholder = (
    roundStr: string | number,
    mIndex: number,
    isTeam2: boolean,
) => {
    const r = parseInt(roundStr as string);
    if (r === 1) return "DA DEFINIRE";
    const prevMatchNum = mIndex * 2 + (isTeam2 ? 2 : 1);
    return `Vincitrice di T${r - 1} P${prevMatchNum}`;
};

onMounted(loadData);

onUnmounted(() => {
    unsubscribe(realtimeChannel);
});
</script>
