/** Minimal fal.ai queue client (Node 22+, no dependencies). */
const KEY = process.env.FAL_KEY;

export const hasKey = (): boolean => Boolean(KEY);

const headers = () => ({ Authorization: `Key ${KEY}`, "Content-Type": "application/json" });

/** Submit to the queue, poll until done, return the result JSON. Retries transient submit failures. */
export async function falQueue<T>(model: string, body: unknown, log = (s: string) => console.log(s)): Promise<T> {
  let sub: { request_id: string; status_url: string; response_url: string } | undefined;
  for (let attempt = 0; attempt < 4 && !sub; attempt++) {
    const res = await fetch(`https://queue.fal.run/${model}`, { method: "POST", headers: headers(), body: JSON.stringify(body) });
    if (res.ok) sub = await res.json();
    else if (res.status === 429 || res.status >= 500) await new Promise((r) => setTimeout(r, 2000 * 2 ** attempt));
    else throw new Error(`${model} -> ${res.status} ${(await res.text()).slice(0, 300)}`);
  }
  if (!sub) throw new Error(`${model}: submit failed`);
  const t0 = Date.now();
  for (;;) {
    await new Promise((r) => setTimeout(r, 4000));
    const st = await (await fetch(sub.status_url, { headers: headers() })).json();
    if (st.status === "COMPLETED") break;
    if (st.status !== "IN_QUEUE" && st.status !== "IN_PROGRESS") throw new Error(`${model}: ${JSON.stringify(st).slice(0, 300)}`);
    if ((Date.now() - t0) % 20000 < 4100) log(`  ${model.split("/").slice(-2).join("/")} ${st.status} ${Math.round((Date.now() - t0) / 1000)}s`);
  }
  const res = await fetch(sub.response_url, { headers: headers() });
  if (!res.ok) throw new Error(`${model} result -> ${res.status} ${(await res.text()).slice(0, 300)}`);
  return (await res.json()) as T;
}

export async function download(url: string): Promise<Buffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download failed: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

export const dataUri = (buf: Buffer, mime: string): string => `data:${mime};base64,${buf.toString("base64")}`;
