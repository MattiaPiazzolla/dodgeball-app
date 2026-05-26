// components/public/PublicTeams.vue
<template>
    <div class="space-y-6 sm:space-y-8">
        <div class="text-center space-y-3 mb-8 sm:mb-12 mobile-fade-in">
            <h1 class="font-impact text-4xl sm:text-5xl text-black">
                Squadre Partecipanti
            </h1>
            <p class="text-gray-500 font-medium">
                Apri una squadra per vedere la rosa dei giocatori e votare i candidati MVP.
            </p>
            <div class="w-16 h-1 bg-primary mx-auto"></div>
        </div>

        <div
            v-if="pending"
            class="text-center text-primary py-12 font-impact text-xl animate-pulse tracking-wider"
        >
            CARICAMENTO SQUADRE...
        </div>

        <div
            v-else-if="teams.length"
            class="grid grid-cols-1 min-[420px]:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6"
        >
            <div
                v-for="team in teams"
                :key="team.id"
                @click="openModal(team)"
                class="card-grunge p-6 text-center flex flex-col items-center justify-center min-h-[220px] sm:min-h-[240px] cursor-pointer group"
            >
                <PublicTeamLogo
                    :src="team.logo_url"
                    :alt="team.name"
                    size-class="w-20 h-20 sm:w-24 sm:h-24 mb-4 group-hover:bg-primary/10 group-hover:text-primary group-hover:scale-105 transition-all border-2 border-black rounded-none shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                    icon-class="text-5xl"
                />
                <h2
                    class="font-impact text-xl text-black tracking-wide"
                >
                    {{ team.name }}
                </h2>
                
                <span class="text-xs font-impact text-primary uppercase mt-3 px-3 py-1 border-2 border-black group-hover:bg-black group-hover:text-white transition-all transform -skew-x-6 shadow-[1px_1px_0px_rgba(0,0,0,1)]">
                    Vedi rosa
                </span>
            </div>
        </div>

        <div
            v-else
            class="text-center text-secondary py-16 bg-white border-4 border-black font-impact tracking-widest uppercase shadow-[4px_4px_0px_rgba(0,0,0,1)]"
        >
            Nessuna squadra è stata ancora approvata.
        </div>

        <!-- Team Details Modal — full screen -->
        <div
            v-if="showModal"
            class="fixed inset-0 bg-white z-50 flex flex-col mobile-fade-in"
        >
            <!-- Sticky Header -->
            <div
                class="sticky top-0 bg-white border-b-4 border-black px-5 py-4 sm:px-8 sm:py-5 flex justify-between items-center z-10 shadow-[0_4px_0px_rgba(0,0,0,1)] flex-shrink-0"
            >
                <h2
                    class="font-impact text-2xl sm:text-4xl text-black tracking-widest uppercase truncate pr-4"
                >
                    {{ selectedTeam?.name }}
                </h2>
                <button
                    @click="closeModal"
                    class="text-secondary hover:text-white transition-all bg-white border-2 border-black hover:bg-primary p-2 shrink-0 shadow-[2px_2px_0px_rgba(0,0,0,1)] active:translate-y-0.5 active:shadow-none"
                >
                    <span class="relative w-5 h-5 flex items-center justify-center">
                        <span class="absolute block w-5 h-0.5 bg-current rotate-45"></span>
                        <span class="absolute block w-5 h-0.5 bg-current -rotate-45"></span>
                    </span>
                </button>
            </div>

            <!-- Scrollable Content -->
            <div class="flex-1 overflow-y-auto custom-scrollbar bg-cement">
                <div class="max-w-4xl mx-auto px-4 sm:px-8 py-8">
                    <div
                        v-if="loadingRoster"
                        class="text-center text-primary py-20 font-impact text-xl animate-pulse uppercase tracking-widest"
                    >
                        Caricamento giocatori...
                    </div>

                    <div
                        v-else-if="roster.length"
                        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6"
                    >
                        <div
                            v-for="player in roster"
                            :key="player.id"
                            class="flex items-center justify-between bg-white border-2 border-black p-4 shadow-[3px_3px_0px_rgba(0,0,0,1)] hover:-translate-y-0.5 transition-all"
                        >
                            <div class="flex items-center gap-3 sm:gap-4 min-w-0">
                                <div
                                    class="w-14 h-14 sm:w-16 sm:h-16 bg-gray-200 border-2 border-black overflow-hidden flex-shrink-0 flex items-center justify-center text-gray-400 shadow-[1px_1px_0px_rgba(0,0,0,1)]"
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
                                        class="font-impact text-base text-black tracking-wide truncate"
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
                                        class="text-primary font-impact text-lg mt-0.5"
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
                                    class="w-10 h-10 flex items-center justify-center transition-all border-2 border-black active:scale-90"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'bg-green-500 border-black text-white cursor-not-allowed shadow-[1px_1px_0px_rgba(0,0,0,1)]'
                                            : 'bg-white border-black text-secondary hover:bg-primary hover:text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]'
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
                                    class="text-[10px] font-impact uppercase text-secondary tracking-widest mt-1"
                                >
                                    {{ player.mvp_votes || 0 }} Voti
                                </span>
                            </div>
                        </div>
                    </div>

                    <div
                        v-else
                        class="text-center text-secondary py-20 font-impact tracking-wider border-4 border-dashed border-black bg-white shadow-[3px_3px_0px_rgba(0,0,0,1)]"
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
