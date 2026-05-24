// pages/index.vue
<script setup lang="ts">
const sections = [
    { id: "live", label: "Live", icon: "mdi:access-point" },
    { id: "schedule", label: "Calendario", icon: "mdi:calendar-clock" },
    { id: "teams", label: "Squadre", icon: "mdi:shield-account" },
];

const activeSection = ref("live");
const route = useRoute();

const sectionComponents = {
    live: defineAsyncComponent(
        () => import("~/components/public/PublicLive.vue"),
    ),
    schedule: defineAsyncComponent(
        () => import("~/components/public/PublicSchedule.vue"),
    ),
    teams: defineAsyncComponent(
        () => import("~/components/public/PublicTeams.vue"),
    ),
};

const activeComponent = computed(
    () =>
        sectionComponents[
            activeSection.value as keyof typeof sectionComponents
        ],
);

const scrollToSection = (id: string) => {
    activeSection.value = id;
    history.replaceState(null, "", `#${id}`);
};

const applyHash = (hashValue: string) => {
    const hash = hashValue.replace("#", "");
    if (sections.some((section) => section.id === hash)) {
        activeSection.value = hash;
    }
};

watch(
    () => route.hash,
    (hash) => applyHash(hash),
);

onMounted(() => {
    applyHash(window.location.hash);
});
</script>

<template>
    <div
        class="min-h-screen bg-[#f7f7f6] px-4 py-5 sm:p-8 font-sans pb-24 selection:bg-red-500 selection:text-white"
    >
        <div class="max-w-[1400px] mx-auto space-y-6 sm:space-y-8">
            <section
                class="mobile-fade-in flex flex-col lg:flex-row lg:items-end justify-between gap-6"
            >
                <div class="max-w-2xl">
                    <p
                        class="text-xs font-black uppercase tracking-widest text-red-600 mb-3"
                    >
                        Torneo 2026
                    </p>
                    <h1
                        class="text-4xl sm:text-6xl font-black uppercase tracking-tight text-black leading-none"
                    >
                        Dodgeball<br /><span class="text-red-600">Urbania</span>
                    </h1>
                    <p class="text-gray-500 font-medium mt-4 max-w-xl">
                        Live, calendario, classifiche e squadre in una sola
                        pagina ottimizzata per consultazione rapida da telefono.
                    </p>
                </div>

                <div
                    class="grid grid-cols-3 gap-1 bg-white/80 border border-gray-100 p-1 rounded-3xl shadow-sm backdrop-blur lg:min-w-[430px]"
                >
                    <button
                        v-for="section in sections"
                        :key="section.id"
                        type="button"
                        @click="scrollToSection(section.id)"
                        class="flex flex-col min-[420px]:flex-row items-center justify-center gap-1 min-[420px]:gap-2 rounded-[1.35rem] px-2 py-3 text-[10px] min-[420px]:text-xs font-black uppercase tracking-widest transition-all"
                        :class="
                            activeSection === section.id
                                ? 'bg-black text-white shadow-md'
                                : 'text-gray-400 hover:text-black hover:bg-gray-50'
                        "
                    >
                        <Icon :name="section.icon" class="text-lg" />
                        {{ section.label }}
                    </button>
                </div>
            </section>

            <Transition name="public-panel" mode="out-in">
                <section :key="activeSection" class="min-h-[520px]">
                    <component :is="activeComponent" />
                </section>
            </Transition>
        </div>
    </div>
</template>

<style scoped>
.public-panel-enter-active,
.public-panel-leave-active {
    transition:
        opacity 220ms var(--ease-organic),
        transform 220ms var(--ease-organic);
}

.public-panel-enter-from,
.public-panel-leave-to {
    opacity: 0;
    transform: translateY(8px) scale(0.99);
}
</style>
