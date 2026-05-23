// app/components/Navbar.vue
<script setup lang="ts">
const { user } = useAuth();
</script>

<template>
    <header class="bg-red-600 text-white shadow-md">
        <div class="container mx-auto p-4 flex justify-between items-center">
            <NuxtLink to="/" class="text-2xl font-black italic tracking-wider"
                >DODGEBALL</NuxtLink
            >
            <nav class="space-x-4 font-semibold flex items-center">
                <template v-if="!user">
                    <NuxtLink
                        to="/login"
                        class="bg-white text-red-600 px-4 py-2 rounded font-bold hover:bg-gray-100 transition"
                    >
                        Register a Team
                    </NuxtLink>
                </template>
                <template v-else>
                    <NuxtLink to="/captain" class="hover:text-red-200"
                        >Captain Portal</NuxtLink
                    >
                </template>
            </nav>
        </div>
    </header>
</template>
