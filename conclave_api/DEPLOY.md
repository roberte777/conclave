# Fly.io Deployment Instructions

## Initial Setup (one-time)

1. Install Fly CLI if not already installed:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. Login to Fly.io:
   ```bash
   fly auth login
   ```

3. Launch the app (from the conclave_api directory):
   ```bash
   cd conclave_api
   fly launch --no-deploy
   ```
   - Choose a unique app name or accept the suggested one
   - Select a region (recommend iad for US East)
   - Don't add any databases when prompted (we're using SQLite with a volume)

## Deploy

Deploy the application:
```bash
fly deploy
```

## Post-deployment

1. Check the app status:
   ```bash
   fly status
   ```

2. View logs:
   ```bash
   fly logs
   ```

3. Open your deployed app:
   ```bash
   fly open
   ```

## Environment Variables

The following environment variables are configured in fly.toml:
- `PORT`: 8080 (Fly.io internal port)
- `DATABASE_URL`: sqlite:/data/conclave.db?mode=rwc (uses persistent volume)

## Persistent Storage

The app uses a Fly.io volume mounted at `/data` to persist the SQLite database across deployments and restarts.

## Updating

To deploy updates:
1. Make your code changes
2. Commit to git (optional but recommended)
3. Run `fly deploy` from the conclave_api directory

## Scaling

To scale the app:
```bash
# Scale to 2 instances (not recommended for SQLite)
fly scale count 2

# Scale memory/CPU
fly scale vm shared-cpu-1x --memory 1024
```

Note: Since we're using SQLite, it's best to keep this as a single instance. For multi-instance deployments, consider migrating to PostgreSQL.

## Monitoring

- View metrics: `fly dashboard`
- SSH into the instance: `fly ssh console`
- Database backup: `fly ssh console -C "cat /data/conclave.db" > backup.db`