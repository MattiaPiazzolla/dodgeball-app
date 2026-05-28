// components/public/PublicLive.vue
<template>
    <div class="space-y-4">
        <!-- Match MVP Rules Popup -->
        <div v-if="showFirstMatchVotePopup" class="fixed inset-0 bg-black/80 z-[100] flex items-center justify-center p-4 mobile-fade-in">
            <div class="bg-white border-4 border-black p-6 sm:p-8 max-w-md w-full shadow-[8px_8px_0px_var(--primary)] text-center animate-fade-in">
                <Icon name="mdi:whistle" class="text-5xl text-primary mb-4" />
                <h2 class="font-impact text-2xl sm:text-3xl mb-4 uppercase tracking-wider text-black">Vota l'MVP della Partita!</h2>
                <p class="font-bold text-gray-600 mb-6 text-sm sm:text-base leading-relaxed">
                    Hai a disposizione <span class="text-black text-lg">3 voti</span> per ogni singolo incontro!
                    <br/><br/>
                    Attenzione: Questi voti sono specifici per questa partita in diretta e non si sommano ai 5 voti globali che hai a disposizione per il torneo.
                </p>
                <button @click="showFirstMatchVotePopup = false" class="btn-skewed w-full">
                    <span class="btn-skewed-content">Ho Capito!</span>
                </button>
            </div>
        </div>

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
                    class="order-2 lg:order-1 lg:col-span-3 bg-white border-4 border-black p-4 sm:p-6 shadow-[4px_4px_0px_rgba(0,0,0,1)] flex flex-col gap-5 sm:gap-6 mobile-fade-in"
                >
                    <h2
                        class="text-xl font-impact tracking-wider text-black flex items-center gap-2"
                    >
                        <Icon
                            name="mdi:format-list-numbered"
                            class="text-primary text-xl"
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
                                class="text-xs font-impact text-secondary uppercase tracking-wider"
                            >
                                {{ group.name }}
                            </h3>
                            <div
                                class="bg-white border-2 border-black overflow-hidden shadow-[1px_1px_0px_rgba(0,0,0,1)]"
                            >
                                <table class="w-full text-left text-xs">
                                    <thead
                                        class="bg-secondary text-white font-impact tracking-wider uppercase text-[10px]"
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
                                                class="py-2.5 px-3 text-right font-black text-white"
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
                        class="px-4 py-8 sm:p-12 relative overflow-hidden transition-all flex flex-col justify-center min-h-[360px] sm:min-h-[420px] mobile-fade-in"
                        :class="
                            liveMatch
                                ? liveMatch.is_timer_running
                                    ? 'bg-white border-4 border-primary shadow-[6px_6px_0px_var(--primary)]'
                                    : 'bg-white border-4 border-yellow-500 shadow-[6px_6px_0px_rgba(251,192,45,1)]'
                                : upcomingMatches.length && upcomingMatches[0].match_type === 'final'
                                    ? 'bg-black text-white border-4 border-yellow-400 shadow-[8px_8px_0px_rgba(250,204,21,1)]'
                                    : 'bg-white text-black border-4 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]'
                        "
                    >
                        <div v-if="!liveMatch && upcomingMatches.length && upcomingMatches[0].match_type === 'final'" class="absolute inset-0 flex items-center justify-center pointer-events-none opacity-30">
                            <div class="w-[150%] h-[150%] bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-yellow-500/40 via-transparent to-transparent"></div>
                        </div>

                        <div class="relative z-10 w-full">
                            <template v-if="liveMatch">
                            <div class="flex justify-center mb-6 sm:mb-8">
                                <div
                                    class="px-6 py-2 text-xs sm:text-sm font-black uppercase tracking-widest text-center transition-colors border-2 border-black shadow-[2px_2px_0px_rgba(0,0,0,1)] transform -skew-x-6"
                                    :class="
                                        liveMatch.is_timer_running
                                            ? 'bg-red-600 text-white animate-pulse'
                                            : 'bg-yellow-400 text-black'
                                    "
                                >
                                    <span class="block transform skew-x-6">
                                        {{
                                            liveMatch.is_timer_running
                                                ? "Partita in Diretta"
                                                : "Partita in Pausa"
                                        }}
                                    </span>
                                </div>
                            </div>

                            <div class="text-center mb-10">
                                <span
                                    class="font-mono text-5xl min-[380px]:text-6xl sm:text-7xl font-black tracking-tight transition-colors"
                                    :class="
                                        liveMatch.is_timer_running
                                            ? 'text-primary'
                                            : 'text-yellow-600'
                                    "
                                >
                                    {{ formattedTimer }}
                                </span>
                                <div
                                    class="text-secondary font-impact uppercase tracking-widest mt-2 text-xs"
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
                                        class="font-impact text-sm min-[380px]:text-base sm:text-2xl text-secondary mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team1_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-5xl min-[380px]:text-6xl sm:text-8xl font-impact text-black leading-none"
                                    >
                                        {{ liveMatch.team1_score || 0 }}
                                    </div>
                                </div>
                                <div
                                    class="px-3 py-2 sm:px-4 sm:py-3 bg-secondary text-white border-2 border-black transform -skew-x-6 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                                >
                                    <span
                                        class="text-white text-sm sm:text-xl font-impact uppercase tracking-widest block transform skew-x-6"
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
                                        class="font-impact text-sm min-[380px]:text-base sm:text-2xl text-secondary mb-1"
                                    >
                                        {{
                                            getTeamName(liveMatch.team2_id) ||
                                            "DA DEFINIRE"
                                        }}
                                    </div>
                                    <div
                                        class="text-5xl min-[380px]:text-6xl sm:text-8xl font-impact text-black leading-none"
                                    >
                                        {{ liveMatch.team2_score || 0 }}
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="upcomingMatches.length && upcomingMatches[0].match_type === 'final'">
                            <div class="flex flex-col items-center justify-center w-full h-full py-4 sm:py-8 text-center animate-fade-in relative z-20">
                                <div class="relative w-20 h-20 sm:w-28 sm:h-28 mb-6">
                                    <div class="absolute inset-0 bg-yellow-500 rounded-full animate-ping opacity-30"></div>
                                    <div class="relative w-full h-full rounded-full border-4 border-yellow-400 bg-black flex items-center justify-center shadow-[0_0_40px_rgba(250,204,21,0.5)]">
                                        <Icon name="mdi:trophy" class="text-5xl sm:text-7xl text-yellow-400 drop-shadow-[0_0_15px_rgba(250,204,21,1)]" />
                                    </div>
                                </div>
                                
                                <h2 class="text-5xl sm:text-7xl lg:text-8xl font-impact uppercase tracking-widest text-transparent bg-clip-text bg-gradient-to-b from-yellow-300 via-yellow-500 to-red-600 animate-pulse drop-shadow-[0_5px_5px_rgba(0,0,0,1)] mb-4 transform -skew-x-6">
                                    GRAN FINALE
                                </h2>
                                
                                <p v-if="upcomingMatches[0].start_time" class="text-red-500 font-black uppercase tracking-widest text-lg sm:text-2xl mb-12 bg-black/50 px-6 py-2 border-y-2 border-red-500 transform skew-x-12 shadow-[0_0_20px_rgba(239,68,68,0.3)]">
                                    ALLE ORE {{ upcomingMatches[0].start_time }}
                                </p>

                                <div class="w-full flex flex-col sm:flex-row items-center justify-center gap-8 sm:gap-12 max-w-4xl mx-auto">
                                    <div class="flex flex-col items-center flex-1 min-w-[200px]">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(upcomingMatches[0].team1_id)"
                                            :alt="getTeamName(upcomingMatches[0].team1_id)"
                                            size-class="w-32 h-32 sm:w-40 sm:h-40 lg:w-48 lg:h-48 mb-6 transform hover:scale-110 transition-transform duration-300 drop-shadow-[0_0_25px_rgba(255,255,255,0.2)]"
                                            icon-class="text-7xl sm:text-9xl"
                                        />
                                        <div class="text-3xl sm:text-4xl lg:text-5xl font-black uppercase text-white drop-shadow-md text-center px-2 break-words w-full">
                                            {{ getTeamName(upcomingMatches[0].team1_id) || "DA DEFINIRE" }}
                                        </div>
                                    </div>
                                    
                                    <div class="relative px-6 py-4 bg-red-600 border-4 border-yellow-400 transform -skew-x-12 shadow-[5px_5px_0px_rgba(0,0,0,1)] z-10 shrink-0">
                                        <span class="text-white text-3xl sm:text-5xl font-impact uppercase tracking-widest block transform skew-x-12 drop-shadow-[0_2px_2px_rgba(0,0,0,0.8)]">VS</span>
                                    </div>
                                    
                                    <div class="flex flex-col items-center flex-1 min-w-[200px]">
                                        <PublicTeamLogo
                                            :src="getTeamLogo(upcomingMatches[0].team2_id)"
                                            :alt="getTeamName(upcomingMatches[0].team2_id)"
                                            size-class="w-32 h-32 sm:w-40 sm:h-40 lg:w-48 lg:h-48 mb-6 transform hover:scale-110 transition-transform duration-300 drop-shadow-[0_0_25px_rgba(255,255,255,0.2)]"
                                            icon-class="text-7xl sm:text-9xl"
                                        />
                                        <div class="text-3xl sm:text-4xl lg:text-5xl font-black uppercase text-white drop-shadow-md text-center px-2 break-words w-full">
                                            {{ getTeamName(upcomingMatches[0].team2_id) || "DA DEFINIRE" }}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </template>

                        <template v-else-if="upcomingMatches.length">
                            <div class="text-center mb-8">
                                <div
                                    class="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4 border-2 border-black shadow-[2px_2px_0px_rgba(0,0,0,1)] text-black"
                                >
                                    <Icon
                                        name="mdi:calendar-clock"
                                        class="text-2xl"
                                    />
                                </div>
                                <h2
                                    class="text-3xl font-black uppercase tracking-tight"
                                >
                                    Prossimo Incontro
                                </h2>
                                <p
                                    v-if="upcomingMatches[0].start_time"
                                    class="text-red-500 font-bold uppercase tracking-widest text-sm mt-1 min-h-[20px]"
                                >
                                    {{ upcomingMatches[0].start_time }}
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
                                        class="text-base sm:text-xl font-black uppercase truncate"
                                    >
                                        {{
                                            getTeamName(
                                                upcomingMatches[0].team1_id,
                                            ) || "DA DEFINIRE"
                                        }}
                                    </div>
                                </div>
                                <span
                                    class="text-lg font-black uppercase tracking-widest text-gray-300"
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
                                        class="text-base sm:text-xl font-black uppercase truncate"
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
                    </div>

                    <div
                        v-if="liveMatch"
                        class="bg-white border-4 border-black p-4 sm:p-6 shadow-[4px_4px_0px_rgba(0,0,0,1)] mobile-fade-in space-y-5"
                    >
                        <div
                            class="flex flex-col sm:flex-row sm:items-center justify-between gap-2"
                        >
                            <div>
                                <h2
                                    class="font-impact text-xl text-black tracking-wider flex flex-wrap items-center gap-2"
                                >
                                    MVP della partita
                                    <span class="text-xs px-2 py-0.5 bg-black text-white transform -skew-x-6 tracking-widest whitespace-nowrap">Voti: <span :class="matchRemainingVotes > 0 ? 'text-primary' : 'text-gray-400'">{{ matchRemainingVotes }}</span>/3</span>
                                    <button @click="showFirstMatchVotePopup = true" class="ml-auto text-gray-400 hover:text-primary transition-colors cursor-pointer text-xs flex items-center gap-1 font-bold font-sans uppercase tracking-widest"><Icon name="mdi:information-outline" class="text-sm" /> Regole</button>
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
                                    class="shrink-0 flex items-center gap-2 bg-white border-2 border-black px-3 py-1.5 shadow-[1px_1px_0px_rgba(0,0,0,1)]"
                                >
                                    <span
                                        class="text-xs font-impact"
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
                                        class="max-w-24 truncate text-xs font-impact tracking-wider uppercase text-black"
                                        >{{ player.name }}</span
                                    >
                                    <span
                                        class="text-xs font-impact text-primary"
                                        >{{ player.match_mvp_votes || 0 }}</span
                                    >
                                </div>
                            </div>
                        </div>

                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div
                                v-for="teamRoster in liveTeamRosters"
                                :key="teamRoster.teamId || teamRoster.name"
                                class="bg-cement border-2 border-black p-3 sm:p-4 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
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
                                        class="flex items-center justify-between gap-3 bg-white border-2 border-black p-3 shadow-[2px_2px_0px_rgba(0,0,0,1)] hover:bg-gray-50 transition-all rounded-none"
                                    >
                                        <div
                                            class="flex items-center gap-3 min-w-0"
                                        >
                                            <div
                                                class="w-11 h-11 border-2 border-black bg-white flex items-center justify-center overflow-hidden shrink-0 text-gray-400 shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
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
                                                    class="font-impact text-sm text-black tracking-wide truncate"
                                                >
                                                    {{ player.name }}
                                                </p>
                                                <p
                                                    class="text-[10px] font-impact tracking-wider text-primary uppercase"
                                                >
                                                    #{{ player.jersey_number || "00" }}
                                                </p>
                                            </div>
                                        </div>

                                        <div
                                            class="flex items-center gap-2 shrink-0"
                                        >
                                            <span
                                                class="w-9 text-center text-sm font-impact text-primary"
                                                >{{ player.match_mvp_votes || 0 }}</span
                                            >
                                            <div class="flex gap-2">
                                                <button
                                                    v-if="getMatchPlayerVotes(player.id) > 0"
                                                    @click="undoMatchVote(player.id)"
                                                    class="w-10 h-10 flex items-center justify-center transition-all border-2 border-black bg-red-500 text-white hover:bg-red-600 shadow-[2px_2px_0px_rgba(0,0,0,1)] active:scale-90"
                                                    title="Rimuovi Voto"
                                                >
                                                    <Icon name="mdi:minus" class="text-lg" />
                                                </button>
                                                <button
                                                    @click="doMatchVote(player.id)"
                                                    :disabled="!matchCanVote"
                                                class="w-10 h-10 flex items-center justify-center transition-all border-2 border-black rounded-none active:scale-90 relative"
                                                :class="
                                                    !matchCanVote
                                                        ? 'bg-gray-100 border-gray-300 text-gray-400 cursor-not-allowed shadow-[1px_1px_0px_rgba(0,0,0,0.1)]'
                                                        : getMatchPlayerVotes(player.id) > 0
                                                          ? 'bg-green-500 border-black text-white hover:bg-green-600 shadow-[2px_2px_0px_rgba(0,0,0,1)]'
                                                          : 'bg-white border-black text-secondary hover:bg-primary hover:text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]'
                                                "
                                                :title="
                                                    !matchCanVote
                                                        ? 'Hai esaurito i voti per questa partita'
                                                        : 'Vota MVP Partita'
                                                "
                                            >
                                                <div v-if="getMatchPlayerVotes(player.id) > 0" class="absolute -top-2 -right-2 bg-primary text-white text-[10px] w-4 h-4 rounded-full flex items-center justify-center font-black border border-black z-10">{{ getMatchPlayerVotes(player.id) }}</div>
                                                <Icon
                                                    :name="
                                                        getMatchPlayerVotes(player.id) > 0
                                                            ? 'mdi:thumb-up'
                                                            : 'mdi:thumb-up-outline'
                                                    "
                                                    class="text-lg"
                                                />
                                                </button>
                                            </div>
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
                        class="relative overflow-hidden bg-white border-4 border-black p-5 sm:p-7 mobile-fade-in shadow-[4px_4px_0px_rgba(0,0,0,1)]"
                    >
                        <div
                            class="absolute -right-12 -top-12 w-40 h-40 bg-primary/20 blur-xl result-pulse"
                        ></div>
                        <div
                            class="relative flex flex-col gap-5"
                        >
                            <div
                                class="flex flex-col sm:flex-row sm:items-center justify-between gap-3"
                            >
                                <div>
                                    <p
                                        class="text-[10px] font-impact uppercase tracking-[0.24em] text-primary"
                                    >
                                        Ultimo incontro
                                    </p>
                                    <h2
                                        class="font-impact text-2xl sm:text-3xl text-black mt-1"
                                    >
                                        {{
                                            getTeamName(lastMatch.winner_id) ||
                                            "Risultato finale"
                                        }}
                                        <span class="text-primary italic">vince</span>
                                    </h2>
                                </div>
                                <div
                                    class="self-start sm:self-auto px-4 py-1.5 bg-secondary text-white text-[10px] font-impact uppercase tracking-widest border-2 border-black transform -skew-x-6 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                                >
                                    <span class="block transform skew-x-6">{{ translateStage(lastMatch.match_type) }}</span>
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
                                        class="w-12 h-12 bg-secondary border-2 border-black flex items-center justify-center shadow-[1px_1px_0px_rgba(0,0,0,1)] result-vs transform -skew-x-6"
                                    >
                                        <span
                                            class="text-white font-impact text-xs uppercase tracking-widest block transform skew-x-6"
                                            >VS</span
                                        >
                                    </div>
                                    <div
                                        class="h-16 w-1 bg-black"
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
                            class="bg-white border-2 border-black p-5 shadow-[3px_3px_0px_rgba(0,0,0,1)] transition-all hover:translate-y-[-1px] rounded-none"
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
                    class="order-3 lg:col-span-3 bg-white border-4 border-black p-4 sm:p-6 shadow-[4px_4px_0px_rgba(0,0,0,1)] flex flex-col max-h-[70vh] lg:max-h-[600px] mobile-fade-in"
                >
                    <h2
                        class="text-xl font-impact tracking-wider text-black mb-4 flex items-center gap-2"
                    >
                        <Icon name="mdi:star" class="text-yellow-500 text-xl animate-pulse" />
                        MVP
                        <span class="text-xs px-2 py-0.5 bg-black text-white transform -skew-x-6 tracking-widest ml-auto">Voti: <span :class="remainingVotes > 0 ? 'text-primary' : 'text-gray-400'">{{ remainingVotes }}</span>/5</span>
                    </h2>

                    <div class="relative mb-4">
                        <Icon
                            name="mdi:magnify"
                            class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-lg z-10"
                        />
                        <input
                            v-model="searchQuery"
                            type="text"
                            placeholder="Cerca giocatore..."
                            class="w-full bg-white border-2 border-black rounded-none py-3 pl-10 pr-4 text-xs font-impact tracking-widest uppercase focus:outline-none focus:border-primary transition-all placeholder:text-gray-400 shadow-[1px_1px_0px_rgba(0,0,0,1)]"
                        />
                    </div>

                    <div
                        class="overflow-y-auto pr-1 space-y-3 flex-1 custom-scrollbar"
                    >
                        <div
                            v-for="player in filteredPlayers"
                            :key="player.id"
                            class="flex items-center justify-between p-3 bg-white border-2 border-black shadow-[2px_2px_0px_rgba(0,0,0,1)] hover:bg-gray-50 transition-all group rounded-none"
                        >
                            <div
                                class="flex items-center gap-3 overflow-hidden"
                            >
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-10 h-10 border-2 border-black object-cover bg-white shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
                                />
                                <div
                                    v-else
                                    class="w-10 h-10 border-2 border-black bg-white flex items-center justify-center text-gray-400 shrink-0 shadow-[1px_1px_0px_rgba(0,0,0,1)] rounded-none"
                                >
                                    <Icon name="mdi:account" class="text-lg" />
                                </div>
                                <div class="min-w-0">
                                    <div
                                        class="font-impact text-xs text-black tracking-wider truncate"
                                    >
                                        {{ player.name }}
                                    </div>
                                    <div
                                        class="text-[9px] text-gray-500 font-bold uppercase truncate"
                                    >
                                        {{ getTeamName(player.team_id) }}
                                    </div>
                                </div>
                            </div>

                            <div
                                class="flex flex-col items-center justify-center gap-0.5 shrink-0 pl-2"
                            >
                                <div class="flex gap-1.5">
                                    <button
                                        v-if="getPlayerVotes(player.id) > 0"
                                        @click="undoVote(player.id)"
                                        class="w-8 h-8 flex items-center justify-center transition-all border-2 border-black bg-red-500 text-white hover:bg-red-600 shadow-[1px_1px_0px_rgba(0,0,0,1)] active:scale-90"
                                        title="Rimuovi Voto"
                                    >
                                        <Icon name="mdi:minus" class="text-sm" />
                                    </button>
                                    <button
                                        @click="doVote(player.id)"
                                        :disabled="!canVote"
                                    class="w-8 h-8 flex items-center justify-center transition-all border-2 border-black rounded-none active:scale-90 relative"
                                    :class="
                                        !canVote
                                            ? 'bg-gray-100 border-gray-300 text-gray-400 cursor-not-allowed shadow-[1px_1px_0px_rgba(0,0,0,0.1)]'
                                            : getPlayerVotes(player.id) > 0
                                              ? 'bg-green-500 border-black text-white hover:bg-green-600 shadow-[1px_1px_0px_rgba(0,0,0,1)]'
                                              : 'bg-white border-black text-secondary hover:bg-primary hover:text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]'
                                    "
                                >
                                    <div v-if="getPlayerVotes(player.id) > 0" class="absolute -top-2 -right-2 bg-primary text-white text-[9px] w-3.5 h-3.5 rounded-full flex items-center justify-center font-black border border-black z-10">{{ getPlayerVotes(player.id) }}</div>
                                    <Icon
                                        :name="
                                            getPlayerVotes(player.id) > 0
                                                ? 'mdi:thumb-up'
                                                : 'mdi:thumb-up-outline'
                                        "
                                        class="text-sm"
                                    />
                                    </button>
                                </div>
                                <span
                                    class="text-[9px] font-impact uppercase tracking-widest mt-1"
                                    :class="
                                        getPlayerVotes(player.id) > 0
                                            ? 'text-green-600'
                                            : 'text-secondary'
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
import { useVotes } from "~/composables/useVotes";
import { useMatchVotes } from "~/composables/useMatchVotes";

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
const { loadVotes, canVote, remainingVotes, recordVote, removeVote, getPlayerVotes } = useVotes();

let realtimeChannel: any = null;
let playerRealtimeChannel: any = null;
const now = ref(Date.now());
let timerInterval: any = null;

const liveMatch = computed(() =>
    matches.value.find((m) => m.status === "in_progress" || m.status === "paused"),
);

const liveMatchId = computed(() => liveMatch.value?.id || null);
const { 
    loadVotes: loadMatchVotes, 
    canVote: matchCanVote, 
    remainingVotes: matchRemainingVotes, 
    recordVote: recordMatchVote, 
    removeVote: removeMatchVote, 
    getPlayerVotes: getMatchPlayerVotes,
    showFirstMatchVotePopup
} = useMatchVotes(liveMatchId);

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
                (b.match_mvp_votes || 0) - (a.match_mvp_votes || 0) ||
                a.name.localeCompare(b.name),
        ),
);

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
    if (pData) players.value = pData;

    loadVotes();
    loadMatchVotes(); 
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

const doVote = async (playerId: string) => {
    if (!canVote.value) return;

    if (recordVote(playerId)) {
        const player = players.value.find((p) => p.id === playerId);
        if (player) player.mvp_votes = (player.mvp_votes || 0) + 1;

        await supabase.rpc("increment_player_votes", { player_uuid: playerId });
    }
};

const undoVote = async (playerId: string) => {
    if (removeVote(playerId)) {
        const player = players.value.find((p) => p.id === playerId);
        if (player) {
            player.mvp_votes = Math.max(0, (player.mvp_votes || 0) - 1);
        }
        await supabase.rpc("decrement_player_votes", { player_uuid: playerId });
    }
};

const doMatchVote = async (playerId: string) => {
    if (!matchCanVote.value) return;

    if (recordMatchVote(playerId)) {
        const player = players.value.find((p) => p.id === playerId);
        if (player) {
            player.mvp_votes = (player.mvp_votes || 0) + 1;
            player.match_mvp_votes = (player.match_mvp_votes || 0) + 1;
        }

        await supabase.rpc("increment_match_player_votes", { player_uuid: playerId });
    }
};

const undoMatchVote = async (playerId: string) => {
    if (removeMatchVote(playerId)) {
        const player = players.value.find((p) => p.id === playerId);
        if (player) {
            player.mvp_votes = Math.max(0, (player.mvp_votes || 0) - 1);
            player.match_mvp_votes = Math.max(0, (player.match_mvp_votes || 0) - 1);
        }
        await supabase.rpc("decrement_match_player_votes", { player_uuid: playerId });
    }
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
    border-radius: 0px !important;
    border: 2px solid var(--secondary);
    padding: 1rem;
    background: var(--surface);
    box-shadow: 2px 2px 0px var(--secondary);
    transition:
        transform 320ms var(--ease-organic),
        box-shadow 320ms var(--ease-organic),
        border-color 320ms var(--ease-organic);
}

.result-winner {
    color: #111827;
    background: var(--surface);
    border-color: var(--primary) !important;
    box-shadow: 4px 4px 0px var(--primary) !important;
    animation: winner-rise 640ms var(--ease-spring) both;
}

.result-winner::after {
    content: "WIN";
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    border-radius: 0px !important;
    border: 1.5px solid var(--secondary);
    background: var(--primary);
    color: #fff;
    font-family: "Impact", sans-serif;
    font-size: 0.625rem;
    font-weight: 900;
    letter-spacing: 0.12em;
    padding: 0.25rem 0.5rem;
    transform: rotate(4deg);
    box-shadow: 2px 2px 0px var(--secondary);
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
