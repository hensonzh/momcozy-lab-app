#!/usr/bin/env node
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, "..");

const requiredArtifacts = [
  {
    kind: "web-rollback-bundle",
    relPath: "legacy_web/dist/index.html",
    command: "npm run build",
  },
  {
    kind: "flutter-local-debug-apk",
    relPath: "flutter_app/build/app/outputs/flutter-apk/app-local-debug.apk",
    command: "flutter build apk --debug --flavor local",
  },
  {
    kind: "flutter-staging-release-apk",
    relPath: "flutter_app/build/app/outputs/flutter-apk/app-staging-release.apk",
    command:
      "flutter build apk --release --flavor staging --dart-define=MOMCOZY_ENV=staging",
  },
];

function runGit(args) {
  const result = spawnSync("git", args, {
    cwd: projectRoot,
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout.trim() : "";
}

function sha256(absPath) {
  return createHash("sha256").update(readFileSync(absPath)).digest("hex");
}

function collectDistFiles() {
  const distDir = path.join(projectRoot, "legacy_web", "dist");
  const files = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const absPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(absPath);
      } else if (entry.isFile()) {
        const relPath = path.relative(projectRoot, absPath);
        const stats = statSync(absPath);
        files.push({ relPath, bytes: stats.size, sha256: sha256(absPath) });
      }
    }
  };
  if (existsSync(distDir)) walk(distDir);
  files.sort((a, b) => a.relPath.localeCompare(b.relPath));
  return files;
}

const failures = [];
const artifacts = requiredArtifacts.map((artifact) => {
  const absPath = path.join(projectRoot, artifact.relPath);
  if (!existsSync(absPath)) {
    failures.push(`${artifact.relPath} is missing; run ${artifact.command}`);
    return { ...artifact, exists: false };
  }
  const stats = statSync(absPath);
  if (!stats.isFile() || stats.size <= 0) {
    failures.push(`${artifact.relPath} is empty or not a file`);
    return { ...artifact, exists: false, bytes: stats.size };
  }
  return {
    ...artifact,
    exists: true,
    bytes: stats.size,
    sha256: sha256(absPath),
  };
});

const distFiles = collectDistFiles();
const hasJs = distFiles.some((file) => file.relPath.endsWith(".js"));
const hasCss = distFiles.some((file) => file.relPath.endsWith(".css"));
if (!hasJs) failures.push("legacy_web/dist/ has no JavaScript bundle");
if (!hasCss) failures.push("legacy_web/dist/ has no CSS bundle");

if (failures.length > 0) {
  console.error("Flutter rollback package check failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

const manifest = {
  generatedAt: new Date().toISOString(),
  git: {
    branch: runGit(["branch", "--show-current"]),
    commit: runGit(["rev-parse", "HEAD"]),
  },
  rollbackPolicy: {
    source: "current Capacitor/Web app remains the rollback source until cutover",
    capacitorAppId: "com.momcozymai.app",
    flutterLocalAppId: "com.momcozymai.app.flutterpoc.local",
    flutterStagingAppId: "com.momcozymai.app.flutterpoc.staging",
    flutterProductionShapedAppId: "com.momcozymai.app.flutterpoc",
  },
  verification: {
    webBuildCommand: "npm run build",
    flutterGateCommand: "npm run flutter:release-gate",
    signing:
      "staging release may use debug signing unless MOMCOZY_REQUIRE_RELEASE_SIGNING=1 is set",
  },
  artifacts,
  webBundle: {
    fileCount: distFiles.length,
    totalBytes: distFiles.reduce((sum, file) => sum + file.bytes, 0),
    files: distFiles,
  },
};

const outputPath = path.join(
  projectRoot,
  "legacy_web",
  "dist",
  "flutter-rollback-manifest.json",
);
mkdirSync(path.dirname(outputPath), { recursive: true });
writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);

for (const artifact of artifacts) {
  console.log(`OK ${artifact.kind}: ${artifact.relPath}`);
}
console.log(`OK web bundle files: ${distFiles.length}`);
console.log(`Wrote ${path.relative(projectRoot, outputPath)}`);
