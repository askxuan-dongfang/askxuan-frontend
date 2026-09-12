import { test, expect, type Page, type BrowserContext } from "@playwright/test";
const png = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=",
  "base64",
);
const conversation = (role = "customer") => ({
  conversationId: "CHAT-TEST",
  sourceType: "consultation",
  sourceId: "CHAT-TEST",
  bookingId: "",
  peerId: role === "customer" ? "W001" : "42",
  peerOpenIMId: role === "customer" ? "m_7" : "u_42",
  peerName: role === "customer" ? "云游道人（演示）" : "善信居士",
  peerAvatar: "",
  templeName: "独立执业大师",
  serviceName: "即时咨询",
  bookingDate: "",
  expiresAt: "2099-01-01 00:00:00",
  lastMessage: "愿你在每一天找到从容。",
  lastMessageAt: "2026-09-12 12:08:00",
  canChat: true,
  unreadCount: 3,
  readThrough: 0,
  peerReadThrough: 0,
});
type Message = ReturnType<typeof message>;
function message(
  id: number,
  role = "master",
  content = "愿你在每一天找到从容。",
) {
  return {
    id,
    conversationId: "CHAT-TEST",
    sourceType: "consultation",
    bookingId: "",
    clientMessageId: `seed-${id}`,
    senderType: role,
    senderId: role === "master" ? "m_7" : "u_42",
    receiverId: role === "master" ? "u_42" : "m_7",
    content,
    status: "sent",
    kind: "text",
    createTime: `2026-09-12 12:${String(Math.floor(id / 60) % 60).padStart(2, "0")}:${String(id % 60).padStart(2, "0")}`,
  };
}
function fixture() {
  return {
    messages: [
      message(1),
      message(2, "customer", "最近事情较多，想请教如何调整心态。"),
      message(
        3,
        "master",
        "先从一件小事开始，给自己留一点安静的时间。\n慢慢来，也是一种进步。",
      ),
    ] as any[],
    reads: [] as number[],
    sentIDs: [] as string[],
    failAfterAccept: false,
    peerRead: 0,
    attachments: new Map<string, Buffer>(),
    call: null as any,
    signals: [] as any[],
  };
}
type State = ReturnType<typeof fixture>;
async function setup(
  context: BrowserContext,
  role: "customer" | "master",
  state: State,
) {
  await context.addInitScript(
    ({ role }) => {
      localStorage.setItem("h5_token", "isolated-test");
      localStorage.setItem(
        "h5-auth",
        JSON.stringify({
          state: {
            token: "isolated-test",
            role,
            userId: 42,
            masterId: 7,
            displayName: "测试用户",
          },
          version: 0,
        }),
      );
    },
    { role },
  );
  await context.route("**/api/v1/**", async (route) => {
    const req = route.request();
    const u = new URL(req.url());
    const path = u.pathname.replace("/api/v1", "");
    const method = req.method();
    const self = role === "master" ? "m_7" : "u_42";
    const ok = (data: any) =>
      route.fulfill({
        contentType: "application/json",
        body: JSON.stringify({ code: 0, message: "", data }),
      });
    if (path.includes("im-token")) return ok({ imToken: "" });
    if (path === "/chats/unread") return ok({ count: 3 });
    if (path === "/chats/incoming-call")
      return ok({
        call:
          state.call?.state === "ringing" && state.call.calleeId === self
            ? state.call
            : null,
      });
    if (path === "/chats" || path === "/bookings/chats")
      return ok({ list: [conversation(role)], total: 1, page: 1, size: 30 });
    if (path === "/chats/CHAT-TEST")
      return ok({ ...conversation(role), peerReadThrough: state.peerRead });
    if (path.endsWith("/call-capabilities"))
      return ok({ enabled: true, iceServers: [] });
    if (path === "/chats/CHAT-TEST/read") {
      state.reads.push(req.postDataJSON().throughId);
      return ok({ readThrough: state.reads.at(-1) });
    }
    if (path === "/chats/CHAT-TEST/messages") {
      if (method === "GET") {
        const before = Number(u.searchParams.get("beforeId")),
          after = Number(u.searchParams.get("afterId"));
        let rows = state.messages.filter(
          (m) => (!before || m.id < before) && (!after || m.id > after),
        );
        const hasMore = rows.length > 50;
        rows = after ? rows.slice(0, 50) : rows.slice(-50);
        return ok({
          list: rows,
          total: state.messages.length,
          hasMore,
          page: 1,
          size: 50,
          peerReadThrough: state.peerRead,
        });
      }
      const body = req.postDataJSON();
      state.sentIDs.push(body.clientMessageId);
      let row = state.messages.find(
        (m) => m.clientMessageId === body.clientMessageId,
      );
      if (!row) {
        row = {
          ...message(
            Math.max(...state.messages.map((m) => m.id), 0) + 1,
            role,
            body.content,
          ),
          ...body,
          status: "sent",
        };
        if (body.attachmentId)
          row.attachment = {
            id: body.attachmentId,
            name: "测试附件",
            contentType: body.kind === "image" ? "image/png" : "audio/webm",
            size: png.length,
            duration: 1,
          };
        state.messages.push(row);
      }
      if (state.failAfterAccept) {
        state.failAfterAccept = false;
        return route.abort("failed");
      }
      return ok(row);
    }
    if (path === "/chats/CHAT-TEST/attachments" && method === "POST") {
      const content = req.postDataBuffer()!;
      const audio = content.includes(Buffer.from("audio/"));
      const id = "13bbf02e-e2d8-4c9c-bd37-6d3990e80fb2";
      state.attachments.set(id, png);
      return ok({
        id,
        name: audio ? "语音.webm" : "测试.png",
        contentType: audio ? "audio/webm" : "image/png",
        size: png.length,
        duration: audio ? 1 : 0,
      });
    }
    if (path.includes("/attachments/"))
      return route.fulfill({ contentType: "image/png", body: png });
    if (path.startsWith("/chats/CHAT-TEST/calls")) {
      if (method === "POST") {
        const body = req.postDataJSON();
        if (body.action === "start")
          state.call = {
            id: body.clientId,
            conversationId: "CHAT-TEST",
            callerId: self,
            calleeId: self === "u_42" ? "m_7" : "u_42",
            kind: body.kind,
            state: "ringing",
            offer: body.sdp,
            answer: "",
            createdAt: "2026-09-12 12:00:00",
          };
        if (body.action === "accept") {
          state.call.state = "active";
          state.call.answer = body.sdp;
        }
        if (body.action === "candidate")
          state.signals.push({
            id: state.signals.length + 1,
            sender: self,
            candidate: body.candidate,
          });
        if (body.action === "end" || body.action === "reject")
          state.call.state = body.action === "reject" ? "rejected" : "ended";
      }
      const isList = path.endsWith("/calls");
      return ok({
        call:
          isList && !["ringing", "active"].includes(state.call?.state)
            ? null
            : state.call,
        signals: state.signals.filter(
          (s) =>
            s.sender !== self &&
            s.id > Number(u.searchParams.get("after") ?? 0),
        ),
      });
    }
    return ok({ list: [], total: 0 });
  });
}
async function open(page: Page, role = "customer") {
  await page.goto(`/${role === "master" ? "m" : "c"}/chats/CHAT-TEST`);
  await expect(page.getByRole("textbox", { name: "输入消息" })).toBeVisible();
  await expect(page.locator(".chat-message")).toHaveCount(3);
}
for (const role of ["customer", "master"] as const)
  for (const width of [375, 430, 768])
    test(`${role} ${width} 页面与输入栏完整可见`, async ({ page, context }) => {
      const state = fixture();
      await setup(context, role, state);
      await page.setViewportSize({ width, height: 932 });
      await open(page, role);
      const room = await page.locator(".chat-room").boundingBox();
      const input = await page
        .getByRole("textbox", { name: "输入消息" })
        .boundingBox();
      expect(room!.x).toBeGreaterThanOrEqual(0);
      expect(room!.x + room!.width).toBeLessThanOrEqual(width + 1);
      expect(input!.y + input!.height).toBeLessThanOrEqual(932);
      await page.screenshot({
        path: `artifacts/chat-results/${role}-${width}.png`,
      });
    });
test("发送结果不确定时复用幂等 ID，重载保留草稿和重试消息", async ({
  page,
  context,
}) => {
  const state = fixture();
  await setup(context, "customer", state);
  await open(page);
  state.failAfterAccept = true;
  await page.getByRole("textbox", { name: "输入消息" }).fill("一次消息");
  await page.getByRole("button", { name: "发送消息", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "发送失败 · 重试" }),
  ).toBeVisible();
  await page.getByRole("textbox", { name: "输入消息" }).fill("尚未发送的草稿");
  await page.reload();
  await expect(page.getByRole("textbox", { name: "输入消息" })).toHaveValue(
    "尚未发送的草稿",
  );
  await expect(page.getByText("一次消息", { exact: true })).toHaveCount(1);
  // A message accepted by the server is reconciled on reload without sending again.
  expect(state.sentIDs).toHaveLength(1);
  expect(state.messages.filter((m) => m.content === "一次消息")).toHaveLength(
    1,
  );
  state.failAfterAccept = true;
  await page.getByRole("textbox", { name: "输入消息" }).fill("点击重试");
  await page.getByRole("button", { name: "发送消息", exact: true }).click();
  await page.getByRole("button", { name: "发送失败 · 重试" }).click();
  expect(state.sentIDs[state.sentIDs.length - 1]).toBe(
    state.sentIDs[state.sentIDs.length - 2],
  );
  expect(state.messages.filter((m) => m.content === "点击重试")).toHaveLength(
    1,
  );
  await expect(page.getByText("已送达", { exact: true })).toHaveCount(0);
});
test("翻阅历史保持位置，收到新消息不抢滚动且不提前标读", async ({
  page,
  context,
}) => {
  const state = fixture();
  state.messages = Array.from({ length: 125 }, (_, i) =>
    message(i + 1, "master", `历史消息 ${i + 1}`),
  );
  await setup(context, "customer", state);
  await page.goto("/c/chats/CHAT-TEST");
  await expect(page.locator(".chat-message")).toHaveCount(50);
  await page.getByRole("button", { name: "查看更早消息" }).click();
  await expect(page.locator(".chat-message")).toHaveCount(100);
  const before = await page
    .locator(".chat-history")
    .evaluate((el) => el.scrollTop);
  state.messages.push(message(126, "master", "刚刚到达的新消息"));
  await expect(page.getByRole("button", { name: "1 条新消息" })).toBeVisible({
    timeout: 12000,
  });
  expect(
    await page.locator(".chat-history").evaluate((el) => el.scrollTop),
  ).toBeCloseTo(before, 0);
  expect(state.reads).not.toContain(126);
  await page.getByRole("button", { name: "1 条新消息" }).click();
  await expect.poll(() => state.reads.includes(126)).toBeTruthy();
});
test("图片上传预览、完整加载和键盘关闭大图", async ({ page, context }) => {
  const state = fixture();
  await setup(context, "customer", state);
  await open(page);
  await page
    .locator("input[type=file]")
    .setInputFiles({ name: "测试.png", mimeType: "image/png", buffer: png });
  await expect(page.getByAltText("待发送图片")).toBeVisible();
  await page.getByRole("button", { name: "发送附件" }).click();
  await expect(page.getByRole("button", { name: "查看大图" })).toBeVisible();
  expect(
    await page
      .locator(".chat-image-button img")
      .evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0),
  ).toBeTruthy();
  await page.getByRole("button", { name: "查看大图" }).click();
  await expect(page.locator("dialog[open]")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.locator("dialog[open]")).toHaveCount(0);
});
test("真实浏览器录音产生可试听附件，取消不会发送", async ({
  page,
  context,
}) => {
  const state = fixture();
  await setup(context, "customer", state);
  await open(page);
  await page.getByRole("button", { name: "录制语音" }).click();
  await expect(page.getByText(/录音中/)).toBeVisible();
  await page.waitForTimeout(1200);
  await page.getByRole("button", { name: "完成", exact: true }).click();
  await expect(page.locator(".chat-preview-media audio")).toBeVisible();
  expect(state.sentIDs).toHaveLength(0);
  await page.getByRole("button", { name: "取消", exact: true }).click();
  await expect(page.locator(".chat-attachment-preview")).toHaveCount(0);
});
test("双账号视频通话交换媒体并在挂断时释放设备", async ({ browser }) => {
  const state = fixture();
  const a = await browser.newContext({ permissions: ["microphone", "camera"] });
  const b = await browser.newContext({ permissions: ["microphone", "camera"] });
  await setup(a, "customer", state);
  await setup(b, "master", state);
  const caller = await a.newPage();
  const callee = await b.newPage();
  await open(caller);
  await open(callee, "master");
  await caller.getByRole("button", { name: "视频通话", exact: true }).click();
  await expect(
    callee.getByRole("button", { name: "接听", exact: true }),
  ).toBeVisible({ timeout: 15000 });
  await callee.getByRole("button", { name: "接听", exact: true }).click();
  await expect
    .poll(
      () =>
        caller
          .locator(".chat-call-remote")
          .evaluate(
            (v: HTMLVideoElement) => v.readyState >= 2 && v.videoWidth > 0,
          ),
      { timeout: 25000 },
    )
    .toBeTruthy();
  await expect
    .poll(
      () =>
        callee
          .locator(".chat-call-remote")
          .evaluate(
            (v: HTMLVideoElement) => v.readyState >= 2 && v.videoWidth > 0,
          ),
      { timeout: 25000 },
    )
    .toBeTruthy();
  await caller.screenshot({
    path: "artifacts/chat-results/video-connected.png",
  });
  await caller.getByRole("button", { name: "静音", exact: true }).click();
  await expect(
    caller.getByRole("button", { name: "取消静音", exact: true }),
  ).toHaveAttribute("aria-pressed", "true");
  await caller.getByRole("button", { name: "挂断", exact: true }).click();
  await expect(caller.locator(".chat-call-overlay")).toHaveCount(0);
  await expect(callee.locator(".chat-call-overlay")).toHaveCount(0, {
    timeout: 10000,
  });
  await a.close();
  await b.close();
});
