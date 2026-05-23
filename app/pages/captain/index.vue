// app/pages/captain/index.vue
<script setup lang="ts">
definePageMeta({
    layout: "dashboard",
    middleware: ["captain"],
});

const client = useSupabaseClient();

const isLoading = ref(true);
const currentStep = ref(1);
const teamId = ref<string | null>(null);
const teamName = ref("");
const message = ref("");
const isError = ref(false);
const isUploading = ref(false);

const previewUrl = ref<string | null>(null);
const fileToUpload = ref<Blob | null>(null);

// Roster state
const players = ref<any[]>([]);
const newPlayerName = ref("");
const newPlayerJersey = ref("");
const isAddingPlayer = ref(false);
const playerPreviewUrl = ref<string | null>(null);
const playerFileToUpload = ref<Blob | null>(null);

// Edit Player state
const editingPlayerId = ref<string | null>(null);
const editPlayerName = ref("");
const editPlayerJersey = ref("");
const editPlayerFileToUpload = ref<Blob | null>(null);
const editPlayerPreviewUrl = ref<string | null>(null);

const fetchPlayers = async () => {
    if (!teamId.value) return;
    const { data } = await client
        .from("players")
        .select("id, name, jersey_number, photo_url")
        .eq("team_id", teamId.value)
        .order("created_at", { ascending: true });
    if (data) players.value = data;
};

onMounted(async () => {
    const {
        data: { user },
    } = await client.auth.getUser();
    if (user) {
        const { data: team } = await client
            .from("teams")
            .select("id, name, logo_url")
            .eq("captain_id", user.id)
            .single();

        if (team) {
            teamId.value = team.id;
            teamName.value = team.name;
            currentStep.value = team.logo_url ? 3 : 2;
            await fetchPlayers();
        }
    }
    isLoading.value = false;
});

const createTeam = async () => {
    message.value = "";
    const {
        data: { user },
    } = await client.auth.getUser();

    if (!user?.id) {
        isError.value = true;
        message.value = "Auth error: User ID is missing.";
        return;
    }

    try {
        const { data, error } = await client
            .from("teams")
            .insert({ name: teamName.value, captain_id: user.id })
            .select()
            .single();

        if (error) throw error;

        teamId.value = data.id;
        isError.value = false;
        message.value = "";
        currentStep.value = 2;
    } catch (error: any) {
        isError.value = true;
        message.value = error.message;
    }
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
                    (blob) => {
                        if (blob) resolve(blob);
                        else reject(new Error("Compression failed"));
                    },
                    "image/jpeg",
                    0.8,
                );
            };
        };
    });
};

const onFileSelected = async (event: Event) => {
    const target = event.target as HTMLInputElement;
    if (!target.files || target.files.length === 0) return;

    const file = target.files[0];
    if (file.size > 10 * 1024 * 1024) {
        isError.value = true;
        message.value = "File size must be under 10MB.";
        return;
    }

    try {
        message.value = "Compressing image...";
        isError.value = false;

        const compressedBlob = await compressImage(file);
        fileToUpload.value = compressedBlob;

        if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
        previewUrl.value = URL.createObjectURL(compressedBlob);
        message.value = "";
    } catch (error: any) {
        isError.value = true;
        message.value = "Failed to compress image.";
    }
};

const confirmUpload = async () => {
    if (!fileToUpload.value) return;

    isUploading.value = true;
    message.value = "Uploading...";
    isError.value = false;

    try {
        const filePath = `${teamId.value}-logo.jpg`;

        const { error: uploadError } = await client.storage
            .from("logos")
            .upload(filePath, fileToUpload.value, {
                upsert: true,
                contentType: "image/jpeg",
            });

        if (uploadError) throw uploadError;

        const {
            data: { publicUrl },
        } = client.storage.from("logos").getPublicUrl(filePath);

        const { error: updateError } = await client
            .from("teams")
            .update({ logo_url: publicUrl })
            .eq("id", teamId.value);

        if (updateError) throw updateError;

        message.value = "";
        currentStep.value = 3;
        await fetchPlayers();
    } catch (error: any) {
        isError.value = true;
        message.value = error.message;
    } finally {
        isUploading.value = false;
    }
};

const onPlayerPhotoSelected = async (event: Event) => {
    const target = event.target as HTMLInputElement;
    if (!target.files || target.files.length === 0) return;

    const file = target.files[0];
    if (file.size > 10 * 1024 * 1024) {
        isError.value = true;
        message.value = "File size must be under 10MB.";
        return;
    }

    try {
        isError.value = false;
        const compressedBlob = await compressImage(file);
        playerFileToUpload.value = compressedBlob;

        if (playerPreviewUrl.value) URL.revokeObjectURL(playerPreviewUrl.value);
        playerPreviewUrl.value = URL.createObjectURL(compressedBlob);
    } catch (error: any) {
        isError.value = true;
        message.value = "Failed to compress player photo.";
    }
};

const addPlayer = async () => {
    if (!newPlayerName.value || !newPlayerJersey.value || !teamId.value) return;
    isAddingPlayer.value = true;
    isError.value = false;
    message.value = "Adding player...";

    try {
        // 1. Insert player
        const { data: playerData, error: insertError } = await client
            .from("players")
            .insert({
                team_id: teamId.value,
                name: newPlayerName.value,
                jersey_number: parseInt(newPlayerJersey.value),
            })
            .select()
            .single();

        if (insertError) throw insertError;

        // 2. Upload photo if selected
        if (playerFileToUpload.value) {
            const filePath = `${playerData.id}-photo.jpg`;
            const { error: uploadError } = await client.storage
                .from("player-photos")
                .upload(filePath, playerFileToUpload.value, {
                    contentType: "image/jpeg",
                });

            if (uploadError) throw uploadError;

            const {
                data: { publicUrl },
            } = client.storage.from("player-photos").getPublicUrl(filePath);

            // 3. Update player row with photo URL
            await client
                .from("players")
                .update({ photo_url: publicUrl })
                .eq("id", playerData.id);
        }

        // Reset form
        newPlayerName.value = "";
        newPlayerJersey.value = "";
        playerFileToUpload.value = null;
        playerPreviewUrl.value = null;
        message.value = "";

        // Refresh list
        const fileInput = document.getElementById(
            "playerPhotoInput",
        ) as HTMLInputElement;
        if (fileInput) fileInput.value = "";

        await fetchPlayers();
    } catch (error: any) {
        isError.value = true;
        message.value = error.message;
    } finally {
        isAddingPlayer.value = false;
    }
};

const removePlayer = async (playerId: string) => {
    isError.value = false;
    message.value = "";
    try {
        const { error } = await client
            .from("players")
            .delete()
            .eq("id", playerId);
        if (error) throw error;
        await fetchPlayers();
    } catch (error: any) {
        isError.value = true;
        message.value = error.message;
    }
};

const startEditPlayer = (player: any) => {
    editingPlayerId.value = player.id;
    editPlayerName.value = player.name;
    editPlayerJersey.value = player.jersey_number.toString();
    editPlayerFileToUpload.value = null;
    editPlayerPreviewUrl.value = null;
};

const cancelEditPlayer = () => {
    editingPlayerId.value = null;
    editPlayerFileToUpload.value = null;
    if (editPlayerPreviewUrl.value) {
        URL.revokeObjectURL(editPlayerPreviewUrl.value);
        editPlayerPreviewUrl.value = null;
    }
};

const onEditPlayerPhotoSelected = async (event: Event) => {
    const target = event.target as HTMLInputElement;
    if (!target.files || target.files.length === 0) return;

    const file = target.files[0];
    if (file.size > 10 * 1024 * 1024) {
        isError.value = true;
        message.value = "File size must be under 10MB.";
        return;
    }

    try {
        isError.value = false;
        const compressedBlob = await compressImage(file);
        editPlayerFileToUpload.value = compressedBlob;

        if (editPlayerPreviewUrl.value) URL.revokeObjectURL(editPlayerPreviewUrl.value);
        editPlayerPreviewUrl.value = URL.createObjectURL(compressedBlob);
    } catch (error: any) {
        isError.value = true;
        message.value = "Failed to compress player photo.";
    }
};

const saveEditPlayer = async (player: any) => {
    if (!editPlayerName.value || !editPlayerJersey.value) return;
    
    isError.value = false;
    message.value = "Saving player...";

    try {
        let photoUrl = player.photo_url;
        
        if (editPlayerFileToUpload.value) {
            const filePath = `${player.id}-photo.jpg`;
            const { error: uploadError } = await client.storage
                .from("player-photos")
                .upload(filePath, editPlayerFileToUpload.value, {
                    upsert: true,
                    contentType: "image/jpeg",
                });

            if (uploadError) throw uploadError;

            photoUrl = client.storage.from("player-photos").getPublicUrl(filePath).data.publicUrl + `?t=${Date.now()}`;
        }

        const { error: updateError } = await client
            .from("players")
            .update({
                name: editPlayerName.value,
                jersey_number: parseInt(editPlayerJersey.value),
                photo_url: photoUrl
            })
            .eq("id", player.id);

        if (updateError) throw updateError;

        message.value = "";
        cancelEditPlayer();
        await fetchPlayers();
    } catch (error: any) {
        isError.value = true;
        message.value = error.message;
    }
};
</script>

<template>
    <div class="max-w-xl">
        <h1 class="text-3xl font-bold text-blue-500 mb-6">Captain Dashboard</h1>

        <div v-if="isLoading" class="text-gray-500 font-semibold animate-pulse">
            Loading dashboard...
        </div>

        <div
            v-else
            class="bg-white p-6 rounded-lg shadow border border-gray-200"
        >
            <!-- Step 1 -->
            <div v-if="currentStep === 1">
                <h2 class="text-xl font-bold mb-4">Step 1: Team Info</h2>
                <form @submit.prevent="createTeam" class="space-y-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700"
                            >Team Name</label
                        >
                        <input
                            v-model="teamName"
                            type="text"
                            required
                            class="mt-1 w-full p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
                        />
                    </div>
                    <p
                        v-if="message && currentStep === 1"
                        :class="isError ? 'text-red-500' : 'text-green-500'"
                        class="text-sm font-bold"
                    >
                        {{ message }}
                    </p>
                    <button
                        type="submit"
                        class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 font-bold transition"
                    >
                        Save & Continue
                    </button>
                </form>
            </div>

            <!-- Step 2 -->
            <div v-else-if="currentStep === 2">
                <h2 class="text-xl font-bold mb-4">Step 2: Upload Logo</h2>
                <p class="text-sm text-gray-600 mb-4">
                    Upload a logo for <strong>{{ teamName }}</strong> (Max
                    10MB).
                </p>

                <input
                    v-if="!previewUrl"
                    type="file"
                    accept="image/*"
                    @change="onFileSelected"
                    class="mb-4 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                />

                <div v-if="previewUrl" class="mb-6 flex flex-col items-center">
                    <p class="text-sm font-bold text-gray-700 mb-2">Preview</p>
                    <img
                        :src="previewUrl"
                        class="w-32 h-32 object-cover rounded-full border-4 border-blue-100 mb-4 shadow"
                    />

                    <div class="flex gap-4">
                        <button
                            @click="
                                previewUrl = null;
                                fileToUpload = null;
                            "
                            :disabled="isUploading"
                            class="px-4 py-2 text-sm font-bold text-gray-600 bg-gray-100 rounded hover:bg-gray-200"
                        >
                            Cancel
                        </button>
                        <button
                            @click="confirmUpload"
                            :disabled="isUploading"
                            class="px-4 py-2 text-sm font-bold text-white bg-blue-600 rounded hover:bg-blue-700"
                        >
                            Confirm & Upload
                        </button>
                    </div>
                </div>

                <p
                    v-if="message && currentStep === 2"
                    :class="isError ? 'text-red-500' : 'text-green-500'"
                    class="text-sm font-bold mb-4 text-center"
                >
                    {{ message }}
                </p>

                <div class="mt-4 border-t pt-4 text-center">
                    <button
                        @click="
                            currentStep = 3;
                            fetchPlayers();
                        "
                        class="text-gray-500 hover:text-gray-700 underline text-sm font-semibold"
                    >
                        Skip for now
                    </button>
                </div>
            </div>

            <!-- Step 3 -->
            <div v-else-if="currentStep === 3">
                <h2 class="text-xl font-bold mb-4">Step 3: Team Roster</h2>
                <p class="text-gray-600 font-medium mb-6">
                    <strong>{{ teamName }}</strong> is ready for players!
                </p>

                <!-- Add Player Form -->
                <form
                    @submit.prevent="addPlayer"
                    class="mb-6 bg-gray-50 p-4 border rounded-lg space-y-4"
                >
                    <div class="flex gap-2">
                        <input
                            v-model="newPlayerName"
                            type="text"
                            placeholder="Player Name"
                            required
                            class="flex-1 p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
                        />
                        <input
                            v-model="newPlayerJersey"
                            type="number"
                            placeholder="Jersey #"
                            required
                            class="w-24 p-2 border rounded focus:ring-blue-500 focus:border-blue-500"
                        />
                    </div>

                    <div class="flex items-center gap-4">
                        <input
                            id="playerPhotoInput"
                            type="file"
                            accept="image/*"
                            @change="onPlayerPhotoSelected"
                            class="flex-1 text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                        />

                        <img
                            v-if="playerPreviewUrl"
                            :src="playerPreviewUrl"
                            class="w-10 h-10 object-cover rounded-full border border-gray-300"
                        />

                        <button
                            type="submit"
                            :disabled="isAddingPlayer"
                            class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 font-bold disabled:opacity-50 whitespace-nowrap"
                        >
                            {{ isAddingPlayer ? "Adding..." : "Add Player" }}
                        </button>
                    </div>
                </form>

                <!-- Player List -->
                <div v-if="players.length > 0" class="space-y-2">
                    <div
                        v-for="player in players"
                        :key="player.id"
                        class="p-3 border rounded"
                    >
                        <!-- View Mode -->
                        <div v-if="editingPlayerId !== player.id" class="flex justify-between items-center">
                            <div class="flex items-center gap-3">
                                <div
                                    v-if="player.photo_url"
                                    class="w-10 h-10 rounded-full bg-gray-200 overflow-hidden border border-gray-300"
                                >
                                    <img
                                        :src="player.photo_url"
                                        class="w-full h-full object-cover"
                                    />
                                </div>
                                <div
                                    v-else
                                    class="w-10 h-10 rounded-full bg-gray-100 border border-gray-300 flex items-center justify-center text-gray-400"
                                >
                                    <Icon name="mdi:account" class="text-xl" />
                                </div>
                                <span class="font-semibold"
                                    >{{ player.name }}
                                    <span class="text-gray-500 font-normal"
                                        >#{{ player.jersey_number }}</span
                                    ></span
                                >
                            </div>
                            <div class="flex gap-2">
                                <button
                                    @click="startEditPlayer(player)"
                                    class="text-blue-500 hover:text-blue-700 text-sm font-bold px-2 py-1 bg-blue-50 rounded"
                                >
                                    Edit
                                </button>
                                <button
                                    @click="removePlayer(player.id)"
                                    class="text-red-500 hover:text-red-700 text-sm font-bold px-2 py-1 bg-red-50 rounded"
                                >
                                    Remove
                                </button>
                            </div>
                        </div>

                        <!-- Edit Mode -->
                        <div v-else class="flex flex-col gap-3">
                            <div class="flex gap-2">
                                <input
                                    v-model="editPlayerName"
                                    type="text"
                                    placeholder="Name"
                                    class="flex-1 p-2 border rounded focus:ring-blue-500 focus:border-blue-500 text-sm"
                                />
                                <input
                                    v-model="editPlayerJersey"
                                    type="number"
                                    placeholder="Jersey"
                                    class="w-24 p-2 border rounded focus:ring-blue-500 focus:border-blue-500 text-sm"
                                />
                            </div>
                            
                            <div class="flex items-center gap-4">
                                <input
                                    type="file"
                                    accept="image/*"
                                    @change="onEditPlayerPhotoSelected"
                                    class="flex-1 text-sm text-gray-500 file:mr-4 file:py-1 file:px-3 file:rounded file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100"
                                />
                                <img
                                    v-if="editPlayerPreviewUrl || player.photo_url"
                                    :src="editPlayerPreviewUrl || player.photo_url"
                                    class="w-10 h-10 object-cover rounded-full border border-gray-300"
                                />
                            </div>
                            
                            <div class="flex gap-2 justify-end">
                                <button
                                    @click="cancelEditPlayer"
                                    class="text-gray-500 hover:text-gray-700 text-sm font-bold px-3 py-1 bg-gray-100 rounded"
                                >
                                    Cancel
                                </button>
                                <button
                                    @click="saveEditPlayer(player)"
                                    class="text-white bg-green-600 hover:bg-green-700 text-sm font-bold px-3 py-1 rounded"
                                >
                                    Save
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
                <p v-else class="text-sm text-gray-500 italic">
                    No players added yet.
                </p>

                <p
                    v-if="message && currentStep === 3"
                    :class="isError ? 'text-red-500' : 'text-green-500'"
                    class="text-sm font-bold mt-4"
                >
                    {{ message }}
                </p>
            </div>
        </div>
    </div>
</template>
