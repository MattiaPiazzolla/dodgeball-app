<!-- app/components/admin/MatchTeaser.vue -->
<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';

interface Player {
    id: string;
    name: string;
    jersey_number: number | string;
    photo_url?: string;
}

interface Team {
    id: string;
    name: string;
    logo_url?: string;
}

const props = defineProps<{
    match: any;
    team1: Team;
    team2: Team;
    team1Players: Player[];
    team2Players: Player[];
}>();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const rafId = ref<number | null>(null);
const status = ref<'idle' | 'loading' | 'ready' | 'playing' | 'recording' | 'done'>('idle');
const recordProgress = ref(0);

// Exporter settings
const customTitle = ref('DODGEBALL CHAMPIONSHIP');
const customDateTime = ref('STASERA ORE 21:00');
const customVenue = ref('ARENA SPORTIVA CENTRALE');
const team1Color = ref('#D32F2F'); // Dodgeball Red
const team2Color = ref('#E65100'); // Neon Orange
const highBitrate = ref(true);

const duration = 10; // 10 seconds duration
const EXPORT_FPS = 60;
const W = 1080;
const H = 1920;
const SCALE = 1; // Native story resolution keeps Safari/MP4 recording smooth.

// Image preloader cache
const preloadedImages = ref<Record<string, HTMLImageElement>>({});

// Recording chunks
const recordedChunks = ref<Blob[]>([]);
const mediaRecorder = ref<MediaRecorder | null>(null);

// Math helper functions
const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const inv = (v: number, s: number, e: number) => clamp((v - s) / (e - s), 0, 1);

const ease = {
    outExpo: (t: number) => t === 1 ? 1 : 1 - Math.pow(2, -10 * t),
    outQuart: (t: number) => 1 - Math.pow(1 - t, 4),
    inOutSine: (t: number) => -(Math.cos(Math.PI * t) - 1) / 2,
    outCubic: (t: number) => 1 - Math.pow(1 - t, 3),
    spring: (t: number) => {
        if (t === 0 || t === 1) return t;
        return Math.pow(2, -8 * t) * Math.sin((t * 12 - 0.75) * (2 * Math.PI / 3)) + 1;
    },
    outElastic: (t: number) => {
        if (t === 0 || t === 1) return t;
        return Math.pow(2, -10 * t) * Math.sin((t * 10 - 0.75) * (2 * Math.PI / 3)) + 1;
    }
};

const hexToRgb = (hex: string) => {
    const shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
    const fullHex = hex.replace(shorthandRegex, (_, r, g, b) => r + r + g + g + b + b);
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(fullHex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : { r: 128, g: 128, b: 128 };
};

const rgba = (rgb: { r: number; g: number; b: number }, a: number) => `rgba(${rgb.r},${rgb.g},${rgb.b},${a})`;

const rgbToHex = ({ r, g, b }: { r: number; g: number; b: number }) =>
    `#${[r, g, b].map(v => clamp(Math.round(v), 0, 255).toString(16).padStart(2, '0')).join('').toUpperCase()}`;

const rgbToHsl = ({ r, g, b }: { r: number; g: number; b: number }) => {
    const nr = r / 255;
    const ng = g / 255;
    const nb = b / 255;
    const max = Math.max(nr, ng, nb);
    const min = Math.min(nr, ng, nb);
    let h = 0;
    let s = 0;
    const l = (max + min) / 2;

    if (max !== min) {
        const d = max - min;
        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        switch (max) {
            case nr:
                h = (ng - nb) / d + (ng < nb ? 6 : 0);
                break;
            case ng:
                h = (nb - nr) / d + 2;
                break;
            default:
                h = (nr - ng) / d + 4;
        }
        h /= 6;
    }

    return { h, s, l };
};

const hslToRgb = ({ h, s, l }: { h: number; s: number; l: number }) => {
    if (s === 0) {
        const gray = l * 255;
        return { r: gray, g: gray, b: gray };
    }

    const hueToRgb = (p: number, q: number, t: number) => {
        let nt = t;
        if (nt < 0) nt += 1;
        if (nt > 1) nt -= 1;
        if (nt < 1 / 6) return p + (q - p) * 6 * nt;
        if (nt < 1 / 2) return q;
        if (nt < 2 / 3) return p + (q - p) * (2 / 3 - nt) * 6;
        return p;
    };

    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;

    return {
        r: hueToRgb(p, q, h + 1 / 3) * 255,
        g: hueToRgb(p, q, h) * 255,
        b: hueToRgb(p, q, h - 1 / 3) * 255
    };
};

const normalizeTeamColor = (rgb: { r: number; g: number; b: number }) => {
    const hsl = rgbToHsl(rgb);
    return rgbToHex(hslToRgb({
        h: hsl.h,
        s: clamp(Math.max(hsl.s, 0.55), 0, 0.9),
        l: clamp(hsl.l, 0.34, 0.58)
    }));
};

const detectDominantLogoColor = (img: HTMLImageElement, fallback: string) => {
    try {
        const sampleSize = 72;
        const sampleCanvas = document.createElement('canvas');
        sampleCanvas.width = sampleSize;
        sampleCanvas.height = sampleSize;
        const sampleCtx = sampleCanvas.getContext('2d', { willReadFrequently: true });
        if (!sampleCtx) return fallback;

        sampleCtx.clearRect(0, 0, sampleSize, sampleSize);
        sampleCtx.drawImage(img, 0, 0, sampleSize, sampleSize);

        const pixels = sampleCtx.getImageData(0, 0, sampleSize, sampleSize).data;
        const buckets = new Map<string, { rgb: { r: number; g: number; b: number }; score: number }>();

        for (let i = 0; i < pixels.length; i += 4) {
            const alpha = pixels[i + 3];
            if (alpha < 160) continue;

            const rgb = { r: pixels[i], g: pixels[i + 1], b: pixels[i + 2] };
            const hsl = rgbToHsl(rgb);
            if (hsl.s < 0.18 || hsl.l < 0.12 || hsl.l > 0.92) continue;

            const quantized = {
                r: Math.round(rgb.r / 24) * 24,
                g: Math.round(rgb.g / 24) * 24,
                b: Math.round(rgb.b / 24) * 24
            };
            const key = `${quantized.r},${quantized.g},${quantized.b}`;
            const existing = buckets.get(key);
            const score = (0.6 + hsl.s) * (1 - Math.abs(hsl.l - 0.5));

            if (existing) {
                existing.score += score;
            } else {
                buckets.set(key, { rgb: quantized, score });
            }
        }

        const best = [...buckets.values()].sort((a, b) => b.score - a.score)[0];
        return best ? normalizeTeamColor(best.rgb) : fallback;
    } catch (error) {
        console.warn('Unable to detect logo color. Using fallback color.', error);
        return fallback;
    }
};

const drawRoundRect = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) => {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
};

const drawSkewedRect = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, skew: number) => {
    ctx.beginPath();
    ctx.moveTo(x + skew, y);
    ctx.lineTo(x + w + skew, y);
    ctx.lineTo(x + w - skew, y + h);
    ctx.lineTo(x - skew, y + h);
    ctx.closePath();
};

// Image preloading with CORS fallback
const loadImage = (url: string): Promise<HTMLImageElement> => {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.src = url;
        img.onload = () => resolve(img);
        img.onerror = (e) => reject(e);
    });
};

const preloadAssets = async () => {
    status.value = 'loading';
    preloadedImages.value = {};
    const promises: Promise<void>[] = [];

    // Preload Team 1 Logo
    if (props.team1?.logo_url) {
        promises.push(
            loadImage(props.team1.logo_url)
                .then((img) => {
                    preloadedImages.value['t1_logo'] = img;
                    team1Color.value = detectDominantLogoColor(img, '#D32F2F');
                })
                .catch(() => {
                    team1Color.value = '#D32F2F';
                    console.warn('CORS or error loading Team 1 logo. Fallback shield will be generated.');
                })
        );
    } else {
        team1Color.value = '#D32F2F';
    }

    // Preload Team 2 Logo
    if (props.team2?.logo_url) {
        promises.push(
            loadImage(props.team2.logo_url)
                .then((img) => {
                    preloadedImages.value['t2_logo'] = img;
                    team2Color.value = detectDominantLogoColor(img, '#E65100');
                })
                .catch(() => {
                    team2Color.value = '#E65100';
                    console.warn('CORS or error loading Team 2 logo. Fallback shield will be generated.');
                })
        );
    } else {
        team2Color.value = '#E65100';
    }

    // Preload Team 1 Player Photos
    props.team1Players.forEach(p => {
        if (p.photo_url) {
            promises.push(
                loadImage(p.photo_url)
                    .then((img) => { preloadedImages.value[`t1_p_${p.id}`] = img; })
                    .catch(() => console.warn(`CORS/Error loading photo for player ${p.name}`))
            );
        }
    });

    // Preload Team 2 Player Photos
    props.team2Players.forEach(p => {
        if (p.photo_url) {
            promises.push(
                loadImage(p.photo_url)
                    .then((img) => { preloadedImages.value[`t2_p_${p.id}`] = img; })
                    .catch(() => console.warn(`CORS/Error loading photo for player ${p.name}`))
            );
        }
    });

    try {
        await Promise.all(promises);
    } catch (e) {
        console.error('Error preloading some assets, moving forward with shields:', e);
    } finally {
        status.value = 'ready';
        drawStaticFrame();
    }
};

// Draw Fallback Team Shield Logo
const drawShieldLogo = (ctx: CanvasRenderingContext2D, x: number, y: number, size: number, name: string, glowColor: string) => {
    ctx.save();
    ctx.translate(x, y);

    // Dynamic Shield Path
    ctx.beginPath();
    ctx.moveTo(0, -size / 2);
    ctx.lineTo(size * 0.4, -size * 0.4);
    ctx.lineTo(size * 0.45, size * 0.1);
    ctx.quadraticCurveTo(size * 0.45, size * 0.45, 0, size * 0.6);
    ctx.quadraticCurveTo(-size * 0.45, size * 0.45, -size * 0.45, size * 0.1);
    ctx.lineTo(-size * 0.45, -size * 0.45);
    ctx.lineTo(-size * 0.4, -size * 0.4);
    ctx.closePath();

    // Dark Grunge inside shield
    ctx.fillStyle = '#1A1A1A';
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 40;
    ctx.fill();
    ctx.shadowBlur = 0;

    // Skewed inner frame
    ctx.strokeStyle = glowColor;
    ctx.lineWidth = 10;
    ctx.stroke();

    // Draw first letter in high impact bold
    ctx.font = `italic 900 ${size * 0.55}px 'Impact', 'Barlow Condensed', sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText((name || 'X').charAt(0).toUpperCase(), 0, 5);

    ctx.restore();
};

// Draw Fallback Player Photo Badge
const drawPlayerAvatar = (ctx: CanvasRenderingContext2D, x: number, y: number, radius: number, player: Player, glowColor: string, imgKey: string) => {
    ctx.save();
    ctx.translate(x, y);

    // Glowing outer ring
    ctx.beginPath();
    ctx.arc(0, 0, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#1A1A1A';
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 15;
    ctx.fill();

    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 4;
    ctx.stroke();

    // Draw inner crop
    ctx.beginPath();
    ctx.arc(0, 0, radius - 2, 0, Math.PI * 2);
    ctx.clip();

    const img = preloadedImages.value[imgKey];
    if (img) {
        // Draw preloaded image fitted inside circle
        const scale = Math.max((radius * 2) / img.width, (radius * 2) / img.height);
        const w = img.width * scale;
        const h = img.height * scale;
        ctx.drawImage(img, -w / 2, -h / 2, w, h);
    } else {
        // Fallback: draw stylish dark badge with jersey number
        ctx.fillStyle = '#111111';
        ctx.fillRect(-radius, -radius, radius * 2, radius * 2);
        
        ctx.font = `italic 900 ${radius * 0.9}px 'Impact', 'Barlow Condensed', sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = glowColor;
        ctx.fillText(String(player.jersey_number || '#'), 0, 0);
    }

    // Inner glowing ring
    ctx.beginPath();
    ctx.arc(0, 0, radius - 2, 0, Math.PI * 2);
    ctx.strokeStyle = glowColor;
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.restore();

    // Name under badge
    ctx.save();
    ctx.translate(x, y);
    ctx.font = `900 24px 'Barlow Condensed', 'Arial Black', sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    
    // Background plate for name
    const textWidth = ctx.measureText(player.name.toUpperCase()).width + 20;
    ctx.fillStyle = 'rgba(0,0,0,0.85)';
    drawSkewedRect(ctx, -textWidth / 2, radius + 15, textWidth, 38, 5);
    ctx.fill();
    ctx.strokeStyle = glowColor;
    ctx.lineWidth = 1.5;
    ctx.stroke();

    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(player.name.toUpperCase(), 0, radius + 22);
    ctx.restore();
};

// Particles setup
interface StoryParticle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    size: number;
    opacity: number;
    life: number;
    speed: number;
    color: string;
}

const particlesList = ref<StoryParticle[]>([]);

const initStoryParticles = () => {
    particlesList.value = Array.from({ length: 80 }, () => {
        const isTop = Math.random() > 0.5;
        return {
            x: Math.random() * W,
            y: H / 2 + (Math.random() - 0.5) * 300,
            vx: (Math.random() - 0.5) * 1.5,
            vy: (Math.random() - 0.5) * 2 - (isTop ? 1 : -1),
            size: Math.random() * 8 + 3,
            opacity: Math.random() * 0.6 + 0.2,
            life: Math.random(),
            speed: Math.random() * 0.008 + 0.003,
            color: isTop ? team1Color.value : team2Color.value
        };
    });
};

// Animation engine
const animateTimeline = () => {
    const canvas = canvasRef.value;
    if (!canvas) return;
    const ctx = canvas.getContext('2d')!;

    const rgb1 = hexToRgb(team1Color.value);
    const rgb2 = hexToRgb(team2Color.value);

    let startTs: number | null = null;

    const drawFrame = (ts: number) => {
        if (!startTs) startTs = ts;
        const elapsed = (ts - startTs) / 1000;
        recordProgress.value = Math.min(100, Math.floor((elapsed / duration) * 100));

        // Update particles
        particlesList.value.forEach(p => {
            p.x += p.vx;
            p.y += p.vy;
            p.life += p.speed;
            if (p.life > 1 || p.y < 0 || p.y > H) {
                p.x = Math.random() * W;
                p.y = H / 2 + (Math.random() - 0.5) * 100;
                p.life = 0;
                p.opacity = Math.random() * 0.6 + 0.2;
            }
        });

        // Set dimensions & scale for internal high-res
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, W * SCALE, H * SCALE);
        ctx.scale(SCALE, SCALE);

        // ╔══ BASE BG (Sports Dark Cement Grid) ══╗
        ctx.fillStyle = '#0F0F12';
        ctx.fillRect(0, 0, W, H);

        // Draw dynamic grid lines
        ctx.strokeStyle = 'rgba(255,255,255,0.015)';
        ctx.lineWidth = 2;
        const gridGap = 80;
        for (let x = 0; x < W; x += gridGap) {
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
        }
        for (let y = 0; y < H; y += gridGap) {
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
        }

        // Camera Shake effect during transitions
        ctx.save();
        if (elapsed > 1.2 && elapsed < 1.6) {
            const shake = Math.sin(elapsed * 100) * 12 * (1 - inv(elapsed, 1.2, 1.6));
            ctx.translate(shake, shake);
        } else if (elapsed > 4.4 && elapsed < 4.8) {
            const shake = Math.sin(elapsed * 100) * 12 * (1 - inv(elapsed, 4.4, 4.8));
            ctx.translate(shake, shake);
        } else if (elapsed > 7.4 && elapsed < 7.8) {
            const shake = Math.sin(elapsed * 100) * 18 * (1 - inv(elapsed, 7.4, 7.8));
            ctx.translate(shake, shake);
        }

        // ╔══ DYNAMIC TIMELINE PHASE DRIVERS ══╗
        // Slashes divider positions
        // 0-1.5s: Slashes close to center
        // 1.5s-4.5s: Divider moves down (Team 1 Spotlight, Top gets 72%)
        // 4.5s-7.5s: Divider moves up (Team 2 Spotlight, Bottom gets 72%)
        // 7.5s-10.0s: Symmetrical division (50/50)
        let dividerY = H / 2;
        if (elapsed >= 1.5 && elapsed < 4.5) {
            const t = ease.inOutSine(inv(elapsed, 1.5, 2.3));
            dividerY = lerp(H / 2, H * 0.72, t);
        } else if (elapsed >= 4.5 && elapsed < 7.5) {
            const t = ease.inOutSine(inv(elapsed, 4.5, 5.3));
            dividerY = lerp(H * 0.72, H * 0.28, t);
        } else if (elapsed >= 7.5 && elapsed < 8.3) {
            const t = ease.inOutSine(inv(elapsed, 7.5, 8.3));
            dividerY = lerp(H * 0.28, H / 2, t);
        }

        const skewX = 140; // slant offset for a sports diagonal look

        // ╔══ BACKGROUND SOLID SLASH RENDER ══╗
        const introT = ease.outQuart(inv(elapsed, 0.1, 1.2));

        // Team 1 Background (Top Half)
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(W, 0);
        ctx.lineTo(W, dividerY - skewX);
        ctx.lineTo(0, dividerY + skewX);
        ctx.closePath();
        ctx.clip();

        // High saturated radial gradient for Team 1
        const gr1 = ctx.createRadialGradient(W / 2, dividerY / 2, 0, W / 2, dividerY / 2, W * 0.9);
        gr1.addColorStop(0, rgba(rgb1, 0.45 * introT));
        gr1.addColorStop(0.6, rgba(rgb1, 0.15 * introT));
        gr1.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = gr1;
        ctx.fillRect(0, 0, W, dividerY + skewX);
        ctx.restore();

        // Team 2 Background (Bottom Half)
        ctx.save();
        ctx.beginPath();
        ctx.moveTo(0, dividerY + skewX);
        ctx.lineTo(W, dividerY - skewX);
        ctx.lineTo(W, H);
        ctx.lineTo(0, H);
        ctx.closePath();
        ctx.clip();

        // High saturated radial gradient for Team 2
        const gr2 = ctx.createRadialGradient(W / 2, dividerY + (H - dividerY) / 2, 0, W / 2, dividerY + (H - dividerY) / 2, W * 0.9);
        gr2.addColorStop(0, rgba(rgb2, 0.45 * introT));
        gr2.addColorStop(0.6, rgba(rgb2, 0.15 * introT));
        gr2.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = gr2;
        ctx.fillRect(0, dividerY - skewX, W, H - dividerY + skewX);
        ctx.restore();

        // ╔══ DRAGGING GLOW SLASHER ══╗
        if (introT > 0) {
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(0, dividerY + skewX);
            ctx.lineTo(W, dividerY - skewX);
            ctx.strokeStyle = `rgba(255,255,255,${0.85 * introT})`;
            ctx.lineWidth = 14;
            ctx.shadowColor = '#FFFFFF';
            ctx.shadowBlur = 30;
            ctx.stroke();

            // Neon outer sparks on slash
            ctx.beginPath();
            ctx.moveTo(0, dividerY + skewX);
            ctx.lineTo(W, dividerY - skewX);
            ctx.strokeStyle = elapsed > 4.5 && elapsed < 7.5 ? team2Color.value : team1Color.value;
            ctx.lineWidth = 26;
            ctx.globalAlpha = 0.4;
            ctx.stroke();
            ctx.restore();
        }

        // Render particles
        particlesList.value.forEach(p => {
            ctx.save();
            ctx.globalAlpha = p.opacity * Math.sin(p.life * Math.PI);
            ctx.fillStyle = p.color;
            ctx.shadowColor = p.color;
            ctx.shadowBlur = 10;
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        });

        // ╔══ PHASE 1: INTRO IMPACT (0s - 1.5s) ══╗
        if (elapsed < 1.6) {
            const shockT = inv(elapsed, 0.9, 1.5);
            if (shockT > 0 && shockT < 1) {
                ctx.save();
                const ringRadius = lerp(0, W * 1.5, ease.outExpo(shockT));
                const ringAlpha = lerp(1, 0, ease.outCubic(shockT));
                ctx.beginPath();
                ctx.arc(W / 2, H / 2, ringRadius, 0, Math.PI * 2);
                ctx.strokeStyle = `rgba(255,255,255,${ringAlpha})`;
                ctx.lineWidth = lerp(35, 1, shockT);
                ctx.shadowColor = '#FFF';
                ctx.shadowBlur = 20;
                ctx.stroke();
                ctx.restore();
            }
        }

        // ╔══ PHASE 2: TEAM 1 SHOWCASE (1.5s - 4.5s) ══╗
        const t1Focus = inv(elapsed, 1.5, 4.5);
        if (t1Focus > 0 && t1Focus < 1) {
            const intro = ease.spring(inv(elapsed, 1.5, 2.3));
            const outro = ease.outExpo(inv(elapsed, 4.2, 4.5));
            const opacity = (1 - outro) * clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Display Team 1 Large Name (skewed/italic)
            ctx.font = `italic 900 90px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'top';
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = team1Color.value;
            ctx.shadowBlur = 20;
            ctx.fillText(props.team1.name.toUpperCase(), W / 2, 140);
            ctx.shadowBlur = 0;

            // "SQUADRA ORIGINALE" subtitle
            ctx.font = `900 24px 'Barlow Condensed', sans-serif`;
            ctx.fillStyle = team1Color.value;
            ctx.letterSpacing = '10px';
            ctx.fillText('TEAM RED / ROSTER', W / 2 + 5, 240);
            ctx.letterSpacing = '0px';

            // Draw Team 1 Logo
            const logoScale = lerp(0, 1, ease.spring(inv(elapsed, 1.7, 2.5)));
            if (logoScale > 0) {
                const logoSize = 250;
                const lx = W / 2;
                const ly = 410;
                const logoImg = preloadedImages.value['t1_logo'];
                
                if (logoImg) {
                    ctx.save();
                    ctx.translate(lx, ly);
                    ctx.scale(logoScale, logoScale);
                    ctx.beginPath();
                    ctx.arc(0, 0, logoSize / 2, 0, Math.PI * 2);
                    ctx.clip();
                    ctx.drawImage(logoImg, -logoSize / 2, -logoSize / 2, logoSize, logoSize);
                    ctx.strokeStyle = team1Color.value;
                    ctx.lineWidth = 6;
                    ctx.stroke();
                    ctx.restore();
                } else {
                    drawShieldLogo(ctx, lx, ly, logoSize * 1.1, props.team1.name, team1Color.value);
                }
            }

            // Draw Team 1 Roster collages
            // Render first 4 players in a gorgeous glowing row
            const showPlayers = props.team1Players.slice(0, 4);
            showPlayers.forEach((p, idx) => {
                const pIntro = ease.spring(inv(elapsed, 2.1 + idx * 0.15, 2.9 + idx * 0.15));
                if (pIntro > 0) {
                    const radius = 95;
                    const spacing = 240;
                    const totalW = (showPlayers.length - 1) * spacing;
                    const px = W / 2 - totalW / 2 + idx * spacing;
                    const py = 760 + Math.sin(elapsed * 2 + idx) * 8; // gentle float

                    ctx.save();
                    ctx.translate(0, lerp(120, 0, pIntro));
                    ctx.globalAlpha = opacity * pIntro;
                    drawPlayerAvatar(ctx, px, py, radius, p, team1Color.value, `t1_p_${p.id}`);
                    ctx.restore();
                }
            });

            ctx.restore();
        }

        // ╔══ PHASE 3: TEAM 2 SHOWCASE (4.5s - 7.5s) ══╗
        const t2Focus = inv(elapsed, 4.5, 7.5);
        if (t2Focus > 0 && t2Focus < 1) {
            const intro = ease.spring(inv(elapsed, 4.5, 5.3));
            const outro = ease.outExpo(inv(elapsed, 7.2, 7.5));
            const opacity = (1 - outro) * clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Display Team 2 Large Name (skewed/italic)
            ctx.font = `italic 900 90px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'top';
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = team2Color.value;
            ctx.shadowBlur = 20;
            ctx.fillText(props.team2.name.toUpperCase(), W / 2, H - 240);
            ctx.shadowBlur = 0;

            // "SQUADRA SFIDANTE" subtitle
            ctx.font = `900 24px 'Barlow Condensed', sans-serif`;
            ctx.fillStyle = team2Color.value;
            ctx.letterSpacing = '10px';
            ctx.fillText('TEAM ORANGE / ROSTER', W / 2 + 5, H - 320);
            ctx.letterSpacing = '0px';

            // Draw Team 2 Logo
            const logoScale = lerp(0, 1, ease.spring(inv(elapsed, 4.7, 5.5)));
            if (logoScale > 0) {
                const logoSize = 250;
                const lx = W / 2;
                const ly = H - 510;
                const logoImg = preloadedImages.value['t2_logo'];
                
                if (logoImg) {
                    ctx.save();
                    ctx.translate(lx, ly);
                    ctx.scale(logoScale, logoScale);
                    ctx.beginPath();
                    ctx.arc(0, 0, logoSize / 2, 0, Math.PI * 2);
                    ctx.clip();
                    ctx.drawImage(logoImg, -logoSize / 2, -logoSize / 2, logoSize, logoSize);
                    ctx.strokeStyle = team2Color.value;
                    ctx.lineWidth = 6;
                    ctx.stroke();
                    ctx.restore();
                } else {
                    drawShieldLogo(ctx, lx, ly, logoSize * 1.1, props.team2.name, team2Color.value);
                }
            }

            // Draw Team 2 Roster collages
            const showPlayers = props.team2Players.slice(0, 4);
            showPlayers.forEach((p, idx) => {
                const pIntro = ease.spring(inv(elapsed, 5.1 + idx * 0.15, 5.9 + idx * 0.15));
                if (pIntro > 0) {
                    const radius = 95;
                    const spacing = 240;
                    const totalW = (showPlayers.length - 1) * spacing;
                    const px = W / 2 - totalW / 2 + idx * spacing;
                    const py = H - 760 - Math.sin(elapsed * 2 + idx) * 8; // gentle float

                    ctx.save();
                    ctx.translate(0, lerp(-120, 0, pIntro));
                    ctx.globalAlpha = opacity * pIntro;
                    drawPlayerAvatar(ctx, px, py, radius, p, team2Color.value, `t2_p_${p.id}`);
                    ctx.restore();
                }
            });

            ctx.restore();
        }

        // ╔══ PHASE 4: CLIMAX SHOWDOWN (7.5s - 10.0s) ══╗
        const showdownT = inv(elapsed, 7.5, 10.0);
        if (showdownT > 0) {
            const intro = ease.spring(inv(elapsed, 7.5, 8.4));
            const opacity = clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Draw Team 1 Logo (Left Side Zoomed)
            const t1LogoImg = preloadedImages.value['t1_logo'];
            const t1Lx = W * 0.28;
            const t1Ly = H * 0.35 + Math.sin(elapsed * 2) * 5;
            if (t1LogoImg) {
                ctx.save();
                ctx.translate(t1Lx, t1Ly);
                ctx.scale(intro, intro);
                ctx.beginPath();
                ctx.arc(0, 0, 140, 0, Math.PI * 2);
                ctx.clip();
                ctx.drawImage(t1LogoImg, -140, -140, 280, 280);
                ctx.strokeStyle = team1Color.value;
                ctx.lineWidth = 8;
                ctx.stroke();
                ctx.restore();
            } else {
                drawShieldLogo(ctx, t1Lx, t1Ly, 280, props.team1.name, team1Color.value);
            }

            // Draw Team 2 Logo (Right Side Zoomed)
            const t2LogoImg = preloadedImages.value['t2_logo'];
            const t2Lx = W * 0.72;
            const t2Ly = H * 0.35 - Math.sin(elapsed * 2) * 5;
            if (t2LogoImg) {
                ctx.save();
                ctx.translate(t2Lx, t2Ly);
                ctx.scale(intro, intro);
                ctx.beginPath();
                ctx.arc(0, 0, 140, 0, Math.PI * 2);
                ctx.clip();
                ctx.drawImage(t2LogoImg, -140, -140, 280, 280);
                ctx.strokeStyle = team2Color.value;
                ctx.lineWidth = 8;
                ctx.stroke();
                ctx.restore();
            } else {
                drawShieldLogo(ctx, t2Lx, t2Ly, 280, props.team2.name, team2Color.value);
            }

            // Render Team names below logos
            ctx.font = `italic 900 56px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = team1Color.value;
            ctx.shadowBlur = 10;
            ctx.fillText(props.team1.name.toUpperCase(), t1Lx, H * 0.35 + 200);

            ctx.shadowColor = team2Color.value;
            ctx.fillText(props.team2.name.toUpperCase(), t2Lx, H * 0.35 + 200);
            ctx.shadowBlur = 0;

            // Custom Tournament Stage Header
            ctx.font = `italic 900 64px 'Impact', sans-serif`;
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = '#000';
            ctx.shadowBlur = 15;
            ctx.fillText(customTitle.value.toUpperCase(), W / 2, H * 0.16 + Math.sin(elapsed * 4) * 4);

            // ╔══ SKY-HIGH GLOWING VS BADGE ══╗
            const vsScale = lerp(3, 1, ease.spring(inv(elapsed, 7.7, 8.4))) * (1 + Math.sin(elapsed * 8) * 0.05);
            ctx.save();
            ctx.translate(W / 2, H * 0.35);
            ctx.scale(vsScale, vsScale);
            
            // Outer glowing dark badge
            ctx.fillStyle = '#060409';
            ctx.strokeStyle = '#FFFFFF';
            ctx.lineWidth = 6;
            ctx.shadowColor = '#FFF';
            ctx.shadowBlur = 30;
            drawRoundRect(ctx, -90, -90, 180, 180, 20);
            ctx.fill();
            ctx.stroke();
            ctx.shadowBlur = 0;

            ctx.font = `italic 900 90px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            
            // Bi-color VS text
            const grd = ctx.createLinearGradient(-50, 0, 50, 0);
            grd.addColorStop(0, team1Color.value);
            grd.addColorStop(1, team2Color.value);
            ctx.fillStyle = grd;
            ctx.fillText('VS', 0, 4);
            ctx.restore();

            // ╔══ BOTTOM METADATA BADGES ══╗
            const cardIntro = ease.spring(inv(elapsed, 8.0, 8.8));
            if (cardIntro > 0) {
                ctx.save();
                ctx.translate(0, lerp(150, 0, cardIntro));
                ctx.globalAlpha = opacity * cardIntro;

                // DateTime Skewed Badge
                const boxW = 860;
                const boxH = 110;
                const bx = W / 2 - boxW / 2;
                const by = H * 0.65;

                ctx.fillStyle = '#111111';
                ctx.strokeStyle = '#FFFFFF';
                ctx.lineWidth = 4;
                ctx.shadowColor = 'rgba(0,0,0,0.5)';
                ctx.shadowBlur = 20;
                drawSkewedRect(ctx, bx, by, boxW, boxH, 15);
                ctx.fill();
                ctx.stroke();
                ctx.shadowBlur = 0;

                ctx.font = `italic 900 50px 'Impact', sans-serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillStyle = '#FFFFFF';
                ctx.fillText(customDateTime.value.toUpperCase(), W / 2, by + boxH / 2 + 3);

                // Venue / Location Sub-badge
                const subBoxW = 740;
                const subBoxH = 80;
                const sbx = W / 2 - subBoxW / 2;
                const sby = H * 0.74;

                ctx.fillStyle = '#1E1E1E';
                ctx.strokeStyle = team2Color.value;
                ctx.lineWidth = 3;
                drawSkewedRect(ctx, sbx, sby, subBoxW, subBoxH, 10);
                ctx.fill();
                ctx.stroke();

                ctx.font = `900 32px 'Barlow Condensed', sans-serif`;
                ctx.fillStyle = team2Color.value;
                ctx.fillText(customVenue.value.toUpperCase(), W / 2, sby + subBoxH / 2 + 2);

                // HYPE SUB-CTA
                ctx.font = `italic 900 42px 'Impact', sans-serif`;
                ctx.fillStyle = '#FFFFFF';
                ctx.shadowColor = team1Color.value;
                ctx.shadowBlur = 10;
                ctx.fillText('NON MANCARE! 🔥 CHOOSE YOUR TEAM! 👇', W / 2, H * 0.86);

                ctx.restore();
            }

            ctx.restore();
        }

        // ╔══ PROGRESS BAR OVERLAY ══╗
        const prg = clamp(elapsed / duration, 0, 1);
        ctx.fillStyle = 'rgba(255,255,255,0.06)';
        ctx.fillRect(0, H - 12, W, 12);
        
        const pbGrd = ctx.createLinearGradient(0, 0, W * prg, 0);
        pbGrd.addColorStop(0, team1Color.value);
        pbGrd.addColorStop(1, team2Color.value);
        ctx.fillStyle = pbGrd;
        ctx.fillRect(0, H - 12, W * prg, 12);

        // ╔══ OUTRO BLACK FADE (9s - 10s) ══╗
        if (elapsed > duration - 1.0) {
            const fade = ease.inOutSine(inv(elapsed, duration - 1.0, duration));
            ctx.fillStyle = `rgba(15,15,18,${fade})`;
            ctx.fillRect(0, 0, W, H);
        }

        ctx.restore();

        // Halt recording if elapsed duration is hit
        if (elapsed >= duration) {
            stopAnimation();
            status.value = 'done';
            if (mediaRecorder.value && mediaRecorder.value.state === 'recording') {
                mediaRecorder.value.stop();
            }
            return;
        }

        rafId.value = requestAnimationFrame(drawFrame);
    };

    if (rafId.value) cancelAnimationFrame(rafId.value);
    rafId.value = requestAnimationFrame(drawFrame);
};

// Static Preview Loader
const drawStaticFrame = () => {
    const canvas = canvasRef.value;
    if (!canvas || status.value !== 'ready') return;
    const ctx = canvas.getContext('2d')!;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, W * SCALE, H * SCALE);
    ctx.scale(SCALE, SCALE);

    // Dark Background Grid
    ctx.fillStyle = '#0F0F12';
    ctx.fillRect(0, 0, W, H);

    ctx.strokeStyle = 'rgba(255,255,255,0.015)';
    ctx.lineWidth = 2;
    const gridGap = 80;
    for (let x = 0; x < W; x += gridGap) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
    }
    for (let y = 0; y < H; y += gridGap) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
    }

    // Split background colors
    const skewX = 140;
    const dividerY = H / 2;
    
    // Top Team background
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(0, 0); ctx.lineTo(W, 0); ctx.lineTo(W, dividerY - skewX); ctx.lineTo(0, dividerY + skewX);
    ctx.closePath(); ctx.clip();
    const gr1 = ctx.createRadialGradient(W/2, dividerY/2, 0, W/2, dividerY/2, W * 0.9);
    gr1.addColorStop(0, rgba(hexToRgb(team1Color.value), 0.35));
    gr1.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gr1; ctx.fillRect(0, 0, W, dividerY + skewX);
    ctx.restore();

    // Bottom Team background
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(0, dividerY + skewX); ctx.lineTo(W, dividerY - skewX); ctx.lineTo(W, H); ctx.lineTo(0, H);
    ctx.closePath(); ctx.clip();
    const gr2 = ctx.createRadialGradient(W/2, dividerY + (H-dividerY)/2, 0, W/2, dividerY + (H-dividerY)/2, W * 0.9);
    gr2.addColorStop(0, rgba(hexToRgb(team2Color.value), 0.35));
    gr2.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gr2; ctx.fillRect(0, dividerY - skewX, W, H - dividerY + skewX);
    ctx.restore();

    // Division glowing slash
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(0, dividerY + skewX); ctx.lineTo(W, dividerY - skewX);
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 14;
    ctx.shadowColor = '#FFFFFF';
    ctx.shadowBlur = 25;
    ctx.stroke();
    ctx.restore();

    // Draw Team 1 Logo Left / Team 2 Logo Right
    const t1LogoImg = preloadedImages.value['t1_logo'];
    const t1Lx = W * 0.28;
    const t1Ly = H * 0.35;
    if (t1LogoImg) {
        ctx.save();
        ctx.translate(t1Lx, t1Ly);
        ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
        ctx.drawImage(t1LogoImg, -140, -140, 280, 280);
        ctx.strokeStyle = team1Color.value; ctx.lineWidth = 8; ctx.stroke();
        ctx.restore();
    } else {
        drawShieldLogo(ctx, t1Lx, t1Ly, 280, props.team1.name, team1Color.value);
    }

    const t2LogoImg = preloadedImages.value['t2_logo'];
    const t2Lx = W * 0.72;
    const t2Ly = H * 0.35;
    if (t2LogoImg) {
        ctx.save();
        ctx.translate(t2Lx, t2Ly);
        ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
        ctx.drawImage(t2LogoImg, -140, -140, 280, 280);
        ctx.strokeStyle = team2Color.value; ctx.lineWidth = 8; ctx.stroke();
        ctx.restore();
    } else {
        drawShieldLogo(ctx, t2Lx, t2Ly, 280, props.team2.name, team2Color.value);
    }

    // Text "VS" in the middle
    ctx.save();
    ctx.translate(W / 2, H * 0.35);
    ctx.fillStyle = '#060409';
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 6;
    ctx.shadowColor = '#FFF';
    ctx.shadowBlur = 20;
    drawRoundRect(ctx, -90, -90, 180, 180, 20);
    ctx.fill(); ctx.stroke();
    ctx.shadowBlur = 0;

    ctx.font = `italic 900 90px 'Impact', sans-serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    const grd = ctx.createLinearGradient(-50, 0, 50, 0);
    grd.addColorStop(0, team1Color.value);
    grd.addColorStop(1, team2Color.value);
    ctx.fillStyle = grd;
    ctx.fillText('VS', 0, 4);
    ctx.restore();

    // Roster preview text
    ctx.font = `italic 900 48px 'Impact', sans-serif`;
    ctx.textAlign = 'center';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(props.team1.name.toUpperCase(), t1Lx, H * 0.35 + 200);
    ctx.fillText(props.team2.name.toUpperCase(), t2Lx, H * 0.35 + 200);

    // Championship & Info Overlay Preview
    ctx.font = `italic 900 64px 'Impact', sans-serif`;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(customTitle.value.toUpperCase(), W / 2, H * 0.16);

    const boxW = 860, boxH = 110;
    const bx = W / 2 - boxW / 2, by = H * 0.65;
    ctx.fillStyle = '#111111'; ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 4;
    drawSkewedRect(ctx, bx, by, boxW, boxH, 15);
    ctx.fill(); ctx.stroke();

    ctx.font = `italic 900 50px 'Impact', sans-serif`;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(customDateTime.value.toUpperCase(), W / 2, by + boxH / 2 + 3);

    const subBoxW = 740, subBoxH = 80;
    const sbx = W / 2 - subBoxW / 2, sby = H * 0.74;
    ctx.fillStyle = '#1E1E1E'; ctx.strokeStyle = team2Color.value; ctx.lineWidth = 3;
    drawSkewedRect(ctx, sbx, sby, subBoxW, subBoxH, 10);
    ctx.fill(); ctx.stroke();

    ctx.font = `900 32px 'Barlow Condensed', sans-serif`;
    ctx.fillStyle = team2Color.value;
    ctx.fillText(customVenue.value.toUpperCase(), W / 2, sby + subBoxH / 2 + 2);
};

// Controls triggers
const stopAnimation = () => {
    if (rafId.value) {
        cancelAnimationFrame(rafId.value);
        rafId.value = null;
    }
};

const handlePreview = () => {
    if (status.value === 'loading' || status.value === 'playing' || status.value === 'recording') return;
    initStoryParticles();
    status.value = 'playing';
    animateTimeline();
};

const getSupportedVideoMimeType = () => {
    const candidates = [
        'video/mp4;codecs=avc1.42E01E',
        'video/mp4;codecs=avc1',
        'video/mp4;codecs=h264',
        'video/mp4',
        'video/webm;codecs=vp9',
        'video/webm;codecs=vp8',
        'video/webm'
    ];

    return candidates.find(type => MediaRecorder.isTypeSupported(type)) || '';
};

const handleRecord = () => {
    if (status.value === 'loading' || status.value === 'playing' || status.value === 'recording') return;
    const canvas = canvasRef.value;
    if (!canvas) return;

    recordedChunks.value = [];
    initStoryParticles();
    status.value = 'recording';
    recordProgress.value = 0;

    // Use WebRTC Stream
    const stream = canvas.captureStream(EXPORT_FPS);
    const mimeType = getSupportedVideoMimeType();

    const bps = highBitrate.value ? 24000000 : 10000000;
    const recorderOptions: MediaRecorderOptions = {
        videoBitsPerSecond: bps
    };

    if (mimeType) {
        recorderOptions.mimeType = mimeType;
    }

    const recorder = new MediaRecorder(stream, recorderOptions);

    mediaRecorder.value = recorder;

    recorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
            recordedChunks.value.push(event.data);
        }
    };

    recorder.onstop = () => {
        stream.getTracks().forEach(track => track.stop());

        const blobType = mimeType || recordedChunks.value[0]?.type || 'video/mp4';
        const blob = new Blob(recordedChunks.value, { type: blobType });
        const fileExt = blobType.includes('mp4') ? 'mp4' : 'webm';
        const url = URL.createObjectURL(blob);
        
        // Dynamic download trigger
        const a = document.createElement('a');
        a.href = url;
        const matchTitle = `${props.team1.name}-vs-${props.team2.name}`.toLowerCase().replace(/\s+/g, '-');
        a.download = `teaser-story-${matchTitle}.${fileExt}`;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        
        setTimeout(() => {
            URL.revokeObjectURL(url);
            a.remove();
        }, 30000);
        status.value = 'ready';
        drawStaticFrame();
    };

    // Tiny timeout to align audio/canvas triggers if necessary
    setTimeout(() => {
        recorder.start();
        animateTimeline();
    }, 100);
};

// Pre-load on mount
onMounted(() => {
    preloadAssets();
});

// React on changes to update the live preview static image
watch([team1Color, team2Color, customTitle, customDateTime, customVenue], () => {
    if (status.value === 'ready') {
        drawStaticFrame();
    }
});

// Reload assets when teams or player lists resolve asynchronously
watch(() => [props.team1, props.team2, props.team1Players, props.team2Players], () => {
    preloadAssets();
}, { deep: true });

onUnmounted(() => {
    stopAnimation();
});
</script>

<template>
    <div class="card-grunge bg-white p-6 md:p-8 space-y-8 border-4 border-black shadow-[8px_8px_0px_rgba(0,0,0,1)]">
        
        <!-- Header -->
        <div class="border-b-4 border-black pb-4 flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
            <div>
                <span class="bg-black text-white text-xs font-impact px-3 py-1 tracking-widest uppercase mb-1 inline-block">Insta Story Tool</span>
                <h2 class="text-3xl font-impact tracking-wider text-black uppercase">Generatore Teaser Verticale 9:16</h2>
                <p class="text-gray-600 text-sm font-semibold">Crea un video di presentazione fluido per le tue storie di Instagram o TikTok.</p>
            </div>
            
            <div class="flex items-center gap-2">
                <span class="inline-block w-3.5 h-3.5 rounded-full"
                    :class="{
                        'bg-red-500 animate-pulse': status === 'recording',
                        'bg-blue-500 animate-pulse': status === 'playing',
                        'bg-green-500': status === 'ready',
                        'bg-gray-400': status === 'loading'
                    }"
                />
                <span class="font-impact text-sm text-black tracking-widest uppercase">
                    {{ status === 'loading' ? 'CARICAMENTO IMMAGINI...' : 
                       status === 'playing' ? 'PLAYING PREVIEW...' : 
                       status === 'recording' ? `RECORDING ${recordProgress}%` : 'PRONTO PER ESPORTAZIONE' }}
                </span>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            
            <!-- Canvas Preview Area (Col 5) -->
            <div class="lg:col-span-5 flex flex-col items-center justify-center space-y-4">
                <div class="relative w-full max-w-[340px] aspect-[9/16] bg-black border-4 border-black shadow-[8px_8px_0px_rgba(0,0,0,1)] overflow-hidden">
                    <canvas
                        ref="canvasRef"
                        :width="W * SCALE"
                        :height="H * SCALE"
                        class="w-full h-full block"
                    />
                    
                    <!-- Recording Overlay Badges -->
                    <div v-if="status === 'recording'" class="absolute inset-0 bg-red-600/10 pointer-events-none border-4 border-red-600 animate-pulse" />
                    <div v-if="status === 'recording'" class="absolute top-4 left-4 bg-black border-2 border-red-500 px-3 py-1 flex items-center gap-2 shadow-md">
                        <span class="w-2.5 h-2.5 rounded-full bg-red-600 animate-ping shadow-[0_0_8px_rgba(239,68,68,1)]" />
                        <span class="font-impact text-xs text-red-500 tracking-wider">REC MP4 ({{ recordProgress }}%)</span>
                    </div>

                    <!-- Watermark Info Tip -->
                    <div v-if="status === 'playing'" class="absolute bottom-4 left-0 right-0 text-center pointer-events-none">
                        <span class="bg-black/80 px-4 py-1 text-white text-xs font-semibold uppercase tracking-widest">Anteprima Video (10s)</span>
                    </div>
                </div>

                <div class="flex gap-4 w-full max-w-[340px]">
                    <button
                        @click="handlePreview"
                        :disabled="status === 'loading' || status === 'playing' || status === 'recording'"
                        class="btn-skewed-secondary flex-1 !bg-white text-black"
                    >
                        <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                            <Icon name="mdi:play" /> {{ status === 'playing' ? 'RIPRODUZIONE' : 'AVVIA ANTEPRIMA' }}
                        </span>
                    </button>
                    
                    <button
                        @click="handleRecord"
                        :disabled="status === 'loading' || status === 'playing' || status === 'recording'"
                        class="btn-skewed flex-1 !bg-primary text-white border-2 border-black"
                    >
                        <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                            <Icon name="mdi:video" /> {{ status === 'recording' ? 'CREAZIONE...' : 'ESPORTA VIDEO' }}
                        </span>
                    </button>
                </div>
            </div>

            <!-- Customizer Controls Area (Col 7) -->
            <div class="lg:col-span-7 space-y-6">
                <h3 class="text-xl font-impact tracking-widest text-black border-b-2 border-black pb-2">PERSONALIZZA TEASER STORY</h3>
                
                <!-- Auto Color Theme -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div class="p-4 border-2 border-black bg-cement space-y-2">
                        <label class="block font-impact text-xs tracking-wider text-black">{{ team1.name.toUpperCase() }} LOGO COLOR</label>
                        <div class="flex items-center gap-3">
                            <span
                                class="w-10 h-10 border-2 border-black shadow-[3px_3px_0px_rgba(0,0,0,1)]"
                                :style="{ backgroundColor: team1Color }"
                            />
                            <span class="flex-1 px-3 py-2 text-sm border-2 border-black font-semibold uppercase text-black bg-white">
                                {{ team1Color }}
                            </span>
                        </div>
                    </div>

                    <div class="p-4 border-2 border-black bg-cement space-y-2">
                        <label class="block font-impact text-xs tracking-wider text-black">{{ team2.name.toUpperCase() }} LOGO COLOR</label>
                        <div class="flex items-center gap-3">
                            <span
                                class="w-10 h-10 border-2 border-black shadow-[3px_3px_0px_rgba(0,0,0,1)]"
                                :style="{ backgroundColor: team2Color }"
                            />
                            <span class="flex-1 px-3 py-2 text-sm border-2 border-black font-semibold uppercase text-black bg-white">
                                {{ team2Color }}
                            </span>
                        </div>
                    </div>
                </div>

                <!-- Text Customizer -->
                <div class="space-y-4">
                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black">TITOLO / CATEGORIA</label>
                        <input
                            type="text"
                            v-model="customTitle"
                            placeholder="es. FINALE CAMPIONATO"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>

                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black">DATA & ORA DI GIOCO</label>
                        <input
                            type="text"
                            v-model="customDateTime"
                            placeholder="es. STASERA ORE 21:00"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>

                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black">ARENA / PALAZZETTO</label>
                        <input
                            type="text"
                            v-model="customVenue"
                            placeholder="es. PALAZZETTO COMUNALE"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>
                </div>

                <!-- Tips & Notes -->
                <div class="border-l-4 border-accent p-4 bg-orange-50 space-y-2">
                    <h4 class="font-impact text-sm text-accent tracking-widest flex items-center gap-1.5">
                        <Icon name="mdi:information-outline" class="text-lg" /> NOTA SULL'ESPORTAZIONE
                    </h4>
                    <p class="text-xs text-gray-700 font-semibold leading-relaxed">
                        L'esportazione genera un file video <strong>.mp4</strong> quando il browser lo supporta, incluso Safari; sugli altri browser usa il formato video migliore disponibile.
                        Una volta scaricato, puoi caricarlo direttamente nelle tue storie. La musica può essere aggiunta al teaser post-download direttamente dall'app di Instagram!
                    </p>
                </div>

                <!-- Export Quality Settings -->
                <div class="flex items-center gap-3 p-3 bg-cement border-2 border-black">
                    <input 
                        type="checkbox" 
                        id="highBitrate" 
                        v-model="highBitrate"
                        class="w-5 h-5 cursor-pointer accent-black"
                    />
                    <label for="highBitrate" class="font-impact text-xs tracking-wider text-black cursor-pointer uppercase select-none">
                        ATTIVA BITRATE ALTO (24 Mbps - QUALITÀ MASSIMA)
                    </label>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
/* Inline styling classes for high-performance controls */
input {
    border-radius: 0px !important;
}
</style>
