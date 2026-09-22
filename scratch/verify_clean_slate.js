// Test script to verify clean slate state of the database
const API_URL = 'http://localhost:5080/api';

async function main() {
  console.log('=== VERIFYING CLEAN SLATE STATE ===\n');

  // 1. Admin login test
  console.log('1. Testing Admin Login (admin@loopworth.local)...');
  const adminRes = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@loopworth.local', password: 'Admin123!' })
  });

  if (!adminRes.ok) {
    console.error(`FAILED: Admin login returned status ${adminRes.status}`);
    process.exit(1);
  }
  const adminData = await adminRes.json();
  console.log(` SUCCESS: Admin logged in! User: ${adminData.name}, Role: ${adminData.role}`);
  const adminToken = adminData.token;

  // 2. Verify deleted accounts cannot log in
  console.log('\n2. Verifying Deleted Demo Accounts cannot log in...');
  const accountsToTest = [
    { email: 'agent@loopworth.local', password: 'Agent123!', role: 'Agent' },
    { email: 'agent2@loopworth.local', password: 'Agent123!', role: 'Agent 2' },
    { email: 'customer@loopworth.local', password: 'Customer123!', role: 'Customer' },
    { email: 'partner@loopworth.local', password: 'Partner123!', role: 'Partner' }
  ];

  for (const acc of accountsToTest) {
    const res = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: acc.email, password: acc.password })
    });
    if (res.status === 401 || res.status === 400) {
      console.log(` SUCCESS: ${acc.role} (${acc.email}) is purged (HTTP ${res.status}).`);
    } else {
      console.error(` UNEXPECTED: ${acc.role} (${acc.email}) login returned HTTP ${res.status}!`);
    }
  }

  // 3. Verify Operational Tables are empty
  console.log('\n3. Verifying Operational Tables are empty...');
  const headers = { Authorization: `Bearer ${adminToken}` };

  // Items
  const itemsRes = await fetch(`${API_URL}/items`, { headers });
  const itemsData = await itemsRes.json();
  const items = itemsData.items || [];
  console.log(` Items count: ${items.length}`);

  // Partners
  const partnersRes = await fetch(`${API_URL}/partners`, { headers });
  const partners = await partnersRes.json();
  console.log(` Partners count: ${Array.isArray(partners) ? partners.length : 'N/A'}`);

  // Collection Agents
  const agentsRes = await fetch(`${API_URL}/admin/collection-agents`, { headers });
  const agents = await agentsRes.json();
  console.log(` Collection Agents count: ${Array.isArray(agents) ? agents.length : 'N/A'}`);

  // Collection Requests
  const crRes = await fetch(`${API_URL}/admin/collections`, { headers });
  const crs = await crRes.json();
  console.log(` Collection Requests count: ${Array.isArray(crs) ? crs.length : 'N/A'}`);

  // Categories (Should still exist)
  const catRes = await fetch(`${API_URL}/categories`, { headers });
  const cats = await catRes.json();
  console.log(` Categories count: ${Array.isArray(cats) ? cats.length : 'N/A'} (Should be >= 6)`);

  const allClear = (items.length === 0) && (partners.length === 0) && (agents.length === 0) && (crs.length === 0) && (cats.length >= 6);
  if (allClear) {
    console.log('\n=== ALL CHECKS PASSED: DATABASE IS A VERIFIED CLEAN SLATE WITH ADMIN CREDENTIALS PRESERVED ===');
  } else {
    console.error('\n=== WARNING: SOME TABLES WERE NOT EMPTY ===');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
