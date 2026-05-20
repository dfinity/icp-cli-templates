<script setup>
import { ref } from "vue";
import { createActor } from "./bindings/backend";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";

const canisterEnv = safeGetCanisterEnv();
const canisterId = canisterEnv?.["PUBLIC_CANISTER_ID:backend"];

const actor = createActor(canisterId, {
  agentOptions: {
    rootKey: canisterEnv.IC_ROOT_KEY,
  },
});

const greeting = ref("");

async function handleSubmit(event) {
  const name = event.target.elements.name.value;
  greeting.value = await actor.greet(name);
}

</script>

<template>
  <main>
    <form @submit.prevent="handleSubmit">
      <label>Name: <input name="name" type="text" /></label>
      <button type="submit">Greet</button>
    </form>
    <p>{% raw %}{{ greeting }}{% endraw %}</p>
  </main>
</template>
