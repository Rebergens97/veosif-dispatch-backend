# Fleetbase – Lancer en local

## 1. API (Laravel, port 8000)

```bash
cd api
php artisan config:clear
php artisan serve
```

Garder ce terminal ouvert. L’API doit répondre sur **http://localhost:8000**.

## 2. Console (Ember)

Si les ports 4200, 4201 ou 4202 sont déjà utilisés :

**Libérer un port** (remplacer `4202` par le port à libérer) :

```bash
kill $(lsof -t -i :4202)
```

**Lancer la console sur un port libre** (ex. 4203) :

```bash
cd console
npm run dev:4203
```

Puis ouvrir **http://localhost:4203** dans le navigateur.

Si 4200 est libre, utiliser simplement :

```bash
cd console
npm run dev
```

→ **http://localhost:4200**

## 3. Erreur 500 sur `/int/v1/auth/login`

Déjà corrigé dans le projet :

- **Telemetry** : fichier `api/.fleetbase-id` créé (évite `getInstanceId()` null).
- **Cache** : si Redis n’est pas installé, le cache utilise `array` pour que `Cache::tags()` fonctionne (`api/config/cache.php`).

À faire après chaque changement de config ou au premier lancement :

```bash
cd api
php artisan config:clear
# Puis redémarrer : php artisan serve
```

## 4. Base de données

`.env` dans `api/` doit avoir par exemple :

- `DB_DATABASE=fleetbase`
- `DB_USERNAME=root`
- `DB_PASSWORD=` (vide si pas de mot de passe)

Créer la base et lancer les migrations :

```bash
cd api
php artisan migrate
# Optionnel : php artisan db:seed
```
