// composables/useMatchRealtime.ts
export const useMatchRealtime = () => {
  const supabase = useSupabaseClient();

  // Subscribe to updates for a single match (for the live match view)
  const subscribeToMatch = (
    matchId: string,
    callback: (payload: any) => void,
  ) => {
    const channel = supabase
      .channel(`match_${matchId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "matches",
          filter: `id=eq.${matchId}`,
        },
        callback,
      )
      .subscribe();

    return channel;
  };

  // Subscribe to updates for all matches (for the public schedule view)
  const subscribeToAllMatches = (callback: (payload: any) => void) => {
    const channel = supabase
      .channel("all_matches")
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "matches" },
        callback,
      )
      .subscribe();

    return channel;
  };

  // Clean up the subscription when leaving the page
  const unsubscribe = (channel: any) => {
    if (channel) {
      supabase.removeChannel(channel);
    }
  };

  return {
    subscribeToMatch,
    subscribeToAllMatches,
    unsubscribe,
  };
};
