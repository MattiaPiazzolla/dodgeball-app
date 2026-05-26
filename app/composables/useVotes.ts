import { ref, computed } from 'vue';

const votes = ref<Record<string, number>>({});
const loaded = ref(false);
const showFirstVotePopup = ref(false);

export const useVotes = () => {
    const loadVotes = () => {
        if (loaded.value) return;
        if (typeof localStorage === 'undefined') return;
        
        const stored = localStorage.getItem('user_global_mvp_votes');
        if (stored) {
            try {
                votes.value = JSON.parse(stored);
            } catch (e) {
                votes.value = {};
            }
        } else {
            // Migrate old votes
            const migrated: Record<string, number> = {};
            let count = 0;
            for (let i = 0; i < localStorage.length; i++) {
                const key = localStorage.key(i);
                if (key && key.startsWith('voted_mvp_player_')) {
                    const playerId = key.replace('voted_mvp_player_', '');
                    if (count < 5) {
                        migrated[playerId] = 1;
                        count++;
                    }
                }
            }
            votes.value = migrated;
            localStorage.setItem('user_global_mvp_votes', JSON.stringify(votes.value));
        }
        loaded.value = true;
    };

    const totalVotes = computed(() => {
        return Object.values(votes.value).reduce((a, b) => a + b, 0);
    });

    const remainingVotes = computed(() => Math.max(0, 5 - totalVotes.value));
    const canVote = computed(() => totalVotes.value < 5);

    const getPlayerVotes = (playerId: string) => votes.value[playerId] || 0;

    const removeVote = (playerId: string) => {
        if (!votes.value[playerId]) return false;
        votes.value[playerId] -= 1;
        if (votes.value[playerId] === 0) {
            delete votes.value[playerId];
        }
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('user_global_mvp_votes', JSON.stringify(votes.value));
        }
        return true;
    };

    const recordVote = (playerId: string) => {
        if (!canVote.value) return false;
        
        if (typeof localStorage !== 'undefined') {
            if (!localStorage.getItem('user_seen_first_vote_popup')) {
                showFirstVotePopup.value = true;
                localStorage.setItem('user_seen_first_vote_popup', 'true');
            }
        }

        votes.value[playerId] = (votes.value[playerId] || 0) + 1;
        if (typeof localStorage !== 'undefined') {
            localStorage.setItem('user_global_mvp_votes', JSON.stringify(votes.value));
        }
        return true;
    };

    return {
        votes,
        totalVotes,
        remainingVotes,
        canVote,
        getPlayerVotes,
        recordVote,
        removeVote,
        loadVotes,
        showFirstVotePopup
    };
};
