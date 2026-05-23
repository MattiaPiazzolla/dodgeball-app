// app/layouts/default.vue
<template>
    <div class="min-h-screen flex flex-col bg-gray-50">
        <Navbar />

        <main class="flex-grow">
            <slot />
        </main>

        <footer class="bg-gray-900 text-white p-6 text-center">
            <p class="text-sm opacity-75">
                &copy; 2026 Dodgeball Tournament Management
            </p>
        </footer>
    </div>
</template>
