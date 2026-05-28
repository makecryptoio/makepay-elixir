import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = process.cwd();

const requiredFiles = [
  'README.md',
  'mix.exs',
  'lib/make_pay.ex',
  'lib/make_pay/client.ex',
  'lib/make_pay/error.ex',
  'lib/make_pay/transport.ex',
  'lib/make_pay/transport/httpc.ex',
  'lib/make_pay/webhook.ex',
  'lib/make_pay/phoenix/webhook_plug.ex',
  'test/make_pay/client_test.exs',
  'test/make_pay/webhook_test.exs',
  'test/make_pay/phoenix/webhook_plug_test.exs',
  'docs/ROADMAP.md',
  'docs/REPOSITORY_PROTECTION.md',
  'SECURITY.md',
  'CONTRIBUTING.md',
  '.github/workflows/validate.yml',
  '.github/dependabot.yml',
];

const forbidden = [
  new RegExp('Jo' + 'zef', 'i'),
  new RegExp('orange' + 'btc', 'i'),
  new RegExp('vcp' + '_[A-Za-z0-9]+'),
  new RegExp('sbp' + '_[A-Za-z0-9]+'),
  new RegExp('Payments' + '2025'),
];

function walk(dir) {
  const entries = [];
  for (const name of readdirSync(dir)) {
    if (['.git', '_build', 'deps', 'doc'].includes(name)) {
      continue;
    }

    const path = join(dir, name);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      entries.push(...walk(path));
    } else {
      entries.push(path);
    }
  }
  return entries;
}

function requireText(file, needles) {
  const content = readFileSync(join(root, file), 'utf8');
  for (const needle of needles) {
    if (!content.includes(needle)) {
      throw new Error(`${file} is missing ${needle}`);
    }
  }
}

for (const file of requiredFiles) {
  if (!existsSync(join(root, file))) {
    throw new Error(`Missing required file: ${file}`);
  }
}

requireText('mix.exs', [
  'app: :make_pay',
  'name: "make_pay"',
  '{:jason, "~> 1.4"}',
  '{:plug, "~> 1.15", optional: true}',
  'https://github.com/makecryptoio/makepay-elixir',
]);

requireText('lib/make_pay/client.ex', [
  'X-MakeCrypto-Key-Id',
  'X-MakeCrypto-Key-Secret',
  '/api/partner/v1/makepay/payment-links',
  '/api/partner/v1/makepay/bookkeeping/invoices',
]);

requireText('lib/make_pay/webhook.ex', [
  ':crypto.mac(:hmac, :sha256',
  'timestamp.raw_body',
  'secure_compare',
]);

requireText('lib/make_pay/phoenix/webhook_plug.ex', [
  'Plug.Conn.read_body',
  'x-makepay-signature',
  'handler',
]);

for (const path of walk(root)) {
  const rel = relative(root, path);
  if (/\.(png|jpg|jpeg|gif|webp|zip|tar|gz)$/i.test(rel)) {
    continue;
  }

  const content = readFileSync(path, 'utf8');
  for (const pattern of forbidden) {
    if (pattern.test(content)) {
      throw new Error(`Forbidden identifier or secret-like value found in ${rel}`);
    }
  }
}

console.log('MakePay Elixir package validation passed.');
