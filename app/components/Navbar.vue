// app/components/Navbar.vue
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useNavbarState } from "~/composables/useNavbarState";

const { user, logout, role, fetchRole } = useAuth();
const { showNavbarTabs, activeSection, registrationsOpen } = useNavbarState();

const isMenuOpen = ref(false);
const showAdminLogin = ref(false);
const longPressTriggered = ref(false);
const brandClickCount = ref(0);
let adminRevealTimer: ReturnType<typeof setTimeout> | null = null;
let brandClickResetTimer: ReturnType<typeof setTimeout> | null = null;

const sections = [
    { id: "live", label: "LIVE IN CORSO", shortLabel: "LIVE", icon: "mdi:access-point" },
    { id: "schedule", label: "CALENDARIO GARE", shortLabel: "GARE", icon: "mdi:calendar-clock" },
    { id: "teams", label: "SQUADRE ISCRITTE", shortLabel: "SQUADRE", icon: "mdi:shield-account" },
];

const hasMobileMenuItems = computed(() => {
    return true;
});

const loadRegistrationSettings = async () => {
    const client = useSupabaseClient();
    const { data } = await client
        .from("app_settings")
        .select("registrations_open")
        .eq("id", 1)
        .single();

    registrationsOpen.value = data?.registrations_open ?? true;
};

const scrollToDashboardSection = (id: string) => {
    activeSection.value = id;
    history.replaceState(null, "", `#${id}`);
    const el = document.getElementById("torneo-dashboard");
    if (el) {
        const offset = 80;
        const bodyRect = document.body.getBoundingClientRect().top;
        const elementRect = el.getBoundingClientRect().top;
        const elementPosition = elementRect - bodyRect;
        const offsetPosition = elementPosition - offset;

        window.scrollTo({
            top: offsetPosition,
            behavior: "smooth"
        });
    }
};

const revealAdminLogin = () => {
    showAdminLogin.value = true;
    longPressTriggered.value = true;
    brandClickCount.value = 0;
    if (brandClickResetTimer) {
        clearTimeout(brandClickResetTimer);
        brandClickResetTimer = null;
    }
};

const startAdminReveal = () => {
    longPressTriggered.value = false;
    if (adminRevealTimer) clearTimeout(adminRevealTimer);

    adminRevealTimer = setTimeout(revealAdminLogin, 3000);
};

const cancelAdminReveal = () => {
    if (adminRevealTimer) {
        clearTimeout(adminRevealTimer);
        adminRevealTimer = null;
    }
};

const handleBrandClick = (event: MouseEvent) => {
    if (longPressTriggered.value) {
        event.preventDefault();
        longPressTriggered.value = false;
        return;
    }

    brandClickCount.value += 1;
    if (brandClickResetTimer) clearTimeout(brandClickResetTimer);
    brandClickResetTimer = setTimeout(() => {
        brandClickCount.value = 0;
    }, 1200);

    if (brandClickCount.value >= 4) {
        event.preventDefault();
        revealAdminLogin();
        longPressTriggered.value = false;
    }
};

const closeMenu = () => {
    isMenuOpen.value = false;
};

const handleLogout = async () => {
    closeMenu();
    await logout();
};

// Re-fetch if user logs in during the session (e.g. navigates to login page)
watch(user, (newUser) => {
    if (newUser) fetchRole();
    else role.value = null;
});

watch(hasMobileMenuItems, (hasItems) => {
    if (!hasItems) closeMenu();
});

onBeforeUnmount(() => {
    cancelAdminReveal();
    if (brandClickResetTimer) clearTimeout(brandClickResetTimer);
});

onMounted(loadRegistrationSettings);
</script>

<template>
    <header
        class="bg-white text-black border-b-4 border-black sticky top-0 z-40 shadow-sm"
    >
        <div
            class="max-w-7xl mx-auto px-4 sm:px-6 py-3 sm:py-4 min-h-[72px] sm:min-h-[auto] flex items-center justify-between"
        >
            <Transition name="navbar-morph" mode="out-in">
                <!-- MORPHED MOBILE TABS VIEW -->
                <div 
                    v-if="showNavbarTabs && !registrationsOpen" 
                    key="morphed-tabs"
                    class="flex items-center justify-between gap-3 w-full sm:hidden min-h-[48px]"
                >
                    <!-- Compact Brand Logo on the left with full text -->
                    <NuxtLink
                        to="/#live"
                        @click="scrollToDashboardSection('live')"
                        class="flex-shrink-0 flex items-center gap-1.5 select-none font-impact text-[13px] tracking-wider text-secondary transition-all hover:text-primary"
                    >
                        <img src="/dodgeballxl-logo.PNG" alt="Dodgeball XL Logo" class="h-6 w-auto object-contain flex-shrink-0" />
                        <span class="inline-block leading-none">
                            DODGEBALL <span class="bg-primary text-white px-1.5 py-0.5 border border-black inline-block transform -skew-x-12 shadow-[1.5px_1.5px_0px_rgba(0,0,0,1)] text-[9px] leading-none">XL</span>
                        </span>
                    </NuxtLink>

                    <!-- Segmented Sporty Tab Controls -->
                    <div class="flex-grow flex items-center justify-end">
                        <div class="flex items-stretch border-2 border-black bg-white shadow-[2px_2px_0px_rgba(0,0,0,1)] overflow-hidden max-w-full">
                            <button
                                v-for="section in sections"
                                :key="section.id"
                                type="button"
                                @click="scrollToDashboardSection(section.id)"
                                class="flex items-center justify-center gap-1 py-1.5 px-2.5 text-[10px] font-impact tracking-widest transition-all cursor-pointer border-r last:border-r-0 border-black select-none !min-h-0 h-9"
                                :class="
                                    activeSection === section.id
                                        ? 'bg-black text-white'
                                        : 'bg-white text-secondary hover:bg-gray-100'
                                "
                            >
                                <span 
                                    v-if="section.id === 'live'" 
                                    class="w-1.5 h-1.5 rounded-full bg-red-600 animate-pulse mr-0.5 inline-block"
                                ></span>
                                <Icon :name="section.icon" class="text-xs flex-shrink-0" />
                                <span>{{ section.shortLabel }}</span>
                            </button>
                        </div>
                    </div>
                </div>

                <!-- DEFAULT VIEW (Desktop, or mobile when not morphed) -->
                <div 
                    v-else 
                    key="default-navbar"
                    class="flex flex-col sm:flex-row sm:items-center justify-between gap-0 sm:gap-4 w-full"
                >
                    <!-- Logo row — always visible -->
                    <div class="flex items-center justify-between gap-3 min-h-[48px]">
                        <NuxtLink
                            to="/#live"
                            @pointerdown="startAdminReveal"
                            @pointerup="cancelAdminReveal"
                            @pointerleave="cancelAdminReveal"
                            @pointercancel="cancelAdminReveal"
                            @click="handleBrandClick"
                            class="font-impact text-xl sm:text-2xl tracking-wider text-secondary transition-all hover:text-primary flex items-center gap-2 select-none"
                        >
                            <img src="/dodgeballxl-logo.PNG" alt="Dodgeball XL Logo" class="h-7 sm:h-9 w-auto object-contain flex-shrink-0" />
                            <span class="inline-block text-base sm:text-xl md:text-2xl">
                                DODGEBALL <span class="bg-primary text-white px-2 py-0.5 border-2 border-black inline-block transform -skew-x-12 shadow-[2px_2px_0px_rgba(0,0,0,1)] text-xs sm:text-sm">XL</span>
                            </span>
                        </NuxtLink>
                        <button
                            v-if="hasMobileMenuItems"
                            type="button"
                            class="sm:hidden inline-flex flex-col h-11 w-11 items-center justify-center gap-[5px] border-2 border-black bg-white text-black transition-all hover:bg-primary hover:text-white active:bg-primary active:text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            :aria-expanded="isMenuOpen"
                            aria-label="Apri menu"
                            @click="isMenuOpen = !isMenuOpen"
                        >
                            <span v-if="!isMenuOpen" class="flex flex-col gap-[5px] items-center justify-center">
                                <span class="block w-5 h-0.5 bg-current transition-all"></span>
                                <span class="block w-5 h-0.5 bg-current transition-all"></span>
                                <span class="block w-5 h-0.5 bg-current transition-all"></span>
                            </span>
                            <span v-else class="relative w-5 h-5 flex items-center justify-center">
                                <span class="absolute block w-5 h-0.5 bg-current rotate-45"></span>
                                <span class="absolute block w-5 h-0.5 bg-current -rotate-45"></span>
                            </span>
                        </button>
                    </div>

                    <!-- Nav — collapses on mobile, horizontal on desktop -->
                    <nav
                        v-if="hasMobileMenuItems"
                        class="grid text-sm transition-all duration-300 sm:flex sm:items-center sm:overflow-x-auto sm:pb-0"
                        :class="
                            isMenuOpen
                                ? 'grid-rows-[1fr] opacity-100 border-t-2 border-black mt-2 sm:border-0 sm:mt-0'
                                : 'grid-rows-[0fr] opacity-0 sm:opacity-100'
                        "
                    >
                        <div
                            class="min-h-0 overflow-hidden sm:overflow-visible flex flex-col sm:flex-row sm:items-center gap-0 sm:gap-3 sm:pt-0"
                        >
                        <ClientOnly>
                            <template v-if="!user">
                                <NuxtLink
                                    to="/login"
                                    @click="closeMenu"
                                    class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 bg-primary text-white font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-black hover:bg-accent sm:hover:-translate-y-0.5 transition-all text-center sm:shadow-[2px_2px_0px_rgba(0,0,0,1)] active:bg-accent"
                                >
                                    {{ registrationsOpen ? "Iscrivi Squadra" : "Area Capitano" }}
                                </NuxtLink>
                                <NuxtLink
                                    v-if="showAdminLogin"
                                    to="/admin/login"
                                    @click="closeMenu"
                                    class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 bg-secondary text-white font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-black hover:bg-gray-800 sm:hover:-translate-y-0.5 transition-all text-center sm:shadow-[2px_2px_0px_rgba(0,0,0,1)] active:bg-gray-800"
                                >
                                    Admin
                                </NuxtLink>
                            </template>
                            <template v-else>
                                <template v-if="role === 'admin'">
                                    <NuxtLink
                                        to="/captain"
                                        @click="closeMenu"
                                        class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 bg-primary text-white font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-black hover:bg-accent sm:hover:-translate-y-0.5 transition-all text-center sm:shadow-[2px_2px_0px_rgba(0,0,0,1)] active:bg-accent"
                                        >La mia squadra</NuxtLink
                                    >
                                    <NuxtLink
                                        to="/admin"
                                        @click="closeMenu"
                                        class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 text-secondary hover:text-primary font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-transparent sm:hover:border-black transition-all text-center"
                                        active-class="bg-black text-white !border-black"
                                        >Admin</NuxtLink
                                    >
                                    <NuxtLink
                                        to="/admin/matches"
                                        @click="closeMenu"
                                        class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 text-secondary hover:text-primary font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-transparent sm:hover:border-black transition-all text-center"
                                        active-class="bg-black text-white !border-black"
                                        >Incontri</NuxtLink
                                    >
                                    <NuxtLink
                                        to="/admin/groups"
                                        @click="closeMenu"
                                        class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 text-secondary hover:text-primary font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-transparent sm:hover:border-black transition-all text-center"
                                        active-class="bg-black text-white !border-black"
                                        >Gironi</NuxtLink
                                    >
                                </template>
                                <template v-else>
                                    <NuxtLink
                                        to="/captain"
                                        @click="closeMenu"
                                        class="flex items-center justify-center min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 bg-primary text-white font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-black hover:bg-accent sm:hover:-translate-y-0.5 transition-all text-center sm:shadow-[2px_2px_0px_rgba(0,0,0,1)] active:bg-accent"
                                        >La mia squadra</NuxtLink
                                    >
                                </template>
                                <button
                                    @click="handleLogout"
                                    class="flex items-center justify-center w-full sm:w-auto min-h-[48px] sm:min-h-[auto] sm:px-4 sm:py-2 px-4 py-3 bg-white text-secondary font-impact tracking-wider uppercase border-x-0 border-b-2 sm:border-2 border-black hover:bg-red-600 hover:text-white transition-all text-center sm:shadow-[2px_2px_0px_rgba(0,0,0,1)] active:bg-red-600 active:text-white"
                                >
                                    Esci
                                </button>
                            </template>
                            <template #fallback></template>
                        </ClientOnly>
                        </div>
                    </nav>
                </div>
            </Transition>
        </div>
    </header>
</template>

<style scoped>
.navbar-morph-enter-active,
.navbar-morph-leave-active {
    transition: opacity 220ms ease, transform 220ms cubic-bezier(0.2, 0.8, 0.2, 1);
}
.navbar-morph-enter-from {
    opacity: 0;
    transform: translateY(-10px);
}
.navbar-morph-leave-to {
    opacity: 0;
    transform: translateY(10px);
}
</style>

