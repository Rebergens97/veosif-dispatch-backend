<?php
/**
 * VEOSIF Dispatch — Test Data Seeder (Tinker Script)
 *
 * Itilizasyon sou sèvè a:
 *   docker compose exec application php artisan tinker --execute="require '/fleetbase/api/scripts/seed-test-data.php';"
 *
 * Oswa kopi nan kontènè a epi:
 *   docker compose exec application php artisan tinker < scripts/seed-test-data.php
 */

use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;

// ─── Koulè output ─────────────────────────────────────────────────────────────
function seed_ok($msg)   { echo "\033[0;32m✔\033[0m  {$msg}\n"; }
function seed_err($msg)  { echo "\033[0;31m✖\033[0m  {$msg}\n"; }
function seed_info($msg) { echo "\033[0;34m→\033[0m  {$msg}\n"; }
function seed_warn($msg) { echo "\033[1;33m⚠\033[0m  {$msg}\n"; }

echo "\n";
echo "========================================\n";
echo "  VEOSIF Dispatch — Test Data Seeder\n";
echo "========================================\n\n";

// ─── Verifye modèl yo disponib ───────────────────────────────────────────────
$models = [
    'company'  => 'Fleetbase\Models\Company',
    'user'     => 'Fleetbase\Models\User',
    'driver'   => 'Fleetbase\FleetOps\Models\Driver',
    'vehicle'  => 'Fleetbase\FleetOps\Models\Vehicle',
    'contact'  => 'Fleetbase\FleetOps\Models\Contact',
    'place'    => 'Fleetbase\FleetOps\Models\Place',
    'order'    => 'Fleetbase\FleetOps\Models\Order',
];

seed_info("Verifye modèl yo...");
foreach ($models as $name => $class) {
    if (class_exists($class)) {
        seed_ok("{$name}: {$class}");
    } else {
        seed_err("{$name}: {$class} — PA JWENN");
    }
}
echo "\n";

// ─── Jwenn company ki egziste deja ───────────────────────────────────────────
seed_info("Chache Company egzistant...");
$Company = $models['company'];
$company = $Company::first();

if (!$company) {
    seed_err("Pa gen okenn company. Kreye yon company nan konsole a anvan.");
    return;
}
seed_ok("Company jwenn: {$company->name} (uuid: {$company->uuid})");
$companyUuid = $company->uuid;

// ─── Jwenn admin user ────────────────────────────────────────────────────────
seed_info("Chache admin user...");
$User = $models['user'];
$user = $User::where('company_uuid', $companyUuid)->first();

if (!$user) {
    seed_err("Pa gen okenn user pou company sa a.");
    return;
}
seed_ok("User jwenn: {$user->name} / {$user->email}");
$userUuid = $user->uuid;

echo "\n";

// ─── Kreye Drivers ───────────────────────────────────────────────────────────
seed_info("Kreyasyon 3 Drivers...");
$Driver = $models['driver'];
$drivers = [];

$driverData = [
    ['name' => 'Pierre Jean',  'phone' => '+50912000001', 'email' => 'pierre.jean@veosif-test.com'],
    ['name' => 'Marie Joseph', 'phone' => '+50912000002', 'email' => 'marie.joseph@veosif-test.com'],
    ['name' => 'Paul André',   'phone' => '+50912000003', 'email' => 'paul.andre@veosif-test.com'],
];

foreach ($driverData as $data) {
    try {
        $existing = $Driver::where('company_uuid', $companyUuid)
                           ->where('name', $data['name'])->first();
        if ($existing) {
            seed_warn("Driver '{$data['name']}' deja egziste — sote.");
            $drivers[] = $existing;
            continue;
        }
        $driver = $Driver::create(array_merge($data, [
            'company_uuid'    => $companyUuid,
            'created_by_uuid' => $userUuid,
            'status'          => 'active',
        ]));
        seed_ok("Driver kreye: {$driver->name} (uuid: {$driver->uuid})");
        $drivers[] = $driver;
    } catch (\Exception $e) {
        seed_err("Driver '{$data['name']}' echwe: " . $e->getMessage());
        $drivers[] = null;
    }
}
echo "\n";

// ─── Kreye Vehicles ──────────────────────────────────────────────────────────
seed_info("Kreyasyon 3 Vehicles...");
$Vehicle = $models['vehicle'];
$vehicles = [];

$vehicleData = [
    ['display_name' => 'Moto-001',  'plate_number' => 'AA-1001', 'trim' => 'Motorcycle'],
    ['display_name' => 'Car-001',   'plate_number' => 'AA-1002', 'trim' => 'Sedan'],
    ['display_name' => 'Truck-001', 'plate_number' => 'AA-1003', 'trim' => 'Truck'],
];

foreach ($vehicleData as $i => $data) {
    try {
        $existing = $Vehicle::where('company_uuid', $companyUuid)
                            ->where('display_name', $data['display_name'])->first();
        if ($existing) {
            seed_warn("Vehicle '{$data['display_name']}' deja egziste — sote.");
            $vehicles[] = $existing;
            continue;
        }

        $attrs = array_merge($data, [
            'company_uuid'    => $companyUuid,
            'created_by_uuid' => $userUuid,
            'status'          => 'active',
        ]);

        // Asiyen chofè si li disponib
        if (isset($drivers[$i]) && $drivers[$i]) {
            $attrs['driver_uuid'] = $drivers[$i]->uuid;
        }

        $vehicle = $Vehicle::create($attrs);
        $driverName = (isset($drivers[$i]) && $drivers[$i]) ? $drivers[$i]->name : 'pa asiyen';
        seed_ok("Vehicle kreye: {$vehicle->display_name} / {$data['plate_number']} — Chofè: {$driverName}");
        $vehicles[] = $vehicle;
    } catch (\Exception $e) {
        seed_err("Vehicle '{$data['display_name']}' echwe: " . $e->getMessage());
        $vehicles[] = null;
    }
}
echo "\n";

// ─── Kreye Places ────────────────────────────────────────────────────────────
seed_info("Kreyasyon 4 Places (adrès)...");
$Place = $models['place'];
$places = [];

$placeData = [
    ['name' => 'Depot VEOSIF',         'street1' => '10 Rue du Centre',      'city' => 'Port-au-Prince', 'country' => 'HT'],
    ['name' => "Bòs André",            'street1' => '25 Blvd Toussaint',     'city' => 'Port-au-Prince', 'country' => 'HT'],
    ['name' => "Madame Claire",        'street1' => '45 Rue Capois',         'city' => 'Pétionville',    'country' => 'HT'],
    ['name' => "Monsieur Remy",        'street1' => '12 Avenue John Brown',  'city' => 'Delmas',         'country' => 'HT'],
];

foreach ($placeData as $data) {
    try {
        $existing = $Place::where('company_uuid', $companyUuid)
                         ->where('name', $data['name'])->first();
        if ($existing) {
            seed_warn("Place '{$data['name']}' deja egziste — sote.");
            $places[] = $existing;
            continue;
        }
        $place = $Place::create(array_merge($data, [
            'company_uuid'    => $companyUuid,
            'created_by_uuid' => $userUuid,
        ]));
        seed_ok("Place kreye: {$place->name} — {$data['street1']}, {$data['city']}");
        $places[] = $place;
    } catch (\Exception $e) {
        seed_err("Place '{$data['name']}' echwe: " . $e->getMessage());
        $places[] = null;
    }
}
echo "\n";

// ─── Kreye Contacts ──────────────────────────────────────────────────────────
seed_info("Kreyasyon 3 Contacts (kliyan)...");
$Contact = $models['contact'];
$contacts = [];

$contactData = [
    ['name' => "Bòs André",      'phone' => '+50913000001', 'email' => 'andre@veosif-test.com',  'place_idx' => 1],
    ['name' => "Madame Claire",  'phone' => '+50913000002', 'email' => 'claire@veosif-test.com', 'place_idx' => 2],
    ['name' => "Monsieur Remy",  'phone' => '+50913000003', 'email' => 'remy@veosif-test.com',   'place_idx' => 3],
];

foreach ($contactData as $data) {
    try {
        $existing = $Contact::where('company_uuid', $companyUuid)
                           ->where('name', $data['name'])->first();
        if ($existing) {
            seed_warn("Contact '{$data['name']}' deja egziste — sote.");
            $contacts[] = $existing;
            continue;
        }
        $attrs = [
            'company_uuid'    => $companyUuid,
            'created_by_uuid' => $userUuid,
            'name'            => $data['name'],
            'phone'           => $data['phone'],
            'email'           => $data['email'],
            'type'            => 'customer',
        ];
        if (isset($places[$data['place_idx']]) && $places[$data['place_idx']]) {
            $attrs['place_uuid'] = $places[$data['place_idx']]->uuid;
        }
        $contact = $Contact::create($attrs);
        seed_ok("Contact kreye: {$contact->name} / {$data['phone']}");
        $contacts[] = $contact;
    } catch (\Exception $e) {
        seed_err("Contact '{$data['name']}' echwe: " . $e->getMessage());
        $contacts[] = null;
    }
}
echo "\n";

// ─── Kreye Orders ────────────────────────────────────────────────────────────
seed_info("Kreyasyon 3 Orders...");
$Order = $models['order'];

$depot = $places[0] ?? null;

$orderData = [
    [
        'label'       => 'Order-001 (Pending, pa asiyen)',
        'status'      => 'pending',
        'pickup'      => $depot,
        'dropoff'     => $places[1] ?? null,
        'driver'      => null,
        'contact'     => $contacts[0] ?? null,
    ],
    [
        'label'       => 'Order-002 (Dispatched, Pierre Jean)',
        'status'      => 'dispatched',
        'pickup'      => $depot,
        'dropoff'     => $places[2] ?? null,
        'driver'      => $drivers[0] ?? null,
        'contact'     => $contacts[1] ?? null,
    ],
    [
        'label'       => 'Order-003 (Completed, Marie Joseph)',
        'status'      => 'completed',
        'pickup'      => $depot,
        'dropoff'     => $places[3] ?? null,
        'driver'      => $drivers[1] ?? null,
        'contact'     => $contacts[2] ?? null,
    ],
];

foreach ($orderData as $data) {
    try {
        $attrs = [
            'company_uuid'    => $companyUuid,
            'created_by_uuid' => $userUuid,
            'status'          => $data['status'],
        ];

        if ($data['driver']) {
            $attrs['driver_assigned_uuid'] = $data['driver']->uuid;
        }

        // Pickup / dropoff via payload
        if ($data['pickup']) {
            $attrs['pickup_uuid']  = $data['pickup']->uuid;
        }
        if ($data['dropoff']) {
            $attrs['dropoff_uuid'] = $data['dropoff']->uuid;
        }

        // Customer/contact
        if ($data['contact']) {
            $attrs['customer_uuid'] = $data['contact']->uuid;
            $attrs['customer_type'] = 'Fleetbase\\FleetOps\\Models\\Contact';
        }

        $order = $Order::create($attrs);
        $pid = $order->public_id ?? $order->uuid;
        seed_ok("Order kreye: {$data['label']} — {$pid}");
    } catch (\Exception $e) {
        seed_err("Order '{$data['label']}' echwe: " . $e->getMessage());
    }
}

echo "\n";
echo "========================================\n";
echo "  Done tès kreye avèk siksè!\n";
echo "  Verifye nan: http://104.131.20.188:4200\n";
echo "  Fleet-Ops → Drivers, Vehicles, Orders\n";
echo "========================================\n\n";
