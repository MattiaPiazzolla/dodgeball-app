// components/public/PublicLive.vue
<template>
    <div class="space-y-4">
        <div
            v-if="pending"
            class="flex justify-center items-center py-32 text-red-500 animate-pulse"
        >
            <Icon name="mdi:loading" class="animate-spin text-5xl" />
        </div>

        <template v-else>
            <div
                class="grid grid-cols-1 lg:grid-cols-12 gap-4 sm:gap-6 items-start"
            >
                <div
                    class="order-2 lg:order-1 lg:col-span-3 bg-white rounded-3xl lg:rounded-[2rem] p-4 sm:p-6 shadow-sm border border-gray-100 flex flex-col gap-5 sm:gap-6 mobile-fade-in"
                >
                    <h2
                        class="text-lg font-black uppercase tracking-tight text-gray-800 flex items-center gap-2"
                    >
                        <Icon
                            name="mdi:format-list-numbered"
                            class="text-red-500 text-xl"
                        />
                        Classifiche
                    </h2>

                    <div class="space-y-6">
                        <div
                            v-for="group in groups"
                            :key="group.id"
                            class="space-y-3"
                        >
                            <h3
                                class="text-xs font-bold text-gray-400 uppercase tracking-widest"
                            >
                                {{ group.name }}
                            </h3>
                            <div
                                class="bg-gray-50/80 rounded-2xl border border-gray-100 overflow-hidden"
                            >
                                <table class="w-full text-left text-xs">
                                    <thead
                                        class="bg-gray-100/50 text-gray-400 uppercase tracking-wider"
                                    >
                                        <tr>
                                            <th class="py-2.5 px-3 font-bold">
                                                Squadra
                                            </th>
                                            <th
                                                class="py-2.5 px-2 text-center font-bold"
                                            >
                                                V-P
                                            </th>
                                            <th
                                                class="py-2.5 px-3 text-right font-black text-black"
                                            >
                                                Pt
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-100">
                                        <tr
                                            v-for="gt in group.group_teams"
                                            :key="gt.id"
                                            class="transition-colors hover:bg-white"
                                        >
                                            <td class="py-2.5 px-3" :title="gt.teams?.name">
                                                <div class="flex items-center gap-2 min-w-0">
                                                    <PublicTeamLogo
                                                        :src="gt.teams?.logo_url"
                                                        :alt="gt.teams?.name"
                                                        size-class="w-7 h-7"
                                                        icon-class="text-sm"
                                                    />
                                                    <span class="font-black uppercase truncate max-w-[92px] text-gray-800">
                                                        {{ gt.teams?.name || "DA DEFINIRE" }}
                                                    </span>
                                                </div>
                                            </td>
                                            <td
                                                class="py-2.5 px-2 text-center font-bold text-gray-500"
                                            >
                                                {{ gt.wins }}-{{ gt.losses }}
                                            </td>
                                            <td
                                                class="py-2.5 px-3 text-right font-black text-red-600"
                                            >
                                                {{ gt.points }}
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        <div
                            v-if="!groups.length"
                            class="text-xs text-gray-400 font-bold uppercase text-center py-8 bg-gray-50 rounded-2xl border border-dashed border-gray-200"
                        >
                            Nessun gruppo formato.
                        </div>
                    </div>
                </div>

                <div class="order-1 lg:order-2 lg:col-span-6 flex flex-col gap-4 sm:gap-6">
                    <div
                        class="bg-white rounded-[1.75rem] sm:rounded-[2.5rem] px-4 py-8 sm:p-12 shadow-sm border-2 sm:border-4 relative overflow-hidden transition-all duration-500 flex flex-col justify-center min-h-[360px] sm:min-h-[420px] mobile-fade-in"
                        :class="
                            liveMatch
                                ? liveMatch.is_timer_running
                                    ? 'border-red-500 shadow-[0_10px_40px_rgba(220,38,38,0.15)]'
                                    : 'border-yellow-400'
                                : 'border-gray-100'
                        "
                    >
                        <template v-if="liveMatch">
                            <div
                                class="absolute top-0 left-0 right-0 text-xs font-black uppercase tracking-widest text-center py-2 transition-colors"
                                :class="
                                    liveMatch.is_timer_running
                                        ? 'bg-red-600 text-white animate-pulse'
                                        : 'bg-yellow-400 text-black'
                                "
                            >
                                {{
                                    liveMatch.is_timer_running
                                        ? "Partita in Diretta"
                                        : "Partita in Pausa"
                                }}
                            </div>

                            <div class="text-center mt-4 mb-10">
                                <span
                                    class="font-mono text-5xl min-[380px]:text-6xl sm:text-7xl font-black tracking-tight drop-shadow-sm transition-colors"
                                    :class="
                                        liveMatch.is_timer_running
                                            ? 'text-red-600'
                                            : 'text-yellow-500'
                                    "
                                >
                                    {{ formattedTimer }}
                                </span>
                                <div
                                    class="text-gray-400 font-bold uppercase tracking-widest mt-2 text-xs"
                                >
                                    {{ translateStage(liveMatch.match_type) }}
                                </div>
                            </div>

                            <div
                                class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-2 min-[380px]:gap-4 sm:gap-8"
                            >
                                <div class="flex-1 text-center">
                                    <PublicTeamLogo
                                        :src="getTeamLogo(liveMatch.team1_id)"
                                        :alt="getTeamName(liveMatch.team1_id)"
                                        size-class="w-14 h-14 min-[380px]:w-16 min-[380px]:h-16 sm:w-24 sm:h-24 mx-auto mb-3 sm:mb-4"
                                        icon-class="text-3xl sm:text-5xl"
                                    />
                                    <div
                                        class="text-sm min-[380px]:text-base sm:text-2xl font-black uppercase truncate text-black mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team1_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-5xl min-[380px]:text-6xl sm:text-8xl font-black text-gray-900 leading-none"
                                    >
                                        {{ liveMatch.team1_score || 0 }}
                                    </div>
                                </div>
                                <div
                                    class="px-3 py-2 sm:px-4 sm:py-3 bg-gray-100 rounded-2xl shadow-inner"
                                >
                                    <span
                                        class="text-gray-400 text-sm sm:text-xl font-black uppercase tracking-widest"
                                        >VS</span
                                    >
                                </div>
                                <div class="flex-1 text-center">
                                    <PublicTeamLogo
                                        :src="getTeamLogo(liveMatch.team2_id)"
                                        :alt="getTeamName(liveMatch.team2_id)"
                                        size-class="w-14 h-14 min-[380px]:w-16 min-[380px]:h-16 sm:w-24 sm:h-24 mx-auto mb-3 sm:mb-4"
                                        icon-class="text-3xl sm:text-5xl"
                                    />
                                    <div
                                        class="text-sm min-[380px]:text-base sm:text-2xl font-black uppercase truncate text-black mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team2_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-5xl min-[380px]:text-6xl sm:text-8xl font-black text-gray-900 leading-none"
                                    >
                                        {{ liveMatch.team2_score || 0 }}
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="upcomingMatches.length">
                            <div class="text-center mb-8">
                                <div
                                    class="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4"
                                >
                                    <Icon
                                        name="mdi:calendar-clock"
                                        class="text-2xl text-gray-400"
                                    />
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black"
                                >
                                    Prossimo Incontro
                                </h2>
                                <p
                                    class="text-red-500 font-bold uppercase tracking-widest text-sm mt-1"
                                >
                                    {{ upcomingMatches[0].start_time || "DA DEFINIRE" }}
                                </p>
                            </div>

                            <div
                                class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3 sm:gap-4"
                            >
                                <div class="flex-1 text-center">
                                    <PublicTeamLogo
                                        :src="getTeamLogo(upcomingMatches[0].team1_id)"
                                        :alt="getTeamName(upcomingMatches[0].team1_id)"
                                        size-class="w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-3"
                                        icon-class="text-3xl sm:text-4xl"
                                    />
                                    <div
                                        class="text-base sm:text-xl font-black uppercase truncate text-black"
                                    >
                                        {{
                                            getTeamName(
                                                upcomingMatches[0].team1_id,
                                            ) || "DA DEFINIRE"
                                        }}
                                    </div>
                                </div>
                                <span
                                    class="text-gray-300 text-lg font-black uppercase tracking-widest"
                                    >VS</span
                                >
                                <div class="flex-1 text-center">
                                    <PublicTeamLogo
                                        :src="getTeamLogo(upcomingMatches[0].team2_id)"
                                        :alt="getTeamName(upcomingMatches[0].team2_id)"
                                        size-class="w-16 h-16 sm:w-20 sm:h-20 mx-auto mb-3"
                                        icon-class="text-3xl sm:text-4xl"
                                    />
                                    <div
                                        class="text-base sm:text-xl font-black uppercase truncate text-black"
                                    >
                                        {{
                                            getTeamName(
                                                upcomingMatches[0].team2_id,
                                            ) || "DA DEFINIRE"
                                        }}
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="showTournamentComplete">
                            <div class="text-center flex flex-col items-center">
                                <div
                                    class="w-24 h-24 bg-yellow-50 border border-yellow-100 rounded-full flex items-center justify-center mx-auto mb-6 shadow-sm"
                                >
                                    <Icon
                                        name="mdi:trophy"
                                        class="text-4xl text-yellow-500"
                                    />
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black mb-2"
                                >
                                    Torneo Terminato
                                </h2>
                                <p
                                    class="text-gray-400 font-bold uppercase tracking-widest text-sm max-w-sm mx-auto"
                                >
                                    Tutti gli incontri sono terminati. Grazie per
                                    aver partecipato!
                                </p>
                            </div>
                        </template>

                        <template v-else-if="showKnockoutDrawHolding">
                            <div
                                class="text-center flex flex-col items-center animate-fade-in"
                            >
                                <div class="relative w-24 h-24 mb-6 mx-auto">
                                    <div
                                        class="absolute inset-0 bg-red-100 rounded-full animate-ping opacity-75"
                                    ></div>
                                    <div
                                        class="relative bg-white border border-red-100 w-24 h-24 rounded-full flex items-center justify-center shadow-md"
                                    >
                                        <Icon
                                            name="mdi:tournament"
                                            class="text-4xl text-red-500"
                                        />
                                    </div>
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight text-black mb-3"
                                >
                                    Fase a Gironi Terminata
                                </h2>
                                <p
                                    class="text-gray-400 font-bold uppercase tracking-widest text-xs max-w-[250px] mx-auto leading-relaxed"
                                >
                                    I gironi sono conclusi. In attesa del
                                    sorteggio del tabellone a eliminazione diretta...
                                </p>
                            </div>
                        </template>

                        <template v-else>
                            <div class="text-center text-gray-400">
                                <Icon
                                    name="mdi:whistle"
                                    class="text-6xl text-gray-200 mb-4"
                                />
                                <p
                                    class="font-black text-xl uppercase tracking-widest"
                                >
                                    Nessuna Partita in Diretta
                                </p>
                            </div>
                        </template>
                    </div>

                    <div
                        v-if="liveMatch"
                        class="bg-white rounded-3xl p-4 sm:p-6 shadow-sm border border-gray-100 mobile-fade-in space-y-5"
                    >
                        <div
                            class="flex flex-col sm:flex-row sm:items-center justify-between gap-2"
                        >
                            <div>
                                <h2
                                    class="text-lg font-black uppercase tracking-tight text-black"
                                >
                                    MVP della partita
                                </h2>
                                <p
                                    class="text-xs font-bold uppercase tracking-widest text-gray-400 mt-1"
                                >
                                    Vota il migliore tra i giocatori in campo
                                </p>
                            </div>
                            <div
                                v-if="rankedLivePlayers.length"
                                class="flex items-center gap-2 overflow-x-auto custom-scrollbar pb-1 sm:pb-0"
                            >
                                <div
                                    v-for="(player, index) in rankedLivePlayers.slice(0, 3)"
                                    :key="player.id"
                                    class="shrink-0 flex items-center gap-2 bg-gray-50 border border-gray-100 rounded-2xl px-3 py-2"
                                >
                                    <span
                                        class="text-xs font-black"
                                        :class="
                                            index === 0
                                                ? 'text-yellow-500'
                                                : index === 1
                                                  ? 'text-gray-400'
                                                  : 'text-amber-600'
                                        "
                                        >#{{ index + 1 }}</span
                                    >
                                    <span
                                        class="max-w-24 truncate text-xs font-black uppercase text-black"
                                        >{{ player.name }}</span
                                    >
                                    <span
                                        class="text-xs font-black text-red-600"
                                        >{{ player.mvp_votes || 0 }}</span
                                    >
                                </div>
                            </div>
                        </div>

                        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div
                                v-for="teamRoster in liveTeamRosters"
                                :key="teamRoster.teamId || teamRoster.name"
                                class="bg-gray-50/80 border border-gray-100 rounded-3xl p-3 sm:p-4"
                            >
                                <div class="flex items-center gap-3 mb-3">
                                    <PublicTeamLogo
                                        :src="getTeamLogo(teamRoster.teamId)"
                                        :alt="teamRoster.name"
                                        size-class="w-10 h-10"
                                        icon-class="text-xl"
                                    />
                                    <div class="min-w-0">
                                        <h3
                                            class="font-black uppercase text-black truncate"
                                        >
                                            {{ teamRoster.name }}
                                        </h3>
                                        <p
                                            class="text-[10px] font-bold uppercase tracking-widest text-gray-400"
                                        >
                                            {{ teamRoster.players.length }} giocatori
                                        </p>
                                    </div>
                                </div>

                                <div
                                    v-if="teamRoster.players.length"
                                    class="space-y-2"
                                >
                                    <div
                                        v-for="player in teamRoster.players"
                                        :key="player.id"
                                        class="interactive-card flex items-center justify-between gap-3 bg-white rounded-2xl border border-gray-100 p-3 hover:border-gray-200"
                                    >
                                        <div
                                            class="flex items-center gap-3 min-w-0"
                                        >
                                            <div
                                                class="w-11 h-11 rounded-full bg-gray-100 border border-gray-100 flex items-center justify-center overflow-hidden shrink-0 text-gray-300"
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
                                                    class="text-2xl"
                                                />
                                            </div>
                                            <div class="min-w-0">
                                                <p
                                                    class="font-black uppercase text-sm text-black truncate"
                                                >
                                                    {{ player.name }}
                                                </p>
                                                <p
                                                    class="text-[10px] font-bold uppercase tracking-widest text-gray-400"
                                                >
                                                    #{{ player.jersey_number || "00" }}
                                                </p>
                                            </div>
                                        </div>

                                        <div
                                            class="flex items-center gap-2 shrink-0"
                                        >
                                            <span
                                                class="w-9 text-center text-sm font-black text-red-600"
                                                >{{ player.mvp_votes || 0 }}</span
                                            >
                                            <button
                                                @click="voteForLivePlayer(player.id)"
                                                :disabled="
                                                    hasVotedInLiveMatch ||
                                                    hasVoted(player.id)
                                                "
                                                class="w-11 h-11 rounded-full flex items-center justify-center transition-all shadow-sm border active:scale-90"
                                                :class="
                                                    hasVotedInLiveMatch ||
                                                    hasVoted(player.id)
                                                        ? 'bg-green-50 border-green-200 text-green-500 cursor-not-allowed'
                                                        : 'bg-white border-gray-200 text-gray-300 hover:text-red-500 hover:border-red-200 hover:shadow-md'
                                                "
                                                :title="
                                                    hasVotedInLiveMatch
                                                        ? 'Hai già votato il migliore'
                                                        : hasVoted(player.id)
                                                          ? 'Voto registrato'
                                                        : 'Vota MVP'
                                                "
                                            >
                                                <Icon
                                                    :name="
                                                        hasVotedInLiveMatch ||
                                                        hasVoted(player.id)
                                                            ? 'mdi:thumb-up'
                                                            : 'mdi:thumb-up-outline'
                                                    "
                                                    class="text-lg"
                                                />
                                            </button>
                                        </div>
                                    </div>
                                </div>

                                <div
                                    v-else
                                    class="text-center py-8 text-xs font-bold uppercase tracking-widest text-gray-400 border border-dashed border-gray-200 rounded-2xl bg-white"
                                >
                                    Nessun giocatore registrato.
                                </div>
                            </div>
                        </div>
                    </div>

                    <section
                        v-if="lastMatch"
                        class="relative overflow-hidden bg-white rounded-[2rem] border border-gray-100 shadow-sm p-5 sm:p-7 mobile-fade-in"
                    >
                        <div
                            class="absolute -right-12 -top-12 w-40 h-40 rounded-full bg-red-50 result-pulse"
                        ></div>
                        <div
                            class="relative flex flex-col gap-5"
                        >
                            <div
                                class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                            >
                                <div>
                                    <p
                                        class="text-[10px] font-black uppercase tracking-[0.24em] text-red-500"
                                    >
                                        Ultimo incontro
                                    </p>
                                    <h2
                                        class="text-2xl sm:text-3xl font-black uppercase tracking-tight text-black mt-1"
                                    >
                                        {{
                                            getTeamName(lastMatch.winner_id) ||
                                            "Risultato finale"
                                        }}
                                        <span class="text-red-600">vince</span>
                                    </h2>
                                </div>
                                <div
                                    class="self-start sm:self-auto px-4 py-2 rounded-full bg-black text-white text-[10px] font-black uppercase tracking-widest shadow-md"
                                >
                                    {{ translateStage(lastMatch.match_type) }}
                                </div>
                            </div>

                            <div
                                class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-stretch gap-2 min-[420px]:gap-4"
                            >
                                <div
                                    class="result-team-card"
                                    :class="
                                        lastMatch.winner_id === lastMatch.team1_id
                                            ? 'result-winner'
                                            : 'result-loser'
                                    "
                                >
                                    <div class="flex justify-center mb-3">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(lastMatch.team1_id)"
                                            :alt="getTeamName(lastMatch.team1_id)"
                                            size-class="w-16 h-16 sm:w-20 sm:h-20"
                                            icon-class="text-4xl"
                                        />
                                    </div>
                                    <p
                                        class="font-black uppercase text-center text-sm sm:text-base truncate"
                                    >
                                        {{
                                            getTeamName(lastMatch.team1_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </p>
                                    <div
                                        class="text-center text-5xl sm:text-6xl font-black leading-none mt-2"
                                    >
                                        {{ lastMatch.team1_score || 0 }}
                                    </div>
                                </div>

                                <div
                                    class="flex flex-col items-center justify-center gap-2 px-1"
                                >
                                    <div
                                        class="w-12 h-12 rounded-full bg-gray-100 border border-gray-200 flex items-center justify-center shadow-inner result-vs"
                                    >
                                        <span
                                            class="text-gray-400 font-black text-xs uppercase"
                                            >VS</span
                                        >
                                    </div>
                                    <div
                                        class="h-16 w-1 rounded-full bg-gradient-to-b from-red-500 via-gray-200 to-black"
                                    ></div>
                                </div>

                                <div
                                    class="result-team-card"
                                    :class="
                                        lastMatch.winner_id === lastMatch.team2_id
                                            ? 'result-winner'
                                            : 'result-loser'
                                    "
                                >
                                    <div class="flex justify-center mb-3">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(lastMatch.team2_id)"
                                            :alt="getTeamName(lastMatch.team2_id)"
                                            size-class="w-16 h-16 sm:w-20 sm:h-20"
                                            icon-class="text-4xl"
                                        />
                                    </div>
                                    <p
                                        class="font-black uppercase text-center text-sm sm:text-base truncate"
                                    >
                                        {{
                                            getTeamName(lastMatch.team2_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </p>
                                    <div
                                        class="text-center text-5xl sm:text-6xl font-black leading-none mt-2"
                                    >
                                        {{ lastMatch.team2_score || 0 }}
                                    </div>
                                </div>
                            </div>

                            <div
                                class="grid grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-3"
                            >
                                <div class="h-3 rounded-full bg-gray-100 overflow-hidden">
                                    <div
                                        class="h-full rounded-full bg-black result-bar"
                                        :style="{
                                            width: `${getScoreShare(lastMatch.team1_score, lastMatch.team2_score, 1)}%`,
                                        }"
                                    ></div>
                                </div>
                                <div
                                    class="text-[10px] font-black uppercase tracking-widest text-gray-400"
                                >
                                    Finale
                                </div>
                                <div class="h-3 rounded-full bg-gray-100 overflow-hidden">
                                    <div
                                        class="h-full rounded-full bg-red-600 result-bar"
                                        :style="{
                                            width: `${getScoreShare(lastMatch.team1_score, lastMatch.team2_score, 2)}%`,
                                        }"
                                    ></div>
                                </div>
                            </div>
                        </div>
                    </section>

                    <div
                        v-if="recentMatches.length > 1"
                        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
                    >
                        <div
                            v-for="match in recentMatches.slice(1, 4)"
                            :key="match.id"
                            class="interactive-card bg-white rounded-3xl p-5 shadow-sm border border-gray-100 hover:-translate-y-0.5 hover:shadow-md"
                        >
                            <div
                                class="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-3 flex justify-between"
                            >
                                <span>{{ translateStage(match.match_type) }}</span>
                                <span class="text-red-500">FINALE</span>
                            </div>
                            <div class="space-y-2">
                                <div class="flex justify-between items-center">
                                    <div class="flex items-center gap-2 min-w-0 pr-2">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team1_id)"
                                            :alt="getTeamName(match.team1_id)"
                                            size-class="w-7 h-7"
                                            icon-class="text-sm"
                                        />
                                        <span
                                            class="font-black uppercase text-sm truncate"
                                            :class="
                                                match.winner_id === match.team1_id
                                                    ? 'text-black'
                                                    : 'text-gray-400'
                                            "
                                            >{{
                                                getTeamName(match.team1_id) || "DA DEFINIRE"
                                            }}</span
                                        >
                                    </div>
                                    <span
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team1_id
                                                ? 'text-green-500'
                                                : 'text-gray-300'
                                        "
                                        >{{ match.team1_score || 0 }}</span
                                    >
                                </div>
                                <div class="flex justify-between items-center">
                                    <div class="flex items-center gap-2 min-w-0 pr-2">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(match.team2_id)"
                                            :alt="getTeamName(match.team2_id)"
                                            size-class="w-7 h-7"
                                            icon-class="text-sm"
                                        />
                                        <span
                                            class="font-black uppercase text-sm truncate"
                                            :class="
                                                match.winner_id === match.team2_id
                                                    ? 'text-black'
                                                    : 'text-gray-400'
                                            "
                                            >{{
                                                getTeamName(match.team2_id) || "DA DEFINIRE"
                                            }}</span
                                        >
                                    </div>
                                    <span
                                        class="font-black text-lg"
                                        :class="
                                            match.winner_id === match.team2_id
                                                ? 'text-green-500'
                                                : 'text-gray-300'
                                        "
                                        >{{ match.team2_score || 0 }}</span
                                    >
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <div
                    class="order-3 lg:col-span-3 bg-white rounded-3xl lg:rounded-[2rem] p-4 sm:p-6 shadow-sm border border-gray-100 flex flex-col max-h-[70vh] lg:max-h-[600px] mobile-fade-in"
                >
                    <h2
                        class="text-lg font-black uppercase tracking-tight text-gray-800 mb-4 flex items-center gap-2"
                    >
                        <Icon name="mdi:star" class="text-yellow-400 text-xl" />
                        MVP
                    </h2>

                    <div class="relative mb-4">
                        <Icon
                            name="mdi:magnify"
                            class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-lg"
                        />
                        <input
                            v-model="searchQuery"
                            type="text"
                            placeholder="Cerca giocatore"
                            class="w-full bg-gray-50 border border-gray-100 rounded-2xl py-3 pl-10 pr-4 text-xs font-bold uppercase tracking-wide focus:outline-none focus:border-red-500 focus:ring-4 focus:ring-red-50 transition-all placeholder:text-gray-300"
                        />
                    </div>

                    <div
                        class="overflow-y-auto pr-1 space-y-3 flex-1 custom-scrollbar"
                    >
                        <div
                            v-for="player in filteredPlayers"
                            :key="player.id"
                            class="interactive-card flex items-center justify-between p-3 bg-gray-50/80 rounded-2xl border border-gray-100 hover:border-gray-200 hover:bg-white transition-all group"
                        >
                            <div
                                class="flex items-center gap-3 overflow-hidden"
                            >
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-10 h-10 rounded-full object-cover shadow-sm bg-white border border-gray-100"
                                />
                                <div
                                    v-else
                                    class="w-10 h-10 rounded-full bg-gray-200 flex items-center justify-center text-gray-400 shrink-0"
                                >
                                    <Icon name="mdi:account" class="text-lg" />
                                </div>
                                <div class="min-w-0">
                                    <div
                                        class="font-black text-black uppercase text-xs truncate"
                                    >
                                        {{ player.name }}
                                    </div>
                                    <div
                                        class="text-[10px] text-gray-400 font-bold uppercase truncate"
                                    >
                                        {{ getTeamName(player.team_id) }}
                                    </div>
                                </div>
                            </div>

                            <div
                                class="flex flex-col items-center justify-center gap-0.5 shrink-0 pl-2"
                            >
                                <button
                                    @click="voteForPlayer(player.id)"
                                    :disabled="hasVoted(player.id)"
                                    class="w-10 h-10 sm:w-8 sm:h-8 rounded-full flex items-center justify-center transition-all shadow-sm border active:scale-90"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'bg-green-50 border-green-200 text-green-500 cursor-not-allowed'
                                            : 'bg-white border-gray-200 text-gray-300 hover:text-red-500 hover:border-red-200 hover:shadow-md'
                                    "
                                >
                                    <Icon
                                        :name="
                                            hasVoted(player.id)
                                                ? 'mdi:thumb-up'
                                                : 'mdi:thumb-up-outline'
                                        "
                                        class="text-sm"
                                    />
                                </button>
                                <span
                                    class="text-[9px] font-black uppercase tracking-widest"
                                    :class="
                                        hasVoted(player.id)
                                            ? 'text-green-600'
                                            : 'text-gray-400'
                                    "
                                >
                                    {{ player.mvp_votes || 0 }}
                                </span>
                            </div>
                        </div>
                        <div
                            v-if="filteredPlayers.length === 0"
                            class="text-center py-8 text-gray-400 font-bold uppercase text-xs"
                        >
                            Nessun giocatore trovato.
                        </div>
                    </div>
                </div>
            </div>
        </template>
    </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from "vue";

const translateStage = (stage: string) => {
    if (!stage) return "";
    const lower = stage.toLowerCase();
    if (lower === "group") return "Fase a Gironi";
    if (lower === "knockout") return "Fase a Eliminazione Diretta";
    return stage;
};

const supabase = useSupabaseClient();
const { subscribeToAllMatches, unsubscribe } = useMatchRealtime();

const matches = ref<any[]>([]);
const teams = ref<any[]>([]);
const groups = ref<any[]>([]);
const players = ref<any[]>([]);
const pending = ref(true);

const searchQuery = ref("");
const trackingVotes = ref<Record<string, boolean>>({});
const liveMatchVotes = ref<Record<string, string>>({});

let realtimeChannel: any = null;
let playerRealtimeChannel: any = null;
const now = ref(Date.now());
let timerInterval: any = null;

const liveMatch = computed(() =>
    matches.value.find((m) => m.status === "in_progress"),
);

const upcomingMatches = computed(() =>
    matches.value
        .filter((m) => m.status === "pending")
        .sort((a, b) =>
            (a.start_time || "z").localeCompare(b.start_time || "z"),
        ),
);

const recentMatches = computed(() =>
    matches.value
        .filter((m) => ["completed", "retired"].includes(m.status))
        .sort((a, b) =>
            (b.start_time || b.id).localeCompare(a.start_time || a.id),
        ),
);

const lastMatch = computed(() => recentMatches.value[0] || null);

// Advanced Computed States
const showTournamentComplete = computed(() => {
    if (matches.value.length === 0) return false;
    const hasKnockouts = matches.value.some((m) => m.match_type !== "group");
    return (
        matches.value.every((m) =>
            ["completed", "retired"].includes(m.status),
        ) && hasKnockouts
    );
});

const showKnockoutDrawHolding = computed(() => {
    if (matches.value.length === 0) return false;
    const groupMatches = matches.value.filter((m) => m.match_type === "group");
    const hasKnockouts = matches.value.some((m) => m.match_type !== "group");
    const allGroupDone =
        groupMatches.length > 0 &&
        groupMatches.every((m) => ["completed", "retired"].includes(m.status));
    return allGroupDone && !hasKnockouts;
});

const filteredPlayers = computed(() => {
    let sorted = [...players.value].sort(
        (a, b) => (b.mvp_votes || 0) - (a.mvp_votes || 0),
    );
    if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase();
        sorted = sorted.filter(
            (p) =>
                p.name.toLowerCase().includes(query) ||
                (p.nickname && p.nickname.toLowerCase().includes(query)),
        );
    }
    return sorted;
});

const getTeamPlayers = (teamId: string | null) =>
    players.value
        .filter((player) => player.team_id === teamId)
        .sort(
            (a, b) =>
                (b.mvp_votes || 0) - (a.mvp_votes || 0) ||
                (a.jersey_number || 999) - (b.jersey_number || 999) ||
                a.name.localeCompare(b.name),
        );

const liveTeamRosters = computed(() => {
    if (!liveMatch.value) return [];
    return [
        {
            teamId: liveMatch.value.team1_id,
            name: getTeamName(liveMatch.value.team1_id) || "DA DEFINIRE",
            players: getTeamPlayers(liveMatch.value.team1_id),
        },
        {
            teamId: liveMatch.value.team2_id,
            name: getTeamName(liveMatch.value.team2_id) || "DA DEFINIRE",
            players: getTeamPlayers(liveMatch.value.team2_id),
        },
    ];
});

const rankedLivePlayers = computed(() =>
    liveTeamRosters.value
        .flatMap((teamRoster) => teamRoster.players)
        .sort(
            (a, b) =>
                (b.mvp_votes || 0) - (a.mvp_votes || 0) ||
                a.name.localeCompare(b.name),
        ),
);

const liveMatchVotePlayerId = computed(() => {
    if (!liveMatch.value) return null;
    return (
        liveMatchVotes.value[liveMatch.value.id] ||
        localStorage.getItem(`voted_mvp_match_${liveMatch.value.id}`)
    );
});

const hasVotedInLiveMatch = computed(() => !!liveMatchVotePlayerId.value);

const getTeamName = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.name;
const getTeamLogo = (id: string | null) =>
    teams.value.find((t) => t.id === id)?.logo_url;

const getScoreShare = (
    team1Score: number | null,
    team2Score: number | null,
    side: 1 | 2,
) => {
    const score1 = team1Score || 0;
    const score2 = team2Score || 0;
    const total = Math.max(score1 + score2, 1);
    const share = side === 1 ? score1 / total : score2 / total;
    return Math.max(10, Math.round(share * 100));
};

const totalElapsed = computed(() => {
    if (!liveMatch.value) return 0;
    let elapsed = liveMatch.value.elapsed_seconds || 0;
    if (liveMatch.value.is_timer_running && liveMatch.value.timer_started_at) {
        const start = new Date(liveMatch.value.timer_started_at).getTime();
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

const loadGroupsAndStandings = async () => {
    const { data: gData } = await supabase
        .from("groups")
        .select(
            `id, name, group_teams ( id, team_id, points, wins, losses, teams ( name, logo_url ) )`,
        )
        .order("name");

    if (gData) {
        gData.forEach((g) => {
            g.group_teams.sort(
                (a: any, b: any) => b.points - a.points || b.wins - a.wins,
            );
        });
        groups.value = gData;
    }
};

const loadData = async () => {
    pending.value = true;
    const [{ data: tData }, { data: mData }, { data: pData }] =
        await Promise.all([
            supabase
                .from("teams")
                .select("*")
                .eq("status", "approved")
                .order("name"),
            supabase.from("matches").select("*"),
            supabase.from("players").select("*"),
        ]);

    if (tData) teams.value = tData;
    if (mData) matches.value = mData;
    if (mData) {
        mData.forEach((match: any) => {
            const votedPlayerId = localStorage.getItem(
                `voted_mvp_match_${match.id}`,
            );
            if (votedPlayerId) liveMatchVotes.value[match.id] = votedPlayerId;
        });
    }
    if (pData) {
        players.value = pData;
        pData.forEach((p: any) => {
            trackingVotes.value[p.id] = !!localStorage.getItem(
                `voted_mvp_player_${p.id}`,
            );
        });
    }

    await loadGroupsAndStandings();

    realtimeChannel = subscribeToAllMatches((payload) => {
        const changedMatch = payload.new || payload.old;
        if (!changedMatch?.id) return;

        const index = matches.value.findIndex((m) => m.id === changedMatch.id);
        const wasActiveNowFinished =
            payload.eventType !== "DELETE" &&
            index !== -1 &&
            matches.value[index].status === "in_progress" &&
            ["completed", "retired"].includes(changedMatch.status);

        if (payload.eventType === "DELETE") {
            matches.value = matches.value.filter(
                (match) => match.id !== changedMatch.id,
            );
        } else if (index !== -1) {
            matches.value[index] = { ...matches.value[index], ...changedMatch };
        } else {
            matches.value.push(changedMatch);
        }

        matches.value.sort((a, b) =>
            (a.start_time || a.id).localeCompare(b.start_time || b.id),
        );

        if (
            (wasActiveNowFinished || payload.eventType !== "UPDATE") &&
            changedMatch.match_type === "group"
        ) {
            loadGroupsAndStandings();
        }
    });

    playerRealtimeChannel = supabase
        .channel("public_live_players")
        .on(
            "postgres_changes",
            { event: "UPDATE", schema: "public", table: "players" },
            (payload) => {
                const updatedPlayer = payload.new;
                const index = players.value.findIndex(
                    (player) => player.id === updatedPlayer.id,
                );
                if (index !== -1) {
                    players.value[index] = {
                        ...players.value[index],
                        ...updatedPlayer,
                    };
                }
            },
        )
        .subscribe();

    timerInterval = setInterval(() => {
        now.value = Date.now();
    }, 1000);
    pending.value = false;
};

const hasVoted = (playerId: string) => !!trackingVotes.value[playerId];

const voteForPlayer = async (playerId: string) => {
    if (hasVoted(playerId)) return;
    const player = players.value.find((p) => p.id === playerId);
    if (player) player.mvp_votes = (player.mvp_votes || 0) + 1;

    trackingVotes.value[playerId] = true;
    localStorage.setItem(`voted_mvp_player_${playerId}`, "true");
    await supabase.rpc("increment_player_votes", { player_uuid: playerId });
};

const voteForLivePlayer = async (playerId: string) => {
    if (!liveMatch.value || hasVotedInLiveMatch.value || hasVoted(playerId)) {
        return;
    }

    const player = players.value.find((p) => p.id === playerId);
    if (player) player.mvp_votes = (player.mvp_votes || 0) + 1;

    trackingVotes.value[playerId] = true;
    liveMatchVotes.value[liveMatch.value.id] = playerId;
    localStorage.setItem(`voted_mvp_player_${playerId}`, "true");
    localStorage.setItem(`voted_mvp_match_${liveMatch.value.id}`, playerId);
    await supabase.rpc("increment_player_votes", { player_uuid: playerId });
};

onMounted(loadData);
onUnmounted(() => {
    unsubscribe(realtimeChannel);
    if (playerRealtimeChannel) supabase.removeChannel(playerRealtimeChannel);
    if (timerInterval) clearInterval(timerInterval);
});
</script>

<style scoped>
/* Clean scrollbar for the voting list */
.custom-scrollbar::-webkit-scrollbar {
    width: 4px;
}
.custom-scrollbar::-webkit-scrollbar-track {
    background: transparent;
}
.custom-scrollbar::-webkit-scrollbar-thumb {
    background: #e5e7eb;
    border-radius: 10px;
}
.custom-scrollbar:hover::-webkit-scrollbar-thumb {
    background: #d1d5db;
}

@keyframes fade-in {
    from {
        opacity: 0;
        transform: translateY(10px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}
.animate-fade-in {
    animation: fade-in 0.5s ease-out forwards;
}

.result-team-card {
    position: relative;
    min-width: 0;
    border-radius: 1.5rem;
    border: 1px solid #f3f4f6;
    padding: 1rem;
    background: #f9fafb;
    transition:
        transform 320ms var(--ease-organic),
        box-shadow 320ms var(--ease-organic),
        border-color 320ms var(--ease-organic);
}

.result-winner {
    color: #111827;
    background:
        linear-gradient(180deg, rgba(254, 242, 242, 0.9), rgba(255, 255, 255, 1)),
        #fff;
    border-color: #fecaca;
    box-shadow: 0 18px 45px rgba(220, 38, 38, 0.12);
    animation: winner-rise 640ms var(--ease-spring) both;
}

.result-winner::after {
    content: "WIN";
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    border-radius: 999px;
    background: #dc2626;
    color: #fff;
    font-size: 0.625rem;
    font-weight: 900;
    letter-spacing: 0.12em;
    padding: 0.25rem 0.5rem;
}

.result-loser {
    color: #9ca3af;
    filter: grayscale(0.35);
}

.result-bar {
    transform-origin: left center;
    animation: score-fill 800ms var(--ease-spring) both;
}

.result-vs {
    animation: soft-pop 560ms var(--ease-spring) both;
}

.result-pulse {
    animation: result-pulse 3.2s var(--ease-organic) infinite;
}

@keyframes winner-rise {
    from {
        opacity: 0;
        transform: translateY(14px) scale(0.96);
    }
    to {
        opacity: 1;
        transform: translateY(0) scale(1);
    }
}

@keyframes score-fill {
    from {
        transform: scaleX(0);
    }
    to {
        transform: scaleX(1);
    }
}

@keyframes soft-pop {
    from {
        opacity: 0;
        transform: scale(0.8) rotate(-8deg);
    }
    to {
        opacity: 1;
        transform: scale(1) rotate(0deg);
    }
}

@keyframes result-pulse {
    0%,
    100% {
        transform: scale(1);
        opacity: 0.7;
    }
    50% {
        transform: scale(1.12);
        opacity: 0.35;
    }
}
</style>
