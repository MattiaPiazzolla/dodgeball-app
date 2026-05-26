// app/layouts/default.vue
<template>
    <div class="min-h-dvh flex flex-col bg-cement text-black">
        <Navbar />

        <main class="flex-grow">
            <slot />
        </main>

        <footer
            class="bg-secondary border-t-4 border-black text-gray-400 px-4 py-8 pb-[calc(2rem+env(safe-area-inset-bottom))] text-center"
        >
            <div class="max-w-7xl mx-auto space-y-4">
                <div class="font-impact text-xl sm:text-2xl tracking-widest text-primary">
                    DODGEBALL XL
                </div>
                <p class="text-xs uppercase font-bold tracking-wider opacity-60">
                    MEMORIAL LORIS PASSERI &bull; ZONA PRATI, ZONA SPORTIVA
                </p>
                <div class="h-[1px] bg-white/10 max-w-xs mx-auto"></div>
                <p class="text-[10px] uppercase font-bold tracking-widest opacity-40">
                    &copy; 2026 Dodgeball XL. All rights aggressive.
                </p>
            </div>
        </footer>
    </div>
</template>
