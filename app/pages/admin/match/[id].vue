// pages/admin/match/[id].vue
<template>
    <div class="max-w-3xl mx-auto p-4 space-y-6">
        <div class="flex items-center gap-4 mb-6">
            <NuxtLink
                to="/admin/matches"
                class="bg-gray-100 p-3 rounded-full hover:bg-gray-200"
            >
                <Icon name="mdi:arrow-left" class="text-xl" />
            </NuxtLink>
            <h1 class="text-2xl font-black uppercase">Console Arbitro</h1>
        </div>

        <div
            v-if="pending"
            class="text-center py-12 font-bold animate-pulse text-gray-500"
        >
            CARICAMENTO INCONTRO...
        </div>

        <div v-else-if="match" class="space-y-6">
            <!-- Match Controls -->
            <div
                v-if="match.status === 'pending'"
                class="bg-white p-8 rounded-3xl shadow-sm border-2 border-dashed border-gray-200 text-center"
            >
                <h2 class="text-xl font-black uppercase mb-4 text-gray-400">
                    L'incontro è pronto
                </h2>
                <button
                    @click="startMatch"
                    class="w-full py-6 bg-red-600 hover:bg-red-700 text-white rounded-2xl text-2xl font-black uppercase tracking-widest shadow-xl transition-transform hover:-translate-y-1"
                >
                    Inizia Incontro
                </button>
            </div>

            <!-- Timer & Status Display -->
            <div
                v-if="match.status !== 'pending'"
                class="bg-black text-white p-6 rounded-3xl shadow-xl flex flex-col items-center justify-center relative overflow-hidden"
            >
                <div
                    v-if="match.status === 'in_progress'"
                    class="absolute top-0 w-full text-[10px] font-black uppercase tracking-widest text-center py-1"
                    :class="
                        match.is_timer_running
                            ? 'bg-red-600 animate-pulse'
                            : 'bg-yellow-500 text-black'
                    "
                >
                    {{ match.is_timer_running ? "Ora in Diretta" : "In Pausa" }}
                </div>

                <div
                    class="text-6xl font-black font-mono tracking-tighter mt-4"
                    :class="{
                        'text-red-500':
                            match.status === 'in_progress' &&
                            match.is_timer_running,
                        'text-yellow-500':
                            match.status === 'in_progress' &&
                            !match.is_timer_running,
                    }"
                >
                    {{ formattedTimer }}
                </div>

                <div class="mt-6 flex flex-wrap justify-center gap-2">
                    <template v-if="match.status === 'in_progress'">
                        <button
                            v-if="match.is_timer_running"
                            @click="pauseMatch"
                            class="px-6 py-3 bg-yellow-500 hover:bg-yellow-600 text-black rounded-xl text-xs font-black uppercase tracking-wide transition-colors"
                        >
                            Pausa Tempo
                        </button>
                        <button
                            v-else
                            @click="resumeMatch"
                            class="px-6 py-3 bg-green-500 hover:bg-green-600 text-white rounded-xl text-xs font-black uppercase tracking-wide transition-colors"
                        >
                            Riprendi Tempo
                        </button>
                        <button
                            @click="endMatch('completed')"
                            class="px-6 py-3 bg-white/20 hover:bg-white/30 rounded-xl text-xs font-black uppercase tracking-wide transition-colors"
                        >
                            Termina Incontro
                        </button>
                    </template>
                    <div
                        v-else
                        class="px-6 py-3 bg-white/10 rounded-xl text-xs font-black uppercase tracking-wide text-gray-300"
                    >
                        {{ translateStatus(match.status) }}
                    </div>
                </div>
            </div>

            <!-- Scoreboard (Always Editable Now) -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <!-- Team 1 -->
                <div
                    class="bg-white border-2 rounded-3xl p-6 text-center shadow-sm"
                    :class="
                        match.winner_id === match.team1_id
                            ? 'border-green-500'
                            : 'border-gray-100'
                    "
                >
                    <h2
                        class="text-xl font-black uppercase mb-4 line-clamp-1"
                        :title="getTeamName(match.team1_id)"
                    >
                        {{ getTeamName(match.team1_id) || "DA DEFINIRE" }}
                    </h2>
                    <div class="text-7xl font-black mb-6">
                        {{ match.team1_score || 0 }}
                    </div>
                    <div class="flex gap-2 justify-center">
                        <button
                            @click="updateScore('team1_score', -1)"
                            class="w-16 h-16 bg-red-100 text-red-600 rounded-2xl text-2xl font-black hover:bg-red-200"
                        >
                            -1
                        </button>
                        <button
                            @click="updateScore('team1_score', 1)"
                            class="flex-1 h-16 bg-green-100 text-green-700 rounded-2xl text-2xl font-black hover:bg-green-200"
                        >
                            +1
                        </button>
                    </div>
                    <button
                        @click="setWinner(match.team1_id)"
                        class="w-full mt-4 py-3 rounded-xl font-black uppercase text-sm"
                        :class="
                            match.winner_id === match.team1_id
                                ? 'bg-green-500 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                        "
                    >
                        {{
                            match.winner_id === match.team1_id
                                ? "Vincitore"
                                : "Imposta Vincitore"
                        }}
                    </button>
                </div>

                <!-- Team 2 -->
                <div
                    class="bg-white border-2 rounded-3xl p-6 text-center shadow-sm"
                    :class="
                        match.winner_id === match.team2_id
                            ? 'border-green-500'
                            : 'border-gray-100'
                    "
                >
                    <h2
                        class="text-xl font-black uppercase mb-4 line-clamp-1"
                        :title="getTeamName(match.team2_id)"
                    >
                        {{ getTeamName(match.team2_id) || "DA DEFINIRE" }}
                    </h2>
                    <div class="text-7xl font-black mb-6">
                        {{ match.team2_score || 0 }}
                    </div>
                    <div class="flex gap-2 justify-center">
                        <button
                            @click="updateScore('team2_score', -1)"
                            class="w-16 h-16 bg-red-100 text-red-600 rounded-2xl text-2xl font-black hover:bg-red-200"
                        >
                            -1
                        </button>
                        <button
                            @click="updateScore('team2_score', 1)"
                            class="flex-1 h-16 bg-green-100 text-green-700 rounded-2xl text-2xl font-black hover:bg-green-200"
                        >
                            +1
                        </button>
                    </div>
                    <button
                        @click="setWinner(match.team2_id)"
                        class="w-full mt-4 py-3 rounded-xl font-black uppercase text-sm"
                        :class="
                            match.winner_id === match.team2_id
                                ? 'bg-green-500 text-white'
                                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                        "
                    >
                        {{
                            match.winner_id === match.team2_id
                                ? "Vincitore"
                                : "Imposta Vincitore"
                        }}
                    </button>
                </div>
            </div>

            <!-- Danger Zone -->
            <div class="pt-6 mt-6 border-t border-gray-200 flex flex-col gap-3">
                <button
                    v-if="match.winner_id"
                    @click="setWinner(null)"
                    class="w-full py-4 bg-gray-100 text-gray-600 rounded-xl font-bold uppercase text-xs hover:bg-gray-200 transition-colors"
                >
                    Rimuovi Vincitore
                </button>
                <button
                    @click="resetMatch"
                    class="w-full py-4 text-red-500 font-bold uppercase text-xs hover:text-red-700 transition-colors"
                >
                    Ripristina Incontro a In attesa (Azzera Punteggi e Tempo)
                </button>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";

definePageMeta({ middleware: ["admin"], layout: "admin" });

const translateStatus = (s: string) => {
    if (s === "pending") return "In attesa";
    if (s === "in_progress") return "In corso";
    if (s === "completed" || s === "finished") return "Completato";
    if (s === "retired") return "Ritirato";
    return s;
};

const route = useRoute();
const supabase = useSupabaseClient();
const match = ref<any>(null);
const teams = ref<any[]>([]);
const pending = ref(true);

// Timer logic
const now = ref(Date.now());
let timerInterval: any = null;

const startTimerSync = () => {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = setInterval(() => {
        now.value = Date.now();
    }, 1000);
};

const totalElapsed = computed(() => {
    if (!match.value) return 0;
    let elapsed = match.value.elapsed_seconds || 0;
    if (match.value.is_timer_running && match.value.timer_started_at) {
        const start = new Date(match.value.timer_started_at).getTime();
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

const loadMatch = async () => {
    const { data: tData } = await supabase.from("teams").select("id, name");
    if (tData) teams.value = tData;

    const { data } = await supabase
        .from("matches")
        .select("*")
        .eq("id", route.params.id)
        .single();
    if (data) {
        match.value = data;
        startTimerSync();
    }
    pending.value = false;
};

const getTeamName = (id: string) => teams.value.find((t) => t.id === id)?.name;

const startMatch = async () => {
    const startTime = new Date().toISOString();
    match.value.status = "in_progress";
    match.value.is_timer_running = true;
    match.value.timer_started_at = startTime;
    match.value.elapsed_seconds = 0;

    await supabase
        .from("matches")
        .update({
            status: "in_progress",
            is_timer_running: true,
            timer_started_at: startTime,
            elapsed_seconds: 0,
        })
        .eq("id", match.value.id);
};

const pauseMatch = async () => {
    const elapsed = totalElapsed.value;
    match.value.is_timer_running = false;
    match.value.elapsed_seconds = elapsed;
    match.value.timer_started_at = null;

    await supabase
        .from("matches")
        .update({
            is_timer_running: false,
            elapsed_seconds: elapsed,
            timer_started_at: null,
        })
        .eq("id", match.value.id);
};

const resumeMatch = async () => {
    const startTime = new Date().toISOString();
    match.value.is_timer_running = true;
    match.value.timer_started_at = startTime;

    await supabase
        .from("matches")
        .update({
            is_timer_running: true,
            timer_started_at: startTime,
        })
        .eq("id", match.value.id);
};

const endMatch = async (status: string) => {
    const elapsed = totalElapsed.value;
    match.value.status = status;
    match.value.is_timer_running = false;
    match.value.elapsed_seconds = elapsed;
    match.value.timer_started_at = null;

    await supabase
        .from("matches")
        .update({
            status,
            is_timer_running: false,
            elapsed_seconds: elapsed,
            timer_started_at: null,
        })
        .eq("id", match.value.id);
};

const resetMatch = async () => {
    if (
        !confirm(
            "Sei sicuro di voler ripristinare questo incontro? Tutti i punteggi e il tempo saranno persi.",
        )
    )
        return;

    match.value = {
        ...match.value,
        status: "pending",
        team1_score: 0,
        team2_score: 0,
        winner_id: null,
        is_timer_running: false,
        elapsed_seconds: 0,
        timer_started_at: null,
    };

    await supabase
        .from("matches")
        .update({
            status: "pending",
            team1_score: 0,
            team2_score: 0,
            winner_id: null,
            is_timer_running: false,
            elapsed_seconds: 0,
            timer_started_at: null,
        })
        .eq("id", match.value.id);
};

const updateScore = async (
    teamKey: "team1_score" | "team2_score",
    delta: number,
) => {
    let newScore = (match.value[teamKey] || 0) + delta;
    if (newScore < 0) newScore = 0;

    match.value[teamKey] = newScore;
    await supabase
        .from("matches")
        .update({ [teamKey]: newScore })
        .eq("id", match.value.id);
};

const setWinner = async (teamId: string | null) => {
    match.value.winner_id = teamId;
    await supabase
        .from("matches")
        .update({ winner_id: teamId })
        .eq("id", match.value.id);

    // Auto end match if not ended
    if (teamId && match.value.status === "in_progress") {
        endMatch("completed");
    }
};

onMounted(loadMatch);
onUnmounted(() => {
    if (timerInterval) clearInterval(timerInterval);
});
</script>
