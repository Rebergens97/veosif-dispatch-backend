# VEOSIF Dispatch — Workflow Test Guide

**Purpose:** Manual test steps for verifying the end-to-end dispatch workflow on a running VEOSIF Dispatch instance.  
**Rule:** Do NOT implement features. This document is for testing and gap identification only.  
**Status:** Read-only — no code changes.

---

## Prerequisites

- Stack running: `docker compose up -d` or `./scripts/local-start.sh`
- API: `http://<HOST>:8000`
- Console: `http://<HOST>:4200`
- Admin account created (via onboarding or `php artisan fleetbase:seed`)
- All containers healthy: `docker compose ps`

---

## Step 1 — Organization creation

**Where:** Console → Onboarding (first login) or Admin → Organizations

| Action | How |
|--------|-----|
| Log in as first/admin user | Go to `http://<HOST>:4200`, enter admin credentials |
| Complete onboarding | Follow the setup wizard if prompted; create the first organization |
| Or create via Admin | Console → Admin → Organizations → New |
| Set minimal data | Name, timezone, country (required fields) |

**Verify:**  
- Organization appears in Admin → Organizations.
- API: `GET /int/v1/companies` returns the company.

---

## Step 2 — Dispatcher / admin account

**Where:** Console → IAM or Admin → Users

| Action | How |
|--------|-----|
| Create or confirm admin user | Admin → Users → New User |
| Set role | Assign "Administrator" role (or dispatcher role if configured in IAM) |
| Assign to organization | Link user to the organization created in Step 1 |
| Verify login | Log out, log back in as this user; confirm dashboard loads |

**Verify:**  
- User can access the Fleet-Ops module.
- No 403 or 500 errors after login.
- `GET /int/v1/users/me` returns user with company and roles.

---

## Step 3 — Driver creation

**Where:** Console → Fleet-Ops → Drivers

| Action | How |
|--------|-----|
| Navigate to Fleet-Ops | Sidebar → Fleet-Ops → Drivers |
| Create driver | Click "New Driver" (or equivalent button) |
| Set minimal data | Name, phone number; vehicle (optional at this stage) |
| Set status | Active |

**Verify:**  
- Driver appears in the Drivers list.
- API: `GET /int/v1/drivers` returns the driver.
- No 500 or validation errors during creation.

---

## Step 4 — Vehicle creation

**Where:** Console → Fleet-Ops → Vehicles

| Action | How |
|--------|-----|
| Navigate | Fleet-Ops → Vehicles |
| Create vehicle | Click "New Vehicle" |
| Set minimal data | Name or plate, type (e.g. car, truck) |
| Optional | Assign driver to vehicle |

**Verify:**  
- Vehicle appears in the Vehicles list.
- API: `GET /int/v1/vehicles` returns vehicle.
- Optionally confirm driver–vehicle relationship in driver detail.

---

## Step 5 — Customer / place creation

**Where:** Console → Fleet-Ops → Customers or Places (depending on engine configuration)

| Action | How |
|--------|-----|
| Navigate | Fleet-Ops → Customers (or Contacts / Places) |
| Create customer | Click "New" and fill in name, phone, address if required |
| Verify address | Use address lookup if available |

**Verify:**  
- Customer/place appears in list.
- API: `GET /int/v1/contacts` or `/int/v1/places` returns the record.
- Address lookup does not produce 500 (if GOOGLE_MAPS_API_KEY not set, expect degraded address search only).

---

## Step 6 — Dispatch order creation

**Where:** Console → Fleet-Ops → Orders (or Order Board)

| Action | How |
|--------|-----|
| Navigate | Fleet-Ops → Orders |
| Create order | Click "New Order" (or "+" on Order Board) |
| Set origin | Address or place for pickup |
| Set destination | Address or place for delivery |
| Set customer | Link to customer created in Step 5 |
| Set order type | If order types are configured, select appropriate type; otherwise default |
| Save | Submit / Create |

**Verify:**  
- Order appears in Orders list with status "New" or "Pending".
- API: `GET /int/v1/orders` returns the order.
- No 500 errors during creation.

---

## Step 7 — Driver assignment

**Where:** Order detail page (Fleet-Ops → Orders → [order])

| Action | How |
|--------|-----|
| Open order | Click the order from list or board |
| Assign driver | Find "Assign Driver" action (or drag-and-drop on board if applicable) |
| Select driver | Choose driver from Step 3 |
| Optionally assign vehicle | Select vehicle from Step 4 |
| Confirm | Save/confirm assignment |

**Verify:**  
- Order shows driver name and vehicle.
- Driver status may change (e.g. "assigned" or "en route" depending on config).
- API: `GET /int/v1/orders/<id>` shows `driver_assigned` or equivalent.

---

## Step 8 — Order lifecycle tracking

**Where:** Order detail; map view if available

| Status transition | Action |
|-------------------|--------|
| Pending → Dispatched | Dispatch action on order |
| Dispatched → Picked up | Update status; driver confirms pickup (in app or manually) |
| Picked up → In Progress | Status change |
| In Progress → Completed | Complete action |

For each transition:
- Change status from order detail (status dropdown or action button).
- Verify status updates immediately in the UI.
- Check order timeline/history if available.
- Verify no 500 or auth errors.

**Verify:**  
- Each status change persists (refresh page; status stays).
- API: `GET /int/v1/orders/<id>` returns correct status.
- Optional: Check `activity` or `tracking` records via API.

---

## Step 9 — Notifications and status updates

**Where:** Admin → Settings → Notifications (or Console → Settings → Notifications)

| Check | How |
|-------|-----|
| Is Twilio configured? | Settings → Notifications → SMS (check for Twilio SID/token) |
| Is push/email configured? | Settings → Notifications → Email, Push |
| Trigger a notification | Change order status; if configured, check SMS/email/push |
| If not configured | Document as "Not configured; skip in current environment" |

**Note:** If `TWILIO_SID`, `TWILIO_TOKEN`, `TWILIO_FROM` are not set in env, SMS notifications will be skipped or fail silently. This is expected for a dev/staging environment.

---

## Step 10 — Gap identification checklist

After completing Steps 1–9, fill in this checklist based on what you observe:

| Item | Status | Notes |
|------|--------|-------|
| Dispatcher-specific role (not admin) | ? | Check IAM roles for a "Dispatcher" role |
| Order types configured | ? | Check Fleet-Ops → Order Config |
| Driver status flow (active/offline/on-trip) | ? | Check driver detail |
| Driver mobile app | ? | Navigator App linked or not |
| ETA or route display on map | ? | Check order map view |
| Proof of delivery / signature | ? | Check order config or completion |
| Reporting / dispatch KPI dashboard | ? | Check dashboards |
| SMS notifications working | ? | Twilio configured or not |
| Push notifications working | ? | Configured or not |
| Batch dispatch (multiple drivers) | ? | Available or not |

---

## Minimal test data checklist

Use this as a quick-start for setting up a test environment:

| Entity | Minimum | Status |
|--------|---------|--------|
| Organization | 1 | [ ] |
| Admin/Dispatcher user | 1 | [ ] |
| Driver | 2 | [ ] |
| Vehicle | 2 | [ ] |
| Customer/Place | 2 | [ ] |
| Order (pending, unassigned) | 1 | [ ] |
| Order (assigned, driver set) | 1 | [ ] |
| Order (completed) | 1 | [ ] |

---

## Recommendations for future improvements

These are identified gaps to address after initial testing. No implementation in this phase.

1. **Define a Dispatcher role** — Create an IAM role with permissions limited to dispatch (create/assign/update orders, view drivers/vehicles) without full admin access.
2. **Order types for dispatch** — Configure order types matching VEOSIF Dispatch workflows (e.g. standard delivery, express, pickup-only).
3. **Driver mobile app integration** — Link and document the Navigator App (open-source) for real-time driver updates and GPS tracking.
4. **ETA and route** — Configure OSRM or Google Maps routing to show ETA on the order map view.
5. **Proof of delivery** — Enable signature or photo capture on order completion (FleetOps config).
6. **Dispatch KPI dashboard** — Add a dashboard widget for active orders, driver availability, and completion rate.
7. **SMS/notification setup** — Provide Twilio or alternative credentials in env for production; document expected behavior per event.
8. **Automated test data seeding** — Create a seed script (`php artisan db:seed --class=VeosifDispatchTestSeeder`) to populate test data in one command.

---

## Rollback note

This document is documentation only. No code or config was changed to create it. To remove it, delete this file.
