// app/pages/login.vue
<script setup lang="ts">
const client = useSupabaseClient();
const email = ref("");
const password = ref("");
const isSignUp = ref(false);
const errorMsg = ref("");

const handleAuth = async () => {
    errorMsg.value = "";
    try {
        if (isSignUp.value) {
            const { error } = await client.auth.signUp({
                email: email.value,
                password: password.value,
            });
            if (error) throw error;
            alert("Check your email to confirm signup!");
        } else {
            const { error } = await client.auth.signInWithPassword({
                email: email.value,
                password: password.value,
            });
            if (error) throw error;
            navigateTo("/captain");
        }
    } catch (error: any) {
        errorMsg.value = error.message;
    }
};
</script>

<template>
    <div
        class="max-w-md mx-auto mt-20 p-6 bg-white rounded-lg shadow-md border-t-4 border-red-600"
    >
        <h1 class="text-2xl font-bold text-center text-gray-900 mb-6">
            {{ isSignUp ? "Captain Signup" : "Captain Login" }}
        </h1>
        <form @submit.prevent="handleAuth" class="space-y-4">
            <div>
                <label class="block text-sm font-medium text-gray-700"
                    >Email</label
                >
                <input
                    v-model="email"
                    type="email"
                    required
                    class="mt-1 w-full p-2 border rounded focus:ring-red-500 focus:border-red-500"
                />
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700"
                    >Password</label
                >
                <input
                    v-model="password"
                    type="password"
                    required
                    class="mt-1 w-full p-2 border rounded focus:ring-red-500 focus:border-red-500"
                />
            </div>
            <p v-if="errorMsg" class="text-red-500 text-sm font-semibold">
                {{ errorMsg }}
            </p>
            <button
                type="submit"
                class="w-full bg-red-600 text-white p-2 rounded hover:bg-red-700 font-bold transition"
            >
                {{ isSignUp ? "Register as Captain" : "Login" }}
            </button>
        </form>
        <button
            @click="isSignUp = !isSignUp"
            class="mt-4 text-sm text-gray-600 hover:text-red-600 hover:underline w-full text-center"
        >
            {{
                isSignUp
                    ? "Already have an account? Login"
                    : "Need an account? Sign up"
            }}
        </button>
    </div>
</template>
