// app/pages/debug-auth.vue
// TEMPORARY DEBUG PAGE — delete after fixing
<script setup lang="ts">
const client = useSupabaseClient();
const user = useSupabaseUser();
const { role, fetchRole } = useAuth();

const sessionData = ref<any>(null);
const dbData = ref<any>(null);
const dbError = ref<any>(null);
const stateRole = computed(() => role.value);

onMounted(async () => {
  // 1. Check getSession()
  const { data: { session }, error: sessionError } = await client.auth.getSession();
  sessionData.value = { session, sessionError };

  // 2. Direct DB query
  if (session?.user?.id) {
    const { data, error } = await client
      .from("users")
      .select("*")
      .eq("id", session.user.id)
      .single();
    dbData.value = data;
    dbError.value = error;
  }

  // 3. Force a fresh fetchRole
  await fetchRole();
});
</script>

<template>
  <div class="p-8 font-mono text-sm max-w-4xl mx-auto space-y-6">
    <h1 class="text-2xl font-bold">Auth Debug</h1>

    <div class="bg-gray-100 p-4 rounded">
      <h2 class="font-bold mb-2">useSupabaseUser() reactive ref:</h2>
      <pre>{{ user }}</pre>
    </div>

    <div class="bg-gray-100 p-4 rounded">
      <h2 class="font-bold mb-2">client.auth.getSession():</h2>
      <pre>{{ JSON.stringify(sessionData, null, 2) }}</pre>
    </div>

    <div class="bg-gray-100 p-4 rounded">
      <h2 class="font-bold mb-2">users table row for this user:</h2>
      <pre class="text-green-700">{{ JSON.stringify(dbData, null, 2) }}</pre>
      <pre class="text-red-600">{{ JSON.stringify(dbError, null, 2) }}</pre>
    </div>

    <div class="bg-yellow-100 p-4 rounded">
      <h2 class="font-bold mb-2">useState("user-role") after fetchRole():</h2>
      <pre class="text-xl">{{ stateRole }}</pre>
    </div>
  </div>
</template>
