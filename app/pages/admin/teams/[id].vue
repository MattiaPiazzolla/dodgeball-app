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
        alert("Compression failed");
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
            alert("Upload failed: " + uploadError.message);
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
    alert("Team updated!");
    fetchData();
};

const updatePlayer = async (p: any) => {
    const jerseyNumber = typeof p.jersey_number === 'string' ? parseInt(p.jersey_number) : p.jersey_number;
    if (players.value.some((other: any) => other.id !== p.id && other.jersey_number === jerseyNumber)) {
        alert("A player with this jersey number already exists.");
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
            alert("Upload failed: " + uploadError.message);
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
    alert("Player updated!");
};

const onPlayerPhotoSelected = async (e: Event, p: any) => {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    try {
        const compressed = await compressImage(file);
        p._fileToUpload = compressed;
        p._previewUrl = URL.createObjectURL(compressed);
    } catch (err) {
        alert("Compression failed");
    }
};

onMounted(fetchData);
</script>

<template>
    <div v-if="team" class="max-w-2xl mx-auto p-6">
        <h1 class="text-2xl font-bold mb-4">Edit Team</h1>
        <input v-model="team.name" class="border p-2 w-full mb-2" />
        <img
            v-if="previewUrl"
            :src="previewUrl"
            class="w-20 h-20 my-2 object-cover border"
        />
        <input type="file" @change="onLogoSelected" class="block mb-2" />
        <button
            @click="updateTeam"
            class="bg-blue-600 text-white px-4 py-2 rounded"
        >
            Save Team
        </button>

        <h2 class="text-xl font-bold mt-8">Roster</h2>
        <div
            v-for="p in players"
            :key="p.id"
            class="p-4 border-b flex flex-col gap-2"
        >
            <div class="flex items-center gap-4 mb-2">
                <img
                    v-if="p._previewUrl || p.photo_url"
                    :src="p._previewUrl || p.photo_url"
                    class="w-16 h-16 rounded-full object-cover border"
                />
                <div v-else class="w-16 h-16 rounded-full bg-gray-200 border flex items-center justify-center text-gray-400">
                    <Icon name="mdi:account" class="text-2xl" />
                </div>
                <input type="file" @change="(e) => onPlayerPhotoSelected(e, p)" class="block text-sm" />
            </div>
            <input v-model="p.name" class="border p-1" placeholder="Name" />
            <input v-model="p.jersey_number" type="number" class="border p-1" placeholder="Jersey Number" />
            <button
                @click="updatePlayer(p)"
                class="bg-green-600 text-white p-1 rounded font-semibold mt-1"
            >
                Save Player
            </button>
        </div>
    </div>
</template>
