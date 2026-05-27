<!-- app/components/admin/WinnerTeaser.vue -->
<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, computed } from 'vue';

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
    winnerTeam: Team;
    loserTeam: Team;
    winnerPlayers: Player[];
}>();

const canvasRef = ref<HTMLCanvasElement | null>(null);
const rafId = ref<number | null>(null);
const status = ref<'idle' | 'loading' | 'ready' | 'playing' | 'recording' | 'done'>('idle');
const recordProgress = ref(0);

// Exporter settings
const customTitle = ref('CAMPIONI DELLA SERATA');
const customText = ref('VITTORIA MERITATA!');
const customVenue = ref('ZONA PRATI');
const goldColor = ref('#FFD700'); // Shiny Gold
const accentColor = ref('#FF8C00'); // Neon Orange/Dark Gold
const highBitrate = ref(true);

const duration = 11.5;
const outroDuration = 1.8;
const W = 1080;
const H = 1920;
const SCALE = 2; // Output 4K / 2K vertical resolution

// Image preloaders cache
const preloadedImages = ref<Record<string, HTMLImageElement>>({});

// Recording chunks
const recordedChunks = ref<Blob[]>([]);
const mediaRecorder = ref<MediaRecorder | null>(null);

const winnerScore = computed(() => {
    if (!props.match || !props.winnerTeam) return 0;
    return props.match.winner_id === props.match.team1_id
        ? props.match.team1_score || 0
        : props.match.team2_score || 0;
});

const loserScore = computed(() => {
    if (!props.match || !props.winnerTeam) return 0;
    return props.match.winner_id === props.match.team1_id
        ? props.match.team2_score || 0
        : props.match.team1_score || 0;
});

const winnerRecordLabel = computed(() => `${winnerScore.value} - ${loserScore.value}`);

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
    } : { r: 250, g: 204, b: 21 }; // Gold fallback
};

const rgba = (rgb: { r: number; g: number; b: number }, a: number) => `rgba(${rgb.r},${rgb.g},${rgb.b},${a})`;

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

// Image loading helper
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

    // Preload Winner Logo
    if (props.winnerTeam?.logo_url) {
        promises.push(
            loadImage(props.winnerTeam.logo_url)
                .then((img) => { preloadedImages.value['win_logo'] = img; })
                .catch(() => console.warn('CORS/Error loading winner logo.'))
        );
    }

    // Preload Loser Logo
    if (props.loserTeam?.logo_url) {
        promises.push(
            loadImage(props.loserTeam.logo_url)
                .then((img) => { preloadedImages.value['lose_logo'] = img; })
                .catch(() => console.warn('CORS/Error loading loser logo.'))
        );
    }

    // Preload Winner Roster Photos
    props.winnerPlayers.forEach(p => {
        if (p.photo_url) {
            promises.push(
                loadImage(p.photo_url)
                    .then((img) => { preloadedImages.value[`p_${p.id}`] = img; })
                    .catch(() => console.warn(`CORS/Error loading photo for player ${p.name}`))
            );
        }
    });

    try {
        await Promise.all(promises);
    } catch (e) {
        console.error('Error preloading some winner teaser assets:', e);
    } finally {
        status.value = 'ready';
        drawStaticFrame();
    }
};

// Vector team shield logo fallback
const drawShieldLogo = (ctx: CanvasRenderingContext2D, x: number, y: number, size: number, name: string, glowColor: string) => {
    ctx.save();
    ctx.translate(x, y);

    ctx.beginPath();
    ctx.moveTo(0, -size / 2);
    ctx.lineTo(size * 0.4, -size * 0.4);
    ctx.lineTo(size * 0.45, size * 0.1);
    ctx.quadraticCurveTo(size * 0.45, size * 0.45, 0, size * 0.6);
    ctx.quadraticCurveTo(-size * 0.45, size * 0.45, -size * 0.45, size * 0.1);
    ctx.lineTo(-size * 0.45, -size * 0.45);
    ctx.closePath();

    ctx.fillStyle = '#111111';
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 40;
    ctx.fill();
    ctx.shadowBlur = 0;

    ctx.strokeStyle = glowColor;
    ctx.lineWidth = 10;
    ctx.stroke();

    ctx.font = `italic 900 ${size * 0.55}px 'Impact', sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText((name || 'W').charAt(0).toUpperCase(), 0, 5);

    ctx.restore();
};

// Player picture avatar badge
const drawPlayerAvatar = (ctx: CanvasRenderingContext2D, x: number, y: number, radius: number, player: Player, glowColor: string, imgKey: string) => {
    ctx.save();
    ctx.translate(x, y);

    ctx.beginPath();
    ctx.arc(0, 0, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#1A1A1A';
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 20;
    ctx.fill();

    ctx.strokeStyle = '#FFFFFF';
    ctx.lineWidth = 4;
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(0, 0, radius - 2, 0, Math.PI * 2);
    ctx.clip();

    const img = preloadedImages.value[imgKey];
    if (img) {
        drawImageCover(ctx, img, -radius, -radius, radius * 2, radius * 2);
    } else {
        ctx.fillStyle = '#1A1A1A';
        ctx.fillRect(-radius, -radius, radius * 2, radius * 2);
        
        ctx.font = `italic 900 ${radius * 0.9}px 'Impact', sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = glowColor;
        ctx.fillText(String(player.jersey_number || '#'), 0, 0);
    }

    ctx.beginPath();
    ctx.arc(0, 0, radius - 2, 0, Math.PI * 2);
    ctx.strokeStyle = glowColor;
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.restore();

    // Name under badge
    ctx.save();
    ctx.translate(x, y);
    ctx.font = `900 24px 'Barlow Condensed', sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    
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

// Celebration floating particles
interface CelebrationParticle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    size: number;
    opacity: number;
    life: number;
    speed: number;
    symbol: string;
    angle: number;
    spin: number;
}

const particlesList = ref<CelebrationParticle[]>([]);

const initCelebrationParticles = () => {
    particlesList.value = Array.from({ length: 90 }, () => ({
        x: Math.random() * W,
        y: H + Math.random() * 200,
        vx: (Math.random() - 0.5) * 2.5,
        vy: -Math.random() * 3.5 - 2.0, // Floating up rapidly
        size: Math.random() * 16 + 8,
        opacity: Math.random() * 0.7 + 0.3,
        life: 0,
        speed: Math.random() * 0.006 + 0.002,
        symbol: ['★', '🏆', '✦', '✨'][Math.floor(Math.random() * 4)],
        angle: Math.random() * Math.PI * 2,
        spin: (Math.random() - 0.5) * 0.05
    }));
};

// Main draw framework
const animateTimeline = (isRecording: boolean) => {
    const canvas = canvasRef.value;
    if (!canvas) return;
    const ctx = canvas.getContext('2d')!;

    const rgbGold = hexToRgb(goldColor.value);
    const rgbAccent = hexToRgb(accentColor.value);

    let startTs: number | null = null;

    const drawFrame = (ts: number) => {
        if (!startTs) startTs = ts;
        const elapsed = (ts - startTs) / 1000;
        recordProgress.value = Math.min(100, Math.floor((elapsed / duration) * 100));

        // Update particles
        particlesList.value.forEach(p => {
            p.x += p.vx + Math.sin(p.life * 10 + p.x) * 0.5;
            p.y += p.vy;
            p.life += p.speed;
            p.angle += p.spin;
            if (p.life > 1 || p.y < -50) {
                p.x = Math.random() * W;
                p.y = H + 50;
                p.life = 0;
                p.opacity = Math.random() * 0.7 + 0.3;
            }
        });

        // Setup dimensions & high-res scaling
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, W * SCALE, H * SCALE);
        ctx.scale(SCALE, SCALE);

        // ╔══ BASE GRADIENT BG (Celebration Dark) ══╗
        ctx.fillStyle = '#09090B';
        ctx.fillRect(0, 0, W, H);

        // Grid lines overlay
        ctx.strokeStyle = 'rgba(255,255,255,0.01)';
        ctx.lineWidth = 2;
        const gridGap = 80;
        for (let x = 0; x < W; x += gridGap) {
            ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
        }
        for (let y = 0; y < H; y += gridGap) {
            ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
        }

        // Gentle camera drift with restrained impact motion.
        ctx.save();
        ctx.translate(Math.sin(elapsed * 0.45) * 7, Math.cos(elapsed * 0.38) * 6);
        if (elapsed > 0.8 && elapsed < 1.3) {
            const shake = Math.sin(elapsed * 68) * 7 * (1 - inv(elapsed, 0.8, 1.3));
            ctx.translate(shake, -shake);
        } else if (elapsed > 7.4 && elapsed < 7.8) {
            const shake = Math.sin(elapsed * 62) * 5 * (1 - inv(elapsed, 7.4, 7.8));
            ctx.translate(-shake, shake);
        }

        // Golden backdrop spotlights
        const introT = ease.outQuart(inv(elapsed, 0.0, 1.5));
        const centerGrd = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, W * 0.95);
        centerGrd.addColorStop(0, rgba(rgbGold, 0.22 * introT));
        centerGrd.addColorStop(0.5, rgba(rgbAccent, 0.06 * introT));
        centerGrd.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = centerGrd;
        ctx.fillRect(0, 0, W, H);

        // Slashed diagonal spotlight bands in gold
        ctx.save();
        ctx.fillStyle = 'rgba(255,215,0,0.02)';
        drawSkewedRect(ctx, W * 0.1, -100, 200, H + 200, 150);
        ctx.fill();
        drawSkewedRect(ctx, W * 0.6, -100, 280, H + 200, 150);
        ctx.fill();
        ctx.restore();

        // Render celebratory floating elements
        particlesList.value.forEach(p => {
            ctx.save();
            ctx.translate(p.x, p.y);
            ctx.rotate(p.angle);
            ctx.globalAlpha = p.opacity * Math.sin(p.life * Math.PI);
            ctx.fillStyle = goldColor.value;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 12;
            ctx.font = `${p.size}px 'Arial', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(p.symbol, 0, 0);
            ctx.restore();
        });

        // ╔══ PHASE 1: GLORIOUS WINNER IMPACT (0s - 1.5s) ══╗
        if (elapsed < 1.6) {
            const shockT = inv(elapsed, 0.7, 1.4);
            if (shockT > 0 && shockT < 1) {
                ctx.save();
                const ringRadius = lerp(0, W * 1.6, ease.outExpo(shockT));
                const ringAlpha = lerp(1, 0, ease.outCubic(shockT));
                ctx.beginPath();
                ctx.arc(W / 2, H / 2, ringRadius, 0, Math.PI * 2);
                ctx.strokeStyle = `rgba(255,215,0,${ringAlpha})`;
                ctx.lineWidth = lerp(45, 1, shockT);
                ctx.shadowColor = goldColor.value;
                ctx.shadowBlur = 30;
                ctx.stroke();
                ctx.restore();
            }
        }

        // Giant Winner Slam Text
        const winnerTextT = ease.spring(inv(elapsed, 0.3, 1.2));
        if (winnerTextT > 0) {
            ctx.save();
            const textScale = lerp(3.5, 1.0, winnerTextT);
            ctx.translate(W / 2, H * 0.28);
            ctx.scale(textScale, textScale);
            ctx.globalAlpha = clamp(winnerTextT * 1.5, 0, 1);

            ctx.font = `italic 900 135px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            
            // Gold metallic glowing gradients for text
            const txtGrd = ctx.createLinearGradient(-300, 0, 300, 0);
            txtGrd.addColorStop(0, '#FFFFFF');
            txtGrd.addColorStop(0.3, goldColor.value);
            txtGrd.addColorStop(0.7, accentColor.value);
            txtGrd.addColorStop(1, '#FFFFFF');
            
            ctx.fillStyle = txtGrd;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 35;
            ctx.fillText('VINCITORI', 0, 0);
            ctx.restore();
        }

        // ╔══ PHASE 2: TEAM SHOWCASE PODIUM (1.5s - 4.5s) ══╗
        const stage1T = inv(elapsed, 1.5, 4.5);
        if (stage1T > 0 && stage1T < 1) {
            const intro = ease.spring(inv(elapsed, 1.5, 2.3));
            const outro = ease.outExpo(inv(elapsed, 4.2, 4.5));
            const opacity = (1 - outro) * clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Podium pedestal shape
            ctx.save();
            ctx.translate(W / 2, H * 0.46);
            ctx.scale(intro, intro);
            
            const pedW = 380;
            const pedH = 60;
            ctx.fillStyle = '#1C1C22';
            ctx.strokeStyle = goldColor.value;
            ctx.lineWidth = 5;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 20;
            drawSkewedRect(ctx, -pedW / 2, 200, pedW, pedH, 15);
            ctx.fill();
            ctx.stroke();
            ctx.shadowBlur = 0;
            ctx.restore();

            // Team Large Name Showcase
            ctx.font = `italic 900 86px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = accentColor.value;
            ctx.shadowBlur = 25;
            ctx.fillText(props.winnerTeam.name.toUpperCase(), W / 2, H * 0.46 + 310);
            ctx.shadowBlur = 0;

            // "CAMPIONI DELLA SERATA" subtitle banner
            ctx.font = `900 24px 'Barlow Condensed', sans-serif`;
            ctx.fillStyle = goldColor.value;
            ctx.letterSpacing = '8px';
            ctx.fillText(customText.value.toUpperCase(), W / 2 + 4, H * 0.46 + 380);
            ctx.letterSpacing = '0px';

            // Zooming Team Logo Shield
            const logoScale = lerp(0, 1, ease.spring(inv(elapsed, 1.8, 2.6)));
            if (logoScale > 0) {
                const logoSize = 290;
                const lx = W / 2;
                const ly = H * 0.50;
                const logoImg = preloadedImages.value['win_logo'];
                
                if (logoImg) {
                    ctx.save();
                    ctx.translate(lx, ly);
                    ctx.scale(logoScale, logoScale);
                    ctx.beginPath();
                    ctx.arc(0, 0, logoSize / 2, 0, Math.PI * 2);
                    ctx.clip();
                    drawImageCover(ctx, logoImg, -logoSize / 2, -logoSize / 2, logoSize, logoSize);
                    ctx.strokeStyle = goldColor.value;
                    ctx.lineWidth = 8;
                    ctx.stroke();
                    ctx.restore();
                } else {
                    drawShieldLogo(ctx, lx, ly, logoSize * 1.15, props.winnerTeam.name, goldColor.value);
                }
            }

            ctx.restore();
        }

        // ╔══ PHASE 3: CHAMPIONS ROSTER COLLAGE (4.5s - 7.5s) ══╗
        const stage2T = inv(elapsed, 4.5, 7.5);
        if (stage2T > 0 && stage2T < 1) {
            const intro = ease.spring(inv(elapsed, 4.5, 5.3));
            const outro = ease.outExpo(inv(elapsed, 7.2, 7.5));
            const opacity = (1 - outro) * clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Showcase Header
            ctx.font = `italic 900 64px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.fillStyle = '#FFFFFF';
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 15;
            ctx.fillText('LA ROSA DEI CAMPIONI', W / 2, H * 0.38);
            ctx.shadowBlur = 0;

            // Subtitle
            ctx.font = `900 24px 'Barlow Condensed', sans-serif`;
            ctx.fillStyle = accentColor.value;
            ctx.letterSpacing = '6px';
            ctx.fillText(props.winnerTeam.name.toUpperCase(), W / 2 + 3, H * 0.43);
            ctx.letterSpacing = '0px';

            // Show all winning players dynamically arranged in a clean grid
            const showPlayers = props.winnerPlayers;
            const count = showPlayers.length;

            if (count > 0) {
                // Calculate grid arrangement
                let cols = 3;
                if (count <= 3) cols = count;
                else if (count === 4) cols = 2; // balanced 2x2 grid
                else if (count <= 6) cols = 3;  // 3x2 grid
                else cols = 4;                 // 4xN grid

                const rows = Math.ceil(count / cols);

                // Grid boundary bounding box
                const startY = 480;
                const endY = H * 0.68;
                const gridH = endY - startY;

                const cellW = W / (cols + 1);
                const cellH = gridH / rows;
                // Automatically scale player card badge radius based on player count and cell sizes
                const radius = Math.min(cellW * 0.38, cellH * 0.35, 95);

                showPlayers.forEach((p, idx) => {
                    const colIdx = idx % cols;
                    const rowIdx = Math.floor(idx / cols);

                    // Center-align items in the final row if it's not a full row
                    let itemsInThisRow = cols;
                    const isLastRow = rowIdx === rows - 1;
                    if (isLastRow) {
                        const remainder = count % cols;
                        if (remainder > 0) itemsInThisRow = remainder;
                    }

                    const rowW = itemsInThisRow * cellW;
                    const px = W / 2 - rowW / 2 + colIdx * cellW + cellW / 2;
                    const py = startY + rowIdx * cellH + cellH / 2;

                    const pIntro = ease.spring(inv(elapsed, 4.8 + idx * 0.1, 5.6 + idx * 0.1));
                    if (pIntro > 0) {
                        ctx.save();
                        ctx.translate(0, lerp(120, 0, pIntro));
                        ctx.globalAlpha = opacity * pIntro;
                        drawPlayerAvatar(ctx, px, py, radius, p, goldColor.value, `p_${p.id}`);
                        ctx.restore();
                    }
                });
            }

            ctx.restore();
        }

        // ╔══ PHASE 4: FINAL TRIUMPH SCORE CARD (7.5s - 10.0s) ══╗
        const stage3T = inv(elapsed, 7.5, 10.0);
        if (stage3T > 0) {
            const intro = ease.spring(inv(elapsed, 7.5, 8.4));
            const opacity = clamp(intro * 1.5, 0, 1);

            ctx.save();
            ctx.globalAlpha = opacity;

            // Draw Winner Shield (Left)
            const winLogoImg = preloadedImages.value['win_logo'];
            const t1Lx = W * 0.28;
            const t1Ly = H * 0.38 + Math.sin(elapsed * 2) * 5;
            if (winLogoImg) {
                ctx.save();
                ctx.translate(t1Lx, t1Ly);
                ctx.scale(intro, intro);
                ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
                drawImageCover(ctx, winLogoImg, -140, -140, 280, 280);
                ctx.strokeStyle = goldColor.value; ctx.lineWidth = 8; ctx.stroke();
                ctx.restore();
            } else {
                drawShieldLogo(ctx, t1Lx, t1Ly, 280, props.winnerTeam.name, goldColor.value);
            }

            // Draw Loser Shield (Right)
            const loseLogoImg = preloadedImages.value['lose_logo'];
            const t2Lx = W * 0.72;
            const t2Ly = H * 0.38 - Math.sin(elapsed * 2) * 5;
            if (loseLogoImg) {
                ctx.save();
                ctx.translate(t2Lx, t2Ly);
                ctx.scale(intro, intro);
                ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
                drawImageCover(ctx, loseLogoImg, -140, -140, 280, 280);
                ctx.strokeStyle = 'rgba(255,255,255,0.2)'; ctx.lineWidth = 6; ctx.stroke();
                ctx.restore();
            } else {
                drawShieldLogo(ctx, t2Lx, t2Ly, 280, props.loserTeam.name, '#555555');
            }

            // Names below logos
            ctx.font = `italic 900 52px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.fillStyle = goldColor.value;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 10;
            ctx.fillText(props.winnerTeam.name.toUpperCase(), t1Lx, H * 0.38 + 200);

            ctx.fillStyle = '#888888';
            ctx.shadowBlur = 0;
            ctx.fillText(props.loserTeam.name.toUpperCase(), t2Lx, H * 0.38 + 200);

            // Giant Matchday Title
            ctx.font = `italic 900 64px 'Impact', sans-serif`;
            ctx.fillStyle = '#FFFFFF';
            ctx.fillText(customTitle.value.toUpperCase(), W / 2, H * 0.18 + Math.sin(elapsed * 4) * 4);

            // Final score skewed gold banner
            const finalScoreStr = `${props.match.team1_score} - ${props.match.team2_score}`;
            const vsScale = lerp(3.5, 1, ease.spring(inv(elapsed, 7.8, 8.5)));
            ctx.save();
            ctx.translate(W / 2, H * 0.38);
            ctx.scale(vsScale, vsScale);
            
            ctx.fillStyle = '#09090B';
            ctx.strokeStyle = goldColor.value;
            ctx.lineWidth = 6;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 30;
            drawRoundRect(ctx, -140, -75, 280, 150, 15);
            ctx.fill(); ctx.stroke();
            ctx.shadowBlur = 0;

            ctx.font = `italic 900 74px 'Impact', sans-serif`;
            ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
            ctx.fillStyle = '#FFFFFF';
            ctx.fillText(finalScoreStr, 0, 0);

            // "VICTORY" stamp below score
            ctx.font = `900 18px 'Barlow Condensed', sans-serif`;
            ctx.fillStyle = goldColor.value;
            ctx.letterSpacing = '4px';
            ctx.fillText('RISULTATO FINALE', 0, 52);
            ctx.restore();

            // Bottom skewed info badge
            const cardIntro = ease.spring(inv(elapsed, 8.1, 8.9));
            if (cardIntro > 0) {
                ctx.save();
                ctx.translate(0, lerp(150, 0, cardIntro));
                ctx.globalAlpha = opacity * cardIntro;

                const boxW = 860, boxH = 110;
                const bx = W / 2 - boxW / 2, by = H * 0.64;

                ctx.fillStyle = '#111111'; ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 4;
                drawSkewedRect(ctx, bx, by, boxW, boxH, 15);
                ctx.fill(); ctx.stroke();

                ctx.font = `italic 900 50px 'Impact', sans-serif`;
                ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
                ctx.fillStyle = goldColor.value;
                ctx.shadowColor = goldColor.value; ctx.shadowBlur = 10;
                ctx.fillText('🏆 SQUADRA VINCITRICE 🏆', W / 2, by + boxH / 2 + 3);
                ctx.shadowBlur = 0;

                const subBoxW = 740, subBoxH = 80;
                const sbx = W / 2 - subBoxW / 2, sby = H * 0.73;

                ctx.fillStyle = '#1E1E1E'; ctx.strokeStyle = accentColor.value; ctx.lineWidth = 3;
                drawSkewedRect(ctx, sbx, sby, subBoxW, subBoxH, 10);
                ctx.fill(); ctx.stroke();

                ctx.font = `900 32px 'Barlow Condensed', sans-serif`;
                ctx.fillStyle = '#FFFFFF';
                ctx.fillText(customVenue.value.toUpperCase(), W / 2, sby + subBoxH / 2 + 2);

                // Celebratory shout
                ctx.font = `italic 900 42px 'Impact', sans-serif`;
                ctx.fillStyle = goldColor.value;
                ctx.fillText('CONGRATULAZIONI AI VINCITORI! 🥇🔥', W / 2, H * 0.85);

                ctx.restore();
            }

            ctx.restore();
        }

        // Bottom progress timer bar
        const prg = clamp(elapsed / duration, 0, 1);
        ctx.fillStyle = 'rgba(255,255,255,0.06)';
        ctx.fillRect(0, H - 12, W, 12);
        
        const pbGrd = ctx.createLinearGradient(0, 0, W * prg, 0);
        pbGrd.addColorStop(0, goldColor.value);
        pbGrd.addColorStop(1, accentColor.value);
        ctx.fillStyle = pbGrd;
        ctx.fillRect(0, H - 12, W * prg, 12);

        // Outro black fade
        if (elapsed > duration - outroDuration) {
            const fade = ease.inOutSine(inv(elapsed, duration - outroDuration, duration));
            ctx.fillStyle = `rgba(9,9,11,${fade})`;
            ctx.fillRect(0, 0, W, H);

            const outroT = inv(elapsed, duration - outroDuration, duration);
            ctx.font = `italic 900 66px 'Impact', sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillStyle = `rgba(255,255,255,${Math.sin(outroT * Math.PI) * 0.95})`;
            ctx.shadowColor = goldColor.value;
            ctx.shadowBlur = 14;
            ctx.fillText(props.winnerTeam.name.toUpperCase(), W / 2, H / 2 - 35);
            ctx.font = `900 28px 'Barlow Condensed', sans-serif`;
            ctx.letterSpacing = '7px';
            ctx.fillStyle = `rgba(255,215,0,${Math.sin(outroT * Math.PI) * 0.9})`;
            ctx.fillText('VINCITORI', W / 2 + 4, H / 2 + 42);
            ctx.letterSpacing = '0px';
            ctx.shadowBlur = 0;
        }

        ctx.restore();

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

// Static preview screen loader
const drawStaticFrame = () => {
    const canvas = canvasRef.value;
    if (!canvas || status.value !== 'ready') return;
    const ctx = canvas.getContext('2d')!;

    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, W * SCALE, H * SCALE);
    ctx.scale(SCALE, SCALE);

    // Dark Background Grid
    ctx.fillStyle = '#09090B';
    ctx.fillRect(0, 0, W, H);

    ctx.strokeStyle = 'rgba(255,255,255,0.01)';
    ctx.lineWidth = 2;
    const gridGap = 80;
    for (let x = 0; x < W; x += gridGap) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
    }
    for (let y = 0; y < H; y += gridGap) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
    }

    // Spotlights
    const centerGrd = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, W * 0.95);
    centerGrd.addColorStop(0, rgba(hexToRgb(goldColor.value), 0.18));
    centerGrd.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = centerGrd; ctx.fillRect(0, 0, W, H);

    // Giant Title
    ctx.font = `italic 900 135px 'Impact', sans-serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    const txtGrd = ctx.createLinearGradient(-300, 0, 300, 0);
    txtGrd.addColorStop(0, '#FFFFFF'); txtGrd.addColorStop(0.5, goldColor.value); txtGrd.addColorStop(1, '#FFFFFF');
    ctx.fillStyle = txtGrd;
    ctx.shadowColor = goldColor.value; ctx.shadowBlur = 35;
    ctx.fillText('VINCITORI', W / 2, H * 0.28);
    ctx.shadowBlur = 0;

    // Draw Winner Shield Left / Loser Shield Right
    const winLogoImg = preloadedImages.value['win_logo'];
    const t1Lx = W * 0.28, t1Ly = H * 0.38;
    if (winLogoImg) {
        ctx.save(); ctx.translate(t1Lx, t1Ly);
        ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
        drawImageCover(ctx, winLogoImg, -140, -140, 280, 280);
        ctx.strokeStyle = goldColor.value; ctx.lineWidth = 8; ctx.stroke();
        ctx.restore();
    } else {
        drawShieldLogo(ctx, t1Lx, t1Ly, 280, props.winnerTeam.name, goldColor.value);
    }

    const loseLogoImg = preloadedImages.value['lose_logo'];
    const t2Lx = W * 0.72, t2Ly = H * 0.38;
    if (loseLogoImg) {
        ctx.save(); ctx.translate(t2Lx, t2Ly);
        ctx.beginPath(); ctx.arc(0, 0, 140, 0, Math.PI * 2); ctx.clip();
        drawImageCover(ctx, loseLogoImg, -140, -140, 280, 280);
        ctx.strokeStyle = 'rgba(255,255,255,0.2)'; ctx.lineWidth = 6; ctx.stroke();
        ctx.restore();
    } else {
        drawShieldLogo(ctx, t2Lx, t2Ly, 280, props.loserTeam.name, '#555555');
    }

    // Winner score badge
    const finalScoreStr = `${props.match.team1_score} - ${props.match.team2_score}`;
    ctx.save();
    ctx.translate(W / 2, H * 0.38);
    ctx.fillStyle = '#09090B'; ctx.strokeStyle = goldColor.value; ctx.lineWidth = 6;
    ctx.shadowColor = goldColor.value; ctx.shadowBlur = 20;
    drawRoundRect(ctx, -140, -75, 280, 150, 15);
    ctx.fill(); ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.font = `italic 900 74px 'Impact', sans-serif`;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(finalScoreStr, 0, 0);
    ctx.restore();

    // Roster preview title text
    ctx.font = `italic 900 52px 'Impact', sans-serif`;
    ctx.textAlign = 'center';
    ctx.fillStyle = goldColor.value;
    ctx.fillText(props.winnerTeam.name.toUpperCase(), t1Lx, H * 0.38 + 200);
    ctx.fillStyle = '#888888';
    ctx.fillText(props.loserTeam.name.toUpperCase(), t2Lx, H * 0.38 + 200);

    // Overlays details
    ctx.font = `italic 900 64px 'Impact', sans-serif`;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(customTitle.value.toUpperCase(), W / 2, H * 0.18);

    const boxW = 860, boxH = 110;
    const bx = W / 2 - boxW / 2, by = H * 0.64;
    ctx.fillStyle = '#111111'; ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 4;
    drawSkewedRect(ctx, bx, by, boxW, boxH, 15);
    ctx.fill(); ctx.stroke();

    ctx.font = `italic 900 50px 'Impact', sans-serif`;
    ctx.fillStyle = goldColor.value;
    ctx.fillText('🏆 SQUADRA VINCITRICE 🏆', W / 2, by + boxH / 2 + 3);

    const subBoxW = 740, subBoxH = 80;
    const sbx = W / 2 - subBoxW / 2, sby = H * 0.73;
    ctx.fillStyle = '#1E1E1E'; ctx.strokeStyle = accentColor.value; ctx.lineWidth = 3;
    drawSkewedRect(ctx, sbx, sby, subBoxW, subBoxH, 10);
    ctx.fill(); ctx.stroke();

    ctx.font = `900 32px 'Barlow Condensed', sans-serif`;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillText(customVenue.value.toUpperCase(), W / 2, sby + subBoxH / 2 + 2);
};

const stopAnimation = () => {
    if (rafId.value) {
        cancelAnimationFrame(rafId.value);
        rafId.value = null;
    }
};

const handlePreview = () => {
    if (status.value === 'loading' || status.value === 'playing' || status.value === 'recording') return;
    initCelebrationParticles();
    status.value = 'playing';
    animateTimeline(false);
};

const handleRecord = () => {
    if (status.value === 'loading' || status.value === 'playing' || status.value === 'recording') return;
    const canvas = canvasRef.value;
    if (!canvas) return;

    recordedChunks.value = [];
    initCelebrationParticles();
    status.value = 'recording';
    recordProgress.value = 0;

    const stream = canvas.captureStream(60);
    let mimeType = 'video/webm;codecs=vp9';
    if (!MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = MediaRecorder.isTypeSupported('video/mp4;codecs=avc1') ? 'video/mp4;codecs=avc1' : 'video/webm';
    }

    const bps = highBitrate.value ? 50000000 : 15000000;

    const recorder = new MediaRecorder(stream, {
        mimeType,
        videoBitsPerSecond: bps
    });

    mediaRecorder.value = recorder;

    recorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
            recordedChunks.value.push(event.data);
        }
    };

    recorder.onstop = () => {
        const fileExt = mimeType.includes('mp4') ? 'mp4' : 'webm';
        const blob = new Blob(recordedChunks.value, { type: mimeType });
        const url = URL.createObjectURL(blob);
        
        const a = document.createElement('a');
        a.href = url;
        const matchTitle = `${props.winnerTeam.name}-win-teaser`.toLowerCase().replace(/\s+/g, '-');
        a.download = `victory-story-${matchTitle}-4K.${fileExt}`;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        
        URL.revokeObjectURL(url);
        a.remove();
        status.value = 'ready';
        drawStaticFrame();
    };

    setTimeout(() => {
        recorder.start();
        animateTimeline(true);
    }, 100);
};

onMounted(() => {
    preloadAssets();
});

watch([goldColor, accentColor, customTitle, customText, customVenue], () => {
    if (status.value === 'ready') {
        drawStaticFrame();
    }
});

// React on dynamic async loaded data
watch(() => [props.winnerTeam, props.loserTeam, props.winnerPlayers], () => {
    preloadAssets();
}, { deep: true });

onUnmounted(() => {
    stopAnimation();
});
</script>

<template>
    <div class="bg-white p-5 md:p-7 space-y-7 border-2 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)] text-black">
        
        <!-- Header -->
        <div class="border-b-2 border-black pb-5 flex flex-col lg:flex-row items-start lg:items-center justify-between gap-5">
            <div>
                <span class="bg-yellow-100 text-black text-xs font-impact px-3 py-1 tracking-widest uppercase mb-2 inline-flex items-center gap-1.5 border border-yellow-500">
                    <Icon name="mdi:trophy" class="text-sm" /> Winner Story
                </span>
                <h2 class="text-3xl font-impact tracking-wider text-black uppercase">Generatore Video Vittoria</h2>
                <p class="text-gray-600 text-sm font-semibold">Esporta una story 9:16 per celebrare il risultato finale.</p>
            </div>
            
            <div class="flex flex-col sm:flex-row lg:flex-col xl:flex-row items-stretch sm:items-center gap-3 w-full lg:w-auto">
                <div class="border-2 border-black bg-cement px-4 py-2 min-w-[170px]">
                    <span class="block text-[10px] font-impact tracking-widest uppercase text-gray-600">Risultato</span>
                    <span class="block font-impact text-3xl leading-none text-black">{{ winnerRecordLabel }}</span>
                </div>

                <div class="border-2 border-black bg-white px-4 py-3 flex items-center gap-2">
                    <span class="inline-block w-3.5 h-3.5 rounded-full"
                    :class="{
                        'bg-red-500 animate-pulse': status === 'recording',
                        'bg-yellow-400 animate-pulse': status === 'playing',
                        'bg-green-500': status === 'ready',
                        'bg-gray-500': status === 'loading'
                    }"
                    />
                    <span class="font-impact text-sm text-black tracking-widest uppercase">
                        {{ status === 'loading' ? 'CARICAMENTO...' : 
                           status === 'playing' ? 'ANTEPRIMA...' : 
                           status === 'recording' ? `EXPORT ${recordProgress}%` : 'PRONTO' }}
                    </span>
                </div>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            
            <!-- Canvas Preview (Col 5) -->
            <div class="lg:col-span-5 flex flex-col items-center justify-center space-y-4">
                <div class="relative w-full max-w-[340px] aspect-[9/16] bg-black border-2 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)] overflow-hidden">
                    <canvas
                        ref="canvasRef"
                        :width="W * SCALE"
                        :height="H * SCALE"
                        class="w-full h-full block"
                    />
                    
                    <div v-if="status === 'recording'" class="absolute inset-0 bg-red-600/10 pointer-events-none border-4 border-red-500 animate-pulse" />
                    <div v-if="status === 'recording'" class="absolute top-4 left-4 bg-black border-2 border-red-500 px-3 py-1 flex items-center gap-2 shadow-md">
                        <span class="w-2.5 h-2.5 rounded-full bg-red-600 animate-ping" />
                        <span class="font-impact text-xs text-red-500 tracking-wider">REC WINNER ({{ recordProgress }}%)</span>
                    </div>

                    <div v-if="status === 'playing'" class="absolute bottom-4 left-0 right-0 text-center pointer-events-none">
                        <span class="bg-yellow-100 text-black px-4 py-1 text-xs font-impact uppercase tracking-widest border border-yellow-500">Anteprima Vittoria (11.5s)</span>
                    </div>
                </div>

                <div class="flex gap-4 w-full max-w-[340px]">
                    <button
                        @click="handlePreview"
                        :disabled="status === 'loading' || status === 'playing' || status === 'recording'"
                        class="btn-skewed-secondary flex-1 !bg-white text-black border-2 border-black"
                    >
                        <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                            <Icon name="mdi:play" /> ANTEPRIMA
                        </span>
                    </button>
                    
                    <button
                        @click="handleRecord"
                        :disabled="status === 'loading' || status === 'playing' || status === 'recording'"
                        class="btn-skewed flex-1 !bg-yellow-300 text-black border-2 border-black"
                    >
                        <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                            <Icon name="mdi:download" /> ESPORTA
                        </span>
                    </button>
                </div>
            </div>

            <!-- Customizer Controls (Col 7) -->
            <div class="lg:col-span-7 space-y-6">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div class="border-2 border-black bg-cement p-4">
                        <span class="block font-impact text-xs tracking-widest uppercase text-gray-600">Vincitore</span>
                        <span class="block font-impact text-2xl tracking-wider uppercase text-black truncate" :title="winnerTeam.name">
                            {{ winnerTeam.name }}
                        </span>
                    </div>
                    <div class="border-2 border-black bg-white p-4">
                        <span class="block font-impact text-xs tracking-widest uppercase text-gray-600">Giocatori in video</span>
                        <span class="block font-impact text-2xl tracking-wider uppercase text-black">
                            {{ winnerPlayers.length }}
                        </span>
                    </div>
                </div>

                <!-- Text Customizer -->
                <div class="space-y-4">
                    <h3 class="text-xl font-impact tracking-widest text-black border-b border-black pb-2 uppercase">Personalizza Story Vittoria</h3>

                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black uppercase">Intestazione / Titolo</label>
                        <input
                            type="text"
                            v-model="customTitle"
                            placeholder="es. MATCHDAY TRIUMPH"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>

                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black uppercase">Messaggio Vittoria</label>
                        <input
                            type="text"
                            v-model="customText"
                            placeholder="es. VITTORIA CONQUISTATA!"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>

                    <div class="flex flex-col space-y-1">
                        <label class="font-impact text-xs tracking-wider text-black uppercase">Arena / Palazzetto</label>
                        <input
                            type="text"
                            v-model="customVenue"
                            placeholder="es. DODGEBALL LEAGUE"
                            class="px-4 py-2 border-2 border-black font-semibold text-black uppercase bg-cement focus:bg-white transition-all focus:outline-none"
                        />
                    </div>
                </div>

                <!-- Tips & Notes -->
                <div class="border-l-2 border-yellow-500 p-4 bg-yellow-50 space-y-2">
                    <h4 class="font-impact text-sm text-black tracking-widest flex items-center gap-1.5 uppercase">
                        <Icon name="mdi:information-outline" class="text-lg" /> Note esportazione
                    </h4>
                    <p class="text-xs text-gray-700 font-semibold leading-relaxed">
                        Esporta una story verticale a <strong>60 FPS</strong>. Il download userà <strong>.mp4</strong> dove supportato dal browser, altrimenti il formato video disponibile.
                    </p>
                </div>

                <!-- Bitrate config -->
                <div class="flex items-center gap-3 p-3 bg-cement border border-black">
                    <input 
                        type="checkbox" 
                        id="highBitrateWinner" 
                        v-model="highBitrate"
                        class="w-5 h-5 cursor-pointer accent-yellow-400"
                    />
                    <label for="highBitrateWinner" class="font-impact text-xs tracking-wider text-black cursor-pointer uppercase select-none">
                        ATTIVA BITRATE ALTO (50 Mbps - MASSIMA FEDELTÀ VIDEO)
                    </label>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
input {
    border-radius: 0px !important;
}
</style>
