// pages/admin/matches.vue

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from "vue";
import { useScrollLock } from "~/composables/useScrollLock";

definePageMeta({ middleware: "admin" });

const supabase = useSupabaseClient();
const { subscribeToAllMatches, unsubscribe } = useMatchRealtime();
const activeTab = ref<"knockout" | "group">("group"); // Default to group
const teams = ref<any[]>([]);
const groups = ref<any[]>([]);
const matches = ref<any[]>([]);
const isLoading = ref(true);
let realtimeChannel: any = null;

// Edit state
const editingMatch = ref<any | null>(null);

// Delete state
const confirmDeleteId = ref<string | null>(null);

// Match Card Mobile Actions Modal
const selectedMatchActions = ref<any | null>(null);

// Mobile actions modal
const showMobileActions = ref(false);

// Add match modal
const showAddModal = ref(false);

// Scroll locks for modals
const { lock, unlock } = useScrollLock();

watch(showAddModal, (isOpen) => {
    if (isOpen) lock();
    else unlock();
});

watch(showMobileActions, (isOpen) => {
    if (isOpen) lock();
    else unlock();
});

watch(() => !!selectedMatchActions.value, (isOpen) => {
    if (isOpen) lock();
    else unlock();
});
const addForm = ref({
    match_type: "knockout" as "knockout" | "group",
    group_id: "",
    round: 1,
    start_time: "",
    team1_type: "team" as "team" | "placeholder",
    team1_id: "",
    team1_placeholder: "",
    team2_type: "team" as "team" | "placeholder",
    team2_id: "",
    team2_placeholder: "",
});

// ── Computed ──────────────────────────────────────────────
const knockoutMatches = computed(() => {
    const byRound: Record<number, any[]> = {};
    matches.value
        .filter((m) => m.match_type === "knockout")
        .forEach((m) => {
            if (!byRound[m.round]) byRound[m.round] = [];
            byRound[m.round].push(m);
        });
    Object.values(byRound).forEach((roundMatches) => {
        roundMatches.sort(
            (a, b) =>
                (a.bracket_position ?? Number.MAX_SAFE_INTEGER) -
                    (b.bracket_position ?? Number.MAX_SAFE_INTEGER) ||
                (a.created_at || "").localeCompare(b.created_at || "") ||
                a.id.localeCompare(b.id),
        );
    });
    return byRound;
});

const groupMatches = computed(() => {
    const byGroup: Record<string, any[]> = {};
    matches.value
        .filter((m) => m.match_type === "group")
        .forEach((m) => {
            if (!m.group_id) return;
            if (!byGroup[m.group_id]) byGroup[m.group_id] = [];
            byGroup[m.group_id].push(m);
        });
    return byGroup;
});

const allGroupMatchesCompleted = computed(() => {
    const gm = matches.value.filter((m) => m.match_type === "group");
    if (gm.length === 0) return true; // Allowed if no group stage exists
    return gm.every((m) => ["completed", "retired"].includes(m.status));
});

const hasKnockoutMatches = computed(() => {
    return matches.value.some((m) => m.match_type === "knockout");
});

watch(hasKnockoutMatches, (hasKnockout) => {
    if (!hasKnockout && activeTab.value === "knockout") {
        activeTab.value = "group";
    }
});

const roundLabel = (r: number) => {
    const total = Object.keys(knockoutMatches.value).length;
    if (r === total) return "Finale";
    if (r === total - 1) return "Semifinali";
    if (r === total - 2) return "Quarti di Finale";
    return `Turno ${r}`;
};

// ── Helpers ───────────────────────────────────────────────
const getTeamName = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.name || null;
const getTeamLogo = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.logo_url || null;
const getGroupName = (id: string) =>
    groups.value.find((g) => g.id === id)?.name || "Group";

const getScoreWinnerId = (match: any) => {
    const team1Score = match.team1_score || 0;
    const team2Score = match.team2_score || 0;

    if (team1Score === team2Score) return null;
    return team1Score > team2Score ? match.team1_id : match.team2_id;
};

const displayName = (match: any, slot: 1 | 2) => {
    const idKey = `team${slot}_id`;
    const phKey = `team${slot}_placeholder`;
    if (match[idKey]) return getTeamName(match[idKey]) || "Unknown";
    if (match[phKey]) return match[phKey];
    return "TBD";
};

const winnerPlaceholder = (round: number, matchNumber: number) =>
    `Vincente incontro ${matchNumber} - turno ${round}`;

const displayKnockoutName = (
    match: any,
    slot: 1 | 2,
    roundNum: string | number,
    matchIndex: number,
) => {
    const idKey = `team${slot}_id`;
    const phKey = `team${slot}_placeholder`;

    if (match[idKey]) return getTeamName(match[idKey]) || "Unknown";
    if (match[phKey]) return match[phKey];

    const round = Number(roundNum);
    if (round > 1) {
        const sourceMatchNumber = matchIndex * 2 + slot;
        return winnerPlaceholder(round - 1, sourceMatchNumber);
    }

    return "DA DEFINIRE";
};

const formatTime = (t: string | null) => (t ? t.slice(0, 5) : null);

const statusColor = (s: string) => {
    if (s === "completed") return "bg-black text-white border-2 border-black font-impact uppercase tracking-widest";
    if (s === "in_progress") return "bg-primary text-white border-2 border-black font-impact uppercase tracking-widest animate-pulse";
    if (s === "retired") return "bg-yellow-400 text-black border-2 border-black font-impact uppercase tracking-widest";
    return "bg-white text-secondary border-2 border-black font-impact uppercase tracking-widest";
};

const translateStage = (stage: string) => {
    if (!stage) return "";
    const lower = stage.toLowerCase();
    if (lower === "group") return "Fase a Gironi";
    if (lower === "knockout") return "Fase a Eliminazione Diretta";
    return stage;
};

const translateStatus = (s: string) => {
    if (s === "pending") return "In attesa";
    if (s === "in_progress") return "In corso";
    if (s === "completed" || s === "finished") return "Completato";
    if (s === "retired") return "Ritirato";
    return s;
};

// ── Data ──────────────────────────────────────────────────
const loadData = async () => {
    const [{ data: tData }, { data: gData }, { data: mData }] =
        await Promise.all([
            supabase
                .from("teams")
                .select("id, name, logo_url")
                .eq("status", "approved"),
            supabase.from("groups").select("*, group_teams(team_id)"),
            supabase.from("matches").select("*").order("round").order("id"),
        ]);
    if (tData) teams.value = tData;
    if (gData) groups.value = gData;
    if (mData) matches.value = mData;

    if (hasKnockoutMatches.value) {
        activeTab.value = "knockout";
    } else {
        activeTab.value = "group";
    }

    isLoading.value = false;
};

const applyMatchRealtimeChange = (payload: any) => {
    const changedMatch = payload.new || payload.old;
    if (!changedMatch?.id) return;

    if (payload.eventType === "DELETE") {
        matches.value = matches.value.filter(
            (match) => match.id !== changedMatch.id,
        );
        if (editingMatch.value?.id === changedMatch.id) {
            editingMatch.value = null;
        }
        if (confirmDeleteId.value === changedMatch.id) {
            confirmDeleteId.value = null;
        }
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
            (a.bracket_position ?? Number.MAX_SAFE_INTEGER) -
                (b.bracket_position ?? Number.MAX_SAFE_INTEGER) ||
            (a.created_at || "").localeCompare(b.created_at || "") ||
            a.id.localeCompare(b.id),
    );
};

// ── Match CRUD ────────────────────────────────────────────
const startEdit = (match: any) => {
    editingMatch.value = { ...match };
};

const cancelEdit = () => {
    editingMatch.value = null;
};

const saveEdit = async () => {
    if (!editingMatch.value) return;

    // RULE: Only ONE match can be in progress at a time
    if (editingMatch.value.status === "in_progress") {
        const otherLive = matches.value.find(
            (m) => m.status === "in_progress" && m.id !== editingMatch.value.id,
        );
        if (otherLive) {
            alert(
                "Un'altra partita è già IN CORSO! Devi terminarla prima di iniziare questa.",
            );
            return;
        }
    }

    const winnerId =
        editingMatch.value.status === "completed"
            ? getScoreWinnerId(editingMatch.value)
            : editingMatch.value.winner_id || null;

    if (editingMatch.value.status === "completed" && !winnerId) {
        alert("Non puoi completare l'incontro in parità. Modifica il punteggio dalla console arbitro prima di chiuderlo.");
        return;
    }

    const { id, team1_id, team2_id, round, start_time, status } =
        editingMatch.value;
    await supabase
        .from("matches")
        .update({
            team1_id: team1_id || null,
            team2_id: team2_id || null,
            round,
            start_time: start_time || null,
            status,
            winner_id: winnerId,
        })
        .eq("id", id);
    editingMatch.value = null;
    await loadData();
};

const deleteMatch = async (id: string) => {
    await supabase.from("matches").delete().eq("id", id);
    confirmDeleteId.value = null;
    await loadData();
};

const openAddModal = () => {
    addForm.value = {
        match_type: activeTab.value,
        group_id: "",
        round: 1,
        start_time: "",
        team1_type: "team",
        team1_id: "",
        team1_placeholder: "",
        team2_type: "team",
        team2_id: "",
        team2_placeholder: "",
    };
    showAddModal.value = true;
};

const saveAdd = async () => {
    const f = addForm.value;
    const nextBracketPosition =
        f.match_type === "knockout"
            ? Math.max(
                  0,
                  ...matches.value
                      .filter(
                          (m) =>
                              m.match_type === "knockout" &&
                              Number(m.round) === Number(f.round),
                      )
                      .map((m) => m.bracket_position || 0),
              ) + 1
            : null;
    const payload: any = {
        match_type: f.match_type,
        round: f.match_type === "group" ? 1 : f.round,
        status: "pending",
        group_id: f.match_type === "group" ? f.group_id || null : null,
        team1_id: f.team1_type === "team" && f.team1_id ? f.team1_id : null,
        team1_placeholder:
            f.team1_type === "placeholder" ? f.team1_placeholder : null,
        team2_id: f.team2_type === "team" && f.team2_id ? f.team2_id : null,
        team2_placeholder:
            f.team2_type === "placeholder" ? f.team2_placeholder : null,
    };
    if (nextBracketPosition) payload.bracket_position = nextBracketPosition;
    if (f.start_time) payload.start_time = f.start_time;
    const { error } = await supabase.from("matches").insert([payload]);
    if (error) {
        alert("Errore: " + error.message);
        return;
    }
    showAddModal.value = false;
    await loadData();
};

// ── Generators ────────────────────────────────────────────
const clearKnockout = async () => {
    if (!confirm("Cancellare l'intero tabellone a eliminazione diretta? L'azione non può essere annullata."))
        return;
    await supabase.from("matches").delete().eq("match_type", "knockout");
    await loadData();
};

const clearGroupMatches = async () => {
    if (!confirm("Cancellare tutti gli incontri dei gironi? L'azione non può essere annullata.")) return;
    await supabase.from("matches").delete().eq("match_type", "group");
    await loadData();
};

const autoGenerateKnockout = async () => {
    if (!allGroupMatchesCompleted.value) {
        alert(
            "Devi completare tutti gli incontri dei gironi prima di generare il tabellone!",
        );
        return;
    }

    if (matches.value.some((m) => m.match_type === "knockout")) {
        if (!confirm("Questo sostituirà il tabellone esistente. Continuare?"))
            return;
        await supabase.from("matches").delete().eq("match_type", "knockout");
    }

    const { data: groupsData } = await supabase
        .from("groups")
        .select("id, group_teams ( team_id, points, wins )");

    let knockoutTeams: (string | null)[] = [];

    if (groupsData && groupsData.length > 0) {
        const firsts: string[] = [];
        const seconds: string[] = [];
        groupsData.forEach((g) => {
            const sorted = [...g.group_teams].sort(
                (a: any, b: any) => b.points - a.points || b.wins - a.wins,
            );
            if (sorted[0]) firsts.push(sorted[0].team_id);
            if (sorted[1]) seconds.push(sorted[1].team_id);
        });
        for (let i = 0; i < firsts.length; i++) {
            knockoutTeams.push(firsts[i]);
            knockoutTeams.push(seconds[(i + 1) % seconds.length] || null);
        }
    } else {
        if (teams.value.length < 2)
            return alert("Sono necessarie almeno 2 squadre approvate.");
        knockoutTeams = [...teams.value]
            .map((t) => t.id)
            .sort(() => 0.5 - Math.random());
    }

    if (knockoutTeams.length < 2) return alert("Squadre insufficienti.");

    const totalRounds = Math.ceil(Math.log2(knockoutTeams.length));
    let matchesInRound = Math.pow(2, totalRounds) / 2;
    const newMatches: any[] = [];

    for (let i = 0; i < matchesInRound * 2; i += 2) {
        newMatches.push({
            team1_id: knockoutTeams[i] || null,
            team2_id: knockoutTeams[i + 1] || null,
            bracket_position: i / 2 + 1,
            round: 1,
            match_type: "knockout",
            status: "pending",
        });
    }
    let prev = matchesInRound;
    for (let r = 2; r <= totalRounds; r++) {
        prev = prev / 2;
        for (let i = 0; i < prev; i++) {
            newMatches.push({
                team1_id: null,
                team2_id: null,
                team1_placeholder: winnerPlaceholder(r - 1, i * 2 + 1),
                team2_placeholder: winnerPlaceholder(r - 1, i * 2 + 2),
                bracket_position: i + 1,
                round: r,
                match_type: "knockout",
                status: "pending",
            });
        }
    }

    const { error } = await supabase.from("matches").insert(newMatches);
    if (error) alert("Errore: " + error.message);
    else await loadData();
};

const autoGenerateGroupMatches = async () => {
    if (matches.value.some((m) => m.match_type === "group")) {
        if (!confirm("Questo sostituirà gli incontri dei gironi esistenti. Continuare?"))
            return;
        await supabase.from("matches").delete().eq("match_type", "group");
    }
    const newMatches: any[] = [];
    groups.value.forEach((group) => {
        const ids = group.group_teams.map((gt: any) => gt.team_id);
        for (let i = 0; i < ids.length; i++)
            for (let j = i + 1; j < ids.length; j++)
                newMatches.push({
                    team1_id: ids[i],
                    team2_id: ids[j],
                    group_id: group.id,
                    match_type: "group",
                    round: 1,
                    status: "pending",
                });
    });
    if (newMatches.length === 0) return alert("Nessuna squadra nei gironi.");
    const { error } = await supabase.from("matches").insert(newMatches);
    if (error) alert("Errore: " + error.message);
    else await loadData();
};

onMounted(async () => {
    await loadData();
    realtimeChannel = subscribeToAllMatches(applyMatchRealtimeChange);
});

onUnmounted(() => {
    unsubscribe(realtimeChannel);
});
</script>

<template>
    <div class="max-w-7xl mx-auto px-3 sm:px-4 py-5 sm:py-8 space-y-5 sm:space-y-6">
        <div
            v-if="isLoading"
            class="flex items-center justify-center py-24 text-red-500"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <div
                class="flex flex-col gap-3"
            >
                <div class="flex gap-2 sm:gap-3 w-full sm:w-auto">
                    <div
                        class="flex-1 flex bg-white border-4 border-black p-1 gap-1 shadow-[2px_2px_0px_rgba(0,0,0,1)] sm:flex-none min-w-0"
                    >
                        <button
                            v-if="hasKnockoutMatches"
                            @click="activeTab = 'knockout'"
                            class="flex-1 sm:flex-none px-2 sm:px-6 py-2.5 text-sm font-impact uppercase tracking-widest transition-all border-2 border-transparent truncate"
                            :class="
                                activeTab === 'knockout'
                                    ? 'bg-primary text-white border-black shadow-[2px_2px_0px_rgba(0,0,0,1)]'
                                    : 'text-secondary hover:text-black'
                            "
                        >
                            Eliminazione
                        </button>
                        <button
                            @click="activeTab = 'group'"
                            class="flex-1 sm:flex-none px-2 sm:px-6 py-2.5 text-sm font-impact uppercase tracking-widest transition-all border-2 border-transparent truncate"
                            :class="
                                activeTab === 'group'
                                    ? 'bg-primary text-white border-black shadow-[2px_2px_0px_rgba(0,0,0,1)]'
                                    : 'text-secondary hover:text-black'
                            "
                        >
                            Gironi
                        </button>
                    </div>

                    <!-- Mobile actions button -->
                    <button
                        class="sm:hidden w-12 flex-shrink-0 flex items-center justify-center bg-white border-4 border-black shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-all active:translate-y-1 active:shadow-[0px_0px_0px_rgba(0,0,0,1)]"
                        @click="showMobileActions = true"
                    >
                        <Icon name="mdi:dots-vertical" class="text-xl text-black" />
                    </button>
                </div>

                <!-- Desktop Actions -->
                <div class="hidden sm:flex gap-3 flex-wrap">
                    <template v-if="activeTab === 'knockout'">
                        <template
                            v-if="Object.keys(knockoutMatches).length > 0"
                        >
                            <button
                                @click="clearKnockout"
                                class="btn-skewed-secondary !text-primary !border-primary hover:!bg-primary hover:!text-white"
                            >
                                <span class="btn-skewed-content text-xs">Cancella tabellone</span>
                            </button>
                            <button
                                @click="openAddModal"
                                class="btn-skewed-secondary"
                            >
                                <span class="btn-skewed-content text-xs">Aggiungi incontro</span>
                            </button>
                            <button
                                @click="autoGenerateKnockout"
                                class="btn-skewed"
                            >
                                <span class="btn-skewed-content text-xs">Rigenera</span>
                            </button>
                        </template>
                    </template>
                    <template v-else>
                        <button
                            @click="clearGroupMatches"
                            class="btn-skewed-secondary !text-primary !border-primary hover:!bg-primary hover:!text-white"
                        >
                            <span class="btn-skewed-content text-xs">Cancella gironi</span>
                        </button>
                        <button
                            @click="openAddModal"
                            class="btn-skewed-secondary"
                        >
                            <span class="btn-skewed-content text-xs">Aggiungi incontro</span>
                        </button>
                        <button
                            @click="autoGenerateGroupMatches"
                            class="btn-skewed"
                        >
                            <span class="btn-skewed-content text-xs">Genera calendario</span>
                        </button>
                    </template>
                </div>
            </div>

            <div v-if="activeTab === 'knockout'">
                <div
                    v-if="Object.keys(knockoutMatches).length === 0"
                    class="animate-in fade-in slide-in-from-bottom-4 duration-500 py-8"
                >
                    <div
                        class="card-grunge !bg-primary border-4 border-black p-8 sm:p-12 relative overflow-hidden flex flex-col items-center justify-center gap-6 text-center"
                    >
                        <Icon
                            name="mdi:tournament"
                            class="absolute -right-8 -bottom-12 text-[250px] text-white opacity-10 pointer-events-none"
                        />
                        <div
                            class="relative z-10 text-white space-y-4 max-w-lg"
                        >
                            <div
                                class="flex items-center justify-center gap-2 text-yellow-300 font-impact uppercase tracking-widest text-sm"
                            >
                                <Icon
                                    name="mdi:check-decagram"
                                    class="text-lg"
                                />
                                Fase a Gironi Completata
                            </div>
                            <h2
                                class="text-4xl sm:text-5xl font-impact uppercase tracking-widest leading-none text-white"
                            >
                                Pronto per il Sorteggio
                            </h2>
                            <p class="text-gray-200 font-bold uppercase tracking-wider">
                                Tutti gli incontri della fase a gironi sono stati
                                risolti. Ora puoi generare il tabellone ufficiale
                                a eliminazione diretta.
                            </p>
                        </div>
                        <div class="relative z-10 mt-4">
                            <button
                                @click="autoGenerateKnockout"
                                class="flex items-center justify-center gap-3 px-10 py-5 bg-white text-primary border-4 border-black font-impact uppercase tracking-widest hover:bg-black hover:text-white hover:border-white transition-all shadow-[6px_6px_0px_rgba(0,0,0,1)] hover:-translate-y-1 transform -skew-x-6"
                            >
                                <Icon name="mdi:whistle" class="text-2xl transform skew-x-6 block" />
                                <span class="transform skew-x-6 block">Genera tabellone</span>
                            </button>
                        </div>
                    </div>
                </div>
                <div v-else class="overflow-x-auto pb-4">
                    <div class="flex gap-6 min-w-max">
                        <div
                            v-for="(roundMatches, roundNum) in knockoutMatches"
                            :key="roundNum"
                            class="flex flex-col gap-4 w-72"
                        >
                            <div class="text-center">
                                <span
                                    class="text-sm font-impact uppercase tracking-widest text-white bg-black border-2 border-black px-4 py-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                                >
                                    {{ roundLabel(Number(roundNum)) }}
                                </span>
                            </div>
                            <div
                                v-for="(match, mIdx) in roundMatches"
                                :key="match.id"
                                class="card-grunge overflow-hidden transition-all"
                                :class="
                                    match.status === 'in_progress'
                                        ? 'bg-red-50 !border-primary shadow-[0_0_15px_rgba(211,47,47,0.5)] ring-1 ring-primary'
                                        : 'bg-white'
                                "
                            >
                                <div
                                    v-if="editingMatch?.id === match.id"
                                    class="p-4 space-y-3"
                                >
                                    <select
                                        v-model="editingMatch.team1_id"
                                        class="w-full bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest uppercase outline-none focus:border-primary transition-all"
                                    >
                                        <option value="">DA DEFINIRE</option>
                                        <option
                                            v-for="t in teams"
                                            :key="t.id"
                                            :value="t.id"
                                        >
                                            {{ t.name }}
                                        </option>
                                    </select>
                                    <select
                                        v-model="editingMatch.team2_id"
                                        class="w-full bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest uppercase outline-none focus:border-primary transition-all"
                                    >
                                        <option value="">DA DEFINIRE</option>
                                        <option
                                            v-for="t in teams"
                                            :key="t.id"
                                            :value="t.id"
                                        >
                                            {{ t.name }}
                                        </option>
                                    </select>
                                    <div class="flex gap-2">
                                        <input
                                            v-model="editingMatch.round"
                                            type="number"
                                            min="1"
                                            placeholder="Turno"
                                            class="w-1/3 bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest outline-none focus:border-primary transition-all"
                                        />
                                        <input
                                            v-model="editingMatch.start_time"
                                            type="time"
                                            class="flex-1 bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest outline-none focus:border-primary transition-all"
                                        />
                                    </div>
                                    <select
                                        v-model="editingMatch.status"
                                        class="w-full bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest uppercase outline-none focus:border-primary transition-all"
                                    >
                                        <option value="pending">In attesa</option>
                                        <option value="in_progress">
                                            In corso
                                        </option>
                                        <option value="completed">
                                            Completato
                                        </option>
                                        <option value="retired">Ritirato</option>
                                    </select>
                                    <div class="flex gap-2 pt-1">
                                        <button
                                            @click="saveEdit"
                                            class="btn-skewed flex-1 !text-xs py-2"
                                        >
                                            Salva
                                        </button>
                                        <button
                                            @click="cancelEdit"
                                            class="btn-skewed-secondary flex-1 !text-xs py-2"
                                        >
                                            Annulla
                                        </button>
                                    </div>
                                </div>

                                <div v-else>
                                    <div
                                        class="relative p-4 sm:p-6 bg-white"
                                    >
                                        <!-- Top Right Actions -->
                                        <div class="absolute top-2 right-2 flex items-center gap-2">
                                            <!-- Desktop Actions -->
                                            <div class="hidden sm:flex gap-1">
                                                <template
                                                    v-if="
                                                        confirmDeleteId === match.id
                                                    "
                                                >
                                                    <button
                                                        @click="
                                                            deleteMatch(match.id)
                                                        "
                                                        class="text-xs font-black text-red-600 hover:text-red-800 uppercase px-2"
                                                    >
                                                        Sì
                                                    </button>
                                                    <button
                                                        @click="
                                                            confirmDeleteId = null
                                                        "
                                                        class="text-xs font-black text-gray-400 hover:text-gray-600 uppercase px-2"
                                                    >
                                                        No
                                                    </button>
                                                </template>
                                                <template v-else>
                                                    <NuxtLink
                                                        :to="`/admin/match/${match.id}`"
                                                        class="text-blue-500 hover:text-blue-700 transition-colors p-1"
                                                        title="Ref Match"
                                                    >
                                                        <Icon
                                                            name="mdi:whistle"
                                                            class="text-base"
                                                        />
                                                    </NuxtLink>
                                                    <button
                                                        @click="startEdit(match)"
                                                        class="text-gray-400 hover:text-black transition-colors p-1"
                                                        title="Edit"
                                                    >
                                                        <Icon
                                                            name="mdi:pencil"
                                                            class="text-base"
                                                        />
                                                    </button>
                                                    <button
                                                        @click="
                                                            confirmDeleteId =
                                                                match.id
                                                        "
                                                        class="text-gray-400 hover:text-red-600 transition-colors p-1"
                                                        title="Delete"
                                                    >
                                                        <Icon
                                                            name="mdi:delete-outline"
                                                            class="text-base"
                                                        />
                                                    </button>
                                                </template>
                                            </div>

                                            <!-- Mobile Actions Button -->
                                            <button
                                                class="sm:hidden text-gray-400 hover:text-black transition-colors p-1 active:translate-y-0.5"
                                                @click="selectedMatchActions = match"
                                            >
                                                <Icon name="mdi:dots-vertical" class="text-xl" />
                                            </button>
                                        </div>

                                        <!-- Top Left Status -->
                                        <div class="absolute top-2 left-2">
                                            <span
                                                :class="
                                                    statusColor(match.status)
                                                "
                                                class="text-[10px] font-impact tracking-widest px-2 py-0.5 border-2 border-black uppercase"
                                            >
                                                {{
                                                    translateStatus(match.status)
                                                }}
                                            </span>
                                        </div>

                                        <!-- Knockout Label -->
                                        <div class="text-center mb-4 sm:mb-6 mt-4">
                                            <span class="text-xs font-impact uppercase tracking-widest text-secondary block">
                                                Incontro {{ mIdx + 1 }}
                                            </span>
                                            <span
                                                v-if="Number(roundNum) > 1"
                                                class="text-[10px] font-impact uppercase tracking-widest text-primary block mt-0.5"
                                            >
                                                Da vincitori
                                            </span>
                                        </div>

                                        <!-- Main Match Content -->
                                        <div class="flex items-center justify-between gap-2 sm:gap-4">
                                            <!-- Team 1 -->
                                            <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                                                <div class="w-12 h-12 sm:w-16 sm:h-16 bg-cement border-2 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                                                    <img
                                                        v-if="getTeamLogo(match.team1_id)"
                                                        :src="getTeamLogo(match.team1_id)"
                                                        class="w-full h-full object-cover"
                                                    />
                                                    <Icon
                                                        v-else
                                                        name="mdi:shield-outline"
                                                        class="text-gray-400 text-2xl"
                                                    />
                                                </div>
                                                <span
                                                    class="font-impact uppercase tracking-widest text-center text-sm sm:text-base leading-tight break-words max-w-full"
                                                    :class="
                                                        match.team1_id
                                                            ? 'text-black'
                                                            : 'text-gray-400'
                                                    "
                                                >
                                                    {{ displayKnockoutName(match, 1, roundNum, mIdx) }}
                                                </span>
                                            </div>

                                            <!-- Center (VS / Scores / Time) -->
                                            <div class="flex flex-col items-center justify-center min-w-[70px] sm:min-w-[90px]">
                                                <template v-if="match.status === 'completed' || match.status === 'finished'">
                                                    <div class="flex items-center gap-2 font-black text-2xl sm:text-3xl font-impact tracking-tighter">
                                                        <span>{{ match.team1_score ?? 0 }}</span>
                                                        <span class="text-secondary text-lg">-</span>
                                                        <span>{{ match.team2_score ?? 0 }}</span>
                                                    </div>
                                                </template>
                                                <template v-else>
                                                    <div class="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-black text-white flex items-center justify-center font-impact italic text-sm sm:text-base">VS</div>
                                                </template>

                                                <span
                                                    v-if="formatTime(match.start_time)"
                                                    class="mt-2 text-xs sm:text-sm font-impact tracking-widest text-secondary"
                                                >
                                                    {{ formatTime(match.start_time) }}
                                                </span>
                                            </div>

                                            <!-- Team 2 -->
                                            <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                                                <div class="w-12 h-12 sm:w-16 sm:h-16 bg-cement border-2 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                                                    <img
                                                        v-if="getTeamLogo(match.team2_id)"
                                                        :src="getTeamLogo(match.team2_id)"
                                                        class="w-full h-full object-cover"
                                                    />
                                                    <Icon
                                                        v-else
                                                        name="mdi:shield-outline"
                                                        class="text-gray-400 text-2xl"
                                                    />
                                                </div>
                                                <span
                                                    class="font-impact uppercase tracking-widest text-center text-sm sm:text-base leading-tight break-words max-w-full"
                                                    :class="
                                                        match.team2_id
                                                            ? 'text-black'
                                                            : 'text-gray-400'
                                                    "
                                                >
                                                    {{ displayKnockoutName(match, 2, roundNum, mIdx) }}
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div v-else>
                <div
                    v-if="Object.keys(groupMatches).length === 0"
                    class="card-grunge !bg-cement p-12 flex flex-col items-center justify-center text-secondary border-dashed"
                >
                    <Icon
                        name="mdi:table-large"
                        class="text-6xl mb-4 opacity-30"
                    />
                    <p class="font-impact uppercase tracking-widest text-lg">
                        Nessun incontro dei gironi ancora
                    </p>
                    <p class="text-sm mt-1 font-bold">
                        Genera tutti gli incontri dei gironi o aggiungili manualmente
                    </p>
                </div>
                <div v-else class="space-y-6">
                    <!-- Call to Action: Generate Knockout Bracket if Group Stage is Complete and no Knockout Matches exist yet -->
                    <div
                        v-if="allGroupMatchesCompleted && !hasKnockoutMatches"
                        class="animate-in fade-in slide-in-from-top-4 duration-500 pb-2"
                    >
                        <div
                            class="card-grunge !bg-primary border-4 border-black p-6 sm:p-8 relative overflow-hidden flex flex-col items-center justify-center gap-4 text-center"
                        >
                            <Icon
                                name="mdi:tournament"
                                class="absolute -right-8 -bottom-12 text-[200px] text-white opacity-10 pointer-events-none"
                            />
                            <div
                                class="relative z-10 text-white space-y-2 max-w-lg"
                            >
                                <div
                                    class="flex items-center justify-center gap-2 text-yellow-300 font-impact uppercase tracking-widest text-xs sm:text-sm"
                                >
                                    <Icon
                                        name="mdi:check-decagram"
                                        class="text-base"
                                    />
                                    Fase a Gironi Completata
                                </div>
                                <h2
                                    class="text-3xl sm:text-4xl font-impact uppercase tracking-widest leading-none text-white"
                                >
                                    Pronto per il Sorteggio
                                </h2>
                                <p class="text-gray-200 font-bold uppercase tracking-wider text-xs sm:text-sm leading-normal">
                                    Tutti gli incontri della fase a gironi sono stati
                                    risolti. Ora puoi generare il tabellone ufficiale
                                    a eliminazione diretta.
                                </p>
                            </div>
                            <div class="relative z-10">
                                <button
                                    @click="autoGenerateKnockout"
                                    class="flex items-center justify-center gap-3 px-8 py-3.5 bg-white text-primary border-4 border-black font-impact uppercase tracking-widest hover:bg-black hover:text-white hover:border-white transition-all shadow-[4px_4px_0px_rgba(0,0,0,1)] hover:-translate-y-0.5 active:scale-95 transform -skew-x-6"
                                >
                                    <Icon name="mdi:whistle" class="text-xl transform skew-x-6 block" />
                                    <span class="transform skew-x-6 block">Genera tabellone</span>
                                </button>
                            </div>
                        </div>
                    </div>

                    <div
                        v-for="(groupMatchList, groupId) in groupMatches"
                        :key="groupId"
                        class="card-grunge bg-white overflow-hidden"
                    >
                        <div
                            class="px-6 py-4 bg-cement border-b-4 border-black flex items-center justify-between"
                        >
                            <h3
                                class="font-impact text-xl uppercase tracking-widest text-black"
                            >
                                {{ getGroupName(String(groupId)) }}
                            </h3>
                            <span
                                class="text-xs font-impact tracking-widest text-secondary border-2 border-black bg-white px-3 py-1 uppercase shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            >
                                {{ groupMatchList.length }} incontri
                            </span>
                        </div>
                        <div class="divide-y-2 divide-black">
                            <div
                                v-for="match in groupMatchList"
                                :key="match.id"
                            >
                                <div
                                    v-if="editingMatch?.id === match.id"
                                    class="p-4 space-y-3"
                                >
                                    <div class="flex gap-2">
                                        <select
                                            v-model="editingMatch.team1_id"
                                            class="flex-1 bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest uppercase outline-none focus:border-primary transition-all"
                                        >
                                            <option value="">DA DEFINIRE</option>
                                            <option
                                                v-for="t in teams"
                                                :key="t.id"
                                                :value="t.id"
                                            >
                                                {{ t.name }}
                                            </option>
                                        </select>
                                        <span
                                            class="text-gray-400 font-black text-sm self-center"
                                            >vs</span
                                        >
                                        <select
                                            v-model="editingMatch.team2_id"
                                            class="flex-1 bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest uppercase outline-none focus:border-primary transition-all"
                                        >
                                            <option value="">DA DEFINIRE</option>
                                            <option
                                                v-for="t in teams"
                                                :key="t.id"
                                                :value="t.id"
                                            >
                                                {{ t.name }}
                                            </option>
                                        </select>
                                        <input
                                            v-model="editingMatch.start_time"
                                            type="time"
                                            class="w-32 bg-white border-4 border-black px-3 py-2.5 text-sm font-impact tracking-widest outline-none focus:border-primary transition-all"
                                        />
                                    </div>
                                    <div class="flex gap-2">
                                        <button
                                            @click="saveEdit"
                                            class="btn-skewed flex-1 !text-xs py-2"
                                        >
                                            Salva
                                        </button>
                                        <button
                                            @click="cancelEdit"
                                            class="btn-skewed-secondary flex-1 !text-xs py-2"
                                        >
                                            Annulla
                                        </button>
                                    </div>
                                </div>
                                <div
                                    v-else
                                    class="relative p-4 sm:p-6 transition-colors"
                                    :class="
                                        match.status === 'in_progress'
                                            ? 'bg-red-50 shadow-[inset_4px_0_0_var(--primary)]'
                                            : 'hover:bg-gray-50'
                                    "
                                >
                                    <!-- Top Right Actions -->
                                    <div class="absolute top-2 right-2 flex items-center gap-2">
                                        <!-- Desktop Actions -->
                                        <div class="hidden sm:flex items-center gap-1">
                                            <template
                                                v-if="confirmDeleteId === match.id"
                                            >
                                                <button
                                                    @click="deleteMatch(match.id)"
                                                    class="text-xs font-black text-red-600 hover:text-red-800 uppercase px-2"
                                                >
                                                    Sì
                                                </button>
                                                <button
                                                    @click="confirmDeleteId = null"
                                                    class="text-xs font-black text-gray-400 hover:text-black uppercase px-2"
                                                >
                                                    No
                                                </button>
                                            </template>
                                            <template v-else>
                                                <NuxtLink
                                                    :to="`/admin/match/${match.id}`"
                                                    class="text-blue-500 hover:text-blue-700 transition-colors p-1"
                                                    title="Ref Match"
                                                >
                                                    <Icon
                                                        name="mdi:whistle"
                                                        class="text-base"
                                                    />
                                                </NuxtLink>
                                                <button
                                                    @click="startEdit(match)"
                                                    class="text-gray-400 hover:text-black transition-colors p-1"
                                                >
                                                    <Icon
                                                        name="mdi:pencil"
                                                        class="text-base"
                                                    />
                                                </button>
                                                <button
                                                    @click="confirmDeleteId = match.id"
                                                    class="text-gray-400 hover:text-red-600 transition-colors p-1"
                                                >
                                                    <Icon
                                                        name="mdi:delete-outline"
                                                        class="text-base"
                                                    />
                                                </button>
                                            </template>
                                        </div>

                                        <!-- Mobile Actions Button -->
                                        <button
                                            class="sm:hidden text-gray-400 hover:text-black transition-colors p-1 active:translate-y-0.5"
                                            @click="selectedMatchActions = match"
                                        >
                                            <Icon name="mdi:dots-vertical" class="text-xl" />
                                        </button>
                                    </div>

                                    <!-- Top Left Status -->
                                    <div class="absolute top-2 left-2">
                                        <span
                                            :class="statusColor(match.status)"
                                            class="text-[10px] font-impact tracking-widest px-2 py-0.5 border-2 border-black uppercase"
                                        >
                                            {{ translateStatus(match.status) }}
                                        </span>
                                    </div>

                                    <!-- Main Match Content -->
                                    <div class="mt-8 flex items-center justify-between gap-2 sm:gap-4">
                                        <!-- Team 1 -->
                                        <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                                            <div class="w-12 h-12 sm:w-16 sm:h-16 bg-white border-2 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                                                <img
                                                    v-if="getTeamLogo(match.team1_id)"
                                                    :src="getTeamLogo(match.team1_id)"
                                                    class="w-full h-full object-cover"
                                                />
                                                <Icon
                                                    v-else
                                                    name="mdi:shield"
                                                    class="text-secondary text-2xl"
                                                />
                                            </div>
                                            <span
                                                class="font-impact uppercase tracking-widest text-center text-sm sm:text-base leading-tight break-words max-w-full"
                                                :class="
                                                    match.team1_id
                                                        ? 'text-black'
                                                        : 'text-secondary'
                                                "
                                            >
                                                {{ displayName(match, 1) }}
                                            </span>
                                        </div>

                                        <!-- Center (VS / Scores / Time) -->
                                        <div class="flex flex-col items-center justify-center min-w-[70px] sm:min-w-[90px]">
                                            <template v-if="match.status === 'completed' || match.status === 'finished'">
                                                <div class="flex items-center gap-2 font-black text-2xl sm:text-3xl font-impact tracking-tighter">
                                                    <span>{{ match.team1_score ?? 0 }}</span>
                                                    <span class="text-secondary text-lg">-</span>
                                                    <span>{{ match.team2_score ?? 0 }}</span>
                                                </div>
                                            </template>
                                            <template v-else>
                                                <div class="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-black text-white flex items-center justify-center font-impact italic text-sm sm:text-base">VS</div>
                                            </template>

                                            <span
                                                v-if="formatTime(match.start_time)"
                                                class="mt-2 text-xs sm:text-sm font-impact tracking-widest text-secondary"
                                            >
                                                {{ formatTime(match.start_time) }}
                                            </span>
                                        </div>

                                        <!-- Team 2 -->
                                        <div class="flex-1 flex flex-col items-center gap-2 min-w-0">
                                            <div class="w-12 h-12 sm:w-16 sm:h-16 bg-white border-2 border-black flex-shrink-0 flex items-center justify-center overflow-hidden">
                                                <img
                                                    v-if="getTeamLogo(match.team2_id)"
                                                    :src="getTeamLogo(match.team2_id)"
                                                    class="w-full h-full object-cover"
                                                />
                                                <Icon
                                                    v-else
                                                    name="mdi:shield"
                                                    class="text-secondary text-2xl"
                                                />
                                            </div>
                                            <span
                                                class="font-impact uppercase tracking-widest text-center text-sm sm:text-base leading-tight break-words max-w-full"
                                                :class="
                                                    match.team2_id
                                                        ? 'text-black'
                                                        : 'text-secondary'
                                                "
                                            >
                                                {{ displayName(match, 2) }}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </template>

        <div
            v-if="showAddModal"
            class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4"
            @click.self="showAddModal = false"
        >
            <div
                class="card-grunge bg-white w-full max-w-md p-6 sm:p-8 space-y-4"
            >
                <div class="flex items-center justify-between">
                    <h3 class="text-xl font-black uppercase tracking-tight">
                        Aggiungi Incontro
                    </h3>
                    <button
                        @click="showAddModal = false"
                        class="text-gray-400 hover:text-black transition-colors"
                    >
                        <Icon name="mdi:close" class="text-xl" />
                    </button>
                </div>

                <div class="space-y-3">
                    <div>
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Tipo</label
                        >
                        <div class="flex border-4 border-black">
                            <button
                                @click="addForm.match_type = 'knockout'"
                                :disabled="!allGroupMatchesCompleted"
                                class="flex-1 py-2 text-sm font-impact uppercase transition-all"
                                :class="[
                                    addForm.match_type === 'knockout'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-500',
                                    !allGroupMatchesCompleted
                                        ? 'opacity-40 cursor-not-allowed'
                                        : '',
                                ]"
                            >
                                Eliminazione Diretta
                            </button>
                            <button
                                @click="addForm.match_type = 'group'"
                                class="flex-1 py-2 text-sm font-impact uppercase transition-all"
                                :class="
                                    addForm.match_type === 'group'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-500'
                                "
                            >
                                Girone
                            </button>
                        </div>
                    </div>

                    <div v-if="addForm.match_type === 'group'">
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Girone</label
                        >
                        <select
                            v-model="addForm.group_id"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm uppercase focus:border-primary outline-none transition-all"
                        >
                            <option value="">-- Seleziona Girone --</option>
                            <option
                                v-for="g in groups"
                                :key="g.id"
                                :value="g.id"
                            >
                                {{ g.name }}
                            </option>
                        </select>
                    </div>

                    <div v-if="addForm.match_type === 'knockout'">
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Turno</label
                        >
                        <input
                            v-model="addForm.round"
                            type="number"
                            min="1"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm focus:border-primary outline-none transition-all"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Squadra 1</label
                        >
                        <div class="flex border-4 border-black mb-3">
                            <button
                                @click="addForm.team1_type = 'team'"
                                class="flex-1 py-1.5 text-xs font-impact uppercase transition-all"
                                :class="
                                    addForm.team1_type === 'team'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-400'
                                "
                            >
                                Squadra
                            </button>
                            <button
                                @click="addForm.team1_type = 'placeholder'"
                                class="flex-1 py-1.5 text-xs font-impact uppercase transition-all"
                                :class="
                                    addForm.team1_type === 'placeholder'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-400'
                                "
                            >
                                Segnaposto
                            </button>
                        </div>
                        <select
                            v-if="addForm.team1_type === 'team'"
                            v-model="addForm.team1_id"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm uppercase focus:border-primary outline-none transition-all"
                        >
                            <option value="">-- Seleziona Squadra --</option>
                            <option
                                v-for="t in teams"
                                :key="t.id"
                                :value="t.id"
                            >
                                {{ t.name }}
                            </option>
                        </select>
                        <input
                            v-else
                            v-model="addForm.team1_placeholder"
                            placeholder="es. Vincitore Partita 3"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm focus:border-primary outline-none transition-all"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Squadra 2</label
                        >
                        <div class="flex border-4 border-black mb-3">
                            <button
                                @click="addForm.team2_type = 'team'"
                                class="flex-1 py-1.5 text-xs font-impact uppercase transition-all"
                                :class="
                                    addForm.team2_type === 'team'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-400'
                                "
                            >
                                Squadra
                            </button>
                            <button
                                @click="addForm.team2_type = 'placeholder'"
                                class="flex-1 py-1.5 text-xs font-impact uppercase transition-all"
                                :class="
                                    addForm.team2_type === 'placeholder'
                                        ? 'bg-white shadow-sm text-black'
                                        : 'text-gray-400'
                                "
                            >
                                Segnaposto
                            </button>
                        </div>
                        <select
                            v-if="addForm.team2_type === 'team'"
                            v-model="addForm.team2_id"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm uppercase focus:border-primary outline-none transition-all"
                        >
                            <option value="">-- Seleziona Squadra --</option>
                            <option
                                v-for="t in teams"
                                :key="t.id"
                                :value="t.id"
                            >
                                {{ t.name }}
                            </option>
                        </select>
                        <input
                            v-else
                            v-model="addForm.team2_placeholder"
                            placeholder="es. Vincitore Partita 4"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm focus:border-primary outline-none transition-all"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-impact uppercase tracking-widest text-secondary mb-1 block"
                            >Orario di inizio (opzionale)</label
                        >
                        <input
                            v-model="addForm.start_time"
                            type="time"
                            class="w-full bg-white border-4 border-black px-3 py-2.5 font-impact text-sm focus:border-primary outline-none transition-all"
                        />
                    </div>
                </div>

                <div class="flex gap-3 pt-2">
                    <button
                        @click="showAddModal = false"
                        class="btn-skewed-secondary flex-1 text-sm"
                    >
                        Annulla
                    </button>
                    <button
                        @click="saveAdd"
                        class="btn-skewed flex-1 text-sm"
                    >
                        Salva
                    </button>
                </div>
            </div>
        </div>

        <!-- Mobile Actions Modal -->
        <div
            v-if="showMobileActions"
            class="fixed inset-0 bg-black/80 flex items-end justify-center z-[100] p-4 sm:hidden animate-in fade-in duration-200"
            @click.self="showMobileActions = false"
        >
            <div
                class="bg-cement w-full max-w-sm border-4 border-black shadow-[8px_8px_0px_rgba(0,0,0,1)] p-5 space-y-4 animate-in slide-in-from-bottom-8 duration-300"
            >
                <div class="flex justify-between items-center mb-2 border-b-4 border-black pb-3">
                    <h3 class="font-impact uppercase tracking-widest text-lg">Azioni</h3>
                    <button
                        @click="showMobileActions = false"
                        class="text-gray-500 hover:text-black"
                    >
                        <Icon name="mdi:close" class="text-2xl" />
                    </button>
                </div>

                <div class="flex flex-col gap-3">
                    <template v-if="activeTab === 'knockout'">
                        <template v-if="Object.keys(knockoutMatches).length > 0">
                            <button
                                @click="
                                    clearKnockout();
                                    showMobileActions = false;
                                "
                                class="btn-skewed-secondary !text-primary !border-primary hover:!bg-primary hover:!text-white w-full"
                            >
                                <span class="btn-skewed-content text-sm">Cancella tabellone</span>
                            </button>
                            <button
                                @click="
                                    openAddModal();
                                    showMobileActions = false;
                                "
                                class="btn-skewed-secondary w-full"
                            >
                                <span class="btn-skewed-content text-sm">Aggiungi incontro</span>
                            </button>
                            <button
                                @click="
                                    autoGenerateKnockout();
                                    showMobileActions = false;
                                "
                                class="btn-skewed w-full"
                            >
                                <span class="btn-skewed-content text-sm">Rigenera</span>
                            </button>
                        </template>
                    </template>
                    <template v-else>
                        <button
                            @click="
                                clearGroupMatches();
                                showMobileActions = false;
                            "
                            class="btn-skewed-secondary !text-primary !border-primary hover:!bg-primary hover:!text-white w-full"
                        >
                            <span class="btn-skewed-content text-sm">Cancella gironi</span>
                        </button>
                        <button
                            @click="
                                openAddModal();
                                showMobileActions = false;
                            "
                            class="btn-skewed-secondary w-full"
                        >
                            <span class="btn-skewed-content text-sm">Aggiungi incontro</span>
                        </button>
                        <button
                            @click="
                                autoGenerateGroupMatches();
                                showMobileActions = false;
                            "
                            class="btn-skewed w-full"
                        >
                            <span class="btn-skewed-content text-sm">Genera calendario</span>
                        </button>
                    </template>
                </div>
            </div>
        </div>

        <!-- Match Card Mobile Actions Modal -->
        <div
            v-if="selectedMatchActions"
            class="fixed inset-0 bg-black/80 flex items-end justify-center z-[110] p-4 sm:hidden animate-in fade-in duration-200"
            @click.self="selectedMatchActions = null; confirmDeleteId = null;"
        >
            <div
                class="bg-cement w-full max-w-sm border-4 border-black shadow-[8px_8px_0px_rgba(0,0,0,1)] p-5 space-y-4 animate-in slide-in-from-bottom-8 duration-300"
            >
                <div class="flex justify-between items-center mb-2 border-b-4 border-black pb-3">
                    <h3 class="font-impact uppercase tracking-widest text-lg">Azioni Incontro</h3>
                    <button
                        @click="selectedMatchActions = null; confirmDeleteId = null;"
                        class="text-gray-500 hover:text-black"
                    >
                        <Icon name="mdi:close" class="text-2xl" />
                    </button>
                </div>

                <div class="flex flex-col gap-3">
                    <template v-if="confirmDeleteId === selectedMatchActions.id">
                        <p class="font-impact text-red-600 text-center uppercase mb-2">Confermi l'eliminazione?</p>
                        <button
                            @click="
                                deleteMatch(selectedMatchActions.id);
                                selectedMatchActions = null;
                            "
                            class="btn-skewed-secondary !text-red-600 !border-red-600 hover:!bg-red-600 hover:!text-white w-full"
                        >
                            <span class="btn-skewed-content text-sm">Sì, elimina</span>
                        </button>
                        <button
                            @click="confirmDeleteId = null"
                            class="btn-skewed-secondary w-full"
                        >
                            <span class="btn-skewed-content text-sm">Annulla</span>
                        </button>
                    </template>
                    <template v-else>
                        <NuxtLink
                            :to="`/admin/match/${selectedMatchActions.id}`"
                            class="btn-skewed flex justify-center py-3"
                            @click="selectedMatchActions = null"
                        >
                            <span class="btn-skewed-content text-base flex items-center gap-2">
                                <Icon name="mdi:whistle" class="text-xl" />
                                Arbitra
                            </span>
                        </NuxtLink>
                        <button
                            @click="
                                startEdit(selectedMatchActions);
                                selectedMatchActions = null;
                            "
                            class="btn-skewed-secondary w-full py-3"
                        >
                            <span class="btn-skewed-content text-base flex items-center gap-2 justify-center text-black">
                                <Icon name="mdi:pencil" class="text-xl" />
                                Modifica
                            </span>
                        </button>
                        <button
                            @click="confirmDeleteId = selectedMatchActions.id"
                            class="btn-skewed-secondary !text-red-600 !border-red-600 hover:!bg-red-600 hover:!text-white w-full py-3"
                        >
                            <span class="btn-skewed-content text-base flex items-center gap-2 justify-center">
                                <Icon name="mdi:delete-outline" class="text-xl" />
                                Elimina
                            </span>
                        </button>
                    </template>
                </div>
            </div>
        </div>
    </div>
</template>
