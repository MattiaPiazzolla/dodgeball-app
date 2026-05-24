// components/public/PublicTeams.vue
<template>
    <div class="space-y-6 sm:space-y-8">
        <div class="text-center space-y-3 mb-8 sm:mb-12 mobile-fade-in">
            <h1 class="text-3xl sm:text-4xl font-black uppercase tracking-tight text-black">
                Squadre Partecipanti
            </h1>
            <p class="text-gray-500 font-medium">
                Apri una squadra per vedere rosa e candidati MVP.
            </p>
        </div>

        <div
            v-if="pending"
            class="text-center text-gray-500 py-12 font-bold animate-pulse"
        >
            CARICAMENTO SQUADRE...
        </div>

        <div
            v-else-if="teams.length"
            class="grid grid-cols-1 min-[420px]:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 sm:gap-6"
        >
            <div
                v-for="team in teams"
                :key="team.id"
                @click="openModal(team)"
                class="interactive-card bg-white border border-gray-100 rounded-3xl p-5 sm:p-6 shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all text-center flex flex-col items-center justify-center min-h-[200px] sm:min-h-[230px] cursor-pointer group"
            >
                <PublicTeamLogo
                    :src="team.logo_url"
                    :alt="team.name"
                    size-class="w-20 h-20 sm:w-24 sm:h-24 mb-4 group-hover:bg-red-50 group-hover:text-red-500 group-hover:scale-105 transition-all"
                    icon-class="text-5xl"
                />
                <h2
                    class="text-lg sm:text-xl font-black uppercase text-black tracking-wide"
                >
                    {{ team.name }}
                </h2>
                <span class="text-xs font-bold text-red-500 uppercase mt-2"
                    >Vedi rosa</span
                >
            </div>
        </div>

        <div
            v-else
            class="text-center text-gray-400 py-16 bg-gray-50 rounded-3xl border border-dashed border-gray-200 font-bold uppercase tracking-wide"
        >
            Nessuna squadra è stata ancora approvata.
        </div>

        <!-- Team Details Modal -->
        <div
            v-if="showModal"
            class="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center z-50 p-0 sm:p-4 mobile-fade-in"
        >
            <div
                class="bg-white rounded-t-[2rem] sm:rounded-3xl shadow-2xl max-w-2xl w-full max-h-[92dvh] overflow-y-auto custom-scrollbar"
            >
                <div
                    class="sticky top-0 bg-white/90 backdrop-blur-md px-5 py-4 sm:p-6 border-b border-gray-100 flex justify-between items-center z-10"
                >
                    <h2
                        class="text-xl sm:text-2xl font-black uppercase text-black tracking-tight truncate pr-4"
                    >
                        {{ selectedTeam?.name }}
                    </h2>
                    <button
                        @click="closeModal"
                        class="text-gray-400 hover:text-red-600 transition-all bg-gray-50 hover:bg-red-50 p-2 rounded-full shrink-0 active:scale-90"
                    >
                        <Icon name="mdi:close" class="text-xl block" />
                    </button>
                </div>

                <div class="p-4 sm:p-6">
                    <div
                        v-if="loadingRoster"
                        class="text-center text-gray-500 py-8 font-bold animate-pulse uppercase tracking-widest"
                    >
                        Caricamento giocatori...
                    </div>

                    <div
                        v-else-if="roster.length"
                        class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4"
                    >
                        <div
                            v-for="player in roster"
                            :key="player.id"
                            class="interactive-card flex items-center justify-between bg-gray-50 border border-gray-100 p-3 sm:p-4 rounded-2xl hover:border-gray-200 hover:bg-white transition-all"
                        >
                            <div class="flex items-center gap-3 sm:gap-4 min-w-0">
                                <div
                                    class="w-14 h-14 sm:w-16 sm:h-16 bg-gray-200 rounded-full overflow-hidden flex-shrink-0 border-2 border-white shadow-sm flex items-center justify-center text-gray-400"
                                >
                                    <img
                                        v-if="player.photo_url"
                                        :src="player.photo_url"
                                        :alt="player.name"
                                        class="w-full h-full object-cover"
                                    />
                                    <Icon
                                        v-else
                                        name="mdi:account"
                                        class="text-3xl"
                                    />
                                </div>
                                <div class="min-w-0">
                                    <div
                                        class="font-black text-black uppercase text-sm truncate"
                                    >
                                        {{ player.name }}
                                    </div>
                                    <div
                                        v-if="player.nickname"
                                        class="text-gray-500 text-xs font-bold uppercase mt-0.5"
                                    >
                                        "{{ player.nickname }}"
                                    </div>
                                    <div
                                        class="text-red-600 font-black text-sm mt-1"
                                    >
                                        #{{ player.jersey_number || "00" }}
                                    </div>
                                </div>
                            </div>

                            <!-- MVP Voting Block -->
                            <div
                                class="flex flex-col items-center justify-center gap-1 pl-2"
                            >
                                <button
                                    @click="voteForPlayer(player.id)"
                                    :disabled="hasVoted(player.id)"
                                    class="w-11 h-11 sm:w-10 sm:h-10 rounded-full flex items-center justify-center transition-all shadow-sm border active:scale-90"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'bg-green-100 border-green-200 text-green-600 cursor-not-allowed'
                                            : 'bg-white border-gray-200 text-gray-400 hover:text-red-500 hover:border-red-200 hover:shadow'
                                    "
                                >
                                    <Icon
                                        :name="
                                            hasVoted(player.id)
                                                ? 'mdi:thumb-up'
                                                : 'mdi:thumb-up-outline'
                                        "
                                        class="text-lg"
                                    />
                                </button>
                                <span
                                    class="text-[10px] font-black uppercase text-gray-400 tracking-wider"
                                >
                                    {{ player.mvp_votes || 0 }} Voti
                                </span>
                            </div>
                        </div>
                    </div>

                    <div
                        v-else
                        class="text-center text-gray-400 py-12 font-bold uppercase tracking-wide border-2 border-dashed border-gray-100 rounded-2xl"
                    >
                        Nessun giocatore trovato per questa squadra.
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { Icon } from "#components";

const supabase = useSupabaseClient();
const teams = ref<any[]>([]);
const pending = ref(true);

const showModal = ref(false);
const selectedTeam = ref<any>(null);
const roster = ref<any[]>([]);
const loadingRoster = ref(false);

const trackingVotes = ref<Record<string, boolean>>({});

const loadTeams = async () => {
    pending.value = true;
    const { data } = await supabase
        .from("teams")
        .select("*")
        .eq("status", "approved")
        .order("name");

    if (data) teams.value = data;
    pending.value = false;
};

const openModal = async (team: any) => {
    selectedTeam.value = team;
    showModal.value = true;
    loadingRoster.value = true;

    const { data } = await supabase
        .from("players")
        .select("*")
        .eq("team_id", team.id)
        .order("name");

    if (data) {
        roster.value = data;
        // Seed voting references from local storage layout
        data.forEach((p: any) => {
            trackingVotes.value[p.id] = !!localStorage.getItem(
                `voted_mvp_player_${p.id}`,
            );
        });
    }
    loadingRoster.value = false;
};

const closeModal = () => {
    showModal.value = false;
    selectedTeam.value = null;
    roster.value = [];
};

const hasVoted = (playerId: string) => {
    return !!trackingVotes.value[playerId];
};

const voteForPlayer = async (playerId: string) => {
    if (hasVoted(playerId)) return;

    // Optimistic UI updates
    const player = roster.value.find((p) => p.id === playerId);
    if (player) {
        player.mvp_votes = (player.mvp_votes || 0) + 1;
    }
    trackingVotes.value[playerId] = true;
    localStorage.setItem(`voted_mvp_player_${playerId}`, "true");

    // Persist incrementally directly to back-end counter system
    await supabase.rpc("increment_player_votes", { player_uuid: playerId });
};

onMounted(loadTeams);
</script>
