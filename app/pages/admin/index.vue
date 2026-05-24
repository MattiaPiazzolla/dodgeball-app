// app/pages/admin/index.vue
<script setup lang="ts">
definePageMeta({ middleware: ["admin"] });
const client = useSupabaseClient();

const teams = ref<any[]>([]);
const matches = ref<any[]>([]);
const topMvpPlayers = ref<any[]>([]);
const isLoading = ref(true);

const fetchAll = async () => {
    const [{ data: teamsData }, { data: matchesData }, { data: mvpData }] =
        await Promise.all([
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
        ]);
    teams.value = teamsData || [];
    matches.value = matchesData || [];
    topMvpPlayers.value = mvpData || [];
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
    await client.from("teams").update({ status }).eq("id", id);
    await fetchAll();
};

const confirmingDeleteId = ref<string | null>(null);

onMounted(fetchAll);
</script>

<template>
    <div class="max-w-6xl mx-auto px-4 py-8 space-y-10">
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
                            Group Stage Complete
                        </div>
                        <h2
                            class="text-3xl sm:text-4xl font-black uppercase tracking-tight leading-none"
                        >
                            Ready for the Draw
                        </h2>
                        <p class="text-white/80 font-medium max-w-md">
                            All group stage matches have been resolved. You can
                            now generate the knockout brackets.
                        </p>
                    </div>

                    <div class="relative z-10 w-full md:w-auto">
                        <NuxtLink
                            to="/admin/knockouts"
                            class="flex items-center justify-center gap-3 w-full md:w-auto px-8 py-5 bg-white text-red-600 rounded-2xl font-black uppercase tracking-widest hover:bg-yellow-400 hover:text-black transition-all hover:-translate-y-1 hover:shadow-xl"
                        >
                            <Icon name="mdi:whistle" class="text-xl" />
                            Generate Bracket
                        </NuxtLink>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Dashboard
                </h2>
                <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <div
                        class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Approved Teams</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            approvedTeams.length
                        }}</span>
                    </div>
                    <div
                        class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1 relative overflow-hidden"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Pending Requests</span
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
                        class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Total Matches</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            totalMatches
                        }}</span>
                        <span class="text-xs text-gray-400 font-medium"
                            >{{ completedMatches }} completed</span
                        >
                    </div>
                    <div
                        class="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 flex flex-col gap-1"
                    >
                        <span
                            class="text-xs font-bold uppercase tracking-wide text-gray-400"
                            >Scheduled Matches</span
                        >
                        <span class="text-4xl font-black text-black">{{
                            pendingMatches
                        }}</span>
                        <span class="text-xs text-gray-400 font-medium"
                            >awaiting play</span
                        >
                    </div>
                </div>
            </section>

            <section v-if="nextMatch">
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Next Match
                </h2>
                <div
                    class="bg-black text-white rounded-2xl p-6 flex flex-col sm:flex-row items-center justify-between gap-6"
                >
                    <div class="flex items-center gap-4 flex-1">
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
                            class="text-xl font-black uppercase tracking-tight"
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
                            {{ nextMatch.match_type }}
                        </span>
                    </div>
                    <div class="flex items-center gap-4 flex-1 justify-end">
                        <span
                            class="text-xl font-black uppercase tracking-tight text-right"
                            >{{
                                getTeamName(nextMatch.nextMatch?.team2_id) ||
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
                    Live MVP Standings (Top Candidates)
                </h2>
                <div
                    class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden"
                >
                    <div
                        v-if="topMvpPlayers.length === 0"
                        class="py-12 text-center text-gray-400 font-medium"
                    >
                        No MVP votes submitted yet. 🗳️
                    </div>
                    <div v-else>
                        <div
                            v-for="(player, idx) in topMvpPlayers"
                            :key="player.id"
                            class="flex items-center justify-between px-6 py-4 hover:bg-gray-50 transition-colors"
                            :class="
                                idx < topMvpPlayers.length - 1
                                    ? 'border-b border-gray-100'
                                    : ''
                            "
                        >
                            <div class="flex items-center gap-4">
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
                                <div>
                                    <div class="flex items-center gap-2">
                                        <span
                                            class="font-black uppercase tracking-tight text-black"
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
                                class="bg-gray-50 px-4 py-2 rounded-xl border border-gray-100 font-black text-black text-sm shadow-inner flex items-center gap-2"
                            >
                                <Icon
                                    name="mdi:thumb-up"
                                    class="text-red-500 text-xs"
                                />
                                <span>{{ player.mvp_votes }} Votes</span>
                            </div>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Registration Requests
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
                        No pending requests. 🎉
                    </div>
                    <div
                        v-for="(team, i) in pendingTeams"
                        :key="team.id"
                        class="flex items-center justify-between px-6 py-4 hover:bg-yellow-50/40 transition-colors"
                        :class="
                            i < pendingTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-4">
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
                            <div>
                                <span
                                    class="font-black uppercase tracking-tight text-black block"
                                    >{{ team.name }}</span
                                >
                                <span class="text-xs text-gray-400 font-medium"
                                    >Requested
                                    {{
                                        new Date(
                                            team.created_at,
                                        ).toLocaleDateString()
                                    }}</span
                                >
                            </div>
                        </div>
                        <div class="flex gap-2">
                            <button
                                @click="setStatus(team.id, 'approved')"
                                class="px-4 py-1.5 bg-green-100 text-green-700 hover:bg-green-200 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                            >
                                Approve
                            </button>
                            <button
                                @click="setStatus(team.id, 'rejected')"
                                class="px-4 py-1.5 bg-red-100 text-red-600 hover:bg-red-200 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                            >
                                Reject
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            <section>
                <h2
                    class="text-xs font-black uppercase tracking-widest text-gray-400 mb-4"
                >
                    Approved Teams
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
                        No approved teams yet.
                    </div>
                    <div
                        v-for="(team, i) in approvedTeams"
                        :key="team.id"
                        class="flex items-center justify-between px-6 py-4 hover:bg-gray-50 transition-colors"
                        :class="
                            i < approvedTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-4">
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
                                class="font-black uppercase tracking-tight text-black"
                                >{{ team.name }}</span
                            >
                        </div>
                        <div class="flex items-center gap-2">
                            <template v-if="confirmingDeleteId === team.id">
                                <span
                                    class="text-xs font-bold text-red-600 uppercase tracking-wide"
                                    >Reject team?</span
                                >
                                <button
                                    @click="
                                        setStatus(team.id, 'rejected');
                                        confirmingDeleteId = null;
                                    "
                                    class="px-4 py-1.5 bg-red-600 text-white hover:bg-red-700 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Yes
                                </button>
                                <button
                                    @click="confirmingDeleteId = null"
                                    class="px-4 py-1.5 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Cancel
                                </button>
                            </template>
                            <template v-else>
                                <button
                                    @click="confirmingDeleteId = team.id"
                                    class="px-4 py-1.5 bg-red-50 text-red-500 hover:bg-red-100 rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Remove
                                </button>
                                <NuxtLink
                                    :to="`/admin/teams/${team.id}`"
                                    class="px-4 py-1.5 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                                >
                                    Manage
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
                    Rejected
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
                        class="flex items-center justify-between px-6 py-4 hover:bg-gray-50 transition-colors opacity-60"
                        :class="
                            i < rejectedTeams.length - 1
                                ? 'border-b border-gray-100'
                                : ''
                        "
                    >
                        <div class="flex items-center gap-4">
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
                                class="font-black uppercase tracking-tight text-gray-500 line-through"
                                >{{ team.name }}</span
                            >
                        </div>
                        <button
                            @click="setStatus(team.id, 'pending')"
                            class="px-4 py-1.5 bg-gray-100 hover:bg-gray-200 text-black rounded-xl font-bold uppercase text-xs tracking-wide transition-colors"
                        >
                            Restore
                        </button>
                    </div>
                </div>
            </section>
        </template>
    </div>
</template>
