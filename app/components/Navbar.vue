// app/components/Navbar.vue
<script setup lang="ts">
import { watch } from 'vue';
const { user, logout, role, fetchRole } = useAuth();

// Re-fetch if user logs in during the session (e.g. navigates to login page)
watch(user, (newUser) => {
  if (newUser) fetchRole();
  else role.value = null;
});
</script>

<template>
    <header class="bg-red-600 text-white shadow-md">
        <div class="container mx-auto p-4 flex justify-between items-center">
            <NuxtLink to="/" class="text-2xl font-black italic tracking-wider"
                >DODGEBALL</NuxtLink
            >
            <nav class="space-x-4 font-semibold flex items-center">
                <ClientOnly>
                <template v-if="!user">
                    <NuxtLink
                        to="/login"
                        class="bg-white text-red-600 px-4 py-2 rounded font-bold hover:bg-gray-100 transition mr-2"
                    >
                        Portale Capitano
                    </NuxtLink>
                    <NuxtLink
                        to="/admin/login"
                        class="bg-gray-800 text-white px-4 py-2 rounded font-bold hover:bg-gray-700 transition"
                    >
                        Accesso Amministratore
                    </NuxtLink>
                </template>
                <template v-else>
                    <template v-if="role === 'admin'">
                        <NuxtLink to="/admin" class="bg-gray-800 text-white px-4 py-2 rounded font-bold hover:bg-gray-700 transition mr-4"
                            >Portale Amministratore</NuxtLink
                        >
                        <NuxtLink to="/admin/matches" class="hover:text-red-200"
                            >Incontri</NuxtLink
                        >
                        <NuxtLink to="/admin/groups" class="hover:text-red-200 mr-4"
                            >Gironi</NuxtLink
                        >
                    </template>
                    <template v-else>
                        <NuxtLink to="/captain" class="hover:text-red-200 mr-4"
                            >Portale Capitano</NuxtLink
                        >
                    </template>
                    <button @click="logout" class="bg-white text-red-600 px-4 py-2 rounded font-bold hover:bg-gray-100 transition">
                        Disconnetti
                    </button>
                </template>
                </ClientOnly>
            </nav>
        </div>
    </header>
</template>
