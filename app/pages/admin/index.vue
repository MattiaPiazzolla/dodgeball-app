// app/pages/admin/index.vue
<script setup lang="ts">
definePageMeta({ middleware: ["admin"] });
const client = useSupabaseClient();
const teams = ref<any[]>([]);
const filter = ref<"pending" | "approved">("pending");

const fetchTeams = async () => {
    const { data } = await client.from("teams").select("*").order("created_at");
    teams.value = data || [];
};

const filteredTeams = computed(() =>
    teams.value.filter((t) =>
        filter.value === "pending" ? !t.is_approved : t.is_approved,
    ),
);

const updateStatus = async (id: string, is_approved: boolean) => {
    await client.from("teams").update({ is_approved }).eq("id", id);
    await fetchTeams();
};

onMounted(fetchTeams);
</script>

<template>
    <div class="max-w-4xl mx-auto p-6">
        <div class="flex gap-4 mb-6">
            <button
                @click="filter = 'pending'"
                :class="filter === 'pending' ? 'font-bold underline' : ''"
            >
                Pending
            </button>
            <button
                @click="filter = 'approved'"
                :class="filter === 'approved' ? 'font-bold underline' : ''"
            >
                Approved
            </button>
        </div>

        <div
            v-for="team in filteredTeams"
            :key="team.id"
            class="p-4 border mb-2 flex justify-between items-center"
        >
            <NuxtLink
                :to="`/admin/teams/${team.id}`"
                class="font-bold hover:text-blue-600"
                >{{ team.name }}</NuxtLink
            >
            <div class="flex gap-2">
                <button
                    v-if="!team.is_approved"
                    @click="updateStatus(team.id, true)"
                    class="text-green-600"
                >
                    Approve
                </button>
                <button
                    v-else
                    @click="updateStatus(team.id, false)"
                    class="text-orange-600"
                >
                    Reject
                </button>
            </div>
        </div>
    </div>
</template>
