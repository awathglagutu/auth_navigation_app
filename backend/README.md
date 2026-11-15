# PHP API

Requires PHP with PDO SQLite enabled. From the project root, run:

```sh
php -S 0.0.0.0:5173 -t backend
```

The SQLite file and schema are created on the first API request, and the Admin account is seeded then. Point `lib/config/api_config.dart` at this server's reachable IP address. For an Android emulator using a PHP server on the host machine, use `http://10.0.2.2:5173`.
