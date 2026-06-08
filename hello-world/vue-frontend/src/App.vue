<script setup>
import { ref } from "vue";
import { createActor } from "./bindings/backend";
import { safeGetCanisterEnv } from "@icp-sdk/core/agent/canister-env";


// Here we define the environment variables that the asset canister serves.
// By default, the CLI sets all the canister IDs in the environment variables of the asset canister
// using the `PUBLIC_CANISTER_ID:<canister-name>` format.
// For this reason, we can expect the `PUBLIC_CANISTER_ID:backend` environment variable to be set.
interface CanisterEnv {
  readonly "PUBLIC_CANISTER_ID:backend": string;
}

// We only want to access the environment variables when serving the frontend from the asset canister.
// `getCanisterEnv` will retrive the environment variables and the root key from the cookie returned
// by the asset canister
// When developing locally, the vite server will inject the cookie into the responses
// see vite.config.ts
const canisterEnv = getCanisterEnv<CanisterEnv>();
const canisterId = canisterEnv["PUBLIC_CANISTER_ID:backend"];

// We always use the rootkey that is coming back from the cookie in the asset canister
const helloWorldActor = createActor(canisterId, {
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

    <main className="page">
      <section className="panel">
        <div className="brand" aria-label="ICP plus Vite">
          <img src="/icp.svg" alt="ICP logo" className="brand-icp" />
          <span className="plus">+</span>
          <img src="/vue.svg" alt="Vite logo" className="brand-framework" />
          <span className="plus">+</span>
          <img src="/vite.svg" alt="Vite logo" className="brand-vite" />
        </div>
        <h1 className="title">Hello World</h1>
        <p className="subtitle">
          Call the backend canister and get a greeting.
        </p>
        <form className="form" @submit.prevent="handleSubmit">
          <label htmlFor="name">Enter your name</label>
          <div className="controls">
            <input
              name="name"
              alt="Name"
              type="text"
              className="input"
              placeholder="Ada Lovelace"
            />
            <button type="submit" className="button">
              Greet
            </button>
          </div>
        </form>
        <section id="greeting" className="greeting" aria-live="polite">
          {% raw %}{{ greeting }}{% endraw %}
        </section>
      </section>
    </main>

</template>
