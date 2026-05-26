<template>
  <div class="max-w-6xl mx-auto px-4 py-5 sm:py-8 space-y-6 sm:space-y-8 mobile-fade-in">

    <!-- Top Bar -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <h1 class="text-3xl sm:text-4xl font-impact uppercase tracking-widest text-black">
        Fasi a Gironi
      </h1>

      <form @submit.prevent="createGroup" class="flex flex-col min-[420px]:flex-row min-[420px]:items-center gap-2 w-full sm:w-auto">
        <input
          v-model="newGroupName"
          placeholder="Nome Gruppo (es. Gruppo A)"
          required
          class="w-full min-[420px]:w-56 bg-white border-4 border-black focus:border-primary focus:outline-none px-4 py-3 text-sm font-impact uppercase tracking-widest text-black placeholder-secondary transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
        />
        <button
          type="submit"
          class="btn-skewed whitespace-nowrap"
        >
          <span class="btn-skewed-content text-sm">Crea Gruppo</span>
        </button>
      </form>
    </div>

    <!-- Empty State -->
    <div
      v-if="!groups.length"
      class="card-grunge bg-white flex flex-col items-center justify-center py-24 text-center"
    >
      <div class="w-20 h-20 bg-cement border-4 border-black flex items-center justify-center mb-5 shadow-[4px_4px_0px_rgba(0,0,0,1)]">
        <Icon name="mdi:trophy-outline" class="text-4xl text-secondary" />
      </div>
      <p class="text-secondary font-impact text-xl uppercase tracking-widest mb-1">Nessun gruppo ancora</p>
      <p class="text-gray-500 text-sm font-bold uppercase tracking-widest">Crea il tuo primo gruppo per iniziare.</p>
    </div>

    <!-- Groups Grid -->
    <div v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div
        v-for="group in groups"
        :key="group.id"
        class="card-grunge bg-white p-4 sm:p-6 flex flex-col gap-5"
      >
        <!-- Card Header -->
        <div class="flex flex-col min-[520px]:flex-row min-[520px]:items-center justify-between gap-3">
          <h2 class="text-2xl font-impact uppercase tracking-widest text-black">
            {{ group.name }}
          </h2>
          <div class="flex flex-wrap items-center gap-2 shrink-0">
            <span class="text-xs font-impact tracking-widest text-secondary border-2 border-black px-3 py-1 bg-cement shadow-[2px_2px_0px_rgba(0,0,0,1)] uppercase">
              {{ group.group_teams.length }} {{ group.group_teams.length === 1 ? 'Squadra' : 'Squadre' }}
            </span>
            <NuxtLink
              to="/admin/matches"
              class="btn-skewed-secondary whitespace-nowrap px-3 py-1"
            >
              <span class="btn-skewed-content text-xs">Vai agli incontri</span>
            </NuxtLink>
          </div>
        </div>

        <!-- Standings Table -->
        <div class="overflow-x-auto border-4 border-black custom-scrollbar bg-white shadow-[4px_4px_0px_rgba(0,0,0,1)]">
          <table class="w-full min-w-[520px] text-sm">
            <thead>
              <tr class="bg-black text-white font-impact uppercase text-xs tracking-widest border-b-4 border-black">
                <th class="px-4 py-3 text-left">#</th>
                <th class="px-4 py-3 text-left">Squadra</th>
                <th class="px-4 py-3 text-center">V</th>
                <th class="px-4 py-3 text-center">P</th>
                <th class="px-4 py-3 text-center text-primary">Pt</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody>
              <template v-if="group.group_teams.length">
                <tr
                  v-for="(gt, index) in group.group_teams"
                  :key="gt.id"
                  :class="[
                    'border-b-2 border-black last:border-0 transition-colors',
                    index === 0 ? 'bg-primary/10 hover:bg-primary/20' : 'hover:bg-gray-100'
                  ]"
                >
                  <td class="px-4 py-3 text-sm font-impact text-secondary">
                    {{ index + 1 }}
                  </td>
                  <td class="px-4 py-3 font-impact uppercase text-black text-sm tracking-wide">
                    {{ gt.teams.name }}
                  </td>
                  <td class="px-4 py-3 text-center font-bold text-secondary">
                    {{ gt.wins }}
                  </td>
                  <td class="px-4 py-3 text-center font-bold text-secondary">
                    {{ gt.losses }}
                  </td>
                  <td class="px-4 py-3 text-center font-impact text-lg text-primary">
                    {{ gt.points }}
                  </td>
                  <td class="px-4 py-3 text-right">
                    <button
                      @click="removeTeam(gt.id)"
                      title="Remove from group"
                      class="text-secondary hover:text-primary transition-colors p-1"
                    >
                      <Icon name="mdi:close-thick" class="text-xl" />
                    </button>
                  </td>
                </tr>
              </template>
              <tr v-else>
                <td colspan="6" class="px-4 py-8 text-center text-secondary text-sm font-impact uppercase tracking-widest bg-cement">
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
              class="flex-1 bg-white border-4 border-black focus:border-primary focus:outline-none px-3 py-3 text-xs font-impact uppercase tracking-widest text-black transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)]"
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
              class="btn-skewed px-4"
            >
              <span class="btn-skewed-content text-xs">Aggiungi</span>
            </button>
          </form>
          <p v-else class="text-xs text-secondary font-impact uppercase tracking-widest bg-cement p-3 border-2 border-black inline-block shadow-[2px_2px_0px_rgba(0,0,0,1)]">
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
