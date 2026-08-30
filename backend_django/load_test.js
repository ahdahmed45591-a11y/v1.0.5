// k6 load test contre le backend local (docker compose, port 3001).
// Un seul login dans setup() : /api/auth/login est throttle a 10/min,
// le refaire par iteration ferait echouer le test sur le throttle lui-meme.
//
//   docker compose up -d
//   k6 run backend_django/load_test.js
//   BASE=http://localhost:3001 VUS=30 DURATION=1m k6 run backend_django/load_test.js

import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.BASE || "http://localhost:3001";
const ADMIN = { email: "admin@elephantbourse.ci", password: "admin2024" };

export const options = {
  stages: [
    { duration: "20s", target: Number(__ENV.VUS) || 20 },
    { duration: __ENV.DURATION || "40s", target: Number(__ENV.VUS) || 20 },
    { duration: "10s", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<500"],
    http_req_failed: ["rate<0.01"],
  },
};

export function setup() {
  const res = http.post(`${BASE}/api/auth/login`, JSON.stringify(ADMIN), {
    headers: { "Content-Type": "application/json" },
  });
  check(res, { "login OK": (r) => r.status === 200 });
  return { token: res.json("token") };
}

export default function (data) {
  const auth = { headers: { Authorization: `Bearer ${data.token}` } };

  check(http.get(`${BASE}/health`), { "health 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/api/stocks`), { "stocks 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/api/stocks/SNTS`), { "stock detail 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/api/admin/users`, auth), { "admin users 200": (r) => r.status === 200 });

  sleep(1);
}
