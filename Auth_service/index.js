const express = require('express');
const client = require('prom-client');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');

const app = express();
const PORT = 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'secret123';

// PostgreSQL setup
const pool = new Pool({
  user: process.env.POSTGRES_USER || 'moath',
  host: process.env.DB_HOST || 'postgres-service',
  database: process.env.POSTGRES_DB || 'users_db',
  password: process.env.DB_PASSWORD || 'moath123',
  port: process.env.DB_PORT || 5432,
});

app.use(express.json()); // for JSON body parsing

client.collectDefaultMetrics({ prefix: 'auth_service_' });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'code'],
});

const httpRequestDurationSeconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5]
});

app.use((req, res, next) => {
  const end = httpRequestDurationSeconds.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.route.path : req.path;
    httpRequestCounter.labels(req.method, route, res.statusCode).inc();
    end({ method: req.method, route: route, code: res.statusCode });
  });
  next();
});

app.get('/', (req, res) => {
  res.send('Auth Service is running!');
});

// Auth endpoint (login)
app.post('/auth', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ error: 'Email and password are required' });

  try {
    const result = await pool.query(
      'SELECT * FROM users WHERE email = $1 AND password = $2',
      [email, password]
    );

    const user = result.rows[0];
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

   
   
    const token = jwt.sign({ email: user.email, user_id: user.id }, JWT_SECRET, { expiresIn: '1h' });

    res.status(200).json({ message: 'Authenticated', token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(PORT, () => {
  console.log(`Auth service listening on port ${PORT}`);
});
