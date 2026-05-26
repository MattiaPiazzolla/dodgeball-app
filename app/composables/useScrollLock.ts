import { ref, onBeforeUnmount } from 'vue';

// Global counter of currently open modals across the entire app
const activeModalsCount = ref(0);

export function useScrollLock() {
    let isLockedByMe = false;

    const lock = () => {
        if (!isLockedByMe) {
            activeModalsCount.value++;
            isLockedByMe = true;
            if (activeModalsCount.value === 1 && typeof document !== 'undefined') {
                document.body.classList.add('overflow-hidden');
            }
        }
    };

    const unlock = () => {
        if (isLockedByMe) {
            activeModalsCount.value = Math.max(0, activeModalsCount.value - 1);
            isLockedByMe = false;
            if (activeModalsCount.value === 0 && typeof document !== 'undefined') {
                document.body.classList.remove('overflow-hidden');
            }
        }
    };

    // Auto-cleanup on component unmount
    onBeforeUnmount(() => {
        unlock();
    });

    return {
        lock,
        unlock
    };
}
