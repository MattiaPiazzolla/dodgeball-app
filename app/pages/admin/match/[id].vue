// pages/admin/match/[id].vue
<template>
    <div class="max-w-3xl mx-auto p-4 space-y-6">
        <div class="flex items-center gap-4 mb-6">
            <NuxtLink
                to="/admin/matches"
                class="bg-white border-2 border-black p-3 hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
            >
                <Icon name="mdi:arrow-left" class="text-xl" />
            </NuxtLink>
            <h1 class="text-3xl font-impact uppercase tracking-widest text-black">Console Arbitro</h1>
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
                class="card-grunge bg-cement p-8 text-center"
            >
                <h2 class="text-2xl font-impact uppercase tracking-widest mb-6 text-secondary">
                    L'incontro è pronto
                </h2>
                <button
                    @click="startMatch"
                    class="btn-skewed w-full max-w-sm mx-auto"
                >
                    <span class="btn-skewed-content text-2xl">Inizia Incontro</span>
                </button>
            </div>

            <!-- Timer & Status Display -->
            <div
                v-if="match.status !== 'pending'"
                class="bg-black text-white p-6 flex flex-col items-center justify-center relative overflow-hidden border-4 border-black shadow-[8px_8px_0px_rgba(0,0,0,1)]"
            >
                <div
                    v-if="match.status === 'in_progress'"
                    class="absolute top-0 w-full text-xs font-impact uppercase tracking-widest text-center py-2"
                    :class="
                        match.is_timer_running
                            ? 'bg-primary border-b-2 border-black animate-pulse'
                            : 'bg-accent text-black border-b-2 border-black'
                    "
                >
                    {{ match.is_timer_running ? "Ora in Diretta" : "In Pausa" }}
                </div>

                <div
                    class="text-7xl font-impact tracking-widest mt-6"
                    :class="{
                        'text-primary':
                            match.status === 'in_progress' &&
                            match.is_timer_running,
                        'text-accent':
                            match.status === 'in_progress' &&
                            !match.is_timer_running,
                    }"
                >
                    {{ formattedTimer }}
                </div>

                <div class="mt-6 flex flex-wrap justify-center gap-4">
                    <template v-if="match.status === 'in_progress'">
                        <button
                            v-if="match.is_timer_running"
                            @click="pauseMatch"
                            class="btn-skewed-secondary !bg-accent !text-black !border-black"
                        >
                            <span class="btn-skewed-content text-sm">Pausa Tempo</span>
                        </button>
                        <button
                            v-else
                            @click="resumeMatch"
                            class="btn-skewed-secondary !bg-green-500 !text-black !border-black"
                        >
                            <span class="btn-skewed-content text-sm">Riprendi Tempo</span>
                        </button>
                        <button
                            @click="endMatch('completed')"
                            class="btn-skewed-secondary !bg-white !text-black !border-black"
                        >
                            <span class="btn-skewed-content text-sm">Termina Incontro</span>
                        </button>
                    </template>
                    <div
                        v-else
                        class="px-6 py-3 border-2 border-white text-sm font-impact uppercase tracking-widest text-white shadow-[2px_2px_0px_rgba(255,255,255,1)]"
                    >
                        {{ translateStatus(match.status) }}
                    </div>
                </div>
            </div>

            <!-- Scoreboard (Always Editable Now) -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <!-- Team 1 -->
                <div
                    class="card-grunge bg-white p-6 text-center transition-all"
                    :class="
                        match.winner_id === match.team1_id
                            ? '!border-primary !shadow-[4px_4px_0px_rgba(211,47,47,1)]'
                            : ''
                    "
                >
                    <h2
                        class="text-2xl font-impact uppercase tracking-widest mb-4 line-clamp-1 text-black"
                        :title="getTeamName(match.team1_id)"
                    >
                        {{ getTeamName(match.team1_id) || "DA DEFINIRE" }}
                    </h2>
                    <div class="text-8xl font-impact mb-6 text-black">
                        {{ match.team1_score || 0 }}
                    </div>
                    <div class="flex gap-4 justify-center">
                        <button
                            @click="updateScore('team1_score', -1)"
                            class="w-16 h-16 bg-white border-4 border-black text-black text-3xl font-impact hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] flex items-center justify-center"
                        >
                            -
                        </button>
                        <button
                            @click="updateScore('team1_score', 1)"
                            class="flex-1 h-16 bg-white border-4 border-black text-black text-3xl font-impact hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] flex items-center justify-center"
                        >
                            +
                        </button>
                    </div>
                    <button
                        @click="setWinner(match.team1_id)"
                        class="w-full mt-6"
                        :class="
                            match.winner_id === match.team1_id
                                ? 'btn-skewed'
                                : 'btn-skewed-secondary'
                        "
                    >
                        <span class="btn-skewed-content">
                            {{
                                match.winner_id === match.team1_id
                                    ? "Vincitore"
                                    : "Imposta Vincitore"
                            }}
                        </span>
                    </button>
                </div>

                <!-- Team 2 -->
                <div
                    class="card-grunge bg-white p-6 text-center transition-all"
                    :class="
                        match.winner_id === match.team2_id
                            ? '!border-primary !shadow-[4px_4px_0px_rgba(211,47,47,1)]'
                            : ''
                    "
                >
                    <h2
                        class="text-2xl font-impact uppercase tracking-widest mb-4 line-clamp-1 text-black"
                        :title="getTeamName(match.team2_id)"
                    >
                        {{ getTeamName(match.team2_id) || "DA DEFINIRE" }}
                    </h2>
                    <div class="text-8xl font-impact mb-6 text-black">
                        {{ match.team2_score || 0 }}
                    </div>
                    <div class="flex gap-4 justify-center">
                        <button
                            @click="updateScore('team2_score', -1)"
                            class="w-16 h-16 bg-white border-4 border-black text-black text-3xl font-impact hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] flex items-center justify-center"
                        >
                            -
                        </button>
                        <button
                            @click="updateScore('team2_score', 1)"
                            class="flex-1 h-16 bg-white border-4 border-black text-black text-3xl font-impact hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] flex items-center justify-center"
                        >
                            +
                        </button>
                    </div>
                    <button
                        @click="setWinner(match.team2_id)"
                        class="w-full mt-6"
                        :class="
                            match.winner_id === match.team2_id
                                ? 'btn-skewed'
                                : 'btn-skewed-secondary'
                        "
                    >
                        <span class="btn-skewed-content">
                            {{
                                match.winner_id === match.team2_id
                                    ? "Vincitore"
                                    : "Imposta Vincitore"
                            }}
                        </span>
                    </button>
                </div>
            </div>

            <!-- Danger Zone -->
            <div class="pt-8 mt-8 border-t-4 border-black flex flex-col gap-4">
                <button
                    v-if="match.winner_id"
                    @click="setWinner(null)"
                    class="w-full py-4 bg-cement text-secondary border-4 border-black font-impact uppercase tracking-widest text-sm hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                >
                    Rimuovi Vincitore
                </button>
                <button
                    @click="resetMatch"
                    class="w-full py-4 bg-white text-primary border-4 border-primary font-impact uppercase tracking-widest text-sm hover:bg-primary hover:text-white transition-all shadow-[2px_2px_0px_rgba(211,47,47,1)]"
                >
                    Ripristina Incontro a In attesa (Azzera Punteggi e Tempo)
                </button>
            </div>
        </div>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";

definePageMeta({ middleware: ["admin"] });

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

const getScoreWinnerId = (targetMatch: any) => {
    const team1Score = targetMatch.team1_score || 0;
    const team2Score = targetMatch.team2_score || 0;

    if (team1Score === team2Score) return null;
    return team1Score > team2Score
        ? targetMatch.team1_id
        : targetMatch.team2_id;
};

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
    const winnerId = status === "completed" ? getScoreWinnerId(match.value) : null;

    if (status === "completed" && !winnerId) {
        alert("Non puoi terminare l'incontro in parità. Modifica il punteggio prima di chiudere.");
        return;
    }

    const elapsed = totalElapsed.value;
    match.value.status = status;
    match.value.winner_id = winnerId;
    match.value.is_timer_running = false;
    match.value.elapsed_seconds = elapsed;
    match.value.timer_started_at = null;

    await supabase
        .from("matches")
        .update({
            status,
            winner_id: winnerId,
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
