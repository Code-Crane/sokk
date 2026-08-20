const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");
const ignoredDirectories = new Set([
  ".git",
  ".next",
  ".expo",
  "coverage",
  "dist",
  "node_modules"
]);
const ignoredFiles = new Set(["pnpm-lock.yaml", "tsconfig.tsbuildinfo"]);
const sourceExtensions = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".cjs",
  ".mjs",
  ".json",
  ".example",
  ".md",
  ""
]);

const findings = [];

function toRelative(filePath) {
  return path.relative(repoRoot, filePath).replace(/\\/g, "/");
}

function addFinding(filePath, reason) {
  findings.push({
    file: toRelative(filePath),
    reason
  });
}

function shouldScan(filePath) {
  const basename = path.basename(filePath);

  if (ignoredFiles.has(basename)) {
    return false;
  }

  if (basename.endsWith(".tsbuildinfo")) {
    return false;
  }

  if (basename === ".env") {
    return false;
  }

  return sourceExtensions.has(path.extname(filePath));
}

function walk(directory, files = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      if (!ignoredDirectories.has(entry.name)) {
        walk(fullPath, files);
      }
      continue;
    }

    if (entry.isFile() && shouldScan(fullPath)) {
      files.push(fullPath);
    }
  }

  return files;
}

function assertEnvIgnored() {
  const gitignorePath = path.join(repoRoot, ".gitignore");
  const gitignore = fs.existsSync(gitignorePath)
    ? fs.readFileSync(gitignorePath, "utf8")
    : "";

  if (!/(^|\n)\.env(\n|$)/.test(gitignore) || !/(^|\n)\.env\.\*(\n|$)/.test(gitignore)) {
    addFinding(gitignorePath, ".env and .env.* must be ignored");
  }
}

function scanPublicSecretExposure(filePath, content) {
  const relative = toRelative(filePath);
  const isClientSide =
    relative.startsWith("mobile/") || relative.startsWith("admin/");

  if (isClientSide && /SUPABASE_SERVICE_ROLE_KEY|SERVICE_ROLE|serviceRoleKey/i.test(content)) {
    addFinding(filePath, "server-only service role key reference appears in client-side code");
  }

  if (
    /(EXPO_PUBLIC|NEXT_PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE)[A-Z0-9_]*/.test(
      content
    )
  ) {
    addFinding(filePath, "public environment variable name appears to expose a secret");
  }
}

function scanHardcodedSecretPatterns(filePath, content) {
  const suspiciousPatterns = [
    /sk_(live|test)_[A-Za-z0-9]{16,}/,
    /sb_secret_[A-Za-z0-9_-]{16,}/,
    /service_role_[A-Za-z0-9_-]{16,}/,
    /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/
  ];

  if (suspiciousPatterns.some((pattern) => pattern.test(content))) {
    addFinding(filePath, "source appears to contain a hardcoded secret/token pattern");
  }
}

function scanEnvExample(filePath, content) {
  if (!filePath.endsWith(".env.example")) {
    return;
  }

  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();

    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) {
      continue;
    }

    const [key, ...valueParts] = trimmed.split("=");
    const value = valueParts.join("=").trim();
    const looksSecret = /(SECRET|SERVICE_ROLE|PRIVATE|JWT_SECRET)/.test(key);
    const looksPlaceholder =
      !value ||
      /^(replace|your-|server-only|00000000-|example|placeholder)/i.test(value);

    if (looksSecret && !looksPlaceholder) {
      addFinding(filePath, `${key} in .env.example does not look like a placeholder`);
    }
  }
}

assertEnvIgnored();

for (const filePath of walk(repoRoot)) {
  const content = fs.readFileSync(filePath, "utf8");
  scanPublicSecretExposure(filePath, content);
  scanHardcodedSecretPatterns(filePath, content);
  scanEnvExample(filePath, content);
}

if (findings.length > 0) {
  console.error("Secret scan failed:");
  for (const finding of findings) {
    console.error(`- ${finding.file}: ${finding.reason}`);
  }
  process.exit(1);
}

console.log("Secret scan passed: no obvious hardcoded secrets or client-exposed server keys found.");
