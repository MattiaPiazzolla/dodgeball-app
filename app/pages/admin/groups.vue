<template>
  <div class="max-w-6xl mx-auto px-4 py-5 sm:py-8 space-y-6 sm:space-y-8 mobile-fade-in">

    <!-- Top Bar -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <h1 class="text-2xl sm:text-3xl font-black uppercase tracking-tight text-black">
        Fasi a Gironi
      </h1>

      <form @submit.prevent="createGroup" class="flex flex-col min-[420px]:flex-row min-[420px]:items-center gap-2 w-full sm:w-auto">
        <input
          v-model="newGroupName"
          placeholder="Nome Gruppo (es. Gruppo A)"
          required
          class="w-full min-[420px]:w-56 bg-gray-100 border border-transparent focus:border-gray-300 focus:bg-white focus:ring-4 focus:ring-gray-100 focus:outline-none rounded-2xl px-4 py-3 text-sm font-medium text-gray-800 placeholder-gray-400 transition-all"
        />
        <button
          type="submit"
          class="bg-black text-white px-4 py-3 rounded-2xl text-sm font-bold hover:bg-gray-800 active:scale-[0.98] transition-all whitespace-nowrap"
        >
          Crea Gruppo
        </button>
      </form>
    </div>

    <!-- Empty State -->
    <div
      v-if="!groups.length"
      class="flex flex-col items-center justify-center py-24 text-center"
    >
      <div class="w-20 h-20 rounded-2xl bg-gray-100 flex items-center justify-center mb-5">
        <Icon name="mdi:trophy-outline" class="text-4xl text-gray-300" />
      </div>
      <p class="text-gray-500 font-semibold text-base mb-1">Nessun gruppo ancora</p>
      <p class="text-gray-400 text-sm">Crea il tuo primo gruppo per iniziare.</p>
    </div>

    <!-- Groups Grid -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div
        v-for="group in groups"
        :key="group.id"
        class="interactive-card bg-white rounded-3xl sm:rounded-2xl border border-gray-100 shadow-sm p-4 sm:p-6 flex flex-col gap-5 hover:shadow-md"
      >
        <!-- Card Header -->
        <div class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3">
          <h2 class="text-lg font-black uppercase tracking-tight text-black">
            {{ group.name }}
          </h2>
          <div class="flex flex-wrap items-center gap-2 shrink-0">
            <span class="text-xs font-bold text-gray-500 bg-gray-100 px-3 py-1 rounded-full">
              {{ group.group_teams.length }} {{ group.group_teams.length === 1 ? 'Squadra' : 'Squadre' }}
            </span>
            <NuxtLink
              to="/admin/matches"
              class="bg-black text-white text-xs font-bold px-3 py-1.5 rounded-full hover:bg-gray-800 active:scale-95 transition-all whitespace-nowrap"
            >
              Vai agli incontri
            </NuxtLink>
          </div>
        </div>

        <!-- Standings Table -->
        <div class="overflow-x-auto rounded-xl border border-gray-100 custom-scrollbar">
          <table class="w-full min-w-[520px] text-sm">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-100 text-gray-400 font-bold uppercase text-xs tracking-wide">
                <th class="px-4 py-2.5 text-left">#</th>
                <th class="px-4 py-2.5 text-left">Squadra</th>
                <th class="px-4 py-2.5 text-center">V</th>
                <th class="px-4 py-2.5 text-center">P</th>
                <th class="px-4 py-2.5 text-center text-red-500">Pt</th>
                <th class="px-4 py-2.5"></th>
              </tr>
            </thead>
            <tbody>
              <template v-if="group.group_teams.length">
                <tr
                  v-for="(gt, index) in group.group_teams"
                  :key="gt.id"
                  :class="[
                    'border-b border-gray-50 last:border-0 transition-colors',
                    index === 0 ? 'bg-yellow-50 hover:bg-yellow-100' : 'hover:bg-gray-50'
                  ]"
                >
                  <td class="px-4 py-3 text-xs font-bold text-gray-400">
                    {{ index + 1 }}
                  </td>
                  <td class="px-4 py-3 font-black uppercase text-black text-xs tracking-wide">
                    {{ gt.teams.name }}
                  </td>
                  <td class="px-4 py-3 text-center font-medium text-gray-500">
                    {{ gt.wins }}
                  </td>
                  <td class="px-4 py-3 text-center font-medium text-gray-500">
                    {{ gt.losses }}
                  </td>
                  <td class="px-4 py-3 text-center font-black text-red-600">
                    {{ gt.points }}
                  </td>
                  <td class="px-4 py-3 text-right">
                    <button
                      @click="removeTeam(gt.id)"
                      title="Remove from group"
                      class="text-gray-300 hover:text-red-500 transition-colors p-1 rounded-lg hover:bg-red-50"
                    >
                      <Icon name="mdi:close" class="text-base" />
                    </button>
                  </td>
                </tr>
              </template>
              <tr v-else>
                <td colspan="6" class="px-4 py-8 text-center text-gray-400 text-xs font-medium">
                  Nessuna squadra ancora assegnata.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Add Team Section -->
        <div>
          <form
            v-if="availableTeams.length"
            @submit.prevent="addTeamToGroup(group.id)"
            class="flex flex-col min-[420px]:flex-row min-[420px]:items-center gap-2"
          >
            <select
              v-model="selectedTeams[group.id]"
              required
              class="flex-1 bg-gray-100 border border-transparent focus:border-gray-300 focus:bg-white focus:ring-4 focus:ring-gray-100 focus:outline-none rounded-2xl px-3 py-3 text-xs font-bold uppercase text-gray-700 transition-all"
            >
              <option value="" disabled>Aggiungi una squadra...</option>
              <option
                v-for="team in availableTeams"
                :key="team.id"
                :value="team.id"
              >
                {{ team.name }}
              </option>
            </select>
            <button
              type="submit"
              class="bg-black text-white px-4 py-3 rounded-2xl text-xs font-black hover:bg-gray-800 active:scale-[0.98] transition-all"
            >
              Aggiungi
            </button>
          </form>
          <p v-else class="text-xs text-gray-400 font-medium">
            Tutte le squadre assegnate.
          </p>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { Icon } from '#components'

definePageMeta({ middleware: 'admin' })

const supabase = useSupabaseClient()
const groups = ref<any[]>([])
const allTeams = ref<any[]>([])
const newGroupName = ref('')
const selectedTeams = ref<Record<string, string>>({})

const loadData = async () => {
  const { data: tData } = await supabase
    .from('teams')
    .select('id, name')
    .eq('status', 'approved')
  if (tData) allTeams.value = tData

  const { data: gData } = await supabase
    .from('groups')
    .select(`
      id, name,
      group_teams ( id, team_id, points, wins, losses, teams ( name ) )
    `)
    .order('name')

  if (gData) {
    gData.forEach((g) => {
      g.group_teams.sort((a: any, b: any) => b.points - a.points)
      if (!selectedTeams.value[g.id]) selectedTeams.value[g.id] = ''
    })
    groups.value = gData
  }
}

// Teams not yet in any group
const availableTeams = computed(() => {
  const assignedIds = groups.value.flatMap((g) =>
    g.group_teams.map((gt: any) => gt.team_id)
  )
  return allTeams.value.filter((t) => !assignedIds.includes(t.id))
})

const createGroup = async () => {
  const { error } = await supabase
    .from('groups')
    .insert([{ name: newGroupName.value }])
  if (error) alert('Errore: ' + error.message)
  else {
    newGroupName.value = ''
    await loadData()
  }
}

const addTeamToGroup = async (groupId: string) => {
  const teamId = selectedTeams.value[groupId]
  if (!teamId) return

  const { error } = await supabase
    .from('group_teams')
    .insert([{ group_id: groupId, team_id: teamId }])
  if (error) alert('Errore: ' + error.message)
  else {
    selectedTeams.value[groupId] = ''
    await loadData()
  }
}

const removeTeam = async (groupTeamId: string) => {
  const { error } = await supabase
    .from('group_teams')
    .delete()
    .eq('id', groupTeamId)
  if (error) alert('Errore: ' + error.message)
  else await loadData()
}

onMounted(loadData)
</script>
