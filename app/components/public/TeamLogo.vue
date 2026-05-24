<script setup lang="ts">
defineProps<{
    src?: string | null;
    alt?: string;
    sizeClass?: string;
    iconClass?: string;
}>();
</script>

<template>
    <div
        class="rounded-full bg-gray-50 border border-gray-100 flex items-center justify-center text-gray-300 overflow-hidden shrink-0 shadow-sm"
        :class="sizeClass || 'w-10 h-10'"
    >
        <img
            v-if="src"
            :src="src"
            :alt="alt || 'Team logo'"
            class="w-full h-full object-cover"
        />
        <Icon
            v-else
            name="mdi:shield-account"
            :class="iconClass || 'text-xl'"
        />
    </div>
</template>
