import { ref, computed, watch, unref } from 'vue';
import type { MaybeRef } from 'vue';

const matchVotesStore = ref<Record<string, Record<string, number>>>({});
const loaded = ref(false);
const showFirstMatchVotePopup = ref(false);

export const useMatchVotes = (matchIdRef: MaybeRef<string | number | null | undefined>) => {
    const loadVotes = () => {
        if (loaded.value) return;
        if (typeof localStorage === 'undefined') return;
        
        const stored = localStorage.getItem('user_match_mvp_votes');
        if (stored) {
            try {
                matchVotesStore.value = JSON.parse(stored);
            } catch (e) {
                matchVotesStore.value = {};
            }
        }
        loaded.value = true;
    };

    const currentMatchId = computed(() => {
        const val = unref(matchIdRef);
        return val ? String(val) : null;
    });

    const currentMatchVotes = computed(() => {
        const id = currentMatchId.value;
        if (!id) return {};
        return matchVotesStore.value[id] || {};
    });

    const totalVotes = computed(() => {
        return Object.values(currentMatchVotes.value).reduce((a, b) => a + b, 0);
    });

    const remainingVotes = computed(() => Math.max(0, 3 - totalVotes.value));
    const canVote = computed(() => totalVotes.value < 3);

    const getPlayerVotes = (playerId: string) => currentMatchVotes.value[playerId] || 0;

    const saveToLocalStorage = () => {
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('user_match_mvp_votes', JSON.stringify(matchVotesStore.value));
        }
    };

    const removeVote = (playerId: string) => {
        const id = currentMatchId.value;
        if (!id) return false;
        
        if (!matchVotesStore.value[id]) matchVotesStore.value[id] = {};
        if (!matchVotesStore.value[id][playerId]) return false;
        
        matchVotesStore.value[id][playerId] -= 1;
        if (matchVotesStore.value[id][playerId] === 0) {
            delete matchVotesStore.value[id][playerId];
        }
        saveToLocalStorage();
        return true;
    };

    const recordVote = (playerId: string) => {
        const id = currentMatchId.value;
        if (!id) return false;
        if (!canVote.value) return false;
        
        if (typeof localStorage !== 'undefined') {
            if (!localStorage.getItem('user_seen_first_match_vote_popup')) {
                showFirstMatchVotePopup.value = true;
                localStorage.setItem('user_seen_first_match_vote_popup', 'true');
            }
        }

        if (!matchVotesStore.value[id]) matchVotesStore.value[id] = {};
        matchVotesStore.value[id][playerId] = (matchVotesStore.value[id][playerId] || 0) + 1;
        
        saveToLocalStorage();
        return true;
    };

    return {
        votes: currentMatchVotes,
        totalVotes,
        remainingVotes,
        canVote,
        getPlayerVotes,
        recordVote,
        removeVote,
        loadVotes,
        showFirstMatchVotePopup
    };
};
