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
const imageAccept = "image/*,.heic,.heif,.HEIC,.HEIF";

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
        message.value = "Errore di autenticazione: ID utente mancante.";
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

const isHeicFile = (file: File) => {
    const extension = file.name.split(".").pop()?.toLowerCase();
    return (
        extension === "heic" ||
        extension === "heif" ||
        file.type === "image/heic" ||
        file.type === "image/heif"
    );
};

const convertHeicToJpeg = async (file: File): Promise<Blob> => {
    try {
        const { heicTo } = await import("heic-to");
        return await heicTo({
            blob: file,
            type: "image/jpeg",
            quality: 0.88,
        });
    } catch (error) {
        console.error("HEIC conversion failed", error);
        throw new Error(
            "Non riesco a convertire questo HEIC. Prova a selezionare una foto diversa o disattiva HEIC dalla fotocamera.",
        );
    }
};

const loadImageFromBlob = (blob: Blob): Promise<HTMLImageElement> => {
    return new Promise((resolve, reject) => {
        const objectUrl = URL.createObjectURL(blob);
        const img = new Image();

        img.onload = () => {
            URL.revokeObjectURL(objectUrl);
            resolve(img);
        };

        img.onerror = () => {
            URL.revokeObjectURL(objectUrl);
            reject(new Error("Formato immagine non supportato."));
        };

        img.src = objectUrl;
    });
};

const compressImage = async (file: File): Promise<Blob> => {
    let img: HTMLImageElement;

    try {
        img = await loadImageFromBlob(file);
    } catch (error) {
        if (!isHeicFile(file)) throw error;

        const convertedBlob = await convertHeicToJpeg(file);
        img = await loadImageFromBlob(convertedBlob);
    }

    return new Promise((resolve, reject) => {
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

            if (a > 20) {
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
    });
};

const onFileSelected = async (event: Event) => {
    const target = event.target as HTMLInputElement;
    if (!target.files || target.files.length === 0) return;

    const file = target.files[0];
    if (file.size > 10 * 1024 * 1024) {
        isError.value = true;
        message.value = "Il file deve essere inferiore a 10 MB.";
        return;
    }

    try {
        message.value = "Compressione dell'immagine...";
        isError.value = false;

        const compressedBlob = await compressImage(file);
        fileToUpload.value = compressedBlob;

        if (previewUrl.value) URL.revokeObjectURL(previewUrl.value);
        previewUrl.value = URL.createObjectURL(compressedBlob);
        message.value = "";
    } catch (error: any) {
        isError.value = true;
        message.value = error.message || "Compressione dell'immagine fallita.";
    }
};

const confirmUpload = async () => {
    if (!fileToUpload.value) return;

    isUploading.value = true;
    message.value = "Caricamento in corso...";
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
        message.value = "Il file deve essere inferiore a 10 MB.";
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
        message.value = error.message || "Compressione della foto del giocatore fallita.";
    }
};

const addPlayer = async () => {
    if (!newPlayerName.value || !newPlayerJersey.value || !teamId.value) return;
    
    // Check for duplicate jersey number
    const jerseyNumber = parseInt(newPlayerJersey.value);
    if (players.value.some(p => p.jersey_number === jerseyNumber)) {
        isError.value = true;
        message.value = "Esiste già un giocatore con questo numero di maglia.";
        return;
    }

    isAddingPlayer.value = true;
    isError.value = false;
    message.value = "Aggiunta del giocatore in corso...";

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
        alert("Impossibile aggiornare il nome della squadra: " + err.message);
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
        alert("Il file deve essere inferiore a 10 MB.");
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
        alert(error.message || "Impossibile aggiornare il logo.");
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
        message.value = "Il file deve essere inferiore a 10 MB.";
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
        message.value = error.message || "Compressione della foto del giocatore fallita.";
    }
};

const saveEditPlayer = async (player: any) => {
    if (!editPlayerName.value || !editPlayerJersey.value) return;
    
    // Check for duplicate jersey number, excluding the current player
    const jerseyNumber = parseInt(editPlayerJersey.value);
    if (players.value.some(p => p.id !== player.id && p.jersey_number === jerseyNumber)) {
        isError.value = true;
        message.value = "Esiste già un giocatore con questo numero di maglia.";
        return;
    }

    isError.value = false;
    message.value = "Salvataggio del giocatore...";

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
    <div class="max-w-6xl mx-auto py-5 sm:py-12 px-4 sm:px-6">
        <div class="flex items-center justify-between mb-6 sm:mb-8 mobile-fade-in">
            <div>
                <h1 class="font-impact text-3xl sm:text-5xl text-black tracking-widest uppercase">La mia squadra</h1>
                <p class="text-secondary font-bold mt-2 uppercase tracking-wide">Nome, logo e rosa in un solo flusso.</p>
            </div>
        </div>

        <div v-if="isLoading" class="flex items-center justify-center py-20 text-primary animate-pulse">
            <Icon name="mdi:loading" class="animate-spin text-4xl" />
        </div>

        <div v-else class="transition-all duration-500">
            <div
                v-if="currentStep < 3"
                class="max-w-2xl mx-auto mb-6 grid grid-cols-3 gap-2 text-xs font-impact uppercase tracking-widest text-center"
            >
                <div
                    class="py-2 border-2 border-black transform -skew-x-6"
                    :class="currentStep >= 1 ? 'bg-primary text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]' : 'bg-white text-secondary shadow-[1px_1px_0px_rgba(0,0,0,1)]'"
                >
                    <span class="block transform skew-x-6">Nome</span>
                </div>
                <div
                    class="py-2 border-2 border-black transform -skew-x-6"
                    :class="currentStep >= 2 ? 'bg-primary text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]' : 'bg-white text-secondary shadow-[1px_1px_0px_rgba(0,0,0,1)]'"
                >
                    <span class="block transform skew-x-6">Logo</span>
                </div>
                <div
                    class="py-2 border-2 border-black transform -skew-x-6"
                    :class="currentStep >= 3 ? 'bg-primary text-white shadow-[2px_2px_0px_rgba(0,0,0,1)]' : 'bg-white text-secondary shadow-[1px_1px_0px_rgba(0,0,0,1)]'"
                >
                    <span class="block transform skew-x-6">Rosa</span>
                </div>
            </div>

            <!-- Step 1: Team Info -->
            <div v-if="currentStep === 1" class="max-w-2xl mx-auto card-grunge p-6 sm:p-12 mobile-fade-in">
                <div class="mb-8 text-center border-b-2 border-black pb-4">
                    <h2 class="text-2xl sm:text-4xl font-impact text-black tracking-widest uppercase">Nome squadra</h2>
                    <p class="text-secondary mt-3 font-bold sm:text-lg uppercase">Scegli il nome che vedranno pubblico e arbitri.</p>
                </div>
                
                <form @submit.prevent="saveTeamInfo" class="space-y-6">
                    <div>
                        <input
                            v-model="teamName"
                            type="text"
                            placeholder="es. THE AVERAGE JOES"
                            required
                            class="w-full px-5 sm:px-6 py-4 sm:py-5 bg-white border-4 border-black focus:border-primary focus:bg-gray-50 transition-all outline-none text-black placeholder-gray-400 text-lg sm:text-2xl font-impact tracking-widest text-center uppercase"
                        />
                    </div>
                    
                    <p
                        v-if="message && currentStep === 1"
                        :class="isError ? 'text-primary' : 'text-green-600'"
                        class="text-sm font-impact tracking-widest text-center uppercase"
                    >
                        {{ message }}
                    </p>
                    
                    <button
                        type="submit"
                        class="btn-skewed w-full text-xl"
                    >
                        <span class="btn-skewed-content">Continua</span>
                    </button>
                </form>
            </div>

            <!-- Step 2: Upload Logo -->
            <div v-else-if="currentStep === 2" class="max-w-2xl mx-auto card-grunge p-6 sm:p-12 mobile-fade-in">
                <div class="mb-8 text-center border-b-2 border-black pb-4">
                    <h2 class="text-2xl sm:text-4xl font-impact text-black tracking-widest uppercase">Logo</h2>
                    <p class="text-secondary mt-3 font-bold sm:text-lg uppercase">Aggiungi un logo per <strong class="text-primary font-impact tracking-wider">{{ teamName }}</strong>.</p>
                </div>

                <div class="flex flex-col items-center">
                    <label class="relative group cursor-pointer w-40 h-40 sm:w-48 sm:h-48 bg-white border-4 border-black flex flex-col items-center justify-center overflow-hidden hover:border-primary transition-all duration-300 shadow-[4px_4px_0px_rgba(0,0,0,1)] hover:shadow-[6px_6px_0px_var(--primary)] hover:-translate-y-1">
                        <img
                            v-if="previewUrl"
                            :src="previewUrl"
                            class="absolute inset-0 w-full h-full object-cover"
                        />
                        <div v-if="!previewUrl" class="text-secondary group-hover:text-primary flex flex-col items-center gap-2 transition-colors">
                            <Icon name="mdi:image-plus" class="text-5xl" />
                            <span class="text-sm font-impact uppercase tracking-widest">Seleziona logo</span>
                        </div>
                        <input
                            type="file"
                            :accept="imageAccept"
                            @change="onFileSelected"
                            class="hidden"
                        />
                    </label>

                    <p class="text-xs font-impact tracking-widest text-secondary mt-6 text-center uppercase">Dimensione max 10MB. PNG, JPG o HEIC.</p>

                    <div v-if="previewUrl" class="mt-8 flex flex-col sm:flex-row gap-3 sm:gap-4 w-full">
                        <button
                            @click="previewUrl = null; fileToUpload = null;"
                            :disabled="isUploading"
                            class="btn-skewed-secondary flex-1"
                        >
                            <span class="btn-skewed-content">Annulla</span>
                        </button>
                        <button
                            @click="confirmUpload"
                            :disabled="isUploading"
                            class="btn-skewed flex-1"
                        >
                            <span class="btn-skewed-content">{{ isUploading ? 'Caricamento...' : 'Salva logo' }}</span>
                        </button>
                    </div>

                    <p
                        v-if="message && currentStep === 2"
                        :class="isError ? 'text-primary' : 'text-green-600'"
                        class="text-sm font-impact tracking-widest mt-4 text-center uppercase"
                    >
                        {{ message }}
                    </p>

                    <button
                        v-if="!previewUrl"
                        @click="currentStep = 3; fetchPlayers();"
                        class="mt-8 text-secondary hover:text-primary text-sm font-impact uppercase tracking-widest transition-colors"
                    >
                        Continua senza logo
                    </button>
                </div>
            </div>

            <!-- Step 3: Team Roster -->
            <div v-else-if="currentStep === 3" class="mobile-fade-in">
                <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-5 sm:gap-6 mb-6 sm:mb-10 card-grunge p-5 sm:p-8">
                    <div class="flex items-center gap-4 sm:gap-6 w-full">
                        <!-- Inline Logo Edit -->
                        <label class="relative w-20 h-20 sm:w-24 sm:h-24 bg-white border-4 border-black overflow-hidden flex-shrink-0 cursor-pointer group flex items-center justify-center transition-all shadow-[4px_4px_0px_rgba(0,0,0,1)] hover:-translate-y-1 hover:border-primary">
                            <img
                                v-if="teamLogoUrl"
                                :src="teamLogoUrl"
                                class="w-full h-full object-cover"
                            />
                            <Icon v-else name="mdi:image-outline" class="text-secondary text-3xl" />
                            
                            <!-- Overlay -->
                            <div class="absolute inset-0 bg-black/70 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center">
                                <Icon v-if="isUpdatingTeamLogo" name="mdi:loading" class="animate-spin text-white text-2xl" />
                                <Icon v-else name="mdi:camera" class="text-white text-2xl" />
                            </div>
                            <input
                                type="file"
                                :accept="imageAccept"
                                @change="onInlineLogoSelected"
                                class="hidden"
                                :disabled="isUpdatingTeamLogo"
                            />
                        </label>
                        
                        <div class="flex-1 min-w-0">
                            <!-- Inline Name Edit -->
                            <div v-if="isEditingTeamName" class="flex flex-col sm:flex-row gap-3 w-full max-w-md">
                                <input
                                    v-model="inlineEditTeamName"
                                    type="text"
                                    class="w-full bg-white px-4 py-3 border-4 border-black focus:border-primary focus:bg-gray-50 outline-none uppercase font-impact text-lg sm:text-xl transition-all"
                                />
                                <div class="flex gap-2">
                                    <button @click="saveInlineTeamName" class="btn-skewed flex-1 sm:flex-none px-4 py-2 text-sm"><span class="btn-skewed-content">Salva</span></button>
                                    <button @click="cancelInlineTeamName" class="btn-skewed-secondary flex-1 sm:flex-none px-4 py-2 text-sm"><span class="btn-skewed-content">Annulla</span></button>
                                </div>
                            </div>
                            
                            <div v-else class="flex items-center gap-3 min-w-0">
                                <h2 class="text-2xl sm:text-4xl font-impact text-black tracking-widest uppercase truncate">{{ teamName }}</h2>
                                <button @click="startInlineEditTeamName" class="text-secondary hover:text-primary transition-all p-2 bg-white border-2 border-black hover:bg-gray-50 shadow-[2px_2px_0px_rgba(0,0,0,1)] active:-translate-y-0.5 shrink-0">
                                    <Icon name="mdi:pencil" class="text-xl block" />
                                </button>
                            </div>
                            <p class="text-secondary mt-1 font-bold text-sm sm:text-base uppercase tracking-widest">Aggiungi, modifica o rimuovi i giocatori della rosa.</p>
                        </div>
                    </div>
                </div>

                <!-- Add Player Form -->
                <form
                    @submit.prevent="addPlayer"
                    class="flex flex-col sm:flex-row gap-3 sm:gap-4 card-grunge p-4 sm:p-6 mb-8 sm:mb-12 items-center transition-all focus-within:border-primary focus-within:shadow-[6px_6px_0px_var(--primary)]"
                >
                    <div class="flex items-center justify-center pl-2">
                        <label class="cursor-pointer group flex items-center justify-center w-14 h-14 bg-white border-4 border-black hover:border-primary transition-all overflow-hidden flex-shrink-0 shadow-[2px_2px_0px_rgba(0,0,0,1)] hover:-translate-y-0.5">
                            <img
                                v-if="playerPreviewUrl"
                                :src="playerPreviewUrl"
                                class="w-full h-full object-cover"
                            />
                            <Icon v-else name="mdi:camera" class="text-secondary group-hover:text-primary text-2xl transition-colors" />
                            <input
                                id="playerPhotoInput"
                                type="file"
                                :accept="imageAccept"
                                @change="onPlayerPhotoSelected"
                                class="hidden"
                            />
                        </label>
                    </div>
                    
                    <div class="w-full flex-1 relative">
                        <input
                            v-model="newPlayerName"
                            type="text"
                            placeholder="NOME GIOCATORE"
                            required
                            class="w-full bg-white px-4 py-3 border-4 border-black text-black placeholder-gray-400 outline-none font-impact tracking-widest text-base sm:text-xl uppercase transition-colors focus:border-primary"
                        />
                    </div>
                    
                    <div class="w-full sm:w-32 relative">
                        <input
                            v-model="newPlayerJersey"
                            type="number"
                            placeholder="N."
                            required
                            class="w-full bg-white px-4 py-3 border-4 border-black text-primary placeholder-gray-400 outline-none font-impact text-2xl focus:border-primary transition-colors text-center"
                        />
                    </div>
                    
                    <div class="w-full sm:w-auto">
                        <button
                            type="submit"
                            :disabled="isAddingPlayer"
                            class="btn-skewed w-full sm:w-auto text-sm px-6"
                        >
                            <span class="btn-skewed-content">{{ isAddingPlayer ? 'Aggiunta...' : 'Aggiungi' }}</span>
                        </button>
                    </div>
                </form>

                <!-- Player Cards Grid -->
                <div v-if="players.length > 0" class="grid grid-cols-1 min-[460px]:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-6">
                    <div
                        v-for="player in players"
                        :key="player.id"
                        class="card-grunge bg-white overflow-hidden flex flex-col group relative"
                    >
                        <!-- View Mode -->
                        <div v-if="editingPlayerId !== player.id" class="flex flex-col h-full">
                            <!-- Photo Section -->
                            <div class="relative h-56 sm:h-64 bg-cement flex items-center justify-center overflow-hidden border-b-4 border-black">
                                <img
                                    v-if="player.photo_url"
                                    :src="player.photo_url"
                                    class="w-full h-full object-cover"
                                />
                                <Icon v-else name="mdi:account" class="text-gray-300 text-8xl" />
                                
                                <!-- Jersey Number Badge -->
                                <div class="absolute bottom-4 left-4 bg-primary text-white w-14 h-14 flex items-center justify-center border-4 border-black font-impact text-2xl shadow-[2px_2px_0px_rgba(0,0,0,1)] transform -skew-x-6">
                                    <span class="transform skew-x-6">{{ player.jersey_number }}</span>
                                </div>
                                
                                <!-- Action Buttons Overlay -->
                                <div
                                    class="absolute top-4 right-4 flex gap-2 transition-all duration-300 opacity-100 sm:opacity-0 sm:translate-y-2 sm:group-hover:opacity-100 sm:group-hover:translate-y-0"
                                    :class="deletingPlayerId === player.id ? 'opacity-100 translate-y-0' : ''"
                                >
                                    <template v-if="deletingPlayerId !== player.id">
                                        <button
                                            @click="startEditPlayer(player)"
                                            class="bg-white text-secondary hover:text-white hover:bg-primary p-2 shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-all border-2 border-black active:-translate-y-0.5"
                                        >
                                            <Icon name="mdi:pencil" class="text-lg" />
                                        </button>
                                        <button
                                            @click="deletingPlayerId = player.id"
                                            class="bg-white text-secondary hover:text-white hover:bg-black p-2 shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-all border-2 border-black active:-translate-y-0.5"
                                        >
                                            <Icon name="mdi:delete" class="text-lg" />
                                        </button>
                                    </template>
                                    <template v-else>
                                        <div class="flex flex-col gap-2 items-end bg-white p-3 border-4 border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]">
                                            <span class="text-xs font-impact text-primary uppercase tracking-widest px-2 pt-1">Eliminare?</span>
                                            <div class="flex gap-2 w-full">
                                                <button
                                                    @click="deletingPlayerId = null"
                                                    class="flex-1 bg-white border-2 border-black text-secondary hover:bg-gray-100 px-3 py-1 text-xs font-impact tracking-widest uppercase transition-colors"
                                                >
                                                    NO
                                                </button>
                                                <button
                                                    @click="removePlayer(player.id)"
                                                    class="flex-1 bg-primary border-2 border-black text-white hover:bg-red-700 px-3 py-1 text-xs font-impact tracking-widest uppercase shadow-[2px_2px_0px_rgba(0,0,0,1)] transition-colors"
                                                >
                                                    SÌ
                                                </button>
                                            </div>
                                        </div>
                                    </template>
                                </div>
                            </div>
                            
                            <!-- Info Section -->
                            <div class="p-4 sm:p-5">
                                <h3 class="font-impact text-black text-xl sm:text-2xl uppercase tracking-widest truncate">{{ player.name }}</h3>
                            </div>
                        </div>

                        <!-- Edit Mode -->
                        <div v-else class="flex flex-col h-full bg-white relative z-10 border-4 border-primary">
                            <!-- Edit Photo -->
                            <label class="relative h-48 flex items-center justify-center cursor-pointer group/edit bg-cement overflow-hidden border-b-4 border-black">
                                <img
                                    v-if="editPlayerPreviewUrl || player.photo_url"
                                    :src="editPlayerPreviewUrl || player.photo_url"
                                    class="w-full h-full object-cover"
                                />
                                <Icon v-else name="mdi:camera" class="text-gray-400 text-6xl" />
                                <div class="absolute inset-0 bg-black/70 opacity-0 group-hover/edit:opacity-100 flex items-center justify-center transition-opacity">
                                    <span class="text-white font-impact uppercase tracking-widest text-sm flex items-center gap-2">
                                        <Icon name="mdi:camera" /> CAMBIA
                                    </span>
                                </div>
                                <input
                                    type="file"
                                    :accept="imageAccept"
                                    @change="onEditPlayerPhotoSelected"
                                    class="hidden"
                                />
                            </label>
                            
                            <!-- Edit Info -->
                            <div class="p-4 flex flex-col gap-3">
                                <div>
                                    <label class="text-xs font-impact text-secondary uppercase tracking-widest ml-1 mb-1 block">Nome</label>
                                    <input
                                        v-model="editPlayerName"
                                        type="text"
                                        class="w-full bg-white px-3 py-2 font-impact tracking-widest text-black border-4 border-black focus:border-primary outline-none uppercase"
                                    />
                                </div>
                                <div>
                                    <label class="text-xs font-impact text-secondary uppercase tracking-widest ml-1 mb-1 block">Numero</label>
                                    <input
                                        v-model="editPlayerJersey"
                                        type="number"
                                        class="w-full bg-white px-3 py-2 font-impact text-primary text-xl border-4 border-black focus:border-primary outline-none"
                                    />
                                </div>
                                
                                <div class="flex gap-2 mt-2">
                                    <button
                                        @click="cancelEditPlayer"
                                        class="btn-skewed-secondary flex-1 px-2 py-2 text-xs"
                                    >
                                        <span class="btn-skewed-content">Annulla</span>
                                    </button>
                                    <button
                                        @click="saveEditPlayer(player)"
                                        class="btn-skewed flex-1 px-2 py-2 text-xs"
                                    >
                                        <span class="btn-skewed-content">Salva</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div v-else class="text-center py-24 px-4 bg-white border-4 border-dashed border-black shadow-[4px_4px_0px_rgba(0,0,0,1)]">
                    <Icon name="mdi:account-group-outline" class="text-6xl text-secondary mx-auto mb-4" />
                    <h3 class="text-xl sm:text-3xl font-impact text-black uppercase tracking-widest">Rosa Vuota</h3>
                    <p class="text-secondary mt-2 font-bold sm:text-lg uppercase">Aggiungi il tuo primo giocatore usando il modulo sopra.</p>
                </div>

                <div v-if="message && currentStep === 3" class="flex justify-center mt-8">
                    <p
                        :class="isError ? 'text-primary' : 'text-green-600'"
                        class="text-sm font-impact tracking-widest px-6 py-3 uppercase"
                    >
                        {{ message }}
                    </p>
                </div>
            </div>
        </div>
    </div>
</template>
