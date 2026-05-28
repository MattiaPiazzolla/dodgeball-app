<!-- app/components/admin/MatchMvpTeaser.vue -->
<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';

interface Player {
    id: string;
    name: string;
    nickname?: string;
    jersey_number?: number | string;
    photo_url?: string;
    mvp_votes: number;
    match_mvp_votes?: number;
    team_id: string;
}

interface Team {
    id: string;
    name: string;
    logo_url?: string;
}

interface Match {
    id: string;
    team1_id: string | null;
    team2_id: string | null;
    status: string;
    team1_score?: number | null;
    team2_score?: number | null;
}

const props = defineProps<{
    match: Match | null;
    topPlayers: Player[];
    teams: Team[];
}>();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const rafId = ref<number | null>(null);
const status = ref<'idle' | 'loading' | 'ready' | 'playing' | 'recording' | 'done'>('idle');
const recordProgress = ref(0);

// Customizer parameters
const customTitle = ref('MVP DELLA PARTITA');
const customSubtitle = ref('');
const customEvent = ref('DODGEBALL XL 2026');
const goldGlow = ref('#FFD700'); // Gold Glow
const silverGlow = ref('#C0C0C0'); // Silver Glow
const bronzeGlow = ref('#CD7F32'); // Bronze Glow
const highBitrate = ref(true);

const duration = 11.3;
const dissolveDuration = 1.25;
const W = 1080;
const H = 1920;
const SCALE = 2; // High-definition supersampled output resolution
const brandRed = '#D32F2F';
const cement = '#F5F5F3';
const ink = '#111111';
const paper = '#FFFFFF';

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

const fitText = (
    ctx: CanvasRenderingContext2D,
    text: string,
    x: number,
    y: number,
    maxWidth: number,
    maxSize: number,
    minSize: number,
    family: string,
    weight = 'bold',
    align: CanvasTextAlign = 'center',
) => {
    const safeText = text.trim() || 'TBD';
    let size = maxSize;
    ctx.textAlign = align;
    while (size > minSize) {
        ctx.font = `${weight} ${size}px ${family}`;
        if (ctx.measureText(safeText).width <= maxWidth) break;
        size -= 2;
    }
    ctx.fillText(safeText, x, y);
};

const drawRoundedRect = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    w: number,
    h: number,
    r = 8,
) => {
    const radius = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
    ctx.lineTo(x + radius, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
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
    props.teams.find((t) => t.id === id)?.name || "TBD";
const getTeamLogo = (id: string | null) =>
    props.teams.find((t) => t.id === id)?.logo_url || null;
const getMatchScore = () => {
    if (!props.match) return '';
    return `${props.match.team1_score ?? 0} - ${props.match.team2_score ?? 0}`;
};
const getMatchupLabel = () => {
    if (!props.match) return customSubtitle.value || 'MATCH MVP';
    return `${getTeamName(props.match.team1_id)} vs ${getTeamName(props.match.team2_id)}`;
};
const getFooterText = () => [customSubtitle.value, customEvent.value]
    .map((value) => value.trim().toUpperCase())
    .filter(Boolean)
    .join('  x  ');

const loadImage = (url: string): Promise<HTMLImageElement> => {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.crossOrigin = 'anonymous';
        img.src = url;
        img.onload = () => resolve(img);
        img.onerror = (e) => reject(e);
    });
};

const getSupportedVideoType = () => {
    const candidates = [
        'video/mp4;codecs=avc1.42E01E',
        'video/mp4;codecs=avc1',
        'video/mp4',
        'video/webm;codecs=vp9',
        'video/webm;codecs=vp8',
        'video/webm',
    ];

    return candidates.find((type) => MediaRecorder.isTypeSupported(type)) || '';
};

const getVideoExtension = (mimeType: string) => mimeType.includes('mp4') ? 'mp4' : 'webm';

const getSafeFilenamePart = (value: string) => value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '') || 'match-mvp';

const preloadAssets = async () => {
    status.value = 'loading';
    preloadedImages.value = {};
    const promises: Promise<void>[] = [
        loadImage('/dodgeballxl-logo.PNG')
            .then((img) => { preloadedImages.value.logo = img; })
            .catch(() => console.warn('CORS/Error loading Dodgeball XL logo'))
    ];

    // Preload match team logos
    if (props.match) {
        const logo1 = getTeamLogo(props.match.team1_id);
        if (logo1) {
            promises.push(
                loadImage(logo1)
                    .then((img) => { preloadedImages.value[`match_logo1`] = img; })
                    .catch(() => console.warn(`Error loading team 1 logo`))
            );
        }
        const logo2 = getTeamLogo(props.match.team2_id);
        if (logo2) {
            promises.push(
                loadImage(logo2)
                    .then((img) => { preloadedImages.value[`match_logo2`] = img; })
                    .catch(() => console.warn(`Error loading team 2 logo`))
            );
        }
    }

    // Preload Roster Photos for top 3 match players
    props.topPlayers.slice(0, 3).forEach((p) => {
        if (p.photo_url) {
            promises.push(
                loadImage(p.photo_url)
                    .then((img) => { preloadedImages.value[`p_${p.id}`] = img; })
                    .catch(() => console.warn(`Error loading photo for player ${p.name}`))
            );
        }
        const logo = getTeamLogo(p.team_id);
        if (logo) {
            promises.push(
                loadImage(logo)
                    .then((img) => { preloadedImages.value[`logo_${p.team_id}`] = img; })
                    .catch(() => console.warn(`Error loading team logo for player ${p.name}`))
            );
        }
    });

    try {
        await Promise.all(promises);
    } catch (e) {
        console.error('Error preloading some Match MVP assets:', e);
    } finally {
        status.value = 'ready';
        drawStaticFrame();
    }
};

const drawMinimalRankCard = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    w: number,
    h: number,
    rank: string,
    player: Player,
    accent: string,
    progress: number,
    elapsed: number
) => {
    const t = clamp(progress, 0, 1);
    const slide = (1 - t) * 92;
    
    // Elastic micro-rotation pop: tilting from -3deg to 0deg during slide-in
    const maxSkew = -3.2 * (Math.PI / 180);
    const rot = lerp(maxSkew, 0, ease.outCubic(t));
    const alpha = t;

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(x + w / 2 - slide, y + h / 2);
    ctx.rotate(rot);
    ctx.translate(-(x + w / 2), -(y + h / 2));

    // Clean editorial card with rank color spine
    ctx.fillStyle = paper;
    ctx.strokeStyle = ink;
    ctx.lineWidth = 4;
    
    // Flat flat-design drop shadow
    ctx.shadowColor = 'rgba(0, 0, 0, 0.07)';
    ctx.shadowBlur = 16;
    ctx.shadowOffsetY = 6;
    
    drawRoundedRect(ctx, x, y, w, h, 8);
    ctx.fill();
    ctx.stroke();
    
    ctx.shadowBlur = 0;
    ctx.shadowColor = 'transparent';

    // RENDER LARGE WATERMARK JERSEY NUMBER IN BACKGROUND (Watermark Impact for Legibility!)
    ctx.save();
    ctx.fillStyle = 'rgba(17, 17, 17, 0.05)';
    ctx.font = 'bold italic 160px Impact, sans-serif';
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    const jerseyText = player.jersey_number ? `N°${player.jersey_number}` : 'N°00';
    ctx.fillText(jerseyText, x + w - 40, y + h / 2 + 10);
    ctx.restore();

    ctx.fillStyle = accent;
    ctx.fillRect(x, y, 18, h);

    // Left Rank Circle Badge
    ctx.fillStyle = rank === '1' ? brandRed : '#F0F0EE';
    ctx.strokeStyle = ink;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(x + 75, y + h / 2, 44, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Rank Number
    ctx.fillStyle = rank === '1' ? paper : ink;
    ctx.font = 'bold 44px Impact, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(rank, x + 75, y + h / 2);

    // Player Details (Extra bold & massive for social media readability!)
    ctx.fillStyle = ink;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'alphabetic';
    fitText(ctx, player.name.toUpperCase(), x + 145, y + h / 2 - 8, w - 430, rank === '1' ? 58 : 52, 30, 'Arial Black, Arial, sans-serif', 'bold', 'left');

    ctx.fillStyle = '#666666';
    fitText(ctx, getTeamName(player.team_id).toUpperCase(), x + 147, y + h / 2 + 30, w - 430, 22, 14, 'Arial, sans-serif', 'bold', 'left');

    // Match Votes capsule on the right (High Contrast & Social Friendly!)
    ctx.save();
    const voteCount = player.match_mvp_votes || 0;
    const voteText = voteCount === 1 ? 'VOTO' : 'VOTI';
    
    // Choose highly visible background colors based on rank
    if (rank === '1') {
        ctx.fillStyle = '#FFD700'; // Gold banner
    } else if (rank === '2') {
        ctx.fillStyle = '#EAEAEE'; // Platinum/Silver
    } else {
        ctx.fillStyle = '#CD7F32'; // Bronze
    }
    
    ctx.strokeStyle = ink;
    ctx.lineWidth = 3;
    
    // Vote banner capsules (highly readable)
    const badgeW = 240;
    const badgeH = 56;
    const badgeX = x + w - badgeW - 35;
    const badgeY = y + h / 2 - badgeH / 2;
    
    ctx.fillRect(badgeX, badgeY, badgeW, badgeH);
    ctx.strokeRect(badgeX, badgeY, badgeW, badgeH);
    
    ctx.fillStyle = ink;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    fitText(ctx, `${voteCount} ${voteText}`, badgeX + badgeW / 2, badgeY + badgeH / 2 + 2, badgeW - 24, 38, 24, 'Impact, sans-serif');
    ctx.restore();

    // Bottom progress line
    ctx.fillStyle = 'rgba(0,0,0,0.06)';
    ctx.fillRect(x + 145, y + h - 24, w - 195, 4);
    ctx.fillStyle = rank === '1' ? brandRed : '#777777';
    ctx.fillRect(x + 145, y + h - 24, (w - 195) * t, 4);

    ctx.restore();
};

const drawMinimalPlayerNode = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    r: number,
    player: Player,
    glowColor: string,
    rankSymbol: string,
    elapsed: number
) => {
    const photoImg = preloadedImages.value[`p_${player.id}`];
    const logoImg = preloadedImages.value[`logo_${player.team_id}`];

    ctx.save();

    // DRAW A ROTATING DASHED framing border around player portrait (Highly creative motion detail!)
    ctx.save();
    ctx.strokeStyle = rankSymbol === '1' ? brandRed : '#111111';
    ctx.lineWidth = 3;
    ctx.setLineDash([8, 8]); // 8px dash, 8px gap
    ctx.translate(x, y);
    ctx.rotate(elapsed * (rankSymbol === '1' ? 0.75 : -0.5)); // spin clockwise for MVP, counter for others
    ctx.beginPath();
    ctx.arc(0, 0, r + 12, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    // 1. Draw avatar with flat shadow and clean thick black border
    ctx.shadowColor = 'rgba(0,0,0,0.12)';
    ctx.shadowBlur = 20;
    ctx.shadowOffsetY = 6;
    ctx.strokeStyle = '#111111';
    ctx.lineWidth = 5;

    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.clip();
    
    if (photoImg) {
        drawImageCover(ctx, photoImg, x - r, y - r, r * 2, r * 2);
    } else {
        // Flat modern fallback
        ctx.save();
        ctx.fillStyle = '#EAEAEE';
        ctx.fillRect(x - r, y - r, r * 2, r * 2);
        
        ctx.fillStyle = '#555555';
        ctx.font = 'bold 36px Arial Black, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(player.name.slice(0, 2).toUpperCase(), x, y);
        ctx.restore();
    }
    
    // Outline
    ctx.shadowBlur = 0;
    ctx.shadowOffsetY = 0;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();

    // 2. Mini team badge (neat circular overlay)
    if (logoImg) {
        ctx.save();
        const bSize = r * 0.36;
        const bX = x + r * 0.72;
        const bY = y + r * 0.72;
        ctx.shadowColor = 'rgba(0,0,0,0.12)';
        ctx.shadowBlur = 8;
        ctx.strokeStyle = '#111111';
        ctx.lineWidth = 3;
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

    // 3. Under-avatar Player Title Badge (unskewed, high contrast)
    ctx.save();
    ctx.fillStyle = rankSymbol === '1' ? brandRed : paper;
    ctx.strokeStyle = ink;
    ctx.lineWidth = 3;
    
    // Classic flat shadow
    ctx.shadowColor = 'rgba(0, 0, 0, 0.08)';
    ctx.shadowBlur = 10;
    ctx.shadowOffsetY = 3;
    
    const pW = r * 2.15;
    const pH = 56;
    const pX = x - pW / 2;
    const pY = y + r + 22;
    
    drawRoundedRect(ctx, pX, pY, pW, pH, 8);
    ctx.fill();
    ctx.stroke();

    // Player text details (Highly readable sizes)
    ctx.shadowBlur = 0;
    ctx.shadowOffsetY = 0;
    ctx.fillStyle = rankSymbol === '1' ? paper : ink;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    fitText(ctx, player.name.toUpperCase(), x, pY + pH / 2 - 8, pW - 22, 18, 11, 'Arial, sans-serif');

    ctx.fillStyle = rankSymbol === '1' ? '#FFFFFF' : '#666666';
    ctx.font = 'bold 13px Arial, sans-serif';
    
    const voteCount = player.match_mvp_votes || 0;
    const voteText = voteCount === 1 ? 'VOTO' : 'VOTI';
    ctx.fillText(`${voteCount} ${voteText} PARTITA`, x, pY + pH / 2 + 12);
    ctx.restore();
};

const drawEndDissolve = (ctx: CanvasRenderingContext2D, elapsed: number) => {
    const t = ease.inOutSine(inv(elapsed, duration - dissolveDuration, duration));
    if (t <= 0) return;

    ctx.fillStyle = `rgba(0,0,0, ${t})`;
    ctx.fillRect(0, 0, W, H);
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

    // 1. Premium match-night background
    ctx.fillStyle = cement;
    ctx.fillRect(0, 0, W, H);

    const wash = ctx.createLinearGradient(0, 0, W, H);
    wash.addColorStop(0, '#FFFFFF');
    wash.addColorStop(0.52, '#F3F3F0');
    wash.addColorStop(1, '#DCDDE1');
    ctx.fillStyle = wash;
    ctx.fillRect(0, 0, W, H);

    ctx.save();
    ctx.globalAlpha = 0.98;
    const slashT = ease.organic(inv(elapsed, 0.2, 1.9));
    ctx.translate(lerp(-520, 0, slashT), 0);
    ctx.fillStyle = brandRed;
    drawSkewedRect(ctx, -130, 1230, 1360, 420, -135);
    ctx.fill();
    ctx.fillStyle = '#171717';
    drawSkewedRect(ctx, 700, 520, 520, 1280, -95);
    ctx.fill();
    ctx.restore();

    // Micro-thin court/grid texture
    ctx.save();
    ctx.strokeStyle = 'rgba(0, 0, 0, 0.035)';
    ctx.lineWidth = 1.5;
    for (let x = 0; x < W; x += 120) {
        ctx.beginPath();
        ctx.moveTo(x, 0);
        ctx.lineTo(x, H);
        ctx.stroke();
    }
    for (let y = 0; y < H; y += 120) {
        ctx.beginPath();
        ctx.moveTo(0, y);
        ctx.lineTo(W, y);
        ctx.stroke();
    }
    ctx.restore();

    ctx.save();
    ctx.globalAlpha = 0.14;
    ctx.strokeStyle = '#111111';
    ctx.lineWidth = 6;
    ctx.beginPath();
    ctx.arc(W / 2, 1215, 410, Math.PI, 0);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(120, 1215);
    ctx.lineTo(960, 1215);
    ctx.stroke();
    ctx.restore();

    // Draw slowly rotating corner design crosses (+)
    ctx.save();
    ctx.strokeStyle = 'rgba(17, 17, 17, 0.12)';
    ctx.lineWidth = 3;
    const drawCross = (cx: number, cy: number, rot: number) => {
        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(rot);
        ctx.beginPath();
        ctx.moveTo(-16, 0); ctx.lineTo(16, 0);
        ctx.moveTo(0, -16); ctx.lineTo(0, 16);
        ctx.stroke();
        ctx.restore();
    };
    const cRot = elapsed * 0.45;
    drawCross(60, 60, cRot);
    drawCross(W - 60, 60, -cRot);
    drawCross(60, H - 60, -cRot);
    drawCross(W - 60, H - 60, cRot);
    ctx.restore();

    // Match Matchup Banner
    if (props.match) {
        const bannerT = ease.anticipate(inv(elapsed, 0.1, 1.4), 0.08);
        ctx.save();
        ctx.translate(0, lerp(-200, 0, bannerT));

        // Clean, unskewed, minimalist banner
        ctx.fillStyle = paper;
        ctx.strokeStyle = ink;
        ctx.lineWidth = 4;
        
        ctx.shadowColor = 'rgba(0, 0, 0, 0.08)';
        ctx.shadowBlur = 18;
        ctx.shadowOffsetY = 6;
        drawRoundedRect(ctx, W / 2 - 430, 280, 860, 132, 8);
        ctx.fill();
        ctx.stroke();
        
        ctx.shadowColor = 'transparent';
        ctx.shadowBlur = 0;

        // Team 1 Logo
        const t1Logo = preloadedImages.value[`match_logo1`];
        if (t1Logo) {
            ctx.save();
            ctx.beginPath();
            ctx.arc(W / 2 - 340, 346, 38, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = paper;
            ctx.fillRect(W / 2 - 378, 308, 76, 76);
            drawImageCover(ctx, t1Logo, W / 2 - 378, 308, 76, 76);
            ctx.restore();
            
            ctx.strokeStyle = ink;
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(W / 2 - 340, 346, 38, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Team 2 Logo
        const t2Logo = preloadedImages.value[`match_logo2`];
        if (t2Logo) {
            ctx.save();
            ctx.beginPath();
            ctx.arc(W / 2 + 340, 346, 38, 0, Math.PI * 2);
            ctx.clip();
            ctx.fillStyle = paper;
            ctx.fillRect(W / 2 + 302, 308, 76, 76);
            drawImageCover(ctx, t2Logo, W / 2 + 302, 308, 76, 76);
            ctx.restore();

            ctx.strokeStyle = ink;
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.arc(W / 2 + 340, 346, 38, 0, Math.PI * 2);
            ctx.stroke();
        }

        ctx.fillStyle = ink;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        const t1Name = getTeamName(props.match.team1_id).toUpperCase();
        const t2Name = getTeamName(props.match.team2_id).toUpperCase();
        fitText(ctx, `${t1Name}   VS   ${t2Name}`, W / 2, 330, 560, 42, 22, 'Impact, sans-serif');
        ctx.fillStyle = brandRed;
        ctx.font = 'bold 34px Impact, sans-serif';
        ctx.fillText(getMatchScore(), W / 2, 375);
        ctx.restore();
    }

    // Side details (Clean flat tag)
    ctx.save();
    const detailT = ease.organic(inv(elapsed, 0.55, 1.85));
    ctx.globalAlpha = detailT;
    ctx.fillStyle = '#111111';
    ctx.fillRect(750, 425, 230, 48);
    
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 16px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('MATCH HIGHLIGHTS', 865, 449);

    ctx.translate(58, 1240);
    ctx.rotate(-Math.PI / 2);
    ctx.fillStyle = 'rgba(17,17,17,0.44)';
    ctx.font = 'bold 24px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('MATCH REPORT', 0, 0);
    ctx.restore();

    // 4. Modern minimal rank cards (Beautifully distributed using vertical canvas space!)
    const cardBaseY = 1190;
    if (p3) {
        drawMinimalRankCard(ctx, 100, cardBaseY + 465, 880, 195, '3', p3, bronzeGlow.value, ease.anticipate(inv(elapsed, 1.55, 3.1), 0.1), elapsed);
    }
    if (p2) {
        drawMinimalRankCard(ctx, 100, cardBaseY + 245, 880, 195, '2', p2, silverGlow.value, ease.anticipate(inv(elapsed, 1.95, 3.55), 0.1), elapsed);
    }
    if (p1) {
        drawMinimalRankCard(ctx, 80, cardBaseY, 920, 220, '1', p1, brandRed, ease.anticipate(inv(elapsed, 2.45, 4.25), 0.12), elapsed);
    }

    // 5. Floating organic avatars (Expanded radii for mobile size pop!)
    const sX = 250;
    const sY = 960;
    const gX = 540;
    const gY = 770; // Spaced vertically from banner
    const bX = 830;
    const bY = 1010;

    if (p2 && elapsed > 1.45) {
        const t = inv(elapsed, 1.65, 3.45);
        const sPlayerT = ease.anticipate(t, 0.18);
        const pY = lerp(H + 180, sY, sPlayerT);
        const drift = Math.sin(t * Math.PI) * -20 + Math.sin((elapsed + 0.8) * 1.5) * 3 * t;
        drawMinimalPlayerNode(ctx, sX + drift, pY + Math.sin((elapsed + 0.4) * 1.2) * 4 * t, 105, p2, silverGlow.value, '2', elapsed);
    }

    if (p3 && elapsed > 1.85) {
        const t = inv(elapsed, 2.05, 3.8);
        const bPlayerT = ease.anticipate(t, 0.18);
        const pY = lerp(H + 180, bY, bPlayerT);
        const drift = Math.sin(t * Math.PI) * 20 + Math.sin((elapsed + 1.3) * 1.4) * 3 * t;
        drawMinimalPlayerNode(ctx, bX + drift, pY + Math.sin((elapsed + 0.9) * 1.1) * 4 * t, 95, p3, bronzeGlow.value, '3', elapsed);
    }

    if (p1 && elapsed > 2.65) {
        const t = inv(elapsed, 2.95, 4.95);
        const gPlayerT = ease.anticipate(t, 0.22);
        const pY = lerp(H + 260, gY, gPlayerT);
        const gBreath = Math.sin(t * Math.PI) * -12 + Math.sin(elapsed * 1.25) * 5 * t;
        
        // Soft, elegant golden halo behind winner
        if (elapsed > 3.45) {
            ctx.save();
            const pulse = 1.0 + 0.04 * Math.sin((elapsed - 3.45) * 2.5);
            const spotGrad = ctx.createRadialGradient(gX, pY, 20, gX, pY, 260 * pulse);
            spotGrad.addColorStop(0, 'rgba(255, 215, 0, 0.24)');
            spotGrad.addColorStop(0.5, 'rgba(255, 215, 0, 0.08)');
            spotGrad.addColorStop(1, 'rgba(255, 215, 0, 0)');
            ctx.fillStyle = spotGrad;
            ctx.beginPath();
            ctx.arc(gX, pY, 260 * pulse, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();
        }

        drawMinimalPlayerNode(ctx, gX, pY + gBreath, 145, p1, brandRed, '1', elapsed);
    }

    // 6. Minimal Title Header Card (Massive Impact Font!)
    const headT = ease.anticipate(inv(elapsed, 0.2, 1.55), 0.09);
    ctx.save();
    ctx.translate(0, lerp(-250, 0, headT));

    // Clean white rectangle with thin black border
    ctx.shadowColor = 'rgba(0, 0, 0, 0.06)';
    ctx.shadowBlur = 16;
    ctx.shadowOffsetY = 4;
    ctx.fillStyle = paper;
    ctx.strokeStyle = ink;
    ctx.lineWidth = 4;
    drawRoundedRect(ctx, W / 2 - 390, 110, 780, 120, 8);
    ctx.fill();
    ctx.stroke();
    
    // Title Text (Modern spaced clean Impact)
    ctx.shadowBlur = 0;
    ctx.fillStyle = ink;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    fitText(ctx, customTitle.value.toUpperCase(), W / 2, 170 + 3, 700, 76, 44, 'Impact, sans-serif');

    ctx.restore();

    // 7. Climax Champion Title Overlay (96px bold Impact!)
    if (elapsed > 3.7 && p1) {
        const climT = clamp(ease.anticipate(inv(elapsed, 4.2, 5.35), 0.1), 0.001, 1);
        ctx.save();
        ctx.scale(climT, climT);
        ctx.translate(W / 2 * (1 / climT - 1), 440 * (1 / climT - 1));

        ctx.fillStyle = brandRed;
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 5;
        ctx.font = 'italic bold 96px Impact, sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        
        ctx.strokeText('MATCH MVP', W / 2, 480);
        ctx.fillText('MATCH MVP', W / 2, 480);
        ctx.fillStyle = '#111111';
        ctx.font = 'bold 54px Impact, sans-serif';
        ctx.strokeText('DELLA PARTITA', W / 2, 555);
        ctx.fillText('DELLA PARTITA', W / 2, 555);
        ctx.restore();
    }

    // 8. Custom Subtitle and Event Footer Plate
    if (elapsed > 5.0) {
        const footT = ease.anticipate(inv(elapsed, 5.65, 6.95), 0.08);
        ctx.save();
        ctx.translate(0, lerp(200, 0, footT));

        ctx.fillStyle = paper;
        ctx.strokeStyle = ink;
        ctx.lineWidth = 3;
        drawRoundedRect(ctx, W / 2 - 350, H - 210, 700, 80, 8);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = ink;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        fitText(ctx, getFooterText(), W / 2, H - 170 + 2, 640, 36, 18, 'Impact, sans-serif');
        ctx.restore();
    }

    // 9. End on a clean dissolve to black
    drawEndDissolve(ctx, elapsed);
};

let startTime = 0;
const tick = (timestamp: number) => {
    if (!startTime) startTime = timestamp;
    const elapsed = (timestamp - startTime) / 1000;

    const canvas = canvasRef.value;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

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

const exportVideo = () => {
    const canvas = canvasRef.value;
    if (!canvas) return;
    stopPlayback();
    status.value = 'recording';
    startTime = 0;
    recordedChunks.value = [];
    recordProgress.value = 0;

    const stream = canvas.captureStream(60);
    const mimeType = getSupportedVideoType();
    const videoBitsPerSecond = highBitrate.value ? 45000000 : 14000000;
    const options = {
        ...(mimeType ? { mimeType } : {}),
        videoBitsPerSecond,
    };

    try {
        mediaRecorder.value = new MediaRecorder(stream, options);
    } catch (e) {
        mediaRecorder.value = new MediaRecorder(stream, { videoBitsPerSecond: highBitrate.value ? 32000000 : 12000000 });
    }

    mediaRecorder.value.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
            recordedChunks.value.push(event.data);
        }
    };

    mediaRecorder.value.onstop = () => {
        const blobType = mediaRecorder.value?.mimeType || mimeType || recordedChunks.value[0]?.type || 'video/webm';
        const blob = new Blob(recordedChunks.value, { type: blobType });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        const matchup = getSafeFilenamePart(getMatchupLabel());
        a.download = `match-mvp-${matchup}-${Date.now()}.${getVideoExtension(blobType)}`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        status.value = 'ready';
        drawStaticFrame();
    };

    mediaRecorder.value.start();

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

watch(() => props.match, (newMatch) => {
    if (newMatch) {
        customSubtitle.value = `${getTeamName(newMatch.team1_id)} VS ${getTeamName(newMatch.team2_id)}`.toUpperCase();
        preloadAssets();
    }
}, { immediate: true });
</script>

<template>
    <div class="bg-cement border-4 border-black p-4 sm:p-6 flex flex-col xl:flex-row gap-6 shadow-[6px_6px_0px_rgba(0,0,0,1)]">
        
        <!-- Left: Preview Canvas -->
        <div class="flex-1 flex flex-col items-center justify-center bg-zinc-200 border-4 border-black p-3 sm:p-5 relative overflow-hidden min-h-[520px] shadow-[4px_4px_0px_rgba(0,0,0,0.15)]">
            <div class="absolute inset-0 bg-gradient-to-b from-zinc-100 to-zinc-300"></div>
            <div class="absolute inset-0 opacity-20 bg-[radial-gradient(rgba(0,0,0,0.25)_1px,transparent_1px)] [background-size:16px_16px]" aria-hidden="true"></div>
            <canvas
                ref="canvasRef"
                :width="W * SCALE"
                :height="H * SCALE"
                class="relative z-10 w-auto h-[68vh] max-h-[720px] max-w-full border-4 border-black bg-white aspect-[9/16] object-contain shadow-[6px_6px_0px_rgba(0,0,0,0.15)] transition-transform duration-500 ease-out animate-in zoom-in-95 duration-700"
            ></canvas>

            <div v-if="status === 'loading'" class="absolute inset-0 bg-white/90 flex flex-col items-center justify-center gap-3">
                <Icon name="mdi:loading" class="animate-spin text-5xl text-primary" />
                <span class="font-impact text-xs uppercase tracking-widest text-black">Caricamento Foto...</span>
            </div>

            <div v-if="status === 'recording'" class="absolute inset-0 bg-white/95 flex flex-col items-center justify-center gap-4">
                <Icon name="mdi:record-circle" class="text-6xl text-red-600 animate-pulse" />
                <span class="font-impact text-2xl uppercase tracking-widest text-black">Generazione Video...</span>
                <div class="w-64 bg-zinc-200 border-2 border-black p-1 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                    <div class="h-4 bg-primary transition-all duration-100" :style="{ width: `${recordProgress}%` }"></div>
                </div>
                <span class="font-impact text-sm text-primary tracking-widest">{{ recordProgress }}% COMPLETATO</span>
                <span class="text-xs text-zinc-500 font-bold uppercase tracking-wider">Non chiudere la pagina</span>
            </div>
        </div>

        <!-- Right: Control Panel Customizer -->
        <div class="w-full xl:w-[25rem] flex flex-col gap-6 justify-between bg-white border-4 border-black p-5 shadow-[4px_4px_0px_rgba(0,0,0,0.15)]">
            <div class="space-y-5">
                <div>
                    <div class="inline-flex items-center gap-2 bg-black text-white border-2 border-black px-3 py-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                        <Icon name="mdi:movie-open-star" class="text-white text-lg" />
                        <span class="font-impact text-xs tracking-widest">CREATIVE STYLE</span>
                    </div>
                    <h3 class="font-impact text-3xl uppercase tracking-wider text-black border-b-4 border-black pb-2 mt-3 inline-block">
                        Match MVP Video Story
                    </h3>
                    <p class="text-xs text-zinc-600 font-bold uppercase tracking-wider mt-2 leading-relaxed">
                        Esporta un video minimalista, pulito ed elegante da condividere su Instagram e TikTok per celebrare l'MVP della partita!
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
                        <label class="block text-xs font-impact text-secondary uppercase tracking-widest mb-1.5">Sottotitolo Matchup</label>
                        <input
                            v-model="customSubtitle"
                            type="text"
                            class="w-full bg-white border-2 border-black text-black font-impact uppercase tracking-wider px-3 py-2 text-sm focus:outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                            placeholder="Sottotitolo Matchup"
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
                <div class="bg-zinc-50 border-2 border-black p-4 space-y-3 shadow-[2px_2px_0px_rgba(0,0,0,1)]">
                    <h4 class="font-impact text-xs uppercase tracking-widest text-black">Opzioni Esportazione</h4>
                    <label class="flex items-center gap-3 cursor-pointer">
                        <input
                            type="checkbox"
                            v-model="highBitrate"
                            class="w-5 h-5 bg-white border-2 border-black checked:bg-black accent-black"
                        />
                        <span class="text-xs text-zinc-700 font-bold uppercase tracking-wider">Alta Qualità (60 FPS / 45 Mbps)</span>
                    </label>
                    <p class="text-[10px] text-zinc-500 font-medium uppercase tracking-wide leading-relaxed">
                        * L'esportazione genererà un file video in formato WebM ad alta definizione pronto all'uso.
                    </p>
                </div>
            </div>

            <!-- Action buttons -->
            <div class="flex flex-col gap-3 pt-4 border-t-4 border-black">
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
                    class="btn-skewed w-full py-4 !bg-black hover:!bg-gray-900 disabled:opacity-50 active:scale-95 transition-transform"
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
