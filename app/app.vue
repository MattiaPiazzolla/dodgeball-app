// app/app.vue
<template>
    <div>
        <NuxtRouteAnnouncer />
        <NuxtLayout>
            <NuxtPage />
        </NuxtLayout>
    </div>
</template>

<style>
:root {
    --ease-organic: cubic-bezier(0.2, 0.8, 0.2, 1);
    --ease-spring: cubic-bezier(0.16, 1, 0.3, 1);
}

html {
    scroll-behavior: smooth;
    -webkit-tap-highlight-color: transparent;
    text-rendering: geometricPrecision;
}

body {
    min-width: 320px;
    background: #f7f7f6;
    color: #0f0f0f;
    overscroll-behavior-y: none;
}

button,
a,
input,
label {
    touch-action: manipulation;
}

button,
a,
label,
.interactive-card {
    transition-duration: 260ms;
    transition-timing-function: var(--ease-organic);
}

button:active,
a:active,
.interactive-card:active {
    transform: scale(0.98);
}

input,
button {
    min-height: 44px;
}

.custom-scrollbar {
    scrollbar-width: thin;
    scrollbar-color: #d1d5db transparent;
}

.custom-scrollbar::-webkit-scrollbar {
    width: 6px;
    height: 6px;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
    background: #d1d5db;
    border-radius: 999px;
}

.mobile-fade-in {
    animation: mobile-fade-in 420ms var(--ease-spring) both;
}

@keyframes mobile-fade-in {
    from {
        opacity: 0;
        transform: translateY(10px) scale(0.98);
    }
    to {
        opacity: 1;
        transform: translateY(0) scale(1);
    }
}

@media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        scroll-behavior: auto !important;
        transition-duration: 0.01ms !important;
    }
}
</style>
