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
@import url('https://fonts.googleapis.com/css2?family=Barlow+Condensed:ital,wght@0,400;0,600;0,700;0,800;0,900;1,400;1,700;1,900&display=swap');

:root {
    --primary: #D32F2F;       /* Dodgeball Red */
    --secondary: #1A1A1A;     /* Charcoal */
    --accent: #E65100;        /* Orange Street */
    --background-page: #F4F4F2; /* Cemento Grigio Chiaro */
    --background-dark: #111111; /* Variant Dark Hero */
    --surface: #FFFFFF;
    
    --text-main: #111111;
    --text-inverse: #FFFFFF;
    --text-muted: #666666;

    --ease-organic: cubic-bezier(0.2, 0.8, 0.2, 1);
    --ease-spring: cubic-bezier(0.16, 1, 0.3, 1);
}

html {
    scroll-behavior: smooth;
    -webkit-tap-highlight-color: transparent;
    text-rendering: geometricPrecision;
    -webkit-text-size-adjust: 100%;
}

body {
    min-width: 320px;
    background: var(--background-page);
    color: var(--text-main);
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-weight: 500;
    letter-spacing: normal;
    overscroll-behavior-y: none;
    /* prevent content shift on iOS when address bar hides */
    padding-bottom: env(safe-area-inset-bottom);
}

/* Force aggressive square corners for form items, buttons, and panels */
button,
a,
input,
select,
textarea,
div.card,
.interactive-card,
.modal-content {
    border-radius: 0px !important;
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
select,
button {
    min-height: 44px;
}

/* Concrete Grunge Texture Background Utility */
.bg-cement {
    background-color: var(--background-page);
    background-image: radial-gradient(rgba(0, 0, 0, 0.06) 1px, transparent 0);
    background-size: 16px 16px;
}

/* High-Impact Headings Style */
.font-impact {
    font-family: "Impact", "Barlow Condensed", "Arial Black", sans-serif;
    text-transform: uppercase;
    font-weight: 900;
    letter-spacing: 0.05em;
}

/* Custom Skewed Primary Button (Tilted Sport Look) */
.btn-skewed {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-family: "Impact", "Barlow Condensed", "Arial Black", sans-serif;
    text-transform: uppercase;
    font-weight: 900;
    letter-spacing: 0.06em;
    background-color: var(--primary);
    color: var(--text-inverse) !important;
    border: 2.5px solid var(--secondary);
    border-radius: 0px !important;
    transform: skewX(-6deg);
    transition: all 200ms var(--ease-organic);
    padding: 0.85rem 1.85rem;
    cursor: pointer;
    text-align: center;
    box-shadow: 2px 2px 0px var(--secondary);
}
.btn-skewed:hover {
    transform: skewX(-6deg) scale(1.03);
    background-color: var(--accent);
    box-shadow: 5px 5px 0px var(--secondary);
}
.btn-skewed:active {
    transform: skewX(-6deg) scale(0.97);
}
.btn-skewed-content {
    display: inline-block;
    transform: skewX(6deg); /* Reverse tilt inside so text remains straight and readable */
}

/* Skewed Secondary Button */
.btn-skewed-secondary {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-family: "Impact", "Barlow Condensed", "Arial Black", sans-serif;
    text-transform: uppercase;
    font-weight: 900;
    letter-spacing: 0.06em;
    background-color: transparent;
    color: var(--text-main) !important;
    border: 2.5px solid var(--secondary);
    border-radius: 0px !important;
    transform: skewX(-6deg);
    transition: all 200ms var(--ease-organic);
    padding: 0.85rem 1.85rem;
    cursor: pointer;
    text-align: center;
    box-shadow: 2px 2px 0px var(--secondary);
}
.btn-skewed-secondary:hover {
    transform: skewX(-6deg) scale(1.03);
    background-color: var(--secondary);
    color: var(--text-inverse) !important;
    box-shadow: 5px 5px 0px var(--primary);
}
.btn-skewed-secondary:active {
    transform: skewX(-6deg) scale(0.97);
}

/* White Outline Skewed Button */
.btn-outline-white {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-family: "Impact", "Barlow Condensed", "Arial Black", sans-serif;
    text-transform: uppercase;
    font-weight: 900;
    letter-spacing: 0.06em;
    background-color: transparent;
    color: var(--text-inverse) !important;
    border: 2.5px solid var(--text-inverse);
    border-radius: 0px !important;
    transform: skewX(-6deg);
    transition: all 200ms var(--ease-organic);
    padding: 0.85rem 1.85rem;
    cursor: pointer;
    text-align: center;
    box-shadow: 2px 2px 0px rgba(0,0,0,0.5);
}
.btn-outline-white:hover {
    transform: skewX(-6deg) scale(1.03);
    background-color: var(--text-inverse);
    color: var(--text-main) !important;
    box-shadow: 5px 5px 0px var(--primary);
}
.btn-outline-white:active {
    transform: skewX(-6deg) scale(0.97);
}

/* Card Grunge (Street Pop Flat Hard-Shadow Card) */
.card-grunge {
    border-radius: 0px !important;
    border: 3px solid var(--secondary) !important;
    background: var(--surface);
    box-shadow: 4px 4px 0px var(--secondary) !important;
    transition: all 220ms var(--ease-organic);
}
/* Only lift on real hover-capable devices — avoids sticky hover on mobile */
@media (hover: hover) and (pointer: fine) {
    .card-grunge:hover {
        transform: translate(-3px, -3px);
        box-shadow: 7px 7px 0px var(--primary) !important;
    }
}
/* Touch tap feedback */
.card-grunge:active {
    transform: scale(0.985);
    box-shadow: 2px 2px 0px var(--secondary) !important;
}

/* Food / Info Post-It Sticker */
.sticker-yellow {
    background: #FBC02D; /* Vibrant sticker yellow */
    border: 3px solid var(--secondary);
    border-radius: 0px !important;
    box-shadow: 5px 5px 0px var(--secondary);
    transform: rotate(-2.5deg);
    font-family: "Impact", "Barlow Condensed", sans-serif;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    color: var(--secondary);
    padding: 2rem;
    transition: all 220ms var(--ease-organic);
}
.sticker-yellow:hover {
    transform: rotate(1.5deg) scale(1.04);
    box-shadow: 7px 7px 0px var(--primary);
}

/* Custom Scrollbars */
.custom-scrollbar {
    scrollbar-width: thin;
    scrollbar-color: var(--secondary) transparent;
}

.custom-scrollbar::-webkit-scrollbar {
    width: 8px;
    height: 8px;
}

.custom-scrollbar::-webkit-scrollbar-thumb {
    background: var(--secondary);
    border-radius: 0px;
}

.custom-scrollbar::-webkit-scrollbar-track {
    background: var(--background-page);
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
