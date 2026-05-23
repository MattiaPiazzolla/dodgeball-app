// app/layouts/dashboard.vue
<script setup lang="ts">
const { logout } = useAuth();
</script>

<template>
    <div class="min-h-screen flex bg-gray-100">
        <!-- Sidebar -->
        <aside class="w-64 bg-gray-900 text-white flex flex-col">
            <div class="p-6 border-b border-gray-800">
                <h2
                    class="text-xl font-bold tracking-widest text-red-500 uppercase"
                >
                    Portal
                </h2>
            </div>
            <nav class="flex-grow p-4 flex flex-col gap-2">
                <NuxtLink
                    to="/"
                    class="p-3 rounded hover:bg-gray-800 transition"
                    >Return to Site</NuxtLink
                >
            </nav>
            <div class="p-4 border-t border-gray-800">
                <button
                    @click="logout"
                    class="w-full text-left p-3 text-red-400 hover:bg-gray-800 hover:text-red-300 rounded transition font-bold"
                >
                    Logout
                </button>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-grow p-8">
            <slot />
        </main>
    </div>
</template>
