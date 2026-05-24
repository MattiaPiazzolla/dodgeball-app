// app/components/Navbar.vue
<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
const { user, logout, role, fetchRole } = useAuth();

const isMenuOpen = ref(false);
const registrationsOpen = ref(false);
const showAdminLogin = ref(false);
const longPressTriggered = ref(false);
const brandClickCount = ref(0);
let adminRevealTimer: ReturnType<typeof setTimeout> | null = null;
let brandClickResetTimer: ReturnType<typeof setTimeout> | null = null;

const hasMobileMenuItems = computed(() => {
    if (!user.value) {
        return registrationsOpen.value || showAdminLogin.value;
    }

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
        class="bg-white/90 text-black border-b border-gray-100 sticky top-0 z-40 backdrop-blur-xl supports-[backdrop-filter]:bg-white/75"
    >
        <div
            class="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-3"
        >
            <div class="flex items-center justify-between gap-3">
                <NuxtLink
                    to="/#live"
                    @pointerdown="startAdminReveal"
                    @pointerup="cancelAdminReveal"
                    @pointerleave="cancelAdminReveal"
                    @pointercancel="cancelAdminReveal"
                    @click="handleBrandClick"
                    class="text-lg sm:text-xl font-black italic tracking-tight uppercase transition-transform hover:-translate-y-0.5"
                    >Dodgeball Urbania</NuxtLink
                >
                <button
                    v-if="hasMobileMenuItems"
                    type="button"
                    class="sm:hidden inline-flex h-11 w-11 items-center justify-center rounded-full bg-gray-100 text-black transition-all active:scale-95"
                    :aria-expanded="isMenuOpen"
                    aria-label="Apri menu"
                    @click="isMenuOpen = !isMenuOpen"
                >
                    <Icon
                        :name="isMenuOpen ? 'mdi:close' : 'mdi:menu'"
                        class="text-2xl transition-transform"
                        :class="isMenuOpen ? 'rotate-90' : 'rotate-0'"
                    />
                </button>
            </div>
            <nav
                v-if="hasMobileMenuItems"
                class="grid gap-2 text-sm font-black uppercase tracking-wide transition-all duration-300 sm:flex sm:items-center sm:overflow-x-auto"
                :class="
                    isMenuOpen
                        ? 'grid-rows-[1fr] opacity-100'
                        : 'grid-rows-[0fr] opacity-0 sm:opacity-100'
                "
            >
                <div
                    class="min-h-0 overflow-hidden sm:overflow-visible flex flex-col sm:flex-row sm:items-center gap-2"
                >
                <ClientOnly>
                    <template v-if="!user">
                        <NuxtLink
                            v-if="registrationsOpen"
                            to="/login"
                            @click="closeMenu"
                            class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl bg-red-600 text-white hover:bg-red-700 transition-all shadow-sm shadow-red-200"
                        >
                            Capitano
                        </NuxtLink>
                        <NuxtLink
                            v-if="showAdminLogin"
                            to="/admin/login"
                            @click="closeMenu"
                            class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl bg-black text-white hover:bg-gray-800 transition-all"
                        >
                            Admin
                        </NuxtLink>
                    </template>
                    <template v-else>
                        <template v-if="role === 'admin'">
                            <NuxtLink
                                to="/admin"
                                @click="closeMenu"
                                class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl text-gray-500 hover:text-black hover:bg-gray-50 transition-all"
                                active-class="bg-gray-100 text-black"
                                >Admin</NuxtLink
                            >
                            <NuxtLink
                                to="/admin/matches"
                                @click="closeMenu"
                                class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl text-gray-500 hover:text-black hover:bg-gray-50 transition-all"
                                active-class="bg-gray-100 text-black"
                                >Incontri</NuxtLink
                            >
                            <NuxtLink
                                to="/admin/groups"
                                @click="closeMenu"
                                class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl text-gray-500 hover:text-black hover:bg-gray-50 transition-all"
                                active-class="bg-gray-100 text-black"
                                >Gironi</NuxtLink
                            >
                        </template>
                        <template v-else>
                            <NuxtLink
                                v-if="registrationsOpen"
                                to="/captain"
                                @click="closeMenu"
                                class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl bg-red-600 text-white hover:bg-red-700 transition-all shadow-sm shadow-red-200"
                                >La mia squadra</NuxtLink
                            >
                        </template>
                        <button
                            @click="handleLogout"
                            class="px-3 py-3 sm:py-2 rounded-2xl sm:rounded-xl bg-gray-100 text-gray-700 hover:bg-gray-200 transition-all text-left"
                        >
                            Esci
                        </button>
                    </template>
                    <template #fallback></template>
                </ClientOnly>
                </div>
            </nav>
        </div>
    </header>
</template>
