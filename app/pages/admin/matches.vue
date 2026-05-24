// pages/admin/matches.vue

<script setup lang="ts">
import { ref, onMounted, computed } from "vue";

definePageMeta({ middleware: "admin" });

const supabase = useSupabaseClient();
const activeTab = ref<"knockout" | "group">("group"); // Default to group
const teams = ref<any[]>([]);
const groups = ref<any[]>([]);
const matches = ref<any[]>([]);
const isLoading = ref(true);

// Edit state
const editingMatch = ref<any | null>(null);

// Delete state
const confirmDeleteId = ref<string | null>(null);

// Add match modal
const showAddModal = ref(false);
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

const displayName = (match: any, slot: 1 | 2) => {
    const idKey = `team${slot}_id`;
    const phKey = `team${slot}_placeholder`;
    if (match[idKey]) return getTeamName(match[idKey]) || "Unknown";
    if (match[phKey]) return match[phKey];
    return "TBD";
};

const formatTime = (t: string | null) => (t ? t.slice(0, 5) : null);

const statusColor = (s: string) => {
    if (s === "completed") return "bg-green-100 text-green-700";
    if (s === "in_progress") return "bg-red-100 text-red-600 animate-pulse";
    return "bg-gray-100 text-gray-500";
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

    if (
        allGroupMatchesCompleted.value &&
        Object.keys(knockoutMatches.value).length > 0
    ) {
        activeTab.value = "knockout";
    } else {
        activeTab.value = "group";
    }

    isLoading.value = false;
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

onMounted(loadData);
</script>

<template>
    <div class="max-w-7xl mx-auto px-4 py-8 space-y-6">
        <div
            v-if="isLoading"
            class="flex items-center justify-center py-24 text-red-500"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <div
                class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
            >
                <div
                    class="flex bg-white border border-gray-200 rounded-xl p-1 gap-1 shadow-sm"
                >
                    <button
                        @click="activeTab = 'group'"
                        class="px-6 py-2.5 rounded-lg text-sm font-black uppercase tracking-wide transition-all"
                        :class="
                            activeTab === 'group'
                                ? 'bg-black text-white shadow-md'
                                : 'text-gray-400 hover:text-black'
                        "
                    >
                        Fase a Gironi
                    </button>
                    <button
                        v-if="allGroupMatchesCompleted"
                        @click="activeTab = 'knockout'"
                        class="px-6 py-2.5 rounded-lg text-sm font-black uppercase tracking-wide transition-all"
                        :class="
                            activeTab === 'knockout'
                                ? 'bg-black text-white shadow-md'
                                : 'text-gray-400 hover:text-black'
                        "
                    >
                        Fase a Eliminazione Diretta
                    </button>
                </div>

                <div class="flex gap-2 flex-wrap">
                    <template v-if="activeTab === 'knockout'">
                        <template
                            v-if="Object.keys(knockoutMatches).length > 0"
                        >
                            <button
                                @click="clearKnockout"
                                class="px-4 py-2 text-sm font-bold uppercase tracking-wide text-red-500 bg-white border border-red-100 hover:bg-red-50 rounded-xl transition-colors"
                            >
                                Cancella
                            </button>
                            <button
                                @click="openAddModal"
                                class="px-4 py-2 text-sm font-bold uppercase tracking-wide bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 rounded-xl transition-colors"
                            >
                                + Aggiungi Incontro
                            </button>
                            <button
                                @click="autoGenerateKnockout"
                                class="px-4 py-2 text-sm font-bold uppercase tracking-wide bg-black text-white hover:bg-gray-800 rounded-xl transition-colors shadow-md"
                            >
                                Rigenera Tabellone
                            </button>
                        </template>
                    </template>
                    <template v-else>
                        <button
                            @click="clearGroupMatches"
                            class="px-4 py-2 text-sm font-bold uppercase tracking-wide text-red-500 bg-white border border-red-100 hover:bg-red-50 rounded-xl transition-colors"
                        >
                            Cancella
                        </button>
                        <button
                            @click="openAddModal"
                            class="px-4 py-2 text-sm font-bold uppercase tracking-wide bg-white border border-gray-200 hover:bg-gray-50 text-gray-700 rounded-xl transition-colors"
                        >
                            + Aggiungi Incontro
                        </button>
                        <button
                            @click="autoGenerateGroupMatches"
                            class="px-4 py-2 text-sm font-bold uppercase tracking-wide bg-black text-white hover:bg-gray-800 rounded-xl transition-colors shadow-md"
                        >
                            Genera Tutti
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
                        class="bg-gradient-to-r from-red-600 to-red-800 rounded-3xl p-8 sm:p-12 shadow-2xl relative overflow-hidden flex flex-col items-center justify-center gap-6 text-center"
                    >
                        <Icon
                            name="mdi:tournament"
                            class="absolute -right-8 -bottom-12 text-[250px] text-white opacity-10 pointer-events-none"
                        />
                        <div
                            class="relative z-10 text-white space-y-4 max-w-lg"
                        >
                            <div
                                class="flex items-center justify-center gap-2 text-yellow-300 font-bold uppercase tracking-widest text-xs"
                            >
                                <Icon
                                    name="mdi:check-decagram"
                                    class="text-lg"
                                />
                                Fase a Gironi Completata
                            </div>
                            <h2
                                class="text-4xl sm:text-5xl font-black uppercase tracking-tight leading-none"
                            >
                                Pronto per il Sorteggio
                            </h2>
                            <p class="text-white/80 font-medium">
                                Tutti gli incontri della fase a gironi sono stati
                                risolti. Ora puoi generare il tabellone ufficiale
                                a eliminazione diretta.
                            </p>
                        </div>
                        <div class="relative z-10 mt-4">
                            <button
                                @click="autoGenerateKnockout"
                                class="flex items-center justify-center gap-3 px-10 py-5 bg-white text-red-600 rounded-2xl font-black uppercase tracking-widest hover:bg-yellow-400 hover:text-black transition-all hover:-translate-y-1 hover:shadow-xl"
                            >
                                <Icon name="mdi:whistle" class="text-2xl" />
                                Genera Tabellone
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
                                    class="text-xs font-black uppercase tracking-widest text-white bg-black px-4 py-1.5 rounded-full"
                                >
                                    {{ roundLabel(Number(roundNum)) }}
                                </span>
                            </div>
                            <div
                                v-for="(match, mIdx) in roundMatches"
                                :key="match.id"
                                class="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden hover:shadow-md transition-shadow"
                            >
                                <div
                                    v-if="editingMatch?.id === match.id"
                                    class="p-4 space-y-3"
                                >
                                    <select
                                        v-model="editingMatch.team1_id"
                                        class="w-full bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black focus:ring-2 focus:ring-black/10 outline-none uppercase"
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
                                        class="w-full bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black focus:ring-2 focus:ring-black/10 outline-none uppercase"
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
                                            class="w-1/3 bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none"
                                        />
                                        <input
                                            v-model="editingMatch.start_time"
                                            type="time"
                                            class="flex-1 bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none"
                                        />
                                    </div>
                                    <select
                                        v-model="editingMatch.status"
                                        class="w-full bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none uppercase"
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
                                            class="flex-1 bg-black text-white py-2 rounded-xl text-xs font-black uppercase hover:bg-gray-800 transition-colors"
                                        >
                                            Salva
                                        </button>
                                        <button
                                            @click="cancelEdit"
                                            class="flex-1 bg-gray-100 text-gray-600 py-2 rounded-xl text-xs font-black uppercase hover:bg-gray-200 transition-colors"
                                        >
                                            Annulla
                                        </button>
                                    </div>
                                </div>

                                <div v-else>
                                    <div
                                        class="flex items-center gap-3 px-4 py-3 border-b border-gray-50"
                                    >
                                        <img
                                            v-if="getTeamLogo(match.team1_id)"
                                            :src="getTeamLogo(match.team1_id)"
                                            class="w-7 h-7 rounded-full object-cover flex-shrink-0"
                                        />
                                        <div
                                            v-else
                                            class="w-7 h-7 rounded-full bg-gray-100 flex-shrink-0 flex items-center justify-center"
                                        >
                                            <Icon
                                                name="mdi:shield-outline"
                                                class="text-gray-400 text-sm"
                                            />
                                        </div>
                                        <span
                                            class="text-sm font-black uppercase tracking-tight truncate"
                                            :class="
                                                match.team1_id
                                                    ? 'text-black'
                                                    : 'text-gray-400'
                                            "
                                        >
                                            {{ displayName(match, 1) }}
                                        </span>
                                    </div>
                                    <div
                                        class="flex items-center justify-center py-1 bg-gray-50"
                                    >
                                        <span
                                            class="text-xs font-black text-gray-400 uppercase tracking-widest"
                                            >vs</span
                                        >
                                    </div>
                                    <div
                                        class="flex items-center gap-3 px-4 py-3 border-t border-gray-50"
                                    >
                                        <img
                                            v-if="getTeamLogo(match.team2_id)"
                                            :src="getTeamLogo(match.team2_id)"
                                            class="w-7 h-7 rounded-full object-cover flex-shrink-0"
                                        />
                                        <div
                                            v-else
                                            class="w-7 h-7 rounded-full bg-gray-100 flex-shrink-0 flex items-center justify-center"
                                        >
                                            <Icon
                                                name="mdi:shield-outline"
                                                class="text-gray-400 text-sm"
                                            />
                                        </div>
                                        <span
                                            class="text-sm font-black uppercase tracking-tight truncate"
                                            :class="
                                                match.team2_id
                                                    ? 'text-black'
                                                    : 'text-gray-400'
                                            "
                                        >
                                            {{ displayName(match, 2) }}
                                        </span>
                                    </div>
                                    <div
                                        class="flex items-center justify-between px-4 py-2.5 bg-gray-50 border-t border-gray-100"
                                    >
                                        <div class="flex items-center gap-2">
                                            <span
                                                v-if="
                                                    formatTime(match.start_time)
                                                "
                                                class="text-xs font-bold text-gray-700"
                                            >
                                                {{
                                                    formatTime(match.start_time)
                                                }}
                                            </span>
                                            <span
                                                v-else
                                                class="text-xs font-bold text-red-400"
                                                >Nessun orario</span
                                            >
                                            <span
                                                :class="
                                                    statusColor(match.status)
                                                "
                                                class="text-xs font-bold px-2 py-0.5 rounded-full capitalize"
                                            >
                                                {{
                                                    translateStatus(match.status)
                                                }}
                                            </span>
                                        </div>
                                        <div class="flex gap-1">
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
                    class="flex flex-col items-center justify-center py-24 text-gray-400"
                >
                    <Icon
                        name="mdi:table-large"
                        class="text-6xl mb-4 opacity-30"
                    />
                    <p class="font-bold uppercase tracking-wide">
                        Nessun incontro dei gironi ancora
                    </p>
                    <p class="text-sm mt-1">
                        Genera tutti gli incontri dei gironi o aggiungili manualmente
                    </p>
                </div>
                <div v-else class="space-y-6">
                    <div
                        v-for="(groupMatchList, groupId) in groupMatches"
                        :key="groupId"
                        class="bg-white border border-gray-100 rounded-2xl shadow-sm overflow-hidden"
                    >
                        <div
                            class="px-6 py-4 border-b border-gray-100 flex items-center justify-between"
                        >
                            <h3
                                class="font-black uppercase tracking-tight text-black"
                            >
                                {{ getGroupName(String(groupId)) }}
                            </h3>
                            <span
                                class="text-xs font-bold text-gray-400 bg-gray-50 px-3 py-1 rounded-full border border-gray-100"
                            >
                                {{ groupMatchList.length }} incontri
                            </span>
                        </div>
                        <div class="divide-y divide-gray-50">
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
                                            class="flex-1 bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none uppercase"
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
                                            class="flex-1 bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none uppercase"
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
                                            class="w-32 bg-gray-50 rounded-xl px-3 py-2.5 text-sm font-bold border border-gray-200 focus:border-black outline-none"
                                        />
                                    </div>
                                    <div class="flex gap-2">
                                        <button
                                            @click="saveEdit"
                                            class="flex-1 bg-black text-white py-2 rounded-xl text-xs font-black uppercase hover:bg-gray-800"
                                        >
                                            Salva
                                        </button>
                                        <button
                                            @click="cancelEdit"
                                            class="flex-1 bg-gray-100 text-gray-600 py-2 rounded-xl text-xs font-black uppercase hover:bg-gray-200"
                                        >
                                            Annulla
                                        </button>
                                    </div>
                                </div>
                                <div
                                    v-else
                                    class="flex items-center justify-between px-6 py-3 hover:bg-gray-50 transition-colors"
                                >
                                    <div
                                        class="flex items-center gap-3 flex-1 min-w-0"
                                    >
                                        <div
                                            class="flex items-center gap-2 flex-1 min-w-0"
                                        >
                                            <img
                                                v-if="
                                                    getTeamLogo(match.team1_id)
                                                "
                                                :src="
                                                    getTeamLogo(match.team1_id)
                                                "
                                                class="w-7 h-7 rounded-full object-cover flex-shrink-0"
                                            />
                                            <span
                                                class="font-black uppercase text-sm truncate"
                                                :class="
                                                    match.team1_id
                                                        ? 'text-black'
                                                        : 'text-gray-400'
                                                "
                                                >{{
                                                    displayName(match, 1)
                                                }}</span
                                            >
                                        </div>
                                        <span
                                            class="text-xs font-black text-gray-400 px-3 flex-shrink-0"
                                            >VS</span
                                        >
                                        <div
                                            class="flex items-center gap-2 flex-1 min-w-0 justify-end"
                                        >
                                            <span
                                                class="font-black uppercase text-sm truncate text-right"
                                                :class="
                                                    match.team2_id
                                                        ? 'text-black'
                                                        : 'text-gray-400'
                                                "
                                                >{{
                                                    displayName(match, 2)
                                                }}</span
                                            >
                                            <img
                                                v-if="
                                                    getTeamLogo(match.team2_id)
                                                "
                                                :src="
                                                    getTeamLogo(match.team2_id)
                                                "
                                                class="w-7 h-7 rounded-full object-cover flex-shrink-0"
                                            />
                                        </div>
                                    </div>
                                    <div
                                        class="flex items-center gap-3 ml-4 flex-shrink-0"
                                    >
                                        <span
                                            v-if="formatTime(match.start_time)"
                                            class="text-xs font-bold text-gray-600"
                                            >{{
                                                formatTime(match.start_time)
                                            }}</span
                                        >
                                        <span
                                            v-else
                                            class="text-xs font-bold text-red-400"
                                            >Nessun orario</span
                                        >
                                        <span
                                            :class="statusColor(match.status)"
                                            class="text-xs font-bold px-2 py-0.5 rounded-full capitalize hidden sm:inline"
                                            >{{
                                                translateStatus(match.status)
                                            }}</span
                                        >
                                        <template
                                            v-if="confirmDeleteId === match.id"
                                        >
                                            <button
                                                @click="deleteMatch(match.id)"
                                                class="text-xs font-black text-red-600 uppercase"
                                            >
                                                Sì
                                            </button>
                                            <button
                                                @click="confirmDeleteId = null"
                                                class="text-xs font-black text-gray-400 uppercase"
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
                                                @click="
                                                    confirmDeleteId = match.id
                                                "
                                                class="text-gray-400 hover:text-red-600 transition-colors p-1"
                                            >
                                                <Icon
                                                    name="mdi:delete-outline"
                                                    class="text-base"
                                                />
                                            </button>
                                        </template>
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
                class="bg-white rounded-2xl shadow-2xl w-full max-w-md p-6 space-y-4"
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
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Tipo</label
                        >
                        <div class="flex bg-gray-100 p-1 rounded-xl">
                            <button
                                @click="addForm.match_type = 'knockout'"
                                :disabled="!allGroupMatchesCompleted"
                                class="flex-1 py-2 text-sm font-black uppercase rounded-lg transition-all"
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
                                class="flex-1 py-2 text-sm font-black uppercase rounded-lg transition-all"
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
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Girone</label
                        >
                        <select
                            v-model="addForm.group_id"
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm uppercase focus:border-black focus:ring-2 focus:ring-black/10 outline-none"
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
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Turno</label
                        >
                        <input
                            v-model="addForm.round"
                            type="number"
                            min="1"
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm focus:border-black outline-none"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Squadra 1</label
                        >
                        <div class="flex bg-gray-100 p-1 rounded-xl mb-2">
                            <button
                                @click="addForm.team1_type = 'team'"
                                class="flex-1 py-1.5 text-xs font-black uppercase rounded-lg transition-all"
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
                                class="flex-1 py-1.5 text-xs font-black uppercase rounded-lg transition-all"
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
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm uppercase focus:border-black outline-none"
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
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm focus:border-black outline-none"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Squadra 2</label
                        >
                        <div class="flex bg-gray-100 p-1 rounded-xl mb-2">
                            <button
                                @click="addForm.team2_type = 'team'"
                                class="flex-1 py-1.5 text-xs font-black uppercase rounded-lg transition-all"
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
                                class="flex-1 py-1.5 text-xs font-black uppercase rounded-lg transition-all"
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
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm uppercase focus:border-black outline-none"
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
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm focus:border-black outline-none"
                        />
                    </div>

                    <div>
                        <label
                            class="text-xs font-bold uppercase tracking-wide text-gray-500 mb-1 block"
                            >Orario di inizio (opzionale)</label
                        >
                        <input
                            v-model="addForm.start_time"
                            type="time"
                            class="w-full bg-gray-50 border border-gray-200 rounded-xl px-3 py-2.5 font-bold text-sm focus:border-black outline-none"
                        />
                    </div>
                </div>

                <div class="flex gap-3 pt-2">
                    <button
                        @click="showAddModal = false"
                        class="flex-1 bg-gray-100 text-gray-600 py-3 rounded-xl font-black uppercase text-sm hover:bg-gray-200 transition-colors"
                    >
                        Annulla
                    </button>
                    <button
                        @click="saveAdd"
                        class="flex-1 bg-black text-white py-3 rounded-xl font-black uppercase text-sm hover:bg-gray-800 transition-colors shadow-md"
                    >
                        Salva
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>
