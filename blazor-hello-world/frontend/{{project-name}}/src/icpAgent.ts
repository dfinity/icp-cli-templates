// Agent bridge for ICP canisters.
//
// SDK: @icp-sdk/core (see the Agent module docs:
// https://js.icp.build/core/latest/libs/agent)
import { Actor, HttpAgent } from "@icp-sdk/core/agent";
import { Principal } from "@icp-sdk/core/principal";

const idlFactory = ({ IDL }: any) =>
  IDL.Service({
    getGreeting: IDL.Func([], [IDL.Text], ["query"]),
    setGreeting: IDL.Func([IDL.Text], [IDL.Text], []),
    hello: IDL.Func([IDL.Text], [IDL.Text], ["query"]),
  });

function getCanisterId(): string {
  const decoded = decodeURIComponent(document.cookie);
  const match = decoded
    .split("; ")
    .find((c) => c.startsWith("ic_env="));

  if (match) {
    const params = new URLSearchParams(match.replace("ic_env=", ""));
    const id = params.get("PUBLIC_CANISTER_ID:{{ project-name }}-backend");
    if (id) return id;
  }

  throw new Error("Canister ID not found. Make sure the app is accessed via the canister subdomain.");
}

let _actor: any = null;

async function getActor() {
  if (!_actor) {
    const isLocal =
      window.location.hostname === "localhost" ||
      window.location.hostname.endsWith(".localhost");

    const canisterId = getCanisterId();

    // Use the port the page was actually served from so the agent works
    // regardless of which gateway port the local replica uses (8000, 8001, ...).
    // Falls back to 8000, the standard local gateway port (see icp.yaml).
    const localHost = `http://localhost:${window.location.port || "8000"}`;
    const agent = await HttpAgent.create({
      host: isLocal ? localHost : "https://ic0.app",
      // Local replica only: a skewed host clock (common with WSL/Windows, where
      // the Windows clock and the WSL replica clock can differ by an hour)
      // makes the replica's certificate look "signed in the future", and
      // @icp-sdk/core only tolerates 5 minutes of skew:
      //   "Invalid certificate: Certificate is signed more than 5 minutes in
      //    the future"
      // Query responses from a local replica are already trust-on-first-use via
      // fetchRootKey(), so skip query signature verification locally. Mainnet
      // (and any non-local host) keeps full verification enabled.
      verifyQuerySignatures: !isLocal,
    });

    if (isLocal) {
      await agent.fetchRootKey();

      // The same clock skew also breaks update calls, because the agent derives
      // the request's ingress_expiry from the browser clock:
      //   "Invalid request expiry: Specified ingress_expiry not within expected
      //    range ... Provided expiry: <browser clock + 5 min>"
      // syncTime() reads the replica's certified time and the agent then
      // compensates ingress_expiry whenever the offset exceeds 30 seconds.
      // Pass our own canister id explicitly: the default fallback is the ICP
      // ledger (ryjl3-tyaaa-aaaaa-aaaba-cai), which does not exist on a freshly
      // created local replica.
      try {
        await agent.syncTime({ canisterId: Principal.fromText(canisterId) });
      } catch (err) {
        console.warn(
          "[icpAgent] syncTime failed; update calls may be rejected if the host clock is skewed.",
          err
        );
      }
    }

    _actor = Actor.createActor(idlFactory, {
      agent,
      canisterId,
    });
  }
  return _actor;
}

export async function getGreeting(): Promise<string> {
  return (await getActor()).getGreeting();
}

export async function setGreeting(name: string): Promise<string> {
  return (await getActor()).setGreeting(name);
}

export async function hello(name: string): Promise<string> {
  return (await getActor()).hello(name);
}
