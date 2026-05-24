// app/layouts/default.vue
<template>
    <div class="min-h-dvh flex flex-col bg-[#f7f7f6]">
        <Navbar />

        <main class="flex-grow">
            <slot />
        </main>

        <footer
            class="bg-white/80 border-t border-gray-100 text-gray-400 px-4 py-5 pb-[calc(1.25rem+env(safe-area-inset-bottom))] text-center backdrop-blur"
        >
            <p class="text-sm opacity-75">
                Dodgeball Urbania 2026
            </p>
        </footer>
    </div>
</template>
