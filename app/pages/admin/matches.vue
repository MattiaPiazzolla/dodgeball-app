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

// Knockout matches where both teams are assigned and match is still pending
const pendingReadyMatches = computed(() =>
    matches.value
        .filter(
            (m) =>
                m.match_type === "knockout" &&
                m.status === "pending" &&
                m.team1_id &&
                m.team2_id,
        )
        .sort(
            (a, b) =>
                (a.round || 0) - (b.round || 0) ||
                (a.bracket_position || 0) - (b.bracket_position || 0),
        ),
);

// First match recommended to play next
const nextRecommendedMatch = computed(
    () => pendingReadyMatches.value[0] ?? null,
);

// Stats for the bracket preview shown in the generate CTA
const knockoutPreview = computed(() => {
    let teamCount =
        groups.value.length > 0
            ? groups.value.length * 2
            : teams.value.length;
    teamCount = Math.max(2, teamCount);
    const rounds = Math.ceil(Math.log2(teamCount));
    const matchesInFirstRound = Math.pow(2, rounds - 1);
    return { teamCount, rounds, matchesInFirstRound };
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

    // Retroactively advance any matches that were completed before this
    // page was loaded (handles historical data and cross-device scenarios)
    await backfillKnockoutAdvancement();
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

    // Auto-advance winner when a match completion arrives via realtime
    // (e.g. completed from the referee console on a separate device)
    if (payload.eventType === "UPDATE" && changedMatch.status === "completed") {
        advanceWinner(changedMatch);
        fillRepechageSlots();
    }
};

// ── Match CRUD ────────────────────────────────────────────
const startEdit = (match: any) => {
    editingMatch.value = { ...match };
};

const cancelEdit = () => {
    editingMatch.value = null;
};

// ── Auto-progression ──────────────────────────────────────
const advanceWinner = async (completedMatch: any) => {
    if (completedMatch?.match_type !== "knockout") return;
    if (completedMatch?.status !== "completed") return;

    const winnerId =
        completedMatch.winner_id || getScoreWinnerId(completedMatch);
    if (!winnerId) return;

    const currentPos: number = Number(completedMatch.bracket_position);
    const currentRound: number = Number(completedMatch.round);
    if (!currentPos) return;

    const nextRound = currentRound + 1;
    const nextPos = Math.ceil(currentPos / 2);
    // Odd bracket_position → fills team1 slot, even → fills team2 slot
    const slot = currentPos % 2 === 1 ? 1 : 2;

    const nextMatch = matches.value.find(
        (m) =>
            m.match_type === "knockout" &&
            Number(m.round) === nextRound &&
            Number(m.bracket_position) === nextPos,
    );

    if (!nextMatch) return; // Final — no further match to advance to

    // Idempotent: skip if the correct team is already placed
    if (slot === 1 && nextMatch.team1_id === winnerId) return;
    if (slot === 2 && nextMatch.team2_id === winnerId) return;

    const updatePayload: Record<string, string | null> =
        slot === 1
            ? { team1_id: winnerId, team1_placeholder: null }
            : { team2_id: winnerId, team2_placeholder: null };

    const { error } = await supabase
        .from("matches")
        .update(updatePayload)
        .eq("id", nextMatch.id);

    if (error) console.error("Errore avanzamento vincitore:", error);

    // After advancing the winner, also check if loser slots in round-1
    // repechage matches need to be filled
    if (Number(completedMatch.round) === 1) {
        await fillRepechageSlots();
    }
};

// ── Repechage (best loser second-chance) ────────────────────────
// When round-1 knockout matches have empty team slots (both null), fill
// them with the best-performing losers from completed round-1 matches.
const fillRepechageSlots = async () => {
    const round1 = matches.value.filter(
        (m) => m.match_type === "knockout" && Number(m.round) === 1,
    );

    // Repechage match: both teams are still null (no real teams, no placeholders)
    const repechageMatches = round1.filter(
        (m) => !m.team1_id && !m.team2_id,
    );
    if (repechageMatches.length === 0) return;

    // Only fill once ALL other round-1 matches (the real ones) are finished —
    // we need the complete picture to pick the true best losers.
    const regularMatches = round1.filter(
        (m) => !repechageMatches.some((r) => r.id === m.id),
    );
    const allRegularDone = regularMatches.every((m) =>
        ["completed", "retired"].includes(m.status),
    );
    if (!allRegularDone) return;

    // Find completed round-1 matches and extract loser stats
    const completedRound1 = round1.filter(
        (m) => m.status === "completed" && m.winner_id,
    );
    if (completedRound1.length === 0) return;

    const loserStats = completedRound1
        .map((m) => {
            const isTeam1Winner = m.winner_id === m.team1_id;
            const loserId = isTeam1Winner ? m.team2_id : m.team1_id;
            if (!loserId) return null; // loser was a placeholder / null
            const loserScore = isTeam1Winner
                ? (m.team2_score ?? 0)
                : (m.team1_score ?? 0);
            const winnerScore = isTeam1Winner
                ? (m.team1_score ?? 0)
                : (m.team2_score ?? 0);
            return {
                teamId: loserId,
                loserScore,
                scoreDiff: loserScore - winnerScore, // negative = how badly they lost
                bracketPos: Number(m.bracket_position),
            };
        })
        .filter(Boolean) as {
        teamId: string;
        loserScore: number;
        scoreDiff: number;
        bracketPos: number;
    }[];

    // Sort: smallest loss margin = best loser (e.g. 6-5 loss beats 6-1 loss)
    // Tie-break: more goals scored; final tie-break: earlier bracket position
    loserStats.sort(
        (a, b) =>
            b.scoreDiff - a.scoreDiff || // scoreDiff is negative; closest to 0 = smallest margin
            b.loserScore - a.loserScore || // more goals scored = better tie-breaker
            a.bracketPos - b.bracketPos,
    );

    // Only exclude teams already assigned inside the repechage match itself.
    // Losers from completed round-1 matches are the ones we WANT to place here —
    // filtering by all round-1 participants would exclude every loser (the bug).
    const repechageTeamIds = new Set<string>(
        repechageMatches
            .flatMap((m) => [m.team1_id, m.team2_id])
            .filter(Boolean),
    );

    // Best losers not already placed in a repechage slot
    const unplaced = loserStats.filter((l) => !repechageTeamIds.has(l.teamId));
    if (unplaced.length === 0) return;

    let idx = 0;
    for (const rep of repechageMatches) {
        const updates: Record<string, string | null> = {};

        if (!rep.team1_id && unplaced[idx]) {
            updates.team1_id = unplaced[idx].teamId;
            updates.team1_placeholder = null;
            idx++;
        }
        if (!rep.team2_id && unplaced[idx]) {
            updates.team2_id = unplaced[idx].teamId;
            updates.team2_placeholder = null;
            idx++;
        }

        if (Object.keys(updates).length > 0) {
            const { error } = await supabase
                .from("matches")
                .update(updates)
                .eq("id", rep.id);
            if (error) console.error("Errore ripescaggio:", error);
        }
    }
};

// ── Backfill already-completed matches ──────────────────────────────
// Runs on every loadData so that matches completed before this code was
// deployed (or on other devices) still trigger auto-progression.
const backfillKnockoutAdvancement = async () => {
    const completed = matches.value
        .filter((m) => m.match_type === "knockout" && m.status === "completed")
        .sort(
            (a, b) =>
                (a.round || 0) - (b.round || 0) ||
                (a.bracket_position || 0) - (b.bracket_position || 0),
        );
    for (const match of completed) {
        await advanceWinner(match);
    }
    // Also fill any repechage slots
    await fillRepechageSlots();
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
    // Snapshot before clearing so advanceWinner has all the data it needs
    const matchSnapshot = { ...editingMatch.value, winner_id: winnerId };
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
    // Automatically slot the winner into the correct next-round match
    await advanceWinner(matchSnapshot);
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
                <!-- ── Smart Suggestions Banner ────────────────────────────── -->
                <div
                    v-if="hasKnockoutMatches && nextRecommendedMatch"
                    class="mb-4 animate-in fade-in slide-in-from-top-4 duration-500"
                >
                    <div
                        class="border-4 border-black bg-yellow-300 p-3 sm:p-4 flex items-center gap-3 sm:gap-4 shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                    >
                        <Icon
                            name="mdi:lightbulb-on"
                            class="text-2xl sm:text-3xl text-black flex-shrink-0 animate-pulse"
                        />
                        <div class="flex-1 min-w-0">
                            <p
                                class="font-impact uppercase tracking-widest text-xs text-black"
                            >
                                Prossimo incontro consigliato
                            </p>
                            <p
                                class="font-black text-black text-sm sm:text-base leading-tight truncate"
                            >
                                {{
                                    getTeamName(
                                        nextRecommendedMatch.team1_id,
                                    )
                                }}
                                <span class="font-impact text-xs mx-1 text-gray-700">vs</span>
                                {{
                                    getTeamName(
                                        nextRecommendedMatch.team2_id,
                                    )
                                }}
                                <span
                                    class="font-impact text-xs text-gray-600 ml-1"
                                    >—
                                    {{
                                        roundLabel(
                                            nextRecommendedMatch.round,
                                        )
                                    }}</span
                                >
                            </p>
                            <p
                                v-if="pendingReadyMatches.length > 1"
                                class="text-[10px] font-bold text-gray-700 mt-0.5"
                            >
                                +{{ pendingReadyMatches.length - 1 }}
                                {{
                                    pendingReadyMatches.length - 1 === 1
                                        ? "altro pronto"
                                        : "altri pronti"
                                }}
                            </p>
                        </div>
                        <NuxtLink
                            :to="`/admin/match/${nextRecommendedMatch.id}`"
                            class="flex-shrink-0 flex items-center gap-1.5 px-3 sm:px-4 py-2 sm:py-2.5 bg-black text-yellow-300 border-2 border-black font-impact uppercase tracking-widest text-xs hover:bg-white hover:text-black transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] -skew-x-3"
                        >
                            <Icon
                                name="mdi:whistle"
                                class="text-sm sm:text-base skew-x-3"
                            />
                            <span class="skew-x-3 hidden sm:inline"
                                >Inizia arbitrio</span
                            >
                            <span class="skew-x-3 sm:hidden">Inizia</span>
                        </NuxtLink>
                    </div>
                </div>

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
                            <div class="flex items-center justify-center gap-2 sm:gap-4 pt-3 flex-wrap">
                                <div class="flex flex-col items-center bg-white/10 border border-white/20 px-3 sm:px-5 py-2">
                                    <span class="font-impact text-xl sm:text-2xl text-white">{{ knockoutPreview.teamCount }}</span>
                                    <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">Squadre</span>
                                </div>
                                <Icon name="mdi:chevron-right" class="text-white text-lg opacity-60" />
                                <div class="flex flex-col items-center bg-white/10 border border-white/20 px-3 sm:px-5 py-2">
                                    <span class="font-impact text-xl sm:text-2xl text-white">{{ knockoutPreview.rounds }}</span>
                                    <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">Turni</span>
                                </div>
                                <Icon name="mdi:chevron-right" class="text-white text-lg opacity-60" />
                                <div class="flex flex-col items-center bg-white/10 border border-white/20 px-3 sm:px-5 py-2">
                                    <span class="font-impact text-xl sm:text-2xl text-white">{{ knockoutPreview.matchesInFirstRound }}</span>
                                    <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">1° Turno</span>
                                </div>
                            </div>
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
                                :class="[
                                    match.status === 'in_progress'
                                        ? 'bg-red-50 !border-primary shadow-[0_0_15px_rgba(211,47,47,0.5)] ring-1 ring-primary'
                                        : 'bg-white',
                                    nextRecommendedMatch?.id === match.id
                                        ? '!border-yellow-400 shadow-[0_0_14px_rgba(250,204,21,0.45)] ring-1 ring-yellow-400'
                                        : '',
                                ]"
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
                                                <span
                                                    v-if="match.winner_id && match.winner_id === match.team1_id"
                                                    class="text-[9px] font-impact uppercase tracking-widest text-emerald-700 bg-emerald-100 border border-emerald-300 px-1.5 py-0.5 mt-0.5"
                                                >
                                                    ✓ Avanza
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
                                                <span
                                                    v-if="match.winner_id && match.winner_id === match.team2_id"
                                                    class="text-[9px] font-impact uppercase tracking-widest text-emerald-700 bg-emerald-100 border border-emerald-300 px-1.5 py-0.5 mt-0.5"
                                                >
                                                    ✓ Avanza
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
                                <div class="flex items-center justify-center gap-2 sm:gap-3 pt-2 flex-wrap">
                                    <div class="flex flex-col items-center bg-white/10 border border-white/20 px-2 sm:px-4 py-1.5">
                                        <span class="font-impact text-lg sm:text-xl text-white">{{ knockoutPreview.teamCount }}</span>
                                        <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">Squadre</span>
                                    </div>
                                    <Icon name="mdi:chevron-right" class="text-white text-base opacity-60" />
                                    <div class="flex flex-col items-center bg-white/10 border border-white/20 px-2 sm:px-4 py-1.5">
                                        <span class="font-impact text-lg sm:text-xl text-white">{{ knockoutPreview.rounds }}</span>
                                        <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">Turni</span>
                                    </div>
                                    <Icon name="mdi:chevron-right" class="text-white text-base opacity-60" />
                                    <div class="flex flex-col items-center bg-white/10 border border-white/20 px-2 sm:px-4 py-1.5">
                                        <span class="font-impact text-lg sm:text-xl text-white">{{ knockoutPreview.matchesInFirstRound }}</span>
                                        <span class="text-[9px] font-impact uppercase tracking-widest text-gray-300">1° Turno</span>
                                    </div>
                                </div>
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
