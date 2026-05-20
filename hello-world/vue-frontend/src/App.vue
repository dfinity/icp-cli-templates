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
