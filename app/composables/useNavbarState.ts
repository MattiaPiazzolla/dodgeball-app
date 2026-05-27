// app/composables/useNavbarState.ts
import { ref } from 'vue';

const showNavbarTabs = ref(false);
const activeSection = ref('live');
const registrationsOpen = ref(true);
const hideNavbar = ref(false);

export function useNavbarState() {
    return {
        showNavbarTabs,
        activeSection,
        registrationsOpen,
        hideNavbar,
    };
}
