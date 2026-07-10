<script lang="ts">
  import { createActor } from "./bindings/backend";
  import { getCanisterEnv } from "@icp-sdk/core/agent/canister-env";
  import "./app.css";

  // Here we define the environment variables that the asset canister serves.
  // By default, the CLI sets all the canister IDs in the environment variables of the asset canister
  // using the `PUBLIC_CANISTER_ID:<canister-name>` format.
  // For this reason, we can expect the `PUBLIC_CANISTER_ID:backend` environment variable to be set.
  interface CanisterEnv {
    readonly "PUBLIC_CANISTER_ID:backend": string;
  }

  // We only want to access the environment variables when serving the frontend from the asset canister.
  // `getCanisterEnv` will retrieve the environment variables and the root key from the cookie returned
  // by the asset canister.
  // When developing locally, the Vite server will inject the cookie into the responses.
  // See vite.config.ts.
  const canisterEnv = getCanisterEnv<CanisterEnv>();
  const canisterId = canisterEnv["PUBLIC_CANISTER_ID:backend"];

  // We always use the root key that is coming back from the cookie in the asset canister
  const helloWorldActor = createActor(canisterId, {
    agentOptions: {
      rootKey: canisterEnv.IC_ROOT_KEY,
    },
  });

  let greeting = $state("");

  async function handleSubmit(event: SubmitEvent) {
    event.preventDefault();
    const form = event.target as HTMLFormElement;
    const name = (form.elements.namedItem("name") as HTMLInputElement).value;
    greeting = await helloWorldActor.greet(name);
  }
</script>

<main class="page">
  <section class="panel">
    <div class="brand" aria-label="ICP plus Svelte">
      <img src="/icp.svg" alt="ICP logo" class="brand-icp" />
      <span class="plus">+</span>
      <img src="/svelte.svg" alt="Svelte logo" class="brand-framework" />
      <span class="plus">+</span>
      <img src="/vite.svg" alt="Vite logo" class="brand-vite" />
    </div>
    <h1 class="title">Hello World</h1>
    <p class="subtitle">
      Call the backend canister and get a greeting.
    </p>
    <form class="form" onsubmit={handleSubmit}>
      <label for="name">Enter your name</label>
      <div class="controls">
        <input
          id="name"
          name="name"
          alt="Name"
          type="text"
          class="input"
          placeholder="Ada Lovelace"
        />
        <button type="submit" class="button">
          Greet me
        </button>
      </div>
    </form>
    <section id="greeting" class="greeting" aria-live="polite">
      {greeting}
    </section>
  </section>
</main>
