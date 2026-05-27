<!-- app/pages/admin/teams/[id].vue -->
<script setup lang="ts">
import { ref, onMounted } from "vue";
definePageMeta({ middleware: ["admin"] });

const route = useRoute();
const client = useSupabaseClient();

const team = ref<any>(null);
const players = ref<any[]>([]);
const previewUrl = ref<string | null>(null);
const fileToUpload = ref<Blob | null>(null);

// New Player form states
const newPlayerName = ref("");
const newPlayerJersey = ref<number | string>("");
const newPlayerPhoto = ref<Blob | null>(null);
const newPlayerPreview = ref<string | null>(null);
const addingPlayer = ref(false);

const fetchData = async () => {
    const { data: teamData } = await client
        .from("teams")
        .select("*")
        .eq("id", route.params.id)
        .single();
    const { data: playerData } = await client
        .from("players")
        .select("*")
        .eq("team_id", route.params.id)
        .order("jersey_number", { ascending: true });
    team.value = teamData;
    players.value = playerData || [];
    previewUrl.value = teamData.logo_url;
};

const compressImage = (file: File): Promise<Blob> => {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.readAsDataURL(file);
        reader.onload = (event) => {
            const img = new Image();
            img.src = event.target?.result as string;
            img.onload = () => {
                const canvas = document.createElement("canvas");
                const MAX_WIDTH = 400;
                const scaleSize = MAX_WIDTH / img.width;
                canvas.width = MAX_WIDTH;
                canvas.height = img.height * scaleSize;
                const ctx = canvas.getContext("2d");
                if (!ctx) return reject(new Error("Failed to get canvas context"));
                
                // Draw initially to analyze pixels
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
                const data = imageData.data;
                
                let totalBrightness = 0;
                let opaquePixels = 0;
                
                for (let i = 0; i < data.length; i += 4) {
                    const r = data[i];
                    const g = data[i + 1];
                    const b = data[i + 2];
                    const a = data[i + 3];
                    
                    if (a > 20) { // Consider mostly opaque pixels
                        const brightness = 0.299 * r + 0.587 * g + 0.114 * b;
                        totalBrightness += brightness;
                        opaquePixels++;
                    }
                }
                
                let avgBrightness = 127;
                if (opaquePixels > 0) {
                    avgBrightness = totalBrightness / opaquePixels;
                }
                
                // Clear and fill with optimal background for contrast
                ctx.clearRect(0, 0, canvas.width, canvas.height);
                ctx.fillStyle = avgBrightness > 127 ? "#000000" : "#ffffff";
                ctx.fillRect(0, 0, canvas.width, canvas.height);
                
                // Redraw the image over the background
                ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

                canvas.toBlob(
                    (blob) => (blob ? resolve(blob) : reject(new Error("Compression failed"))),
                    "image/jpeg",
                    0.8,
                );
            };
        };
    });
};

const onLogoSelected = async (e: Event) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
        const compressed = await compressImage(file);
        fileToUpload.value = compressed;
        previewUrl.value = URL.createObjectURL(compressed);
    } catch (err) {
        alert("Compressione fallita");
    }
};

const onLogoDrop = async (e: DragEvent) => {
    e.preventDefault();
    const file = e.dataTransfer?.files?.[0];
    if (!file) return;
    try {
        const compressed = await compressImage(file);
        fileToUpload.value = compressed;
        previewUrl.value = URL.createObjectURL(compressed);
    } catch (err) {
        alert("Compressione fallita");
    }
};

const updateTeam = async () => {
    if (!team.value.name.trim()) {
        alert("Inserisci il nome della squadra.");
        return;
    }

    let logo_url = team.value.logo_url;
    if (fileToUpload.value) {
        const path = `${team.value.id}-logo.jpg`;
        const { error: uploadError } = await client.storage
            .from("logos")
            .upload(path, fileToUpload.value, {
                upsert: true,
                contentType: "image/jpeg",
            });

        if (uploadError) {
            console.error(uploadError);
            alert("Caricamento logo fallito: " + uploadError.message);
            return;
        }
        logo_url = client.storage.from("logos").getPublicUrl(path)
            .data.publicUrl + `?t=${Date.now()}`;
        
        fileToUpload.value = null; // Clear
    }

    const { error } = await client
        .from("teams")
        .update({ name: team.value.name.trim(), logo_url })
        .eq("id", team.value.id);

    if (error) {
        alert("Aggiornamento squadra fallito: " + error.message);
    } else {
        alert("Squadra aggiornata con successo!");
        fetchData();
    }
};

const updatePlayer = async (p: any) => {
    if (!p.name.trim()) {
        alert("Inserisci il nome del giocatore.");
        return;
    }
    if (p.jersey_number === "") {
        alert("Inserisci il numero di maglia.");
        return;
    }

    const jerseyNumber = typeof p.jersey_number === 'string' ? parseInt(p.jersey_number) : p.jersey_number;
    if (players.value.some((other: any) => other.id !== p.id && other.jersey_number === jerseyNumber)) {
        alert("Esiste già un giocatore con questo numero di maglia.");
        return;
    }

    let photo_url = p.photo_url;
    if (p._fileToUpload) {
        const path = `${p.id}-photo.jpg`;
        const { error: uploadError } = await client.storage
            .from("player-photos")
            .upload(path, p._fileToUpload, {
                upsert: true,
                contentType: "image/jpeg",
            });

        if (uploadError) {
            console.error(uploadError);
            alert("Caricamento foto fallito: " + uploadError.message);
            return;
        }
        photo_url = client.storage.from("player-photos").getPublicUrl(path)
            .data.publicUrl + `?t=${Date.now()}`;
        
        p._fileToUpload = null;
        p.photo_url = photo_url;
    }

    const { error } = await client
        .from("players")
        .update({ name: p.name.trim(), jersey_number: jerseyNumber, photo_url })
        .eq("id", p.id);

    if (error) {
        alert("Aggiornamento giocatore fallito: " + error.message);
    } else {
        alert("Giocatore aggiornato con successo!");
        fetchData();
    }
};

const onPlayerPhotoSelected = async (e: Event, p: any) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
        const compressed = await compressImage(file);
        p._fileToUpload = compressed;
        p._previewUrl = URL.createObjectURL(compressed);
    } catch (err) {
        alert("Compressione fallita");
    }
};

const onNewPlayerPhotoSelected = async (e: Event) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
        const compressed = await compressImage(file);
        newPlayerPhoto.value = compressed;
        newPlayerPreview.value = URL.createObjectURL(compressed);
    } catch (err) {
        alert("Compressione fallita");
    }
};

const addPlayer = async () => {
    if (!newPlayerName.value.trim()) {
        alert("Inserisci il nome del giocatore.");
        return;
    }
    if (newPlayerJersey.value === "") {
        alert("Inserisci il numero di maglia.");
        return;
    }

    const jerseyNumber = typeof newPlayerJersey.value === 'string' ? parseInt(newPlayerJersey.value) : newPlayerJersey.value;
    if (players.value.some((p: any) => p.jersey_number === jerseyNumber)) {
        alert("Esiste già un giocatore con questo numero di maglia.");
        return;
    }

    addingPlayer.value = true;

    try {
        const { data, error } = await client
            .from("players")
            .insert([{
                name: newPlayerName.value.trim(),
                jersey_number: jerseyNumber,
                team_id: route.params.id
            }])
            .select()
            .single();

        if (error) throw error;

        if (newPlayerPhoto.value && data) {
            const path = `${data.id}-photo.jpg`;
            const { error: uploadError } = await client.storage
                .from("player-photos")
                .upload(path, newPlayerPhoto.value, {
                    upsert: true,
                    contentType: "image/jpeg"
                });

            if (uploadError) throw uploadError;

            const photo_url = client.storage.from("player-photos").getPublicUrl(path)
                .data.publicUrl + `?t=${Date.now()}`;

            await client
                .from("players")
                .update({ photo_url })
                .eq("id", data.id);
        }

        alert("Giocatore aggiunto con successo!");
        newPlayerName.value = "";
        newPlayerJersey.value = "";
        newPlayerPhoto.value = null;
        newPlayerPreview.value = null;
        fetchData();
    } catch (err: any) {
        console.error(err);
        alert("Aggiunta fallita: " + err.message);
    } finally {
        addingPlayer.value = false;
    }
};

const deletePlayer = async (id: string) => {
    if (!confirm("Sei sicuro di voler rimuovere questo giocatore dalla rosa?")) return;

    try {
        const { error } = await client
            .from("players")
            .delete()
            .eq("id", id);

        if (error) throw error;

        alert("Giocatore rimosso con successo!");
        fetchData();
    } catch (err: any) {
        alert("Rimozione fallita: " + err.message);
    }
};

onMounted(fetchData);
</script>

<template>
    <div v-if="team" class="max-w-4xl mx-auto p-4 sm:p-8 space-y-8">
        
        <!-- Header -->
        <div class="flex items-center gap-4 mb-6">
            <NuxtLink
                to="/admin"
                class="bg-white border-2 border-black p-3 hover:bg-black hover:text-white transition-all shadow-[2px_2px_0px_rgba(0,0,0,1)] flex items-center justify-center"
            >
                <Icon name="mdi:arrow-left" class="text-xl" />
            </NuxtLink>
            <div>
                <h1 class="text-3xl font-impact uppercase tracking-widest text-black">Modifica Squadra</h1>
                <p class="text-zinc-500 font-semibold text-sm">Aggiorna identità e rosa della squadra in tempo reale.</p>
            </div>
        </div>

        <!-- Team Details Card (Sports Grunge style) -->
        <section class="card-grunge bg-cement p-6 md:p-8 border-4 border-black shadow-[6px_6px_0px_rgba(0,0,0,1)] space-y-6">
            <h2 class="text-xl font-impact tracking-wider text-black border-b-2 border-black pb-2 uppercase">Identità Squadra</h2>
            <div class="flex flex-col md:flex-row gap-6 md:items-end">
                
                <!-- Logo Uploader -->
                <div class="flex flex-col space-y-2 shrink-0">
                    <label class="block text-[10px] font-impact uppercase text-zinc-500">Logo Ufficiale</label>
                    <label
                        @dragover.prevent
                        @drop.prevent="onLogoDrop"
                        class="relative w-28 h-28 bg-white border-4 border-black flex items-center justify-center cursor-pointer hover:border-primary shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-colors overflow-hidden group"
                        title="Trascina o fai clic per caricare il logo"
                    >
                        <img
                            v-if="previewUrl"
                            :src="previewUrl"
                            class="absolute inset-0 w-full h-full object-cover"
                            alt="Logo preview"
                        />
                        <div v-else class="flex flex-col items-center justify-center text-center p-2 text-zinc-400 group-hover:text-primary transition-colors">
                            <Icon name="mdi:image-plus" class="text-3xl" />
                            <span class="text-[8px] font-bold uppercase mt-1">Carica</span>
                        </div>
                        <input type="file" @change="onLogoSelected" class="hidden" />
                    </label>
                </div>

                <!-- Team Name Input -->
                <div class="flex-1 space-y-2">
                    <label class="block text-[10px] font-impact uppercase text-zinc-500">Nome Squadra</label>
                    <input
                        v-model="team.name"
                        class="w-full bg-white border-4 border-black px-4 py-3 font-bold uppercase text-black focus:bg-cement focus:border-primary outline-none shadow-[2px_2px_0px_rgba(0,0,0,1)]"
                        placeholder="NOME SQUADRA"
                    />
                </div>

                <!-- Save Team Details -->
                <button
                    @click="updateTeam"
                    class="w-full md:w-auto btn-skewed !bg-black !text-white border-2 border-black sm:self-end"
                >
                    <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                        <Icon name="mdi:content-save" /> Salva Squadra
                    </span>
                </button>
            </div>
        </section>

        <!-- Dynamic Player Roster Management -->
        <section class="space-y-6">
            <h2 class="text-2xl font-impact tracking-widest text-black uppercase border-b-4 border-black pb-2">Roster Squadra ({{ players.length }})</h2>

            <!-- Add Player Card -->
            <div class="card-grunge bg-zinc-950 text-white p-6 border-4 border-yellow-400 shadow-[6px_6px_0px_rgba(0,0,0,1)] space-y-4">
                <h3 class="font-impact text-xl text-yellow-400 tracking-wider uppercase">Aggiungi Nuovo Giocatore</h3>
                <div class="flex flex-col md:flex-row md:items-end gap-4">
                    
                    <!-- New Player Photo Upload -->
                    <div class="flex flex-col space-y-2 shrink-0">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">Foto</label>
                        <label class="relative w-16 h-16 bg-zinc-900 border-2 border-dashed border-zinc-700 hover:border-yellow-400 overflow-hidden flex items-center justify-center cursor-pointer transition-colors group">
                            <img v-if="newPlayerPreview" :src="newPlayerPreview" class="w-full h-full object-cover" />
                            <Icon v-else name="mdi:image-plus" class="text-2xl text-zinc-500 group-hover:text-yellow-400 transition-colors" />
                            <input type="file" @change="onNewPlayerPhotoSelected" class="hidden" />
                        </label>
                    </div>

                    <!-- New Player Name -->
                    <div class="flex-1 space-y-2">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">Nome Completo</label>
                        <input
                            v-model="newPlayerName"
                            class="w-full bg-zinc-900 border-2 border-zinc-700 px-4 py-2 font-bold text-white uppercase focus:bg-zinc-950 focus:border-yellow-400 outline-none"
                            placeholder="Nome Giocatore"
                        />
                    </div>

                    <!-- New Player Jersey Number -->
                    <div class="w-full md:w-28 space-y-2">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">N. Maglia</label>
                        <input
                            v-model="newPlayerJersey"
                            type="number"
                            class="w-full bg-zinc-900 border-2 border-zinc-700 px-4 py-2 font-bold text-yellow-400 focus:bg-zinc-950 focus:border-yellow-400 outline-none"
                            placeholder="N."
                        />
                    </div>

                    <!-- Add Button -->
                    <button
                        @click="addPlayer"
                        :disabled="addingPlayer"
                        class="w-full md:w-auto btn-skewed !bg-yellow-400 !text-black border-2 border-black"
                    >
                        <span class="btn-skewed-content text-sm flex items-center justify-center gap-2">
                            <Icon name="mdi:account-plus" /> {{ addingPlayer ? 'Aggiunta...' : 'Aggiungi' }}
                        </span>
                    </button>
                </div>
            </div>

            <!-- Players List -->
            <div class="space-y-4">
                <div
                    v-for="p in players"
                    :key="p.id"
                    class="border-4 border-black bg-white shadow-[4px_4px_0px_rgba(0,0,0,1)] p-4 flex flex-col md:flex-row md:items-end gap-4 hover:shadow-[6px_6px_0px_rgba(0,0,0,1)] transition-all"
                >
                    <!-- Player Photo Uploader -->
                    <div class="flex flex-col space-y-1.5 shrink-0">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">Foto</label>
                        <label class="relative w-16 h-16 bg-cement border-2 border-black flex items-center justify-center text-zinc-500 overflow-hidden cursor-pointer hover:border-primary transition-colors">
                            <img
                                v-if="p._previewUrl || p.photo_url"
                                :src="p._previewUrl || p.photo_url"
                                class="w-full h-full object-cover"
                                alt="Player Photo"
                            />
                            <Icon v-else name="mdi:account" class="text-3xl" />
                            <input type="file" @change="(e) => onPlayerPhotoSelected(e, p)" class="hidden" />
                        </label>
                    </div>

                    <!-- Player Name Input -->
                    <div class="flex-1 space-y-1.5">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">Nome Giocatore</label>
                        <input
                            v-model="p.name"
                            class="w-full bg-cement border-2 border-black px-4 py-2.5 font-bold uppercase focus:bg-white focus:border-primary outline-none text-black"
                            placeholder="Nome"
                        />
                    </div>

                    <!-- Player Jersey Input -->
                    <div class="w-full md:w-28 space-y-1.5">
                        <label class="block text-[9px] font-impact uppercase text-zinc-400">N. Maglia</label>
                        <input
                            v-model="p.jersey_number"
                            type="number"
                            class="w-full bg-cement border-2 border-black px-4 py-2.5 font-black text-primary focus:bg-white focus:border-primary outline-none"
                            placeholder="N."
                        />
                    </div>

                    <!-- Actions Panel -->
                    <div class="flex items-center gap-2 sm:mb-0 pt-2 w-full md:w-auto shrink-0">
                        <button
                            @click="updatePlayer(p)"
                            class="flex-1 md:flex-initial bg-black text-white px-5 py-3 font-impact uppercase text-xs hover:bg-zinc-800 transition-all border-2 border-black flex items-center justify-center gap-1.5 shadow-[2px_2px_0px_rgba(0,0,0,1)] active:scale-95"
                        >
                            <Icon name="mdi:check" /> Salva
                        </button>
                        <button
                            @click="deletePlayer(p.id)"
                            class="bg-red-600 text-white p-3 hover:bg-black hover:text-white transition-all border-2 border-black flex items-center justify-center shadow-[2px_2px_0px_rgba(0,0,0,1)] active:scale-95"
                            title="Elimina giocatore"
                        >
                            <Icon name="mdi:trash-can-outline" class="text-lg" />
                        </button>
                    </div>
                </div>
                
                <div v-if="players.length === 0" class="text-center py-12 bg-white border-4 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)] font-bold italic text-zinc-400">
                    Nessun giocatore registrato in rosa. Aggiungi il primo sopra!
                </div>
            </div>
        </section>
    </div>
</template>
