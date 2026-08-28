// DIY 东方材料目录。字段与 diy-service 及商城管理台一致。

export interface Material {
  id: number;
  name: string;
  spec: string;
  price: number;
  unit: string;
  category: string;
  fiveElements: string;
  materialType: string;
  shape: string;
  diameterMm: number;
  colorHex: string;
  textureKey: string;
  finish: string;
  translucency: number;
  image: string;
  stock: number;
  status: string;
}

type MaterialSeed = Omit<Material, 'id'>;
type MaterialSeedTuple = [string, string, number, string, string, string, string, string, number, string, string, string, number, string, number, string];

const seedRows: MaterialSeedTuple[] = [
  ["小叶紫檀圆珠", "10mm", 28, "颗", "main_bead", "wood", "wood", "round", 10, "#6B2727", "wood_grain", "polished", 0, "/assets/materials/rosewood.jpg", 500, "on_shelf"],
  ["星月菩提", "10mm", 18, "颗", "main_bead", "wood", "seed", "round", 10, "#D8C99F", "bodhi", "natural", 0, "/assets/materials/bodhi.jpg", 500, "on_shelf"],
  ["凤眼菩提", "10mm", 22, "颗", "main_bead", "wood", "seed", "round", 10, "#9C6B42", "bodhi", "natural", 0, "/assets/materials/rudraksha.jpg", 500, "on_shelf"],
  ["白玉", "8mm", 35, "颗", "main_bead", "earth", "jade", "round", 8, "#E7E4D7", "jade_cloud", "polished", 0.28, "/assets/materials/jade.jpg", 300, "on_shelf"],
  ["青金石", "10mm", 25, "颗", "main_bead", "water", "gemstone", "round", 10, "#234B91", "lapis", "polished", 0.05, "/assets/materials/lapis.jpg", 300, "on_shelf"],
  ["南红玛瑙", "8mm", 32, "颗", "main_bead", "fire", "gemstone", "round", 8, "#B93631", "agate", "polished", 0.22, "/assets/materials/agate.jpg", 300, "on_shelf"],
  ["蜜蜡", "10mm", 45, "颗", "main_bead", "earth", "organic", "round", 10, "#D99518", "amber", "polished", 0.42, "/assets/materials/amber.jpg", 260, "on_shelf"],
  ["黑曜石", "10mm", 12, "颗", "main_bead", "water", "gemstone", "round", 10, "#202726", "obsidian", "polished", 0.02, "/assets/materials/obsidian.jpg", 500, "on_shelf"],
  ["藏银三通", "10mm", 48, "个", "three_way", "metal", "metal", "three_way", 10, "#AEB8BA", "metal", "brushed", 0, "/assets/materials/silver-three-way.jpg", 120, "on_shelf"],
  ["蜜蜡佛头", "12mm", 68, "个", "buddha_head", "earth", "organic", "buddha_head", 12, "#D99518", "amber", "carved", 0.36, "/assets/materials/amber-head.jpg", 120, "on_shelf"],
  ["花丝莲花吊坠", "15mm", 20, "个", "pendant", "metal", "metal", "pendant", 15, "#C7A45A", "metal", "carved", 0, "/assets/materials/lotus-pendant.jpg", 200, "on_shelf"],
  ["白水晶隔片", "6mm", 2.5, "颗", "spacer", "water", "crystal", "disc", 6, "#E8F1F4", "crystal", "faceted", 0.82, "/assets/materials/crystal-spacer.jpg", 1000, "on_shelf"],
  ["流苏配饰", "", 28, "个", "tassel", "fire", "textile", "tassel", 14, "#A92F35", "silk", "woven", 0, "/assets/materials/tassel.jpg", 180, "on_shelf"],
  ["弹力绳", "", 2, "根", "cord", "wood", "cord", "cord", 0, "#8B6B4A", "cord", "woven", 0, "/assets/materials/cord.jpg", 1000, "on_shelf"],
  ["东陵玉", "8mm", 6, "颗", "main_bead", "wood", "jade", "round", 8, "#5D936C", "jade_cloud", "polished", 0.24, "", 600, "on_shelf"],
  ["和田青白玉", "8mm", 42, "颗", "main_bead", "metal", "jade", "round", 8, "#DCE2D5", "jade_cloud", "polished", 0.3, "", 260, "on_shelf"],
  ["岫玉", "10mm", 8, "颗", "main_bead", "wood", "jade", "round", 10, "#91AD75", "jade_cloud", "polished", 0.32, "", 500, "on_shelf"],
  ["紫水晶", "8mm", 12, "颗", "main_bead", "fire", "crystal", "round", 8, "#79579E", "crystal", "faceted", 0.58, "", 500, "on_shelf"],
  ["茶晶", "10mm", 16, "颗", "main_bead", "earth", "crystal", "round", 10, "#725546", "crystal", "polished", 0.48, "", 400, "on_shelf"],
  ["粉晶", "8mm", 10, "颗", "main_bead", "fire", "crystal", "round", 8, "#D98FA1", "crystal", "polished", 0.54, "", 600, "on_shelf"],
  ["海蓝宝", "8mm", 38, "颗", "main_bead", "water", "crystal", "faceted", 8, "#77ACC4", "crystal", "faceted", 0.66, "", 220, "on_shelf"],
  ["黄水晶切面珠", "8mm", 22, "颗", "main_bead", "earth", "crystal", "faceted", 8, "#D6A42C", "crystal", "faceted", 0.62, "", 320, "on_shelf"],
  ["虎眼石", "10mm", 9, "颗", "main_bead", "earth", "gemstone", "round", 10, "#A36C22", "tiger_eye", "polished", 0.08, "", 500, "on_shelf"],
  ["绿松石工艺珠", "10mm", 35, "颗", "main_bead", "wood", "gemstone", "round", 10, "#4B9B93", "turquoise", "polished", 0.03, "", 240, "on_shelf"],
  ["仿古工艺天珠", "12x30mm", 88, "颗", "main_bead", "earth", "ceramic", "barrel", 12, "#5A3727", "dzi", "matte", 0, "", 120, "on_shelf"],
  ["朱砂工艺珠", "8mm", 10, "颗", "main_bead", "fire", "ceramic", "round", 8, "#A92F35", "cinnabar", "matte", 0, "", 500, "on_shelf"],
  ["雷击枣木", "10mm", 18, "颗", "main_bead", "wood", "wood", "round", 10, "#6E4429", "wood_grain", "natural", 0, "", 260, "on_shelf"],
  ["桃木", "10mm", 4, "颗", "main_bead", "wood", "wood", "round", 10, "#B06E52", "wood_grain", "natural", 0, "", 800, "on_shelf"],
  ["崖柏", "10mm", 8, "颗", "main_bead", "wood", "wood", "round", 10, "#9A6038", "wood_grain", "polished", 0, "", 500, "on_shelf"],
  ["沉香木", "8mm", 30, "颗", "main_bead", "wood", "wood", "round", 8, "#4B3428", "wood_grain", "natural", 0, "", 180, "on_shelf"],
  ["金刚菩提", "12mm", 12, "颗", "main_bead", "wood", "seed", "round", 12, "#74462D", "seed", "natural", 0, "", 400, "on_shelf"],
  ["椰蒂", "8mm", 5, "颗", "main_bead", "water", "seed", "disc", 8, "#302722", "seed", "polished", 0, "", 700, "on_shelf"],
  ["青花瓷珠", "10mm", 15, "颗", "main_bead", "water", "ceramic", "round", 10, "#E8E5DA", "porcelain", "glazed", 0.04, "", 360, "on_shelf"],
  ["景泰蓝掐丝珠", "10mm", 26, "颗", "main_bead", "metal", "metal", "round", 10, "#276C79", "cloisonne", "polished", 0, "", 240, "on_shelf"],
  ["莲花琉璃珠", "10mm", 16, "颗", "main_bead", "fire", "glass", "round", 10, "#A85672", "glass", "carved", 0.55, "", 360, "on_shelf"],
  ["铜鎏金隔片", "6mm", 3, "颗", "spacer", "metal", "metal", "disc", 6, "#B98532", "metal", "brushed", 0, "", 800, "on_shelf"],
  ["祥云银色隔片", "6mm", 6, "颗", "spacer", "metal", "metal", "disc", 6, "#B9C2C4", "metal", "carved", 0, "", 600, "on_shelf"],
  ["绿松石三通", "14mm", 78, "个", "three_way", "wood", "gemstone", "three_way", 14, "#4B9B93", "turquoise", "carved", 0.02, "", 100, "on_shelf"],
  ["檀木佛头", "12mm", 28, "个", "buddha_head", "wood", "wood", "buddha_head", 12, "#6B372B", "wood_grain", "carved", 0, "", 200, "on_shelf"],
  ["朱砂葫芦吊坠", "18mm", 38, "个", "pendant", "fire", "ceramic", "pendant", 18, "#A92F35", "cinnabar", "carved", 0, "", 160, "on_shelf"],
  ["和田玉平安扣", "18mm", 120, "个", "pendant", "earth", "jade", "pendant", 18, "#E0E3D4", "jade_cloud", "polished", 0.28, "", 80, "on_shelf"],
  ["木鱼小吊坠", "15mm", 18, "个", "pendant", "wood", "wood", "pendant", 15, "#895436", "wood_grain", "carved", 0, "", 220, "on_shelf"],
  ["中国结流苏", "", 28, "个", "tassel", "fire", "textile", "tassel", 14, "#B52F39", "silk", "woven", 0, "", 260, "on_shelf"],
  ["五色编绳", "", 5, "根", "cord", "earth", "cord", "cord", 0, "#A35B43", "cord", "woven", 0, "", 900, "on_shelf"],
  ["玉线", "", 2, "根", "cord", "wood", "cord", "cord", 0, "#DDD7C9", "cord", "woven", 0, "", 1200, "on_shelf"]
];

const seeds: MaterialSeed[] = seedRows.map(([name, spec, price, unit, category, fiveElements, materialType, shape, diameterMm, colorHex, textureKey, finish, translucency, image, stock, status]) => ({
  name, spec, price, unit, category, fiveElements, materialType, shape,
  diameterMm, colorHex, textureKey, finish, translucency, image, stock, status,
}));

export const materials: Material[] = seeds.map((material, index) => ({
  id: index + 1,
  ...material,
}));
