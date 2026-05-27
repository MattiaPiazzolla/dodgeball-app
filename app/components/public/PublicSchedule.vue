// components/public/PublicSchedule.vue
<template>
    <div class="space-y-6 sm:space-y-8 relative">
        <div class="text-center space-y-3 mb-8 sm:mb-12 mobile-fade-in">
            <h1 class="font-impact text-4xl sm:text-5xl text-black">
                Calendario del Torneo
            </h1>
            <p class="text-gray-500 font-medium">
                Orari, incontri, risultati in tempo reale e classifiche dei gironi.
            </p>
            <div class="w-16 h-1 bg-primary mx-auto"></div>
        </div>

        <div
            v-if="pending"
            class="text-center text-primary py-12 font-impact text-xl animate-pulse tracking-wider"
        >
            CARICAMENTO CALENDARIO...
        </div>

        <div v-else class="mobile-fade-in">
            <!-- Tabs — full width on mobile -->
            <div
                v-if="hasKnockoutMatches"
                class="flex border-2 border-black w-full max-w-md mx-auto mb-6 sm:mb-10 shadow-[2px_2px_0px_rgba(0,0,0,1)] bg-white"
            >
                <button
                    @click="activeTab = 'knockout'"
                    :class="
                        activeTab === 'knockout'
                            ? 'bg-black text-white border-r-2 border-black'
                            : 'text-secondary hover:bg-gray-100 border-r-2 border-black'
                    "
                    class="flex-1 py-3 font-impact uppercase tracking-wider text-xs sm:text-sm transition-all text-center select-none"
                >
                    Eliminazione
                </button>
                <button
                    @click="activeTab = 'group'"
                    :class="
                        activeTab === 'group'
                            ? 'bg-black text-white'
                            : 'text-secondary hover:bg-gray-100'
                    "
                    class="flex-1 py-3 font-impact uppercase tracking-wider text-xs sm:text-sm transition-all text-center select-none"
                >
                    Gironi
                </button>
            </div>

            <!-- GROUP STAGE -->
            <div v-if="activeTab === 'group'" class="space-y-8 sm:space-y-12">
                <div
                    v-if="groups.length === 0"
                    class="text-center text-secondary py-16 bg-white border-4 border-black font-impact tracking-widest uppercase shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                >
                    La fase a gironi non è stata ancora sorteggiata.
                </div>

                <div
                    v-for="group in groups"
                    :key="group.id"
                    class="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-6 bg-cement p-3 sm:p-6 border-4 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                >
                    <!-- Standings -->
                    <div class="space-y-4">
                        <h3
                            class="text-xl font-impact text-black tracking-wider"
                        >
                            Classifica {{ group.name }}
                        </h3>
                        <div
                            class="bg-white border-2 border-black overflow-hidden shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                        >
                            <table class="w-full table-fixed text-left text-xs sm:text-sm">
                                <thead
                                    class="bg-secondary text-white border-b-2 border-black font-impact tracking-wider uppercase text-xs"
                                >
                                    <tr>
                                        <th class="w-[52%] p-3">Squadra</th>
                                        <th class="w-[16%] p-3 text-center">V</th>
                                        <th class="w-[16%] p-3 text-center">P</th>
                                        <th class="w-[16%] p-3 text-center text-primary">Pt</th>
                                    </tr>
                                </thead>
                                <tbody class="divide-y-2 divide-black">
                                    <tr
                                        v-for="gt in group.group_teams"
                                        :key="gt.id"
                                        class="hover:bg-gray-50 transition-colors"
                                    >
                                        <td class="p-3">
                                            <div class="flex items-center gap-2 min-w-0">
                                                <PublicTeamLogo
                                                    :src="gt.teams?.logo_url"
                                                    :alt="gt.teams?.name"
                                                    size-class="w-7 h-7 border border-black shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
                                                    icon-class="text-sm"
                                                />
                                                <span class="font-impact text-sm text-black truncate">
                                                    {{ gt.teams?.name || "Unknown" }}
                                                </span>
                                            </div>
                                        </td>
                                        <td
                                            class="p-3 text-center font-bold text-secondary"
                                        >
                                            {{ gt.wins }}
                                        </td>
                                        <td
                                            class="p-3 text-center font-bold text-secondary"
                                        >
                                            {{ gt.losses }}
                                        </td>
                                        <td
                                            class="p-3 text-center font-impact text-primary text-lg"
                                        >
                                            {{ gt.points }}
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <!-- Matches -->
                    <div class="space-y-4">
                        <h3
                            class="text-xl font-impact text-black tracking-wider"
                        >
                            Partite
                        </h3>
                        <div class="space-y-4">
                            <div
                                v-for="match in groupedGroupMatches[group.id]"
                                :key="match.id"
                                class="border-2 border-black p-3 sm:p-4 flex flex-col gap-2 relative overflow-hidden transition-all hover:translate-y-[-1px]"
                                :class="
                                    match.status === 'in_progress'
                                        ? 'bg-red-50 !border-primary shadow-[0_0_15px_rgba(211,47,47,0.5)] ring-1 ring-primary'
                                        : 'bg-white shadow-[3px_3px_0px_rgba(0,0,0,1)]'
                                "
                            >
                                <div
                                    v-if="match.status === 'in_progress'"
                                    class="absolute top-0 left-0 right-0 bg-primary text-white text-[10px] font-impact tracking-widest text-center py-1 animate-pulse"
                                >
                                    ORA IN DIRETTA
                                </div>

                                <div
                                    class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center justify-between"
                                    :class="match.status === 'in_progress' ? 'mt-4' : 'mt-2'"
                                >
                                    <!-- Team 1 -->
                                    <div
                                        class="min-w-0 text-right pr-2 sm:pr-4 font-impact text-xs sm:text-sm flex flex-col items-end"
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
                                                size-class="w-8 h-8 border border-black shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
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
                                            class="text-2xl mt-1 font-impact"
                                            :class="
                                                match.winner_id ===
                                                match.team1_id
                                                    ? 'text-primary'
                                                    : 'text-gray-400'
                                            "
                                            >{{ match.team1_score || 0 }}</span
                                        >
                                    </div>

                                    <!-- Divider vs -->
                                    <div
                                        class="flex flex-col items-center justify-center px-2 sm:px-4 border-x-2 border-black min-w-[76px] sm:min-w-[100px]"
                                    >
                                        <span
                                            class="text-[10px] font-impact mb-1 tracking-wider text-primary min-h-[15px]"
                                            >{{ match.start_time || "" }}</span
                                        >
                                        <span
                                            class="bg-secondary text-white text-[9px] font-impact px-2 py-0.5 transform -skew-x-6 tracking-widest border border-black"
                                            >VS</span
                                        >
                                    </div>

                                    <!-- Team 2 -->
                                    <div
                                        class="min-w-0 text-left pl-2 sm:pl-4 font-impact text-xs sm:text-sm flex flex-col"
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
                                                size-class="w-8 h-8 border border-black shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
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
                                            class="text-2xl mt-1 font-impact"
                                            :class="
                                                match.winner_id ===
                                                match.team2_id
                                                    ? 'text-primary'
                                                    : 'text-gray-400'
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
                                        class="text-[9px] font-impact uppercase tracking-widest text-white bg-secondary px-2 py-0.5 border border-black transform -skew-x-6"
                                        >{{ translateStatus(match.status) }}</span
                                    >
                                </div>
                            </div>
                            <div
                                v-if="!groupedGroupMatches[group.id]?.length"
                                class="text-center text-gray-400 text-xs font-impact uppercase py-4"
                            >
                                Nessun incontro programmato
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- KNOCKOUT BRACKET -->
            <div v-if="activeTab === 'knockout'" 
                 class="overflow-x-auto pb-8 custom-scrollbar transition-colors duration-1000"
                 :class="{
                     'bg-[#111111] py-8 rounded-none border-y-4 border-yellow-400 shadow-[0_0_50px_rgba(250,204,21,0.2)]': isFinaleLive
                 }"
            >
                <div
                    v-if="Object.keys(groupedKnockoutMatches).length"
                    class="flex gap-6 sm:gap-8 min-w-max mx-auto justify-start xl:justify-center p-2"
                >
                    <div
                        v-for="(
                            roundMatches, roundNum
                        ) in groupedKnockoutMatches"
                        :key="roundNum"
                        class="flex flex-col gap-4 sm:gap-6 w-[82vw] max-w-72 sm:w-72"
                    >
                        <h3
                            class="text-sm sm:text-base font-impact text-center uppercase tracking-widest py-3 border-2 border-black shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-colors"
                            :class="[
                                roundLabel(roundNum) === 'Finale' 
                                    ? 'bg-yellow-400 text-black text-lg sm:text-xl' 
                                    : (isFinaleLive ? 'bg-zinc-800 text-zinc-400 border-zinc-600 shadow-none' : 'bg-secondary text-white')
                            ]"
                        >
                            {{ roundLabel(roundNum) }}
                        </h3>

                        <div
                            v-for="(match, mIndex) in roundMatches"
                            :key="match.id"
                            class="border-2 p-4 relative group overflow-hidden transition-all hover:translate-y-[-1px]"
                            :class="[
                                match.status === 'in_progress'
                                    ? (roundLabel(roundNum) === 'Finale' ? 'bg-black border-yellow-400 shadow-[0_0_30px_rgba(250,204,21,0.6)] ring-2 ring-yellow-400' : 'bg-red-50 !border-primary shadow-[0_0_15px_rgba(211,47,47,0.5)] ring-1 ring-primary')
                                    : (isFinaleLive ? 'bg-zinc-900 border-zinc-700 opacity-60 shadow-none' : 'bg-white border-black shadow-[3px_3px_0px_rgba(0,0,0,1)]')
                            ]"
                        >
                            <div
                                v-if="match.status === 'in_progress'"
                                class="absolute top-0 left-0 right-0 text-white text-[10px] font-impact tracking-widest text-center py-1 z-10 animate-pulse transition-colors"
                                :class="roundLabel(roundNum) === 'Finale' ? 'bg-yellow-500 text-black' : 'bg-primary'"
                            >
                                ORA IN DIRETTA
                            </div>

                            <div
                                class="absolute -top-0.5 -left-0.5 bg-black text-white text-[10px] font-impact px-2 py-0.5 z-20 border-r-2 border-b-2"
                                :class="[
                                    {'mt-5': match.status === 'in_progress'},
                                    isFinaleLive && roundLabel(roundNum) !== 'Finale' ? 'border-zinc-700' : 'border-black',
                                    isFinaleLive && roundLabel(roundNum) === 'Finale' ? 'text-yellow-400 border-yellow-400' : ''
                                ]"
                            >
                                M{{ mIndex + 1 }}
                            </div>

                            <div
                                class="flex flex-col gap-2"
                                :class="{
                                    'mt-5': match.status === 'in_progress',
                                }"
                            >
                                <!-- Team 1 -->
                                <div
                                    class="flex justify-between items-center px-3 py-2 border-2 transition-colors"
                                    :class="[
                                        (match.status === 'in_progress' && roundLabel(roundNum) === 'Finale') 
                                            ? 'bg-black border-yellow-400 shadow-[1px_1px_0px_rgba(250,204,21,1)]' 
                                            : (isFinaleLive ? 'bg-zinc-800 border-zinc-700 shadow-none' : 'bg-white border-black shadow-[1px_1px_0px_rgba(0,0,0,1)]')
                                    ]"
                                >
                                    <div class="flex items-center gap-2 min-w-0">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team1_id)"
                                            :alt="getTeamName(match.team1_id)"
                                            size-class="w-7 h-7 border rounded-none"
                                            icon-class="text-xs"
                                            :class="isFinaleLive && roundLabel(roundNum) !== 'Finale' ? 'border-zinc-600 opacity-50' : 'border-black shadow-[1px_1px_0px_rgba(0,0,0,1)]'"
                                        />
                                        <span
                                            class="truncate font-impact text-sm"
                                            :class="[
                                                match.team1_id 
                                                    ? (isFinaleLive && roundLabel(roundNum) !== 'Finale' ? 'text-zinc-300' : 'text-black') 
                                                    : (isFinaleLive ? 'text-zinc-500 font-medium text-xs uppercase' : 'text-gray-400 font-medium text-xs uppercase'),
                                                (match.status === 'in_progress' && roundLabel(roundNum) === 'Finale' && match.team1_id) ? '!text-yellow-400' : ''
                                            ]"
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
                                        class="font-impact text-lg"
                                        :class="
                                            match.winner_id === match.team1_id
                                                ? 'text-primary'
                                                : (isFinaleLive ? 'text-zinc-500' : 'text-gray-400')
                                        "
                                    >
                                        {{ match.team1_score || 0 }}
                                    </span>
                                </div>

                                <div
                                    class="flex justify-center -my-3.5 z-10 relative"
                                >
                                    <span
                                        class="text-[9px] font-impact px-2 py-0.5 rounded-none border transform -skew-x-6 uppercase tracking-wider transition-colors"
                                        :class="[
                                            (match.status === 'in_progress' && roundLabel(roundNum) === 'Finale') 
                                                ? 'bg-yellow-500 text-black border-yellow-400' 
                                                : (isFinaleLive ? 'bg-zinc-700 text-zinc-400 border-zinc-600' : 'bg-secondary text-white border-black')
                                        ]"
                                        >VS</span
                                    >
                                </div>

                                <!-- Team 2 -->
                                <div
                                    class="flex justify-between items-center px-3 py-2 border-2 transition-colors"
                                    :class="[
                                        (match.status === 'in_progress' && roundLabel(roundNum) === 'Finale') 
                                            ? 'bg-black border-yellow-400 shadow-[1px_1px_0px_rgba(250,204,21,1)]' 
                                            : (isFinaleLive ? 'bg-zinc-800 border-zinc-700 shadow-none' : 'bg-white border-black shadow-[1px_1px_0px_rgba(0,0,0,1)]')
                                    ]"
                                >
                                    <div class="flex items-center gap-2 min-w-0">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team2_id)"
                                            :alt="getTeamName(match.team2_id)"
                                            size-class="w-7 h-7 border rounded-none"
                                            icon-class="text-xs"
                                            :class="isFinaleLive && roundLabel(roundNum) !== 'Finale' ? 'border-zinc-600 opacity-50' : 'border-black shadow-[1px_1px_0px_rgba(0,0,0,1)]'"
                                        />
                                        <span
                                            class="truncate font-impact text-sm"
                                            :class="[
                                                match.team2_id 
                                                    ? (isFinaleLive && roundLabel(roundNum) !== 'Finale' ? 'text-zinc-300' : 'text-black') 
                                                    : (isFinaleLive ? 'text-zinc-500 font-medium text-xs uppercase' : 'text-gray-400 font-medium text-xs uppercase'),
                                                (match.status === 'in_progress' && roundLabel(roundNum) === 'Finale' && match.team2_id) ? '!text-yellow-400' : ''
                                            ]"
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
                                        class="font-impact text-lg"
                                        :class="
                                            match.winner_id === match.team2_id
                                                ? 'text-primary'
                                                : (isFinaleLive ? 'text-zinc-500' : 'text-gray-400')
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
                                    class="text-xs font-impact tracking-wider min-w-[30px]"
                                    :class="(match.status === 'in_progress' && roundLabel(roundNum) === 'Finale') ? 'text-yellow-400' : (isFinaleLive ? 'text-zinc-500' : 'text-primary')"
                                >
                                    {{ match.start_time || "" }}
                                </span>
                                <span
                                    v-if="
                                        match.status !== 'pending' &&
                                        match.status !== 'in_progress'
                                    "
                                    class="text-[9px] font-impact uppercase tracking-widest px-2 py-0.5 border transform -skew-x-6"
                                    :class="isFinaleLive ? 'bg-zinc-700 text-zinc-300 border-zinc-600' : 'bg-secondary text-white border-black'"
                                >
                                    {{ translateStatus(match.status) }}
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
                <div
                    v-else
                    class="text-center text-secondary py-16 bg-white border-4 border-black font-impact tracking-widest uppercase shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                >
                    Il tabellone a eliminazione diretta non è stato ancora generato.
                </div>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from "vue";

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

const hasKnockoutMatches = computed(() => {
    return matches.value.some((m) => m.match_type === "knockout");
});

watch(hasKnockoutMatches, (hasKnockout) => {
    if (!hasKnockout && activeTab.value === "knockout") {
        activeTab.value = "group";
    }
});

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

const isFinaleLive = computed(() => {
    const total = Object.keys(groupedKnockoutMatches.value).length;
    if (total === 0) return false;
    const finalMatches = groupedKnockoutMatches.value[total] || [];
    return finalMatches.some((m: any) => m.status === 'in_progress');
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

const roundLabel = (r: string | number) => {
    const roundNum = typeof r === "string" ? parseInt(r) : r;
    const total = Object.keys(groupedKnockoutMatches.value).length;
    if (total === 0) return `Turno ${roundNum}`;
    
    if (roundNum === total) return "Finale";
    if (roundNum === total - 1) return "Semifinali";
    if (roundNum === total - 2) return "Quarti di Finale";
    return `Turno ${roundNum}`;
};

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
    if (mData) {
        matches.value = mData;
        const hasKnockout = mData.some((m) => m.match_type === "knockout");
        activeTab.value = hasKnockout ? "knockout" : "group";
    }

    realtimeChannel = subscribeToAllMatches((payload) => {
        const changedMatch = payload.new || payload.old;
        if (!changedMatch?.id) return;

        if (payload.eventType === "DELETE") {
            matches.value = matches.value.filter(
                (match) => match.id !== changedMatch.id,
            );
        } else {
            const index = matches.value.findIndex(
                (match) => match.id === changedMatch.id,
            );

            if (index !== -1) {
                matches.value[index] = {
                    ...matches.value[index],
                    ...changedMatch,
                };
            } else {
                matches.value.push(changedMatch);
            }
        }

        matches.value.sort(
            (a, b) =>
                (a.round || 0) - (b.round || 0) ||
                (a.start_time || "").localeCompare(b.start_time || "") ||
                a.id.localeCompare(b.id),
        );

        if (changedMatch.match_type === "group") {
            loadGroupsAndStandings();
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
