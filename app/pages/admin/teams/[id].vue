// app/pages/admin/teams/[id].vue
<script setup lang="ts">
definePageMeta({ middleware: ["admin"] });
const route = useRoute();
const client = useSupabaseClient();

const team = ref<any>(null);
const players = ref<any[]>([]);
const previewUrl = ref<string | null>(null);
const fileToUpload = ref<Blob | null>(null);

const fetchData = async () => {
    const { data: teamData } = await client
        .from("teams")
        .select("*")
        .eq("id", route.params.id)
        .single();
    const { data: playerData } = await client
        .from("players")
        .select("*")
        .eq("team_id", route.params.id);
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



const updateTeam = async () => {
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
            alert("Caricamento fallito: " + uploadError.message);
            return;
        }
        logo_url = client.storage.from("logos").getPublicUrl(path)
            .data.publicUrl + `?t=${Date.now()}`;
        
        fileToUpload.value = null; // Clear the uploaded file to avoid re-uploading on next save
    }

    await client
        .from("teams")
        .update({ name: team.value.name, logo_url })
        .eq("id", team.value.id);
    alert("Squadra aggiornata!");
    fetchData();
};

const updatePlayer = async (p: any) => {
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
            alert("Caricamento fallito: " + uploadError.message);
            return;
        }
        photo_url = client.storage.from("player-photos").getPublicUrl(path)
            .data.publicUrl + `?t=${Date.now()}`;
        
        p._fileToUpload = null;
        p.photo_url = photo_url;
    }

    await client
        .from("players")
        .update({ name: p.name, jersey_number: p.jersey_number, photo_url })
        .eq("id", p.id);
    alert("Giocatore aggiornato!");
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

onMounted(fetchData);
</script>

<template>
    <div v-if="team" class="max-w-4xl mx-auto p-4 sm:p-8 space-y-6">
        <div class="flex items-center gap-3">
            <NuxtLink
                to="/admin"
                class="w-11 h-11 rounded-full bg-white border border-gray-100 flex items-center justify-center text-gray-500 hover:text-black hover:border-gray-200 transition"
            >
                <Icon name="mdi:arrow-left" class="text-xl" />
            </NuxtLink>
            <div>
                <h1 class="text-3xl font-black uppercase tracking-tight text-black">
                    Modifica squadra
                </h1>
                <p class="text-gray-500 font-medium">
                    Aggiorna identità e rosa senza cambiare pagina.
                </p>
            </div>
        </div>

        <section class="bg-white border border-gray-100 rounded-3xl p-6 shadow-sm">
            <div class="flex flex-col sm:flex-row gap-6 sm:items-center">
                <label
                    class="relative w-28 h-28 rounded-full bg-gray-50 border-2 border-dashed border-gray-200 overflow-hidden flex items-center justify-center cursor-pointer hover:border-red-300 transition"
                >
                    <img
                        v-if="previewUrl"
                        :src="previewUrl"
                        class="absolute inset-0 w-full h-full object-cover"
                    />
                    <Icon v-else name="mdi:image-plus" class="text-3xl text-gray-300" />
                    <input type="file" @change="onLogoSelected" class="hidden" />
                </label>
                <div class="flex-1 space-y-3">
                    <label class="block text-xs font-black uppercase tracking-wide text-gray-500">
                        Nome squadra
                    </label>
                    <input
                        v-model="team.name"
                        class="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 font-black uppercase text-black focus:bg-white focus:border-red-500 focus:ring-2 focus:ring-red-100 outline-none"
                    />
                </div>
                <button
                    @click="updateTeam"
                    class="w-full sm:w-auto bg-black text-white px-6 py-3 rounded-xl font-black uppercase text-sm hover:bg-gray-800 transition"
                >
                    Salva
                </button>
            </div>
        </section>

        <h2 class="text-xs font-black uppercase tracking-widest text-gray-400">
            Rosa
        </h2>
        <div
            v-for="p in players"
            :key="p.id"
            class="bg-white border border-gray-100 rounded-2xl p-4 flex flex-col sm:flex-row sm:items-center gap-4 shadow-sm"
        >
            <label class="w-16 h-16 rounded-full bg-gray-100 border border-gray-100 flex items-center justify-center text-gray-400 overflow-hidden cursor-pointer shrink-0">
                <img
                    v-if="p._previewUrl || p.photo_url"
                    :src="p._previewUrl || p.photo_url"
                    class="w-full h-full object-cover"
                />
                <template v-else>
                    <Icon name="mdi:account" class="text-2xl" />
                </template>
                <input type="file" @change="(e) => onPlayerPhotoSelected(e, p)" class="hidden" />
            </label>
            <input
                v-model="p.name"
                class="flex-1 bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 font-bold uppercase focus:bg-white focus:border-red-500 outline-none"
                placeholder="Nome"
            />
            <input
                v-model="p.jersey_number"
                type="number"
                class="w-full sm:w-28 bg-gray-50 border border-gray-200 rounded-xl px-4 py-3 font-black text-red-600 focus:bg-white focus:border-red-500 outline-none"
                placeholder="N."
            />
            <button
                @click="updatePlayer(p)"
                class="bg-red-600 text-white px-5 py-3 rounded-xl font-black uppercase text-sm hover:bg-red-700 transition"
            >
                Salva
            </button>
        </div>
    </div>
</template>
