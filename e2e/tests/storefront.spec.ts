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
    await page.getByRole("button", { name: "逛逛好物" }).click();
    await page.waitForTimeout(400);
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
  await page.goto(h5 + "/c/shop/1");
  await expect(
    page.getByRole("button", { name: "加入购物车", exact: true }),
  ).toBeEnabled();
  await expect(page.getByRole("button", { name: /特大号/ })).toBeDisabled();
  await page.getByRole("button", { name: /尺寸 · 大号/ }).click();
  await expect(page.locator(".store-detail-copy")).toContainText("78.80");
  await page.getByRole("button", { name: "增加数量" }).click();
  await page.getByRole("button", { name: "增加数量" }).click();
  await expect(page.getByRole("button", { name: "增加数量" })).toBeDisabled();
  await page.getByRole("button", { name: "查看商品图片2" }).click();
  await expect(
    page.getByRole("button", { name: "查看商品图片2" }),
  ).toHaveAttribute("aria-pressed", "true");
  await page.getByRole("button", { name: "加入购物车", exact: true }).click();
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
    localStorage.setItem("df_platform_admin_token", t);
    localStorage.setItem(
      "df_platform_admin_user",
      JSON.stringify({ userId: 9901, nickname: "本地商城验收" }),
    );
  }, token);
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
    await expect(page.getByRole("radio", {name:"顾客视角"})).toBeChecked();
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
