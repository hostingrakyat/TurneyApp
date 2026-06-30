/// InterActive QRIS (qris.id) helpers.
///
/// When QRIS_MOCK=true (or no API key is configured) a representative — but
/// NOT real — EMVCo-style payload is returned so the whole flow is testable
/// without live credentials. Wire the real call in `createLiveQrisInvoice`
/// using the field mapping documented in docs/QRIS.md once you have an APIKEY.

export interface QrisInvoice {
  invoiceId: string;
  qrisString: string;
}

/// Decides whether to mock the QRIS invoice.
///
/// Priority: no live API key → always mock (safety); otherwise the admin's
/// `app_settings.qris_mock` toggle wins when provided; finally the env default.
export function isMock(dbMock?: boolean): boolean {
  if (!Deno.env.get("QRIS_API_KEY")) return true;
  if (dbMock !== undefined && dbMock !== null) return dbMock;
  return (Deno.env.get("QRIS_MOCK") ?? "true") === "true";
}

export function mockQrisInvoice(refId: string, amount: number): QrisInvoice {
  const rand = Math.floor(Math.random() * 1_000_000).toString().padStart(6, "0");
  const amt = String(amount);
  // Display-only payload; not a valid bank QR.
  const qris =
    `00020101021226670016COM.TURNEYAPP.WWW011893600912${rand}` +
    `520459995303360540${amt.length}${amt}5802ID5909TurneyApp6007Jakarta6304MOCK`;
  return { invoiceId: `MOCK-${refId}-${Date.now()}`, qrisString: qris };
}

/// Live call to qris.id. Endpoint/fields per docs/QRIS.md — adjust to match
/// the response shape your merchant account returns.
export async function createLiveQrisInvoice(
  refId: string,
  amount: number,
): Promise<QrisInvoice> {
  const base = Deno.env.get("QRIS_BASE_URL") ??
    "https://qris.interactive.co.id/restapi/qris/show_qris.php";
  const apiKey = Deno.env.get("QRIS_API_KEY")!;
  const merchantId = Deno.env.get("QRIS_MERCHANT_ID") ?? "";

  const form = new URLSearchParams({
    do: "create-invoice",
    apikey: apiKey,
    mID: merchantId,
    cliTrxNumber: refId,
    cliTrxAmount: String(amount),
    useTip: "no",
  });

  const res = await fetch(base, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  });
  if (!res.ok) {
    throw new Error(`QRIS create failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json();
  const data = body?.data ?? body;
  const qrisString = data?.qris_content ?? data?.qris_string ?? "";
  const invoiceId = data?.qris_invoiceid ?? data?.invoice_id ?? refId;
  if (!qrisString) {
    throw new Error(`QRIS response missing payload: ${JSON.stringify(body)}`);
  }
  return { invoiceId: String(invoiceId), qrisString: String(qrisString) };
}
