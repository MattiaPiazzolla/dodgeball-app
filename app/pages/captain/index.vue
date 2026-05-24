// app/pages/captain/index.vue
<script setup lang="ts">
definePageMeta({
    layout: "default",
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

const teamLogoUrl = ref<string | null>(null);

// Inline Team Edit state
const isEditingTeamName = ref(false);
const inlineEditTeamName = ref("");
const isUpdatingTeamLogo = ref(false);

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

// Delete Player state
const deletingPlayerId = ref<string | null>(null);

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
            teamLogoUrl.value = team.logo_url;
            currentStep.value = team.logo_url ? 3 : 2;
            await fetchPlayers();
        }
    }
    isLoading.value = false;
});

const saveTeamInfo = async () => {
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
        if (teamId.value) {
            // Update existing team
            const { error } = await client
                .from("teams")
                .update({ name: teamName.value })
                .eq("id", teamId.value);
                
            if (error) throw error;
        } else {
            // Create new team
            const { data, error } = await client
                .from("teams")
                .insert({ name: teamName.value, captain_id: user.id })
                .select()
                .single();

            if (error) throw error;
            teamId.value = data.id;
        }

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
    
    // Check for duplicate jersey number
    const jerseyNumber = parseInt(newPlayerJersey.value);
    if (players.value.some(p => p.jersey_number === jerseyNumber)) {
        isError.value = true;
        message.value = "A player with this jersey number already exists.";
        return;
    }

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

const startInlineEditTeamName = () => {
    inlineEditTeamName.value = teamName.value;
    isEditingTeamName.value = true;
};

const saveInlineTeamName = async () => {
    if (!inlineEditTeamName.value || !teamId.value) {
        isEditingTeamName.value = false;
        return;
    }
    
    try {
        const { error } = await client
            .from("teams")
            .update({ name: inlineEditTeamName.value })
            .eq("id", teamId.value);
            
        if (error) throw error;
        
        teamName.value = inlineEditTeamName.value;
        isEditingTeamName.value = false;
    } catch (err: any) {
        alert("Failed to update team name: " + err.message);
    }
};

const cancelInlineTeamName = () => {
    isEditingTeamName.value = false;
};

const onInlineLogoSelected = async (event: Event) => {
    const target = event.target as HTMLInputElement;
    if (!target.files || target.files.length === 0 || !teamId.value) return;

    const file = target.files[0];
    if (file.size > 10 * 1024 * 1024) {
        alert("File size must be under 10MB.");
        return;
    }

    try {
        isUpdatingTeamLogo.value = true;
        const compressedBlob = await compressImage(file);
        const filePath = `${teamId.value}-logo.jpg`;

        const { error: uploadError } = await client.storage
            .from("logos")
            .upload(filePath, compressedBlob, {
                upsert: true,
                contentType: "image/jpeg",
            });

        if (uploadError) throw uploadError;

        const {
            data: { publicUrl },
        } = client.storage.from("logos").getPublicUrl(filePath);
        
        const newLogoUrl = publicUrl + `?t=${Date.now()}`;

        const { error: updateError } = await client
            .from("teams")
            .update({ logo_url: newLogoUrl })
            .eq("id", teamId.value);

        if (updateError) throw updateError;

        teamLogoUrl.value = newLogoUrl;
    } catch (error: any) {
        alert("Failed to update logo: " + error.message);
    } finally {
        isUpdatingTeamLogo.value = false;
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
    } finally {
        deletingPlayerId.value = null;
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
    
    // Check for duplicate jersey number, excluding the current player
    const jerseyNumber = parseInt(editPlayerJersey.value);
    if (players.value.some(p => p.id !== player.id && p.jersey_number === jerseyNumber)) {
        isError.value = true;
        message.value = "A player with this jersey number already exists.";
        return;
    }

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
    <div class="max-w-6xl mx-auto py-12 px-4 sm:px-6">
        <div class="flex items-center justify-between mb-8">
            <h1 class="text-4xl font-black text-black tracking-tight uppercase italic">Captain HQ</h1>
        </div>

        <div v-if="isLoading" class="flex items-center justify-center py-20 text-red-600 animate-pulse">
            <Icon name="mdi:loading" class="animate-spin text-4xl" />
        </div>

        <div v-else class="transition-all duration-500">
            <!-- Step 1: Team Info -->
            <div v-if="currentStep === 1" class="max-w-2xl mx-auto bg-white p-8 sm:p-12 rounded-3xl shadow-xl border border-gray-100 animate-in fade-in slide-in-from-bottom-4">
                <div class="mb-8 text-center">
                    <h2 class="text-3xl font-black text-black tracking-tight uppercase">Create your team</h2>
                    <p class="text-gray-500 mt-3 font-medium text-lg">What is the name of your dodgeball squad?</p>
                </div>
                
                <form @submit.prevent="saveTeamInfo" class="space-y-6">
                    <div>
                        <input
                            v-model="teamName"
                            type="text"
                            placeholder="e.g. The Average Joes"
                            required
                            class="w-full px-6 py-5 bg-gray-50 border-2 border-transparent rounded-2xl focus:bg-white focus:border-red-500 focus:ring-4 focus:ring-red-50 transition-all outline-none text-black placeholder-gray-300 text-xl font-bold text-center uppercase"
                        />
                    </div>
                    
                    <p
                        v-if="message && currentStep === 1"
                        :class="isError ? 'text-red-600' : 'text-green-600'"
                        class="text-sm font-bold text-center"
                    >
                        {{ message }}
                    </p>
                    
                    <button
                        type="submit"
                        class="w-full bg-red-600 text-white px-8 py-5 rounded-2xl hover:bg-red-700 font-black text-lg uppercase tracking-widest active:scale-95 transition-all shadow-lg shadow-red-200"
                    >
                        Save & Continue
                    </button>
                </form>
            </div>

            <!-- Step 2: Upload Logo -->
            <div v-else-if="currentStep === 2" class="max-w-2xl mx-auto bg-white p-8 sm:p-12 rounded-3xl shadow-xl border border-gray-100 animate-in fade-in slide-in-from-bottom-4">
                <div class="mb-8 text-center">
                    <h2 class="text-3xl font-black text-black tracking-tight uppercase">Team Identity</h2>
                    <p class="text-gray-500 mt-3 font-medium text-lg">Upload a logo for <strong class="text-red-600">{{ teamName }}</strong> to stand out.</p>
                </div>

                <div class="flex flex-col items-center">
                    <label class="relative group cursor-pointer w-48 h-48 rounded-full bg-gray-50 border-4 border-dashed border-gray-200 flex flex-col items-center justify-center overflow-hidden hover:border-red-500 hover:bg-red-50 transition-all duration-300">
                        <img
                            v-if="previewUrl"
                            :src="previewUrl"
                            class="absolute inset-0 w-full h-full object-cover"
                        />
                        <div v-if="!previewUrl" class="text-gray-400 group-hover:text-red-500 flex flex-col items-center gap-2 transition-colors">
                            <Icon name="mdi:image-plus" class="text-5xl" />
                            <span class="text-sm font-bold uppercase tracking-wide">Select logo</span>
                        </div>
                        <input
                            type="file"
                            accept="image/*"
                            @change="onFileSelected"
                            class="hidden"
                        />
                    </label>

                    <p class="text-sm text-gray-400 mt-6 font-medium">Max size 10MB. Transparent PNGs recommended.</p>

                    <div v-if="previewUrl" class="mt-8 flex gap-4 w-full">
                        <button
                            @click="previewUrl = null; fileToUpload = null;"
                            :disabled="isUploading"
                            class="flex-1 px-6 py-4 text-base font-bold text-gray-700 bg-gray-100 rounded-2xl hover:bg-gray-200 active:scale-95 transition-all uppercase"
                        >
                            Cancel
                        </button>
                        <button
                            @click="confirmUpload"
                            :disabled="isUploading"
                            class="flex-1 px-6 py-4 text-base font-bold text-white bg-red-600 rounded-2xl hover:bg-red-700 shadow-lg shadow-red-200 active:scale-95 transition-all uppercase"
                        >
                            {{ isUploading ? 'Uploading...' : 'Confirm' }}
                        </button>
                    </div>

                    <p
                        v-if="message && currentStep === 2"
                        :class="isError ? 'text-red-600' : 'text-green-600'"
                        class="text-sm font-bold mt-4 text-center"
                    >
                        {{ message }}
                    </p>

                    <button
                        v-if="!previewUrl"
                        @click="currentStep = 3; fetchPlayers();"
                        class="mt-8 text-gray-400 hover:text-red-600 text-sm font-bold uppercase tracking-wide transition-colors"
                    >
                        Skip for now
                    </button>
                </div>
            </div>

            <!-- Step 3: Team Roster -->
            <div v-else-if="currentStep === 3" class="animate-in fade-in slide-in-from-bottom-4 duration-500">
                <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-6 mb-10 bg-white p-8 rounded-3xl shadow-sm border border-gray-100">
                    <div class="flex items-center gap-6 w-full">
                        <!-- Inline Logo Edit -->
                        <label class="relative w-24 h-24 rounded-full overflow-hidden border-4 border-red-50 bg-gray-50 flex-shrink-0 cursor-pointer group flex items-center justify-center transition-all hover:border-red-200">
                            <img
                                v-if="teamLogoUrl"
                                :src="teamLogoUrl"
                                class="w-full h-full object-cover"
                            />
                            <Icon v-else name="mdi:image-outline" class="text-gray-300 text-3xl" />
                            
                            <!-- Overlay -->
                            <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center">
                                <Icon v-if="isUpdatingTeamLogo" name="mdi:loading" class="animate-spin text-white text-2xl" />
                                <Icon v-else name="mdi:camera" class="text-white text-2xl" />
                            </div>
                            <input
                                type="file"
                                accept="image/*"
                                @change="onInlineLogoSelected"
                                class="hidden"
                                :disabled="isUpdatingTeamLogo"
                            />
                        </label>
                        
                        <div class="flex-1">
                            <!-- Inline Name Edit -->
                            <div v-if="isEditingTeamName" class="flex flex-col sm:flex-row gap-3 w-full max-w-md">
                                <input
                                    v-model="inlineEditTeamName"
                                    type="text"
                                    class="w-full bg-gray-50 px-4 py-2 rounded-xl text-black border border-gray-200 focus:border-red-500 focus:ring-2 focus:ring-red-100 outline-none uppercase font-black text-xl"
                                />
                                <div class="flex gap-2">
                                    <button @click="saveInlineTeamName" class="px-4 py-2 bg-red-600 text-white rounded-xl font-bold uppercase text-sm hover:bg-red-700 transition-colors">Save</button>
                                    <button @click="cancelInlineTeamName" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-xl font-bold uppercase text-sm hover:bg-gray-200 transition-colors">Cancel</button>
                                </div>
                            </div>
                            
                            <div v-else class="flex items-center gap-3">
                                <h2 class="text-3xl font-black text-black tracking-tight uppercase">{{ teamName }}</h2>
                                <button @click="startInlineEditTeamName" class="text-gray-400 hover:text-red-600 transition-colors bg-gray-50 hover:bg-red-50 p-2 rounded-full">
                                    <Icon name="mdi:pencil" class="text-xl block" />
                                </button>
                            </div>
                            <p class="text-gray-500 mt-1 font-medium">Manage your players and build your ultimate team.</p>
                        </div>
                    </div>
                </div>

                <!-- Add Player Form -->
                <form
                    @submit.prevent="addPlayer"
                    class="flex flex-col sm:flex-row gap-4 bg-white p-4 rounded-[2.5rem] mb-12 items-center shadow-lg shadow-gray-100/50 border border-gray-100 transition-all focus-within:ring-4 focus-within:ring-red-50 focus-within:border-red-200"
                >
                    <div class="flex items-center justify-center pl-2">
                        <label class="cursor-pointer group flex items-center justify-center w-14 h-14 rounded-full bg-gray-50 border-2 border-gray-100 hover:border-red-400 hover:bg-red-50 transition-all overflow-hidden flex-shrink-0">
                            <img
                                v-if="playerPreviewUrl"
                                :src="playerPreviewUrl"
                                class="w-full h-full object-cover"
                            />
                            <Icon v-else name="mdi:camera" class="text-gray-400 group-hover:text-red-500 text-2xl transition-colors" />
                            <input
                                id="playerPhotoInput"
                                type="file"
                                accept="image/*"
                                @change="onPlayerPhotoSelected"
                                class="hidden"
                            />
                        </label>
                    </div>
                    
                    <div class="w-full flex-1 relative">
                        <input
                            v-model="newPlayerName"
                            type="text"
                            placeholder="PLAYER NAME"
                            required
                            class="w-full bg-transparent px-4 py-3 text-black placeholder-gray-300 outline-none font-bold text-lg uppercase tracking-wide"
                        />
                    </div>
                    <div class="w-full h-px sm:w-px sm:h-10 bg-gray-100 hidden sm:block"></div>
                    <div class="w-full sm:w-32 relative">
                        <input
                            v-model="newPlayerJersey"
                            type="number"
                            placeholder="NO."
                            required
                            class="w-full bg-transparent px-4 py-3 text-red-600 placeholder-gray-300 outline-none font-black text-2xl"
                        />
                    </div>
                    
                    <div class="w-full sm:w-auto pr-2">
                        <button
                            type="submit"
                            :disabled="isAddingPlayer"
                            class="w-full sm:w-auto bg-red-600 text-white px-8 py-4 rounded-full text-sm font-black uppercase tracking-widest hover:bg-red-700 shadow-md shadow-red-200 active:scale-95 transition-all disabled:opacity-50"
                        >
                            {{ isAddingPlayer ? 'ADDING...' : 'ADD' }}
                        </button>
                    </div>
                </form>

                <!-- Player Cards Grid -->
                <div v-if="players.length > 0" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                    <div
                        v-for="player in players"
                        :key="player.id"
                        class="bg-white rounded-[2rem] overflow-hidden shadow-sm hover:shadow-xl hover:-translate-y-1 border border-gray-100 transition-all duration-300 flex flex-col group relative"
                    >
                        <!-- View Mode -->
                        <div v-if="editingPlayerId !== player.id" class="flex flex-col h-full">
                            <!-- Photo Section -->
                            <div class="relative h-64 bg-gray-50 flex items-center justify-center overflow-hidden border-b border-gray-100">
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-full h-full object-cover"
                                />
                                <Icon v-else name="mdi:account" class="text-gray-200 text-8xl" />
                                
                                <!-- Jersey Number Badge -->
                                <div class="absolute bottom-4 left-4 bg-black text-white w-14 h-14 flex items-center justify-center rounded-full font-black text-2xl shadow-xl">
                                    {{ player.jersey_number }}
                                </div>
                                
                                <!-- Action Buttons Overlay -->
                                <div 
                                    class="absolute top-4 right-4 flex gap-2 transition-all duration-300"
                                    :class="deletingPlayerId === player.id ? 'opacity-100 translate-y-0' : 'opacity-0 group-hover:opacity-100 translate-y-2 group-hover:translate-y-0'"
                                >
                                    <template v-if="deletingPlayerId !== player.id">
                                        <button
                                            @click="startEditPlayer(player)"
                                            class="bg-white text-black hover:text-red-600 p-3 rounded-full shadow-lg transition-colors border border-gray-100 hover:scale-110 active:scale-95"
                                        >
                                            <Icon name="mdi:pencil" class="text-lg" />
                                        </button>
                                        <button
                                            @click="deletingPlayerId = player.id"
                                            class="bg-white text-black hover:text-red-600 p-3 rounded-full shadow-lg transition-colors border border-gray-100 hover:scale-110 active:scale-95"
                                        >
                                            <Icon name="mdi:delete" class="text-lg" />
                                        </button>
                                    </template>
                                    <template v-else>
                                        <div class="flex flex-col gap-2 items-end bg-white/90 backdrop-blur-sm p-2 rounded-2xl shadow-xl border border-red-100 animate-in fade-in zoom-in-95 duration-200">
                                            <span class="text-xs font-black text-red-600 uppercase tracking-widest px-2 pt-1">Delete player?</span>
                                            <div class="flex gap-2 w-full">
                                                <button
                                                    @click="deletingPlayerId = null"
                                                    class="flex-1 bg-gray-100 text-gray-600 hover:bg-gray-200 px-4 py-2 rounded-xl text-xs font-bold uppercase transition-colors"
                                                >
                                                    Cancel
                                                </button>
                                                <button
                                                    @click="removePlayer(player.id)"
                                                    class="flex-1 bg-red-600 text-white hover:bg-red-700 px-4 py-2 rounded-xl text-xs font-bold uppercase shadow-md shadow-red-200 transition-colors"
                                                >
                                                    Confirm
                                                </button>
                                            </div>
                                        </div>
                                    </template>
                                </div>
                            </div>
                            
                            <!-- Info Section -->
                            <div class="p-6">
                                <h3 class="font-black text-black text-2xl uppercase tracking-tight truncate">{{ player.name }}</h3>
                            </div>
                        </div>

                        <!-- Edit Mode -->
                        <div v-else class="flex flex-col h-full bg-white relative z-10 border-4 border-red-100 rounded-[2rem]">
                            <!-- Edit Photo -->
                            <label class="relative h-48 flex items-center justify-center cursor-pointer group/edit bg-gray-50 overflow-hidden border-b border-gray-100">
                                <img
                                    v-if="editPlayerPreviewUrl || player.photo_url"
                                    :src="editPlayerPreviewUrl || player.photo_url"
                                    class="w-full h-full object-cover"
                                />
                                <Icon v-else name="mdi:camera" class="text-gray-300 text-6xl" />
                                <div class="absolute inset-0 bg-red-600/70 opacity-0 group-hover/edit:opacity-100 flex items-center justify-center transition-opacity backdrop-blur-sm">
                                    <span class="text-white font-black uppercase tracking-widest text-sm flex items-center gap-2">
                                        <Icon name="mdi:camera" /> CHANGE
                                    </span>
                                </div>
                                <input
                                    type="file"
                                    accept="image/*"
                                    @change="onEditPlayerPhotoSelected"
                                    class="hidden"
                                />
                            </label>
                            
                            <!-- Edit Info -->
                            <div class="p-5 flex flex-col gap-4">
                                <div>
                                    <label class="text-xs font-bold text-gray-400 uppercase tracking-widest ml-1 mb-1 block">Name</label>
                                    <input
                                        v-model="editPlayerName"
                                        type="text"
                                        class="w-full bg-gray-50 px-4 py-3 rounded-xl font-bold text-black border border-transparent focus:bg-white focus:border-red-500 focus:ring-2 focus:ring-red-100 outline-none uppercase"
                                    />
                                </div>
                                <div>
                                    <label class="text-xs font-bold text-gray-400 uppercase tracking-widest ml-1 mb-1 block">Number</label>
                                    <input
                                        v-model="editPlayerJersey"
                                        type="number"
                                        class="w-full bg-gray-50 px-4 py-3 rounded-xl font-black text-red-600 text-xl border border-transparent focus:bg-white focus:border-red-500 focus:ring-2 focus:ring-red-100 outline-none"
                                    />
                                </div>
                                
                                <div class="flex gap-2 mt-2">
                                    <button
                                        @click="cancelEditPlayer"
                                        class="flex-1 px-4 py-3 rounded-xl text-sm font-bold text-gray-500 bg-gray-100 hover:bg-gray-200 uppercase transition-colors"
                                    >
                                        Cancel
                                    </button>
                                    <button
                                        @click="saveEditPlayer(player)"
                                        class="flex-1 px-4 py-3 rounded-xl text-sm font-bold text-white bg-red-600 hover:bg-red-700 uppercase shadow-md shadow-red-200 active:scale-95 transition-all"
                                    >
                                        Save
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div v-else class="text-center py-24 px-4 rounded-[2rem] bg-white border-2 border-dashed border-gray-200">
                    <Icon name="mdi:account-group-outline" class="text-6xl text-gray-200 mx-auto mb-4" />
                    <h3 class="text-2xl font-black text-gray-400 uppercase tracking-wide">Empty Roster</h3>
                    <p class="text-gray-400 mt-2 font-medium text-lg">Add your first player using the form above.</p>
                </div>

                <div v-if="message && currentStep === 3" class="flex justify-center mt-8">
                    <p
                        :class="isError ? 'text-red-600 bg-red-50 border-red-100' : 'text-green-600 bg-green-50 border-green-100'"
                        class="text-sm font-bold px-6 py-3 rounded-full border shadow-sm"
                    >
                        {{ message }}
                    </p>
                </div>
            </div>
        </div>
    </div>
</template>
