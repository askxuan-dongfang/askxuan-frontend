import { test, expect, type Page } from "@playwright/test";
const h5 = "http://127.0.0.1:5383",
  admin = "http://127.0.0.1:5384/admin";
const categories = [
  { id: 7, name: "草木与香", parentId: 0, level: 1, sort: 2 },
  { id: 9, name: "随身好物", parentId: 0, level: 1, sort: 1 },
];
const product = {
  id: 1,
  name: "天然香珠手串",
  productNo: "QA-1",
  categoryId: 9,
  categoryName: "随身好物",
  description: "木质纹理，温润随身。请保持干燥，妥善养护。",
  mainImage: "/fixture-product.svg",
  status: "on_shelf",
  price: 68.35,
  marketPrice: 99,
  stock: 3,
  tags: "天然材质,随身好物",
  freightTemplateId: 4,
  images: [],
  skus: [],
};
const products = Array.from({ length: 23 }, (_, i) => ({
  ...product,
  id: i + 1,
  name: i ? "日常好物 " + (i + 1) : product.name,
  stock: i === 1 ? 0 : 3,
  price: 68.35 + i,
  mainImage: i === 1 ? "/missing.jpg" : "/fixture-product.svg",
}));
async function fixtures(
  page: Page,
  options: { failMore?: boolean; failDetail?: boolean } = {},
) {
  const requests: URL[] = [];
  let failed = false;
  await page.addInitScript(() => {
    localStorage.setItem("h5_token", "fixture");
    localStorage.setItem(
      "h5-auth",
      JSON.stringify({
        state: {
          role: "customer",
          token: "fixture",
          userId: 1,
          displayName: "本地验收",
        },
        version: 0,
      }),
    );
  });
  await page.route("**/fixture-product.svg", (r) =>
    r.fulfill({
      contentType: "image/svg+xml",
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#423021"/><circle cx="250" cy="250" r="130" stroke="#c6a066" stroke-width="44" fill="none"/><text x="250" y="264" text-anchor="middle" fill="#d8bd8d" font-size="38">好物</text></svg>',
    }),
  );
  await page.route("**/missing.jpg", (r) => r.fulfill({ status: 404 }));
  await page.route("**/api/v1/**", async (r) => {
    const u = new URL(r.request().url());
    let data: any = { list: [], total: 0 };
    if (u.pathname.endsWith("/products/categories"))
      data = { list: categories, total: 2 };
    else if (u.pathname.endsWith("/products/1")) {
      if (options.failDetail)
        return r.fulfill({
          status: 503,
          json: { code: 500, message: "商品连接暂不可用" },
        });
      data = {
        ...product,
        skus: [
          {
            id: 11,
            specName: "尺寸",
            specValue: "小号",
            price: 68.35,
            stock: 2,
          },
          {
            id: 12,
            specName: "尺寸",
            specValue: "大号",
            price: 78.8,
            stock: 3,
          },
          {
            id: 13,
            specName: "尺寸",
            specValue: "特大号",
            price: 88,
            stock: 0,
          },
        ],
        images: [
          {
            id: 1,
            imageUrl: "/fixture-product.svg?second",
            type: "main",
            sort: 1,
          },
        ],
      };
    } else if (u.pathname.endsWith("/products")) {
      requests.push(u);
      if (options.failMore && !failed && u.searchParams.get("page") === "2") {
        failed = true;
        return r.fulfill({
          status: 503,
          json: { code: 500, message: "加载中断，请重试" },
        });
      }
      let rows = [...products];
      if (u.searchParams.get("keyword"))
        rows = rows.filter((p) =>
          p.name.includes(u.searchParams.get("keyword")!),
        );
      if (u.searchParams.get("inStock") === "true")
        rows = rows.filter((p) => p.stock > 0);
      if (u.searchParams.get("sort") === "price_desc") rows.reverse();
      const n = Number(u.searchParams.get("page") || 1);
      data = {
        list: rows.slice((n - 1) * 20, n * 20),
        total: rows.length,
        page: n,
        size: 20,
      };
    }
    await r.fulfill({ json: { code: 0, message: "local fixture", data } });
  });
  return requests;
}
for (const width of [320, 390, 768])
  test(`store layout ${width}`, async ({ page }) => {
    await fixtures(page);
    await page.setViewportSize({ width, height: 900 });
    await page.goto(h5 + "/c/shop");
    await expect(page.locator(".store-product")).toHaveCount(20);
    await expect(page.locator(".store-picture-fallback").first()).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth + 1,
      ),
    ).toBeTruthy();
    await page.screenshot({ path: `/private/tmp/askxuan-store-${width}.png` });
    expect(
      (await page.locator(".store-product").first().boundingBox())!.y,
    ).toBeLessThan(600);
    await page.locator(".store-product").first().scrollIntoViewIfNeeded();
    await page.screenshot({
      path: `/private/tmp/askxuan-store-catalog-${width}.png`,
    });
  });
test("filters use server parameters; detail back preserves filters", async ({
  page,
}) => {
  const calls = await fixtures(page);
  await page.goto(h5 + "/c/shop");
  await page.getByRole("button", { name: "随身好物", exact: true }).click();
  await page
    .getByRole("combobox", { name: "商品排序" })
    .selectOption("price_desc");
  await page.getByRole("checkbox", { name: "只看有货" }).check();
  await expect(page.locator(".store-product").first()).toContainText(
    "日常好物 23",
  );
  expect(calls.at(-1)?.searchParams.get("categoryId")).toBe("9");
  expect(calls.at(-1)?.searchParams.get("inStock")).toBe("true");
  expect(calls.at(-1)?.searchParams.get("page")).toBe("1");
  await page.getByRole("textbox", { name: "搜索文创好物" }).fill("天然");
  await page
    .locator(".store-search")
    .getByRole("button", { name: "搜索", exact: true })
    .click();
  await expect(page.locator(".store-product")).toHaveCount(1);
  await page.locator(".store-product").click();
  await expect(
    page.getByRole("button", { name: "加入购物车", exact: true }),
  ).toBeEnabled();
  await page.goBack();
  await expect(page.getByRole("textbox", { name: "搜索文创好物" })).toHaveValue(
    "天然",
  );
  await expect(page.getByRole("checkbox", { name: "只看有货" })).toBeChecked();
});
test("pagination failure retries same page without duplicating items", async ({
  page,
}) => {
  const calls = await fixtures(page, { failMore: true });
  await page.goto(h5 + "/c/shop");
  await page.getByRole("button", { name: /再看看/ }).click();
  await expect(page.getByRole("alert")).toBeVisible();
  await page.getByRole("button", { name: "重新加载", exact: true }).click();
  await expect(page.locator(".store-product")).toHaveCount(23);
  expect(
    calls
      .filter((u) => u.searchParams.get("page") !== "1")
      .map((u) => u.searchParams.get("page")),
  ).toEqual(["2", "2"]);
});
test("SKU stock, cents, gallery and cart feedback", async ({ page }) => {
  await fixtures(page);
  await page.setViewportSize({ width: 390, height: 900 });
  await page.goto(h5 + "/c/shop/1");
  await expect(
    page.getByRole("button", { name: "加入购物车", exact: true }),
  ).toBeEnabled();
  await page.getByRole("button", { name: "加入购物车", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(page.getByRole("button", { name: /特大号/ })).toBeDisabled();
  await page.getByRole("button", { name: /尺寸 · 大号/ }).click();
  await expect(page.locator(".store-detail-copy")).toContainText("78.80");
  await page.getByRole("button", { name: "增加数量" }).click();
  await page.getByRole("button", { name: "增加数量" }).click();
  await expect(page.getByRole("button", { name: "增加数量" })).toBeDisabled();
  await page.screenshot({ path: "/private/tmp/askxuan-market-sheet.png" });
  await page.getByRole("button", { name: "确认加入购物车" }).click();
  await page.getByRole("button", { name: "查看商品图片2" }).click();
  await expect(
    page.getByRole("button", { name: "查看商品图片2" }),
  ).toHaveAttribute("aria-pressed", "true");
  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(page.locator(".store-detail-cart-note")).toContainText(
    "已放入购物车",
  );
  await page.screenshot({
    path: "/private/tmp/askxuan-store-detail.png",
    fullPage: true,
  });
});
test("failed authoritative detail cannot be purchased", async ({ page }) => {
  await fixtures(page, { failDetail: true });
  await page.goto(h5 + "/c/shop");
  await page.locator(".store-product").first().click();
  await expect(page.getByRole("alert")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "加入购物车", exact: true }),
  ).toBeDisabled();
  await expect(
    page.getByRole("button", { name: "请先刷新商品" }),
  ).toBeDisabled();
});
async function adminFixture(page: Page, failDetail = false) {
  const token =
    "e30." +
    Buffer.from(
      JSON.stringify({
        userId: 9901,
        roles: ["platform_super"],
        clientId: "platform-admin",
        exp: Math.floor(Date.now() / 1000) + 3600,
      }),
    ).toString("base64url") +
    ".fixture";
  await page.addInitScript((t) => {
    if (sessionStorage.getItem("storeSeeded")) return;
    sessionStorage.setItem("storeSeeded", "1");
    localStorage.setItem("df_platform_admin_token", t);
    localStorage.setItem(
      "df_platform_admin_user",
      JSON.stringify({ userId: 9901, nickname: "本地商城验收" }),
    );
  }, token);
  await page.route("**/fixture-product.svg", (r) =>
    r.fulfill({
      contentType: "image/svg+xml",
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#423021"/><circle cx="250" cy="250" r="130" stroke="#c6a066" stroke-width="44" fill="none"/></svg>',
    }),
  );
  const saved: any[] = [];
  await page.route("**/api/v1/**", (r) => {
    const p = new URL(r.request().url()).pathname;
    let data: any = { list: [], total: 0 };
    if (p.endsWith("/products/categories"))
      data = { list: categories, total: 2 };
    else if (p.endsWith("/products/1")) {
      if (failDetail)
        return r.fulfill({
          status: 503,
          json: { code: 500, message: "unavailable" },
        });
      if (r.request().method() === "PUT")
        saved.push(r.request().postDataJSON());
      data = product;
    } else if (p.endsWith("/products")) data = { list: [product], total: 1 };
    return r.fulfill({ json: { code: 0, message: "local fixture", data } });
  });
  return saved;
}
test("admin edit previews exact customer fields and preserves freight on save", async ({
  page,
}) => {
  const saved = await adminFixture(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(admin + "/commerce/products/edit/1");
  await expect(page.getByRole("textbox", { name: /商品名称/ })).toHaveValue(
    product.name,
  );
  await page
    .getByRole("textbox", { name: /商品名称/ })
    .fill("随身香珠 · 新名称");
  await expect(page.locator(".store-preview-product")).toContainText(
    "随身香珠 · 新名称",
  );
  await expect(page.locator(".store-preview-product")).toContainText("68.35");
  await page.screenshot({
    path: "/private/tmp/askxuan-store-admin.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "保存修改" }).click();
  await expect.poll(() => saved.length).toBe(1);
  expect(saved[0].freightTemplateId).toBe(4);
  expect(saved[0].tags).toBe(product.tags);
  expect(saved[0].categoryId).toBe(9);
});
test("admin failed detail disables save", async ({ page }) => {
  await adminFixture(page, true);
  await page.goto(admin + "/commerce/products/edit/1");
  await expect(
    page.getByText("商品加载失败，请重试后再编辑，避免覆盖已有数据。"),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: "保存修改" })).toBeDisabled();
});
test("slow previous search cannot overwrite newer results", async ({
  page,
}) => {
  await fixtures(page);
  await page.goto(h5 + "/c/shop");
  await expect(page.locator(".store-product")).toHaveCount(20);
  await page.route("**/api/v1/products?**", async (route) => {
    const q = new URL(route.request().url()).searchParams.get("keyword");
    if (q === "旧") {
      await new Promise((r) => setTimeout(r, 600));
      return route.fulfill({
        json: {
          code: 0,
          data: {
            list: [{ ...product, name: "旧查询商品" }],
            total: 1,
            page: 1,
            size: 20,
          },
        },
      });
    }
    if (q === "新")
      return route.fulfill({
        json: {
          code: 0,
          data: {
            list: [{ ...product, name: "新查询商品" }],
            total: 1,
            page: 1,
            size: 20,
          },
        },
      });
    return route.fallback();
  });
  const input = page.getByRole("textbox", { name: "搜索文创好物" }),
    search = page
      .locator(".store-search")
      .getByRole("button", { name: "搜索", exact: true });
  await input.fill("旧");
  await search.click();
  await input.fill("新");
  await search.click();
  await expect(page.locator(".store-product")).toContainText("新查询商品");
  await page.waitForTimeout(700);
  await expect(page.locator(".store-product")).toContainText("新查询商品");
  await expect(page.locator(".store-product")).toHaveCount(1);
});
for (const width of [390, 1440])
  test(`admin catalog modes and category preview ${width}`, async ({
    page,
  }) => {
    await adminFixture(page);
    await page.setViewportSize({ width, height: 1000 });
    await page.goto(admin + "/commerce/products");
    await expect(
      page.getByText("天然香珠手串", { exact: true }).first(),
    ).toBeVisible();
    await page.getByText("顾客视角", { exact: true }).click();
    await expect(page.getByRole("radio", { name: "顾客视角" })).toBeChecked();
    await expect(page.locator(".catalog-preview-grid article")).toContainText(
      product.name,
    );
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth + 1,
      ),
    ).toBeTruthy();
    await page.screenshot({
      path: `/private/tmp/askxuan-store-admin-list-${width}.png`,
      fullPage: true,
    });
    await page.goto(admin + "/commerce/categories");
    await expect(page.locator(".category-navigation-preview")).toContainText(
      "随身好物",
    );
  });

for (const code of [40102, 40103])
  test(`expired admin session redirects on business code ${code}`, async ({
    page,
  }) => {
    await adminFixture(page);
    await page.route("**/api/v1/admin/products?**", (route) =>
      route.fulfill({ json: { code, message: "token 无效" } }),
    );
    await page.goto(admin + "/commerce/products");
    await expect(page).toHaveURL(/\/admin\/login$/);
    await expect(page.getByPlaceholder("管理员账号")).toBeVisible();
  });

// Local-only checkout fixtures: no production orders or payments are created.
const basketItem = (
  skuId: number,
  name: string,
  price: number,
  quantity = 1,
) => ({
  productId: 1,
  skuId,
  productName: name,
  skuSpec: skuId === 11 ? "尺寸：小号" : "尺寸：大号",
  image: "/fixture-product.svg",
  price,
  quantity,
  stock: 3,
});
async function checkoutFixture(
  page: Page,
  { failCreate = false, stockChanged = false, experience = false } = {},
) {
  await fixtures(page);
  const calls: any[] = [],
    payments: any[] = [];
  let paid = false,
    failed = false;
  await page.addInitScript(
    (items) => {
      if (!sessionStorage.getItem("cartSeeded")) {
        localStorage.setItem(
          "askxuan-cart-v1",
          JSON.stringify({ state: { baskets: { "1": items } }, version: 0 }),
        );
        sessionStorage.setItem("cartSeeded", "1");
      }
    },
    [
      basketItem(11, "小号手串", 68.35, 2),
      basketItem(12, "大号手串", 78.8),
    ].map((i) => ({ ...i, isExperience: experience })),
  );
  await page.route("**/api/v1/users/addresses", (r) =>
    r.fulfill({
      json: {
        code: 0,
        data: {
          list: [
            {
              id: 5,
              name: "本地验收",
              phone: "13800000000",
              province: "上海市",
              city: "上海市",
              district: "浦东新区",
              detail: "测试地址，不发货",
              isDefault: true,
            },
          ],
        },
      },
    }),
  );
  const order = () => ({
    id: 81,
    orderNo: experience ? "EXO-81" : "LOCAL-81",
    isExperience: experience,
    status: paid ? "paid" : "pending_payment",
    payAmount: 136.7,
    totalAmount: 136.7,
    items: calls[0]?.items || [],
    userId: "1",
    addressId: 5,
    createTime: "2026-09-10T12:00:00",
  });
  await page.route("**/api/v1/orders", async (r) => {
    if (r.request().method() !== "POST") return r.fallback();
    calls.push(r.request().postDataJSON());
    if (failCreate && !failed) {
      failed = true;
      return r.fulfill({
        status: 503,
        json: { code: 500, message: "网络中断，请重试" },
      });
    }
    return r.fulfill({
      json: { code: 0, data: { id: 81, orderNo: "LOCAL-81" } },
    });
  });
  await page.route("**/api/v1/orders/81", (r) =>
    r.fulfill({ json: { code: 0, data: order() } }),
  );
  await page.route("**/api/v1/orders/81/returns", (r) =>
    r.fulfill({ json: { code: 0, data: [] } }),
  );
  await page.route("**/api/v1/payments", (r) => {
    payments.push(r.request().postDataJSON());
    paid = true;
    return r.fulfill({
      json: { code: 0, data: { id: 91, paymentNo: "LOCAL-PAY" } },
    });
  });
  await page.route("**/api/v1/payments/91", (r) =>
    r.fulfill({
      json: {
        code: 0,
        data: {
          id: 91,
          status: "success",
          amount: 136.7,
          paymentNo: "LOCAL-PAY",
        },
      },
    }),
  );
  if (stockChanged)
    await page.route("**/api/v1/products/1", (r) =>
      r.fulfill({
        json: { code: 0, data: { ...product, stock: 0, skus: [] } },
      }),
    );
  if (experience)
    await page.route("**/api/v1/products/1", (r) =>
      r.fulfill({
        json: {
          code: 0,
          data: {
            ...product,
            isExperience: true,
            sourceName: "公开案例",
            sourceUrl: "https://example.com/item",
            sourceNote: "体验案例",
            skus: [
              {
                id: 11,
                specName: "尺寸",
                specValue: "小号",
                price: 68.35,
                stock: 10,
              },
              {
                id: 12,
                specName: "尺寸",
                specValue: "大号",
                price: 78.8,
                stock: 10,
              },
            ],
          },
        },
      }),
    );
  return { calls, payments };
}
test("selected cart checkout survives reload and preserves unselected items", async ({
  page,
}) => {
  const { calls, payments } = await checkoutFixture(page);
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto(h5 + "/c/shop/cart");
  await page.getByRole("checkbox", { name: "选择大号手串" }).uncheck();
  await expect(page.locator(".market-cart-bar")).toContainText("136.70");
  await page.screenshot({ path: "/private/tmp/askxuan-market-cart-320.png" });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth + 1,
    ),
  ).toBeTruthy();
  await page.getByRole("button", { name: "去结算 (2)" }).click();
  await page.reload();
  await expect(
    page.getByRole("region", { name: "本次结算商品" }),
  ).not.toContainText("大号手串");
  await expect(
    page.getByRole("button", { name: "提交并模拟支付" }),
  ).toBeEnabled();
  await page.screenshot({
    path: "/private/tmp/askxuan-market-checkout-320.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "提交并模拟支付" }).click();
  await expect(page).toHaveURL(/orders\/81/);
  expect(calls).toHaveLength(1);
  expect(calls[0].items.map((i: any) => i.skuId)).toEqual([11]);
  expect(calls[0].items[0].quantity).toBe(2);
  expect(payments[0].amount).toBe(136.7);
  await page.goto(h5 + "/c/shop/cart");
  await expect(page.locator(".market-cart-item")).toHaveCount(1);
  await expect(page.locator(".market-cart-item")).toContainText("大号手串");
});
test("buy now creates a separate checkout and leaves cart untouched", async ({
  page,
}) => {
  const { calls } = await checkoutFixture(page);
  await page.setViewportSize({ width: 390, height: 900 });
  await page.goto(h5 + "/c/shop/1");
  await page.getByRole("button", { name: "立即购买", exact: true }).click();
  await page.getByRole("button", { name: "确认并去结算" }).click();
  await expect(page.locator(".market-cart-item")).toHaveCount(1);
  await expect(page.locator(".market-cart-bar")).toContainText("68.35");
  await page.getByRole("button", { name: "提交并模拟支付" }).click();
  await expect(page).toHaveURL(/orders\/81/);
  expect(calls[0].items).toHaveLength(1);
  expect(calls[0].items[0].quantity).toBe(1);
  await page.goto(h5 + "/c/shop/cart");
  await expect(page.locator(".market-cart-item")).toHaveCount(2);
  await expect(page.locator(".market-cart-bar")).toContainText("215.50");
});
test("checkout retry after refresh reuses the original request", async ({
  page,
}) => {
  const { calls } = await checkoutFixture(page, { failCreate: true });
  await page.goto(h5 + "/c/shop/cart");
  await page.getByRole("button", { name: "去结算 (3)" }).click();
  await page.getByRole("button", { name: "提交并模拟支付" }).click();
  await expect(page.getByRole("alert")).toContainText("网络中断");
  await page.reload();
  await page.getByRole("button", { name: "提交并模拟支付" }).click();
  await expect(page).toHaveURL(/orders\/81/);
  expect(calls).toHaveLength(2);
  expect(calls[1]).toEqual(calls[0]);
});
test("sold out cart item blocks checkout without writing an order", async ({
  page,
}) => {
  const { calls } = await checkoutFixture(page, { stockChanged: true });
  await page.goto(h5 + "/c/shop/cart");
  await page.getByRole("button", { name: "去结算 (3)" }).click();
  await page.getByRole("button", { name: "提交并模拟支付" }).click();
  await expect(page.getByRole("alert")).toContainText("库存不足");
  expect(calls).toHaveLength(0);
});
test("order cards show real status and totals without fabricated payment success", async ({
  page,
}) => {
  await fixtures(page);
  await page.route("**/api/v1/orders?*", (r) =>
    r.fulfill({
      json: {
        code: 0,
        data: {
          list: [
            {
              id: 81,
              orderNo: "LOCAL-81",
              status: "pending_payment",
              payAmount: 136.7,
              totalAmount: 136.7,
              items: [{ id: 1, ...basketItem(11, "小号手串", 68.35, 2) }],
            },
          ],
          total: 1,
        },
      },
    }),
  );
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto(h5 + "/c/shop/orders");
  await expect(page.locator(".market-order")).toContainText("待付款");
  await expect(page.locator(".market-order")).toContainText("共 2 件");
  await expect(page.locator(".market-order")).not.toContainText("模拟支付成功");
  await expect(page.getByRole("link", { name: "去付款" })).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth + 1,
    ),
  ).toBeTruthy();
  await page.screenshot({ path: "/private/tmp/askxuan-market-orders-320.png" });
});

test("experience checkout preserves disclosure and simulated order identity", async ({
  page,
}) => {
  const { calls, payments } = await checkoutFixture(page, { experience: true });
  await page.goto(h5 + "/c/shop/cart");
  await page.getByRole("button", { name: /去结算/ }).click();
  await expect(
    page.getByText("体验订单不发放消费积分。", { exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "提交并模拟支付", exact: true })
    .click();
  await expect(page).toHaveURL(/orders\/81/);
  expect(calls).toHaveLength(1);
  expect(payments[0].orderNo).toBe("EXO-81");
  expect(payments[0].channel).toBe("mock");
  await expect(page.getByText(/体验订单 · 全程模拟/)).toBeVisible();
});
test("experience detail discloses provenance and does not promise shipping", async ({
  page,
}) => {
  await checkoutFixture(page, { experience: true });
  await page.goto(h5 + "/c/shop/1");
  await expect(
    page.getByText("体验商品 · 模拟库存", { exact: true }),
  ).toBeVisible();
  await expect(page.getByRole("link", { name: /公开案例/ })).toHaveAttribute(
    "href",
    "https://example.com/item",
  );
  await page.getByText("配送与售后", { exact: true }).click();
  await expect(page.getByText(/本商品用于体验商城流程/)).toBeVisible();
  await page.screenshot({
    path: "/private/tmp/askxuan-case-detail.png",
    fullPage: true,
  });
});

test("paid response waits for order synchronization instead of asking for another payment", async ({
  page,
}) => {
  await checkoutFixture(page, { experience: true });
  let reads = 0;
  await page.route("**/api/v1/orders/81", (r) =>
    r.fulfill({
      json: {
        code: 0,
        data: {
          id: 81,
          orderNo: "EXO-81",
          isExperience: true,
          userId: "1",
          status: ++reads < 4 ? "pending_payment" : "paid",
          payAmount: 136.7,
          totalAmount: 136.7,
          items: [],
          addressId: 5,
          createTime: "2026-09-11",
        },
      },
    }),
  );
  await page.goto(h5 + "/c/shop/cart");
  await page.getByRole("button", { name: /去结算/ }).click();
  await page
    .getByRole("button", { name: "提交并模拟支付", exact: true })
    .click();
  await expect(
    page.getByText("支付已确认 · 正在同步订单", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "继续模拟支付", exact: true }),
  ).toHaveCount(0);
  await expect(page.getByText("已付款", { exact: true })).toBeVisible();
});
test("experience receipt dialog is explicit and cancellation does not complete order", async ({
  page,
}) => {
  await fixtures(page);
  let completed = false,
    writes = 0;
  await page.route("**/api/v1/orders/81", (r) =>
    r.fulfill({
      json: {
        code: 0,
        data: {
          id: 81,
          orderNo: "EXO-81",
          isExperience: true,
          userId: "1",
          status: completed ? "completed" : "shipped",
          payAmount: 118,
          totalAmount: 118,
          items: [],
          addressId: 5,
          createTime: "2026-09-11",
        },
      },
    }),
  );
  await page.route("**/api/v1/orders/81/returns", (r) =>
    r.fulfill({ json: { code: 0, data: [] } }),
  );
  await page.route("**/api/v1/orders/81/confirm", (r) => {
    writes++;
    completed = true;
    return r.fulfill({ json: { code: 0, data: {} } });
  });
  await page.goto(h5 + "/c/shop/orders/81");
  await page.getByRole("button", { name: "确认收货", exact: true }).click();
  await expect(page.getByRole("dialog")).toContainText("完成模拟收货？");
  await page.getByRole("button", { name: "关闭确认", exact: true }).click();
  expect(writes).toBe(0);
  await page.getByRole("button", { name: "确认收货", exact: true }).click();
  await page.getByRole("button", { name: "确认模拟收货", exact: true }).click();
  await expect(page.getByText("已完成", { exact: true })).toBeVisible();
  expect(writes).toBe(1);
});
