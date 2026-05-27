<!-- app/components/admin/MvpPodiumTeaser.vue -->
<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';

interface Player {
    id: string;
    name: string;
    nickname?: string;
    jersey_number?: number | string;
    photo_url?: string;
    mvp_votes: number;
    team_id: string;
}

interface Team {
    id: string;
    name: string;
    logo_url?: string;
}

const props = defineProps<{
    topPlayers: Player[];
    teams: Team[];
}>();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const rafId = ref<number | null>(null);
const status = ref<'idle' | 'loading' | 'ready' | 'playing' | 'recording' | 'done'>('idle');
const recordProgress = ref(0);

// Customizer parameters
const customTitle = ref('PODIO MVP');
const customSubtitle = ref('CLASSIFICA FINALE');
const customEvent = ref('DODGEBALL XL 2026');
const goldGlow = ref('#FFD700'); // Gold Glow
const silverGlow = ref('#C0C0C0'); // Silver Glow
const bronzeGlow = ref('#CD7F32'); // Bronze Glow
const highBitrate = ref(true);

const duration = 11.3;
const outroDuration = 3.15;
const W = 1080;
const H = 1920;
const SCALE = 2; // High-definition supersampled output resolution
const brandRed = '#D32F2F';
const deepRed = '#8E1515';
const softRed = '#F05A5A';
const cement = '#F4F4F2';
const charcoal = '#111111';

const preloadedImages = ref<Record<string, HTMLImageElement>>({});
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
    outBackSoft: (t: number) => {
        const c1 = 0.9;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2);
    },
    organic: (t: number) => {
        const eased = t < 0.5
            ? 4 * t * t * t
            : 1 - Math.pow(-2 * t + 2, 3) / 2;
        return clamp(eased + Math.sin(t * Math.PI) * 0.028 - Math.sin(t * Math.PI * 2) * 0.012, 0, 1);
    },
    anticipate: (t: number, amount = 0.12) => {
        if (t < 0.22) {
            const pull = t / 0.22;
            return -amount * Math.sin(pull * Math.PI);
        }
        const normalized = (t - 0.22) / 0.78;
        return ease.organic(clamp(normalized, 0, 1));
    },
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
    } : { r: 255, g: 215, b: 0 };
};

const drawSkewedRect = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, skew: number) => {
    ctx.beginPath();
    ctx.moveTo(x + skew, y);
    ctx.lineTo(x + w + skew, y);
    ctx.lineTo(x + w - skew, y + h);
    ctx.lineTo(x - skew, y + h);
    ctx.closePath();
};

const drawImageCover = (
    ctx: CanvasRenderingContext2D,
    img: HTMLImageElement,
    x: number,
    y: number,
    w: number,
    h: number
) => {
    const scale = Math.max(w / img.width, h / img.height);
    const sw = w / scale;
    const sh = h / scale;
    const sx = (img.width - sw) / 2;
    const sy = (img.height - sh) / 2;
    ctx.drawImage(img, sx, sy, sw, sh, x, y, w, h);
};

const drawImageContain = (
    ctx: CanvasRenderingContext2D,
    img: HTMLImageElement,
    x: number,
    y: number,
    w: number,
    h: number
) => {
    const scale = Math.min(w / img.width, h / img.height);
    const dw = img.width * scale;
    const dh = img.height * scale;
    ctx.drawImage(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh);
};

const getTeamName = (id: string | null) =>
    props.teams.find((t) => t.id === id)?.name || "Unknown";
const getTeamLogo = (id: string | null) =>
    props.teams.find((t) => t.id === id)?.logo_url || null;

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
    const promises: Promise<void>[] = [
        loadImage('/dodgeballxl-logo.PNG')
            .then((img) => { preloadedImages.value.logo = img; })
            .catch(() => console.warn('CORS/Error loading Dodgeball XL logo'))
    ];

    // Preload Roster Photos for top 3
    props.topPlayers.slice(0, 3).forEach((p, idx) => {
        if (p.photo_url) {
            promises.push(
                loadImage(p.photo_url)
                    .then((img) => { preloadedImages.value[`p_${p.id}`] = img; })
                    .catch(() => console.warn(`CORS/Error loading photo for player ${p.name}`))
            );
        }
        const logo = getTeamLogo(p.team_id);
        if (logo) {
            promises.push(
                loadImage(logo)
                    .then((img) => { preloadedImages.value[`logo_${p.team_id}`] = img; })
                    .catch(() => console.warn(`CORS/Error loading team logo for player ${p.name}`))
            );
        }
    });

    try {
        await Promise.all(promises);
    } catch (e) {
        console.error('Error preloading some MVP podium assets:', e);
    } finally {
        status.value = 'ready';
        drawStaticFrame();
    }
};

const drawPlayerFallback = (ctx: CanvasRenderingContext2D, x: number, y: number, r: number, name: string, jersey: string, glowColor: string) => {
    ctx.save();
    ctx.translate(x, y);

    // Glowing border
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 25;
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 6;
    ctx.fillStyle = '#1A1A1A';
    
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    
    // Clear shadow
    ctx.shadowBlur = 0;
    
    // Scanlines on background
    ctx.fillStyle = 'rgba(255,255,255,0.06)';
    for (let i = -r; i < r; i += 6) {
        ctx.fillRect(-r, i, r * 2, 2.5);
    }

    // Initials text
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 36px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(name.slice(0, 2).toUpperCase(), 0, -10);

    // Jersey number
    ctx.fillStyle = glowColor;
    ctx.font = 'bold 22px Arial, sans-serif';
    ctx.fillText(`N°${jersey || '00'}`, 0, 22);

    ctx.restore();
};

// Particles for animation
interface StarParticle {
    x: number;
    y: number;
    size: number;
    color: string;
    speedY: number;
    speedX: number;
    life: number;
    maxLife: number;
    rot: number;
    rotSpeed: number;
}

const particles = ref<StarParticle[]>([]);
const initParticles = () => {
    particles.value = [];
    const colors = [goldGlow.value, '#FFFFFF', '#FFA500'];
    for (let i = 0; i < 80; i++) {
        particles.value.push({
            x: Math.random() * W,
            y: H + Math.random() * 200,
            size: 8 + Math.random() * 15,
            color: colors[Math.floor(Math.random() * colors.length)],
            speedY: -(2 + Math.random() * 6),
            speedX: -1.5 + Math.random() * 3,
            life: 0,
            maxLife: 100 + Math.random() * 100,
            rot: Math.random() * Math.PI,
            rotSpeed: -0.05 + Math.random() * 0.1
        });
    }
};

const updateParticles = () => {
    particles.value.forEach(p => {
        p.x += p.speedX;
        p.y += p.speedY;
        p.life++;
        p.rot += p.rotSpeed;
        if (p.life > p.maxLife || p.y < -50) {
            p.y = H + Math.random() * 100;
            p.x = Math.random() * W;
            p.life = 0;
        }
    });
};

const drawStar = (ctx: CanvasRenderingContext2D, cx: number, cy: number, spikes: number, outerRadius: number, innerRadius: number, color: string) => {
    let rot = Math.PI / 2 * 3;
    let x = cx;
    let y = cy;
    const step = Math.PI / spikes;

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(cx, cy - outerRadius);
    for (let i = 0; i < spikes; i++) {
        x = cx + Math.cos(rot) * outerRadius;
        y = cy + Math.sin(rot) * outerRadius;
        ctx.lineTo(x, y);
        rot += step;

        x = cx + Math.cos(rot) * innerRadius;
        y = cy + Math.sin(rot) * innerRadius;
        ctx.lineTo(x, y);
        rot += step;
    }
    ctx.lineTo(cx, cy - outerRadius);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
    ctx.restore();
};

const drawModernRankCard = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    w: number,
    h: number,
    rank: string,
    player: Player,
    accent: string,
    progress: number
) => {
    const t = clamp(progress, 0, 1);
    const slide = (1 - t) * 90;
    const alpha = t;

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(slide, 0);

    ctx.shadowColor = 'rgba(0,0,0,0.35)';
    ctx.shadowBlur = 24;
    ctx.shadowOffsetY = 12;

    const plateGrad = ctx.createLinearGradient(x, y, x + w, y + h);
    plateGrad.addColorStop(0, rank === '1' ? brandRed : '#171717');
    plateGrad.addColorStop(0.52, rank === '1' ? deepRed : '#242424');
    plateGrad.addColorStop(1, '#050505');

    ctx.fillStyle = plateGrad;
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 5;
    drawSkewedRect(ctx, x, y, w, h, 18);
    ctx.fill();
    ctx.stroke();

    ctx.shadowBlur = 0;
    ctx.fillStyle = accent;
    drawSkewedRect(ctx, x + 18, y + 18, 118, h - 36, 10);
    ctx.fill();

    ctx.fillStyle = rank === '1' ? '#FFFFFF' : '#111111';
    ctx.font = 'bold 82px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(rank, x + 78, y + h / 2);

    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 42px Impact, sans-serif';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    ctx.fillText(player.name.toUpperCase(), x + 162, y + 74);

    ctx.fillStyle = 'rgba(255,255,255,0.72)';
    ctx.font = 'bold 22px Arial, sans-serif';
    ctx.fillText(getTeamName(player.team_id).toUpperCase(), x + 164, y + 112);

    ctx.fillStyle = accent;
    ctx.font = 'bold 30px Impact, sans-serif';
    ctx.fillText(`${player.mvp_votes} VOTI`, x + 164, y + 156);

    ctx.fillStyle = 'rgba(255,255,255,0.16)';
    ctx.fillRect(x + 162, y + h - 34, w - 205, 10);
    ctx.fillStyle = accent;
    ctx.fillRect(x + 162, y + h - 34, (w - 205) * t, 10);

    ctx.restore();
};

const drawDodgeball = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    r: number,
    rot: number,
    alpha = 1
) => {
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(x, y);
    ctx.rotate(rot);

    const ballGrad = ctx.createRadialGradient(-r * 0.35, -r * 0.35, r * 0.1, 0, 0, r);
    ballGrad.addColorStop(0, '#FF7A7A');
    ballGrad.addColorStop(0.45, brandRed);
    ballGrad.addColorStop(1, deepRed);
    ctx.fillStyle = ballGrad;
    ctx.shadowColor = 'rgba(211,47,47,0.75)';
    ctx.shadowBlur = 35;
    ctx.beginPath();
    ctx.arc(0, 0, r, 0, Math.PI * 2);
    ctx.fill();

    ctx.shadowBlur = 0;
    ctx.strokeStyle = '#111111';
    ctx.lineWidth = Math.max(5, r * 0.08);
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.88, -0.95, 0.95);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(0, 0, r * 0.88, Math.PI - 0.95, Math.PI + 0.95);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-r * 0.18, -r * 0.95);
    ctx.bezierCurveTo(r * 0.1, -r * 0.45, r * 0.1, r * 0.45, -r * 0.18, r * 0.95);
    ctx.stroke();

    ctx.restore();
};

const drawOutroExplosion = (ctx: CanvasRenderingContext2D, elapsed: number) => {
    const logoImg = preloadedImages.value.logo;
    const outroT = inv(elapsed, duration - outroDuration, duration);
    if (outroT <= 0) return;

    const flightT = ease.anticipate(inv(outroT, 0.02, 0.34), 0.14);
    const impactFlashT = inv(outroT, 0.3, 0.43);
    const explodeT = ease.organic(inv(outroT, 0.36, 0.72));
    const logoT = ease.anticipate(inv(outroT, 0.54, 0.8), 0.07);
    const holdT = inv(outroT, 0.78, 1);
    const cx = W / 2;
    const cy = H / 2;
    const impactY = cy + 24;

    ctx.save();
    ctx.fillStyle = `rgba(17,17,17,${0.14 + outroT * 0.82})`;
    ctx.fillRect(0, 0, W, H);

    const ballX = lerp(W + 240, cx, flightT);
    const ballY = lerp(H + 210, impactY, flightT) + Math.sin(flightT * Math.PI) * -125;
    const ballR = lerp(78, 146, flightT);

    if (flightT > 0 && explodeT < 0.72) {
        ctx.save();
        ctx.globalAlpha = (1 - explodeT) * 0.72;
        ctx.strokeStyle = softRed;
        ctx.lineWidth = 18;
        ctx.shadowColor = brandRed;
        ctx.shadowBlur = 22;
        ctx.beginPath();
        ctx.moveTo(ballX + 180, ballY + 150);
        ctx.quadraticCurveTo(ballX + 70, ballY + 40, ballX - 20, ballY - 10);
        ctx.stroke();
        ctx.restore();

        drawDodgeball(ctx, ballX, ballY, ballR, elapsed * 6.1, 1 - explodeT * 0.96);
    }

    if (impactFlashT > 0 && impactFlashT < 1) {
        const flashAlpha = Math.sin(impactFlashT * Math.PI);
        ctx.save();
        ctx.globalAlpha = flashAlpha * 0.9;
        const flashGrad = ctx.createRadialGradient(cx, impactY, 0, cx, impactY, 560);
        flashGrad.addColorStop(0, '#FFFFFF');
        flashGrad.addColorStop(0.14, 'rgba(255,255,255,0.72)');
        flashGrad.addColorStop(0.42, 'rgba(211,47,47,0.34)');
        flashGrad.addColorStop(1, 'rgba(211,47,47,0)');
        ctx.fillStyle = flashGrad;
        ctx.fillRect(0, 0, W, H);
        ctx.restore();
    }

    if (explodeT > 0) {
        ctx.save();
        ctx.globalAlpha = 1 - explodeT * 0.62;
        ctx.strokeStyle = brandRed;
        ctx.lineWidth = lerp(18, 3, explodeT);
        ctx.shadowColor = brandRed;
        ctx.shadowBlur = 32;
        ctx.beginPath();
        ctx.arc(cx, impactY, lerp(80, 780, explodeT), 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = lerp(10, 2, explodeT);
        ctx.beginPath();
        ctx.arc(cx, impactY, lerp(35, 470, explodeT), 0, Math.PI * 2);
        ctx.stroke();

        ctx.strokeStyle = softRed;
        ctx.lineWidth = lerp(7, 1, explodeT);
        ctx.beginPath();
        ctx.arc(cx, impactY, lerp(150, 980, explodeT), 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();

        for (let i = 0; i < 42; i++) {
            const angle = (i / 42) * Math.PI * 2 + Math.sin(i * 1.7) * 0.2;
            const distance = lerp(50, 700 + (i % 6) * 40, explodeT);
            const px = cx + Math.cos(angle) * distance;
            const py = impactY + Math.sin(angle) * distance + Math.sin(explodeT * Math.PI + i) * 22;
            const size = lerp(42 + (i % 4) * 9, 7, explodeT);
            ctx.save();
            ctx.globalAlpha = Math.max(0, 1 - explodeT * 0.78);
            ctx.translate(px, py);
            ctx.rotate(angle + elapsed * 4.2 + i * 0.18);
            ctx.fillStyle = i % 3 === 0 ? brandRed : i % 3 === 1 ? '#FFFFFF' : softRed;
            drawSkewedRect(ctx, -size / 2, -size / 2, size, size * 0.58, size * 0.16);
            ctx.fill();
            ctx.restore();
        }

        ctx.save();
        ctx.globalAlpha = Math.max(0, 1 - explodeT * 1.05);
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 84px Impact, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.translate(cx, impactY - 170);
        ctx.rotate(-0.04);
        ctx.fillText('BOOM', 0, 0);
        ctx.restore();
    }

    if (logoImg) {
        ctx.save();
        const logoPulse = 1 + Math.sin(holdT * Math.PI * 2) * 0.018 * holdT;
        const logoScale = lerp(0.62, 1, logoT) * logoPulse;
        ctx.globalAlpha = logoT;
        ctx.translate(cx, cy - 20);
        ctx.scale(logoScale, logoScale);
        ctx.shadowColor = 'rgba(211,47,47,0.78)';
        ctx.shadowBlur = 42;
        ctx.fillStyle = 'rgba(244,244,242,0.96)';
        drawSkewedRect(ctx, -330, -300, 660, 650, 24);
        ctx.fill();
        ctx.strokeStyle = brandRed;
        ctx.lineWidth = 8;
        ctx.stroke();
        drawImageContain(ctx, logoImg, -235, -220, 470, 470);
        ctx.fillStyle = charcoal;
        ctx.font = 'bold 52px Impact, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('DODGEBALL XL', 0, 235);
        ctx.fillStyle = brandRed;
        ctx.font = 'bold 28px Impact, sans-serif';
        ctx.fillText('MVP REVEAL', 0, 286);
        ctx.restore();
    }

    if (holdT > 0.15) {
        ctx.save();
        ctx.globalAlpha = (holdT - 0.15) * 0.22;
        ctx.fillStyle = brandRed;
        ctx.fillRect(0, 0, W, 18);
        ctx.fillRect(0, H - 18, W, 18);
        ctx.restore();
    }

    ctx.restore();
};

const drawStaticFrame = () => {
    const canvas = canvasRef.value;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.save();
    ctx.scale(SCALE, SCALE);
    renderCanvas(ctx, 0);
    ctx.restore();
};

const renderCanvas = (ctx: CanvasRenderingContext2D, elapsed: number) => {
    const p1 = props.topPlayers[0];
    const p2 = props.topPlayers[1];
    const p3 = props.topPlayers[2];

    const goldColorRgb = hexToRgb(goldGlow.value);
    const silverColorRgb = hexToRgb(silverGlow.value);
    const bronzeColorRgb = hexToRgb(bronzeGlow.value);

    // 1. Dodgeball XL concrete/grunge background
    ctx.fillStyle = cement;
    ctx.fillRect(0, 0, W, H);

    ctx.save();
    ctx.strokeStyle = 'rgba(0,0,0,0.055)';
    ctx.lineWidth = 3;
    for (let x = 0; x < W; x += 100) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, H);
        ctx.stroke();
    }
    for (let y = 0; y < H; y += 100) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(W, y);
        ctx.stroke();
    }
    ctx.fillStyle = 'rgba(0,0,0,0.035)';
    for (let x = 0; x < W; x += 32) {
        for (let y = 0; y < H; y += 32) {
            ctx.beginPath();
            ctx.arc(x, y, 1.8, 0, Math.PI * 2);
            ctx.fill();
        }
    }
    ctx.restore();

    ctx.save();
    const heroGrad = ctx.createLinearGradient(0, 0, 0, 720);
    heroGrad.addColorStop(0, deepRed);
    heroGrad.addColorStop(0.38, charcoal);
    heroGrad.addColorStop(0.74, 'rgba(17,17,17,0.92)');
    heroGrad.addColorStop(1, 'rgba(17,17,17,0)');
    ctx.fillStyle = heroGrad;
    ctx.fillRect(0, 0, W, 760);
    ctx.restore();

    ctx.save();
    const redWash = ctx.createRadialGradient(W * 0.5, H * 0.18, 80, W * 0.5, H * 0.18, 760);
    redWash.addColorStop(0, 'rgba(211,47,47,0.34)');
    redWash.addColorStop(0.48, 'rgba(211,47,47,0.16)');
    redWash.addColorStop(1, 'rgba(211,47,47,0)');
    ctx.fillStyle = redWash;
    ctx.fillRect(0, 0, W, H);
    ctx.restore();

    // 2. Rising Stars particles
    updateParticles();
    particles.value.forEach(p => {
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.rot);
        ctx.shadowColor = p.color;
        ctx.shadowBlur = 10;
        drawStar(ctx, 0, 0, 5, p.size, p.size / 2, p.color);
        ctx.restore();
    });

    // 3. Diagonal neon slashes
    ctx.save();
    const slashT = ease.organic(inv(elapsed, 0.1, 1.55));
    ctx.strokeStyle = brandRed;
    ctx.lineWidth = 18;
    ctx.shadowColor = brandRed;
    ctx.shadowBlur = 38;
    
    ctx.beginPath();
    ctx.moveTo(lerp(-300, 200, slashT), -50);
    ctx.lineTo(lerp(-100, 400, slashT), H + 50);
    ctx.stroke();

    ctx.strokeStyle = softRed;
    ctx.beginPath();
    ctx.moveTo(W - lerp(-300, 200, slashT), -50);
    ctx.lineTo(W - lerp(-100, 400, slashT), H + 50);
    ctx.stroke();
    ctx.restore();

    ctx.save();
    const detailT = ease.organic(inv(elapsed, 0.55, 1.85));
    ctx.globalAlpha = detailT;
    ctx.fillStyle = 'rgba(211,47,47,0.88)';
    drawSkewedRect(ctx, 740, 310, 260, 54, 10);
    ctx.fill();
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 24px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('TOP 3 REVEAL', 870, 337);

    ctx.translate(58, 1240);
    ctx.rotate(-Math.PI / 2);
    ctx.fillStyle = 'rgba(17,17,17,0.86)';
    ctx.font = 'bold 32px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('DODGEBALL XL 2026', 0, 0);
    ctx.restore();

    const logoImg = preloadedImages.value.logo;
    if (logoImg && elapsed < duration - outroDuration) {
        ctx.save();
        const logoT = ease.organic(inv(elapsed, 0.7, 1.7));
        ctx.globalAlpha = 0.18 * logoT;
        ctx.filter = 'grayscale(1) contrast(1.25)';
        drawImageContain(ctx, logoImg, W / 2 - 190, 365, 380, 380);
        ctx.filter = 'none';
        ctx.restore();
    }

    // 4. Modern dynamic rank cards
    const cardBaseY = 1120;
    if (p3) {
        drawModernRankCard(ctx, 120, cardBaseY + 420, 840, 190, '3', p3, bronzeGlow.value, ease.anticipate(inv(elapsed, 1.55, 3.1), 0.1));
    }
    if (p2) {
        drawModernRankCard(ctx, 120, cardBaseY + 210, 840, 190, '2', p2, silverGlow.value, ease.anticipate(inv(elapsed, 1.95, 3.55), 0.1));
    }
    if (p1) {
        drawModernRankCard(ctx, 85, cardBaseY - 35, 910, 220, '1', p1, brandRed, ease.anticipate(inv(elapsed, 2.45, 4.25), 0.12));
    }

    // 5. Render Players as floating editorial portraits
    const sX = 250;
    const sY = 980;
    const gX = 540;
    const gY = 820;
    const bX = 830;
    const bY = 1030;

    if (p2 && elapsed > 1.45) {
        const t = inv(elapsed, 1.65, 3.45);
        const sPlayerT = ease.anticipate(t, 0.18);
        const pY = lerp(H + 180, sY, sPlayerT);
        const drift = Math.sin(t * Math.PI) * -30 + Math.sin((elapsed + 0.8) * 1.8) * 4 * t;
        drawPlayerNode(ctx, sX + drift, pY + Math.sin((elapsed + 0.4) * 1.6) * 5 * t, 78, p2, silverGlow.value, '2');
    }

    if (p3 && elapsed > 1.85) {
        const t = inv(elapsed, 2.05, 3.8);
        const bPlayerT = ease.anticipate(t, 0.18);
        const pY = lerp(H + 180, bY, bPlayerT);
        const drift = Math.sin(t * Math.PI) * 30 + Math.sin((elapsed + 1.3) * 1.7) * 4 * t;
        drawPlayerNode(ctx, bX + drift, pY + Math.sin((elapsed + 0.9) * 1.5) * 5 * t, 72, p3, bronzeGlow.value, '3');
    }

    if (p1 && elapsed > 2.65) {
        const t = inv(elapsed, 2.95, 4.95);
        const gPlayerT = ease.anticipate(t, 0.22);
        const pY = lerp(H + 260, gY, gPlayerT);
        const gBreath = Math.sin(t * Math.PI) * -16 + Math.sin(elapsed * 1.45) * 6 * t;
        
        // Massive golden spotlight glow
        if (elapsed > 3.45) {
            ctx.save();
            const pulse = 1.0 + 0.08 * Math.sin((elapsed - 3.45) * 5);
            const spotGrad = ctx.createRadialGradient(gX, pY, 40, gX, pY, 320 * pulse);
            spotGrad.addColorStop(0, 'rgba(211,47,47,0.46)');
            spotGrad.addColorStop(0.34, 'rgba(211,47,47,0.22)');
            spotGrad.addColorStop(1, 'rgba(0,0,0,0)');
            ctx.fillStyle = spotGrad;
            ctx.beginPath();
            ctx.arc(gX, pY, 280 * pulse, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        }

        drawPlayerNode(ctx, gX, pY + gBreath, 108, p1, brandRed, '1');

        // Gold shockwave ring burst on landing
        const landingT = inv(elapsed, 4.35, 4.95);
        if (landingT > 0 && landingT < 1) {
            ctx.save();
            ctx.strokeStyle = brandRed;
            ctx.lineWidth = 10 * (1 - landingT);
            ctx.shadowColor = brandRed;
            ctx.shadowBlur = 20;
            ctx.beginPath();
            ctx.arc(gX, pY + gBreath, lerp(100, 300, landingT), 0, Math.PI * 2);
            ctx.stroke();
            ctx.restore();
        }
    }

    // 6. Giant Skewed Header
    const headT = ease.anticipate(inv(elapsed, 0.2, 1.55), 0.09);
    ctx.save();
    ctx.translate(0, lerp(-250, 0, headT));

    // Skewed sports background plate
    ctx.shadowColor = 'rgba(211,47,47,0.55)';
    ctx.shadowBlur = 22;
    ctx.fillStyle = deepRed;
    ctx.strokeStyle = brandRed;
    ctx.lineWidth = 6;
    drawSkewedRect(ctx, W / 2 - 400, 100, 800, 160, 20);
    ctx.fill();
    ctx.stroke();
    
    // Overlay text
    ctx.shadowBlur = 0;
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 72px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(customTitle.value.toUpperCase(), W / 2, 180);

    ctx.restore();

    // 7. Climax Champion Title Overlay
    if (elapsed > 3.7 && p1) {
        const climT = clamp(ease.anticipate(inv(elapsed, 4.2, 5.35), 0.1), 0.001, 1);
        ctx.save();
        ctx.scale(climT, climT);
        ctx.translate(W / 2 * (1 / climT - 1), 320 * (1 / climT - 1));

        ctx.shadowColor = 'rgba(211,47,47,0.55)';
        ctx.shadowBlur = 35;
        ctx.fillStyle = brandRed;
        ctx.strokeStyle = '#000000';
        ctx.lineWidth = 8;
        ctx.font = 'italic bold 104px Impact, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        
        ctx.strokeText('MVP', W / 2, 300);
        ctx.fillText('MVP', W / 2, 300);
        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 58px Impact, sans-serif';
        ctx.strokeText('DEL GIRONE', W / 2, 370);
        ctx.fillText('DEL GIRONE', W / 2, 370);
        ctx.restore();
    }

    // 8. Custom Subtitle and Event Footer Plate
    if (elapsed > 5.0) {
        const footT = ease.anticipate(inv(elapsed, 5.65, 6.95), 0.08);
        ctx.save();
        ctx.translate(0, lerp(200, 0, footT));

        ctx.fillStyle = deepRed;
        ctx.strokeStyle = brandRed;
        ctx.lineWidth = 4;
        drawSkewedRect(ctx, W / 2 - 360, H - 240, 720, 100, 12);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#FFFFFF';
        ctx.font = 'bold 36px Impact, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(`${customSubtitle.value.toUpperCase()} — ${customEvent.value.toUpperCase()}`, W / 2, H - 190);
        ctx.restore();
    }

    // 9. Ball impact outro with Dodgeball XL logo lockup
    drawOutroExplosion(ctx, elapsed);
};

const drawPlayerNode = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    r: number,
    player: Player,
    glowColor: string,
    rankSymbol: string
) => {
    const photoImg = preloadedImages.value[`p_${player.id}`];
    const logoImg = preloadedImages.value[`logo_${player.team_id}`];

    ctx.save();

    // 1. Draw Player Picture circular card
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 30;
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 8;

    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.clip();
    
    if (photoImg) {
        drawImageCover(ctx, photoImg, x - r, y - r, r * 2, r * 2);
    } else {
        // Fallback graphical vector shield
        drawPlayerFallback(ctx, x, y, r, player.name, String(player.jersey_number), glowColor);
    }
    
    // Redraw clip border
    ctx.shadowBlur = 0;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    // 2. Mini team badge overlay attached to avatar
    if (logoImg) {
        ctx.save();
        const bSize = r * 0.42;
        const bX = x + r * 0.7;
        const bY = y + r * 0.7;
        ctx.shadowColor = '#000000';
        ctx.shadowBlur = 10;
        ctx.strokeStyle = '#000000';
        ctx.lineWidth = 4;
        ctx.fillStyle = '#FFFFFF';
        ctx.beginPath();
        ctx.arc(bX, bY, bSize, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
        
        ctx.beginPath();
        ctx.arc(bX, bY, bSize, 0, Math.PI * 2);
        ctx.clip();
        drawImageCover(ctx, logoImg, bX - bSize, bY - bSize, bSize * 2, bSize * 2);
        ctx.restore();
    }

    // 3. Under-avatar Player Title Skew Plate
    ctx.save();
    ctx.shadowColor = 'rgba(211,47,47,0.28)';
    ctx.shadowBlur = 18;
    ctx.fillStyle = rankSymbol === '1' ? brandRed : '#111111';
    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 3;
    
    const pW = r * 2.15;
    const pH = 50;
    const pX = x - pW / 2;
    const pY = y + r + 25;
    drawSkewedRect(ctx, pX, pY, pW, pH, 8);
    ctx.fill();
    ctx.stroke();

    // Player text details
    ctx.shadowBlur = 0;
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 20px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(player.name.toUpperCase(), x, pY + pH / 2 - 8);

    ctx.fillStyle = rankSymbol === '1' ? '#FFFFFF' : glowColor;
    ctx.font = 'bold 14px Arial, sans-serif';
    ctx.fillText(`${player.mvp_votes} VOTI`, x, pY + pH / 2 + 13);
    ctx.restore();
};

// Exporter pipeline triggers
let startTime = 0;
const tick = (timestamp: number) => {
    if (!startTime) startTime = timestamp;
    const elapsed = (timestamp - startTime) / 1000;

    const canvas = canvasRef.value;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Render loop
    ctx.save();
    ctx.scale(SCALE, SCALE);
    renderCanvas(ctx, elapsed);
    ctx.restore();

    if (elapsed < duration) {
        rafId.value = requestAnimationFrame(tick);
    } else {
        stopPlayback();
    }
};

const startPreview = () => {
    if (status.value !== 'ready') return;
    stopPlayback();
    status.value = 'playing';
    startTime = 0;
    initParticles();
    rafId.value = requestAnimationFrame(tick);
};

const stopPlayback = () => {
    if (rafId.value) {
        cancelAnimationFrame(rafId.value);
        rafId.value = null;
    }
    startTime = 0;
    if (status.value === 'playing' || status.value === 'recording') {
        status.value = 'ready';
        drawStaticFrame();
    }
};

// WebRTC High Bitrate MediaRecorder Exporter
const exportVideo = () => {
    const canvas = canvasRef.value;
    if (!canvas) return;
    stopPlayback();
    status.value = 'recording';
    startTime = 0;
    initParticles();
    recordedChunks.value = [];
    recordProgress.value = 0;

    // Capture Canvas stream at 60 FPS
    const stream = canvas.captureStream(60);
    const options = {
        mimeType: 'video/webm;codecs=vp9',
        videoBitsPerSecond: highBitrate.value ? 45000000 : 14000000
    };

    try {
        mediaRecorder.value = new MediaRecorder(stream, options);
    } catch (e) {
        // Fallback for Safari/other browsers
        mediaRecorder.value = new MediaRecorder(stream, { videoBitsPerSecond: highBitrate.value ? 32000000 : 12000000 });
    }

    mediaRecorder.value.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
            recordedChunks.value.push(event.data);
        }
    };

    mediaRecorder.value.onstop = () => {
        const blob = new Blob(recordedChunks.value, { type: 'video/webm' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `mvp_podium_${Date.now()}.webm`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        status.value = 'ready';
        drawStaticFrame();
    };

    mediaRecorder.value.start();

    // Custom animation tick tracking progress
    const recTick = (ts: number) => {
        if (!startTime) startTime = ts;
        const elapsed = (ts - startTime) / 1000;
        recordProgress.value = Math.min(100, Math.floor((elapsed / duration) * 100));

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        ctx.save();
        ctx.scale(SCALE, SCALE);
        renderCanvas(ctx, elapsed);
        ctx.restore();

        if (elapsed < duration) {
            rafId.value = requestAnimationFrame(recTick);
        } else {
            mediaRecorder.value?.stop();
            stopPlayback();
        }
    };

    rafId.value = requestAnimationFrame(recTick);
};

onMounted(() => {
    preloadAssets();
});

onUnmounted(() => {
    stopPlayback();
});

watch(() => props.topPlayers, () => {
    preloadAssets();
}, { deep: true });
</script>

<template>
    <div class="bg-cement border-4 border-black p-4 sm:p-6 flex flex-col xl:flex-row gap-6 shadow-[6px_6px_0px_rgba(0,0,0,1)]">
        
        <!-- Left: Preview Canvas -->
        <div class="flex-1 flex flex-col items-center justify-center bg-[#8E1515] border-4 border-black p-3 sm:p-5 relative overflow-hidden min-h-[520px] shadow-[4px_4px_0px_rgba(211,47,47,1)]">
            <div class="absolute inset-0 bg-gradient-to-b from-primary/70 via-[#111111]/90 to-[#111111]"></div>
            <div class="absolute inset-0 opacity-20 bg-[radial-gradient(rgba(255,255,255,0.6)_1px,transparent_1px)] [background-size:16px_16px]" aria-hidden="true"></div>
            <canvas
                ref="canvasRef"
                :width="W * SCALE"
                :height="H * SCALE"
                class="relative z-10 w-auto h-[68vh] max-h-[720px] max-w-full border-4 border-white bg-cement aspect-[9/16] object-contain shadow-[6px_6px_0px_rgba(211,47,47,1)] transition-transform duration-500 ease-out"
            ></canvas>

            <div v-if="status === 'loading'" class="absolute inset-0 bg-black/80 flex flex-col items-center justify-center gap-3">
                <Icon name="mdi:loading" class="animate-spin text-5xl text-primary" />
                <span class="font-impact text-xs uppercase tracking-widest text-white">Caricamento Foto...</span>
            </div>

            <div v-if="status === 'recording'" class="absolute inset-0 bg-black/85 flex flex-col items-center justify-center gap-4">
                <Icon name="mdi:record-circle" class="text-6xl text-red-600 animate-pulse" />
                <span class="font-impact text-2xl uppercase tracking-widest text-white">Generazione Video...</span>
                <div class="w-64 bg-zinc-800 border-2 border-black p-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                    <div class="h-4 bg-primary transition-all duration-100" :style="{ width: `${recordProgress}%` }"></div>
                </div>
                <span class="font-impact text-sm text-primary tracking-widest">{{ recordProgress }}% COMPLETATO</span>
                <span class="text-xs text-zinc-400 font-bold uppercase tracking-wider">Non chiudere la pagina</span>
            </div>
        </div>

        <!-- Right: Control Panel Customizer -->
        <div class="w-full xl:w-[25rem] flex flex-col gap-6 justify-between bg-white border-4 border-black p-5 shadow-[4px_4px_0px_rgba(211,47,47,1)]">
            <div class="space-y-5">
                <div>
                    <div class="inline-flex items-center gap-2 bg-primary text-white border-2 border-black px-3 py-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                        <Icon name="mdi:movie-open-star" class="text-white text-lg" />
                        <span class="font-impact text-xs tracking-widest">MVP EXPORT</span>
                    </div>
                    <h3 class="font-impact text-3xl uppercase tracking-wider text-primary border-b-4 border-black pb-2 mt-3 inline-block">
                        Story Generator Podium MVP
                    </h3>
                    <p class="text-xs text-zinc-600 font-bold uppercase tracking-wider mt-2 leading-relaxed">
                        Esporta un video verticale premium da condividere su Instagram e TikTok per celebrare i migliori candidati della fase a gironi!
                    </p>
                </div>

                <!-- Fields customizers -->
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-impact text-secondary uppercase tracking-widest mb-1.5">Titolo Principale</label>
                        <input
                            v-model="customTitle"
                            type="text"
                            class="w-full bg-white border-2 border-black text-black font-impact uppercase tracking-wider px-3 py-2 text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            placeholder="Titolo Principale"
                        />
                    </div>
                    <div>
                        <label class="block text-xs font-impact text-secondary uppercase tracking-widest mb-1.5">Sottotitolo Classifica</label>
                        <input
                            v-model="customSubtitle"
                            type="text"
                            class="w-full bg-white border-2 border-black text-black font-impact uppercase tracking-wider px-3 py-2 text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            placeholder="Sottotitolo"
                        />
                    </div>
                    <div>
                        <label class="block text-xs font-impact text-secondary uppercase tracking-widest mb-1.5">Dettaglio Torneo / Luogo</label>
                        <input
                            v-model="customEvent"
                            type="text"
                            class="w-full bg-white border-2 border-black text-black font-impact uppercase tracking-wider px-3 py-2 text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            placeholder="Es. Dodgeball XL 2026"
                        />
                    </div>
                </div>

                <!-- Export quality selector -->
                <div class="bg-red-50 border-2 border-black p-4 space-y-3 shadow-[2px_2px_0px_rgba(211,47,47,1)]">
                    <h4 class="font-impact text-xs uppercase tracking-widest text-black">Opzioni Esportazione</h4>
                    <label class="flex items-center gap-3 cursor-pointer">
                        <input
                            type="checkbox"
                            v-model="highBitrate"
                            class="w-5 h-5 bg-white border-2 border-black checked:bg-primary accent-primary"
                        />
                        <span class="text-xs text-zinc-700 font-bold uppercase tracking-wider">Alta Qualità (60 FPS / 45 Mbps)</span>
                    </label>
                    <p class="text-[10px] text-zinc-500 font-medium uppercase tracking-wide leading-relaxed">
                        * L'esportazione genererà un file video in formato WebM ad alta definizione pronto all'uso.
                    </p>
                </div>
            </div>

            <!-- Action buttons -->
            <div class="flex flex-col gap-3 pt-4 border-t-4 border-primary">
                <button
                    v-if="status === 'playing'"
                    @click="stopPlayback"
                    class="btn-skewed w-full py-4 !bg-red-600 active:scale-95 transition-transform"
                >
                    <span class="btn-skewed-content flex items-center justify-center gap-2">
                        <Icon name="mdi:stop" class="text-xl" />
                        Ferma Anteprima
                    </span>
                </button>
                <button
                    v-else
                    @click="startPreview"
                    :disabled="status === 'loading' || status === 'recording'"
                    class="btn-skewed-secondary w-full py-4 disabled:opacity-50 active:scale-95 transition-transform"
                >
                    <span class="btn-skewed-content flex items-center justify-center gap-2">
                        <Icon name="mdi:play" class="text-xl" />
                        Avvia Anteprima
                    </span>
                </button>

                <button
                    @click="exportVideo"
                    :disabled="status === 'loading' || status === 'recording'"
                    class="btn-skewed w-full py-4 !bg-primary hover:!bg-accent disabled:opacity-50 active:scale-95 transition-transform"
                >
                    <span class="btn-skewed-content flex items-center justify-center gap-2 font-black">
                        <Icon name="mdi:movie-open-play" class="text-xl" />
                        Esporta Story Video
                    </span>
                </button>
            </div>
        </div>

    </div>
</template>
