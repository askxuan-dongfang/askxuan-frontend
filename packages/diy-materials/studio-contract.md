# Material studio v1

`renderAssets.studio` extends the existing JSON field. Absence means legacy material behavior; do not rewrite old design snapshots or material IDs.

```ts
interface MaterialStudio {
  version: 1;
  part: 'bead' | 'hanging';
  motion: 'fixed' | 'rigid' | 'flexible';
  source: 'template' | 'generated';
  templateId: string;
  dimensionsMm: [number, number, number]; // width X, thickness Y, length Z
  rotation: [number, number, number]; // model-local XYZ Euler degrees, applied before bounding normalization
  mount: [number, number, number]; // normalized bounding-box position, each axis [-.5,.5]
  connectorMm: number;
  rigidFraction: number;
  photos: string[];
  model?: { jobId: string; glbUrl: string; usdzUrl: string };
  previewConfirmed: boolean;
}
```

- `part=bead` requires `motion=fixed`; `part=hanging` requires `motion=rigid|flexible`. Connection behavior is independent of the existing business category; changing part/motion must not rewrite that category.
- Customer material groups are 主珠、隔珠、佛头、三通、动态挂件、绳线, alongside 全部/正在使用. The accessory group includes pendant/tassel categories and authored hanging parts; fixed pendant/tassel models keep their authored fixed behavior. Cord takes precedence and remains separate. Material IDs, stored categories and order subtypes are unchanged.
- `source=template` uses `round`, `disc`, `barrel`, `faceted`, or a key from `geometry-profiles.json.models`. `templateId=custom` is reserved for `source=generated`. Generated assets are ready, permanently stored GLB + USDZ, bound to the server-owned generation job.
- Dimensions are finite in [.5,120] mm per axis; maximum 4 photograph URLs. Rotation is finite [-180,180] degrees per axis. Connector is [1,30] mm for hanging parts; zero for beads. A hanging mount must have Z < .5, leaving a nonzero body length. Rigid fraction is [.1,.9], only used by flexible parts.
- All model vertices are rotated, then normalized independently against that rotated bounding box to [-.5,.5], then multiplied by dimensionsMm. The mount follows the same normalized coordinates. Positive Z runs from the attachment toward the free end; flexible deformation uses that longitudinal axis. Admin provides orientation controls and displays axes/mount before confirmation.
- Ordinary beads align their bore center at the common bracelet plane Y=0. Their main bore axis is local X. The main cord never follows a hanging body's silhouette or changing physical height; hanging objects attach to a ring slot through their own fixed-length short connector. Whole-bracelet rotation keeps that plane intact.
- Authored ordinary bead spacing follows its X dimension; authored hanging slots use a 2 mm pitch, spacing and radial footprint. Hanging body dimensions affect their rendered body, collision and preview framing, not the main wearing length.
- For templates, initialize dimensions from the existing model bounds times nominal diameter, and mount from its existing anchor converted to normalized bounds. Model position is centered on its normalized bounds for preview. Main-thread body transforms and custom model geometry must use identical bounds normalization on Web/native.
- Preview confirmation is cleared whenever dimensions, source/model/template, photos, orientation, part/motion, mount, connector or rigid fraction changes. New studio materials save as drafts (off_shelf). Publish validates configuration, previewConfirmed, and ready model ownership. Existing legacy materials remain readable/editable without an automatic mass migration.
- AI generation needs a configured provider. Never return a template or pretend a generated model is ready when the provider fails or is unconfigured. User-confirmed generated assets are persisted; frontends never expose provider keys or depend on expiring provider URLs.

The H5 app, admin preview and iOS app consume the same material metadata. Existing prices, quantities, saved design IDs, order snapshots and reward semantics are unchanged.
