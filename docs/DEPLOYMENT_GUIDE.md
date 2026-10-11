# QueueLess hosting guide

This guide describes a production-style deployment of QueueLess using Render for the Rails API and PostgreSQL, plus a static site host for the Vite frontend. The examples use Render for both parts to keep the setup in one dashboard. The same architecture works with another Rails host, managed PostgreSQL provider, and static site host.

## What you will deploy

```text
Staff, patients, and waiting-room screen
                  |
                  v
         Static React frontend
                  |
          HTTPS JSON requests
                  v
        Rails API web service
                  |
                  v
         Managed PostgreSQL
```

The frontend and API are separate services. PostgreSQL stores queues, visits, and staff accounts. Only the frontend URL is public to users; the Rails API is also internet reachable, with staff routes requiring sign-in and selected health/status/display routes public.

## Before deploying

1. Review the current application limitations under [Security before production](#security-before-production). This is an MVP and should not receive real patient information until the required review and controls are in place.
2. Make sure `.env` files, database credentials, and local data are not committed. The root `.gitignore` excludes `.env` files.
3. Create a private GitHub repository and push the project. Render deploys from a connected Git provider. In PowerShell, from the project folder:

   ```powershell
   git init -b main
   git add .
   git commit -m "Prepare QueueLess deployment"
   git remote add origin https://github.com/YOUR-ACCOUNT/queueless.git
   git push -u origin main
   ```

   Create the GitHub repository empty, then replace `YOUR-ACCOUNT` with your account name. Do not commit local `.env` files, `node_modules`, or patient exports.

## Deploy the frontend

Create a Render **Static Site** from the GitHub repository. The frontend is in a monorepo subdirectory, so configure:

| Setting | Value |
| --- | --- |
| Root Directory | `frontend` |
| Build Command | `npm ci && npm run build` |
| Publish Directory | `dist` |
| Environment | `VITE_API_BASE_URL=https://queueless-api.onrender.com/api/v1` |

Choose a site name/domain and note its final HTTPS origin, for example `https://queueless-frontend.onrender.com`. The example API hostname assumes you will name the API service `queueless-api`; if the provider assigns a different URL, update `VITE_API_BASE_URL` and rebuild the frontend after the API exists.

QueueLess uses React Router. In the static site's Redirects/Rewrites settings add:

| Source | Action | Destination |
| --- | --- | --- |
| `/*` | Rewrite | `/index.html` |

This makes direct links such as `/display/1` and `/token/<lookup>` load the React app. It must be a rewrite, not a redirect.

## Create the PostgreSQL database

Create a managed PostgreSQL database in the same region as the API service. For an India-based clinic, choose Singapore when it is available in the provider's region list, or select the region closest to your users. Copy the database's **internal/private connection URL** for the API service. Keep this URL secret.

Use a persistent production database plan with backup and restore options suitable for the data and uptime you require. Do not use the local WSL PostgreSQL database as a production database.

## Deploy the Rails API

Create a Render **Web Service** from the same GitHub repository:

| Setting | Value |
| --- | --- |
| Root Directory | `backend` |
| Runtime | Ruby |
| Region | Same region as PostgreSQL |
| Build Command | `bundle install && bundle exec rails db:migrate` |
| Start Command | `bundle exec rails server -b 0.0.0.0` |

On a Render paid web-service plan, migrations can instead run in the service's Pre-Deploy Command (`bundle exec rails db:migrate`) with `bundle install` as the Build Command. Render's Pre-Deploy Command is not available on its free compute plan; the build-command migration above is the documented alternative.

Set these environment variables on the API service. Enter passwords and database URLs in the provider's secret manager; never put secret values in Git or this guide.

| Variable | Value |
| --- | --- |
| `RAILS_ENV` | `production` |
| `DATABASE_URL` | Internal/private connection URL from the managed PostgreSQL service. |
| `SECRET_KEY_BASE` | Generate a long random Rails secret with `bundle exec rails secret`; store the result only in the provider's secret manager. |
| `FRONTEND_ORIGIN` | Exact deployed frontend origin, e.g. `https://queueless-frontend.onrender.com`. No trailing slash or path. |
| `QUEUELESS_ADMIN_USERNAME` | Your chosen first administrator username. |
| `QUEUELESS_ADMIN_PASSWORD` | A unique password with at least 12 characters. Do not use `admin`. |
| `QUEUELESS_ADMIN_NAME` | Optional name shown in the staff workspace. |
| `QUEUELESS_DOCTOR_USERNAME` / `QUEUELESS_DOCTOR_PASSWORD` | Optional first doctor account; configure both, with a unique password of at least 12 characters. |
| `QUEUELESS_DOCTOR_NAME` | Optional doctor display name. |
| `QUEUELESS_RECEPTIONIST_USERNAME` / `QUEUELESS_RECEPTIONIST_PASSWORD` | Optional first receptionist account; configure both, with a unique password of at least 12 characters. |
| `QUEUELESS_RECEPTIONIST_NAME` | Optional receptionist display name. |

The host supplies `PORT`; Puma reads that value from the app configuration. The app requires `FRONTEND_ORIGIN` in production so the browser can call the API only from the configured site origin.

### Initialize the production database

The build command applies schema migrations. After the API service is deployed and its environment variables are configured, run this command **once** in the provider's service shell or one-off command facility:

```bash
bundle exec rails db:seed
```

This creates the default queues and only the staff accounts configured in the production environment. It creates no demo passwords and no sample patients. Seed execution updates the configured staff accounts, so do not make `db:seed` part of every deploy. Render's service shell requires a paid compute plan; if your chosen host/plan has no shell, run this as a one-time deployment task using that provider's supported secure method. Do not put seeding into the recurring start command.

Log in at the frontend using the administrator username and password you configured. Create any additional staff accounts using the environment variables and seed task before opening the app to staff. After deployment, reception staff can register visits.

## Connect and verify the services

1. Open the Rails health check at `https://YOUR-API-HOST/api/v1/health`. Expect `{"status":"ok","database":"connected"}`.
2. Set the frontend's `VITE_API_BASE_URL` to `https://YOUR-API-HOST/api/v1`, then trigger a new static-site deployment. Vite embeds this setting at build time.
3. Set the API's `FRONTEND_ORIGIN` to the frontend's exact HTTPS origin and redeploy the API.
4. Open the frontend root URL and sign in with the production administrator account.
5. Register a fictional check-in, use **Call next**, and verify that the queue and display update.
6. Open `https://YOUR-FRONTEND-HOST/display/1` on the waiting-room monitor and select **Full screen**. Queue IDs can be checked from the administrator queue list. Keep this public page free of names and visit details.
7. Verify the private customer status URL and a CSV export with test data before inviting staff.

## Custom domains

Use separate hostnames such as `app.example.com` for the frontend and `api.example.com` for the API. Add each hostname in the corresponding hosting dashboard and follow its DNS/TLS instructions. Then update:

- Frontend `VITE_API_BASE_URL` to `https://api.example.com/api/v1`, followed by a frontend rebuild.
- API `FRONTEND_ORIGIN` to `https://app.example.com`, followed by an API redeploy.
- Public display URL to `https://app.example.com/display/1` (use the correct queue ID).

## Common deployment problems

| Symptom | Check |
| --- | --- |
| Browser reports a CORS error | `FRONTEND_ORIGIN` must exactly match the browser's frontend origin, including scheme and hostname, with no path/trailing slash. Redeploy the API after changing it. |
| Frontend says it cannot reach QueueLess | Check `VITE_API_BASE_URL`, API deploy status, and `/api/v1/health`. Rebuild the frontend after changing its `VITE_*` value. |
| Direct `/display/1` or `/token/...` URL returns 404 | Add a static-site rewrite from `/*` to `/index.html`. |
| API fails during boot | Check production `DATABASE_URL`, `FRONTEND_ORIGIN`, `RAILS_ENV`, and the service logs. |
| Login rejects the administrator | Confirm the production seed ran once with the same admin username/password currently set on the API. Do not use development demo credentials. |
| Display has no serving token | A receptionist must call the next waiting token. If nobody is serving yet, the first waiting token is labelled as next to be called.” |

## Security before production

QueueLess currently uses bearer sessions and role checks, and its public token and waiting-room endpoints return limited data. That is a useful starting boundary, not a complete clinical security program. The current MVP lacks login throttling, password reset/change flows, audit history, and several controls that may be required for health information in your jurisdiction. Arrange a security/privacy assessment, use TLS, establish backups and restore tests, define retention/access policies, and confirm legal and regulatory obligations before putting real patient information into the service. Do not load this repository's fictional sample patients into production.

## Hosting references

- [Render: Deploy a Rails 8 app](https://render.com/docs/deploy-rails-8)
- [Render: Static sites](https://render.com/docs/static-sites)
- [Render: Blueprint reference](https://render.com/docs/blueprint-spec)
- [Render: Static site rewrites](https://render.com/docs/redirects-rewrites)
- [Render: Create and connect PostgreSQL](https://render.com/docs/postgresql-creating-connecting)
