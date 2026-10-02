# GastoHogar

Aplicación Ruby on Rails para registrar y analizar gastos personales y familiares. Corresponde al **TP N.º 1 de Programación IV** e incluye un back-office administrativo HTML y una API JSON autenticada para usuarios finales.

## Funcionalidades principales

- Alta y administración de usuarios desde el back-office, con roles `user` y `admin`.
- Administración de categorías, gastos, hogares y membresías.
- Gastos personales o asociados a un hogar, con categoría, importe, fecha, descripción y notas opcionales.
- API para consultar, crear, modificar y eliminar los gastos propios, con filtros combinables.
- Consulta del catálogo de categorías y de los hogares a los que pertenece el usuario.
- Creación de hogares desde la API con una membresía `owner` automática, dentro de una transacción.
- Dashboard JSON con importe total, cantidad de gastos y totales por categoría.
- Un comprobante opcional por gasto mediante Active Storage, cargado desde el back-office.
- Email de bienvenida al crear correctamente un usuario desde el back-office mediante Action Mailer.
- Autenticación administrativa con sesión/cookie y autenticación independiente de API mediante Bearer token.

## Tecnologías

Versiones verificadas en `.ruby-version`, `Gemfile.lock` y el entorno local:

| Tecnología | Versión / uso |
| --- | --- |
| Ruby | 4.0.6 |
| Ruby on Rails | 8.1.3.1 |
| PostgreSQL | 16.15 en el entorno verificado; el repositorio no fija una versión del servidor |
| Active Record | 8.1.3.1, modelos, relaciones y consultas SQL |
| Active Storage | 8.1.3.1, archivos adjuntos |
| Action Mailer | 8.1.3.1, emails con vistas HTML y texto |
| Active Job | 8.1.3.1, envío diferido de correos |
| Minitest | 6.0.6 |
| RuboCop | 1.91.0, configuración `rubocop-rails-omakase` |
| Brakeman | 8.0.6 |
| Bundler | 4.0.16, según `Gemfile.lock` |

## Modelo de datos

| Modelo | Responsabilidad y relaciones |
| --- | --- |
| `User` | Usuario con nombre, email, contraseña almacenada como hash (`has_secure_password`) y rol global `user` o `admin`. Tiene muchos gastos y membresías, y pertenece a hogares a través de sus membresías. |
| `Category` | Categoría con nombre único y descripción opcional. Tiene muchos gastos. |
| `Expense` | Gasto que pertenece obligatoriamente a un usuario y una categoría. Su hogar es opcional. Tiene descripción, importe positivo, fecha, notas opcionales y un comprobante opcional. |
| `Household` | Hogar con nombre y descripción opcional. Tiene gastos y membresías; sus usuarios se obtienen a través de las membresías. |
| `Membership` | Relación entre `User` y `Household`, con rol `owner` o `member`. Cada par usuario/hogar es único. Este rol es independiente del rol global de `User`. |

En `Expense`, `household_id = NULL` representa un gasto personal. Asociar un gasto a un hogar no cambia su propietario: sigue perteneciendo al usuario que lo registró. En la API, compartir hogar no permite consultar gastos ajenos.

`Expense` declara `has_one_attached :receipt`: puede tener un único comprobante opcional mediante Active Storage. El archivo se almacena fuera de la tabla `expenses`.

## Instalación y ejecución local

Los comandos de Rails deben ejecutarse desde el directorio que contiene `Gemfile` y `bin/rails`.

### 1. Clonar el repositorio

No hay un remoto Git configurado en la copia inspeccionada. **Reemplazar `https://github.com/JuanZunino/gasto_hogar.git` por la URL real antes de ejecutar:**

```bash
git clone https://github.com/JuanZunino/gasto_hogar.git gasto_hogar
cd gasto_hogar
```

### 2. Preparar Ruby y dependencias

Instalar Ruby **4.0.6** con el gestor de versiones preferido. También se necesita PostgreSQL en ejecución y herramientas de compilación para las dependencias nativas.

Ejemplo de paquetes de sistema para Ubuntu/Debian:

```bash
sudo apt update
sudo apt install build-essential libpq-dev postgresql postgresql-contrib
sudo service postgresql start
```

Con la versión correcta de Ruby activa:

```bash
ruby -v
gem install bundler -v 4.0.16
bundle install
```

### 3. Preparar PostgreSQL

`config/database.yml` usa PostgreSQL por conexión local, sin usuario ni contraseña explícitos para development/test. Por defecto, el rol de PostgreSQL debe coincidir con el usuario del sistema operativo y poder crear bases de datos.

En Ubuntu/Debian, si ese rol todavía no existe:

```bash
sudo -u postgres createuser --createdb "$(whoami)"
```

Comprobar la conexión:

```bash
psql -d postgres -c 'SELECT current_user;'
```

Si se usa otro servidor o autenticación por contraseña, configurar los valores locales de conexión en `config/database.yml` o las variables de conexión de PostgreSQL (`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`). No publicar credenciales en Git. Development y test deben usar bases separadas:

- `gasto_hogar_development`
- `gasto_hogar_test`

### 4. Preparar las bases de datos

```bash
bin/rails db:prepare
RAILS_ENV=test bin/rails db:prepare
```

`db:prepare` crea la base si no existe y prepara el esquema o aplica las migraciones pendientes, incluidas las tablas de Active Storage. `db/seeds.rb` no carga usuarios, categorías ni otros datos iniciales.

Cuando se incorporen nuevas migraciones a una base existente:

```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:prepare
```

### 5. Iniciar Rails

```bash
bin/rails server
```

El servidor local está disponible en `http://localhost:3000`. Abrir `/admin/login`; no hay una página de inicio definida para `/`. `bin/dev` también inicia el servidor Rails.

## Back-office administrativo

Ingresar en `http://localhost:3000/admin/login`. Solamente los usuarios con `role: "admin"` pueden acceder. La sesión administrativa usa cookies y es independiente del Bearer token de la API.

Pantallas disponibles:

- `/admin/users`: alta, consulta, edición y eliminación de usuarios.
- `/admin/categories`: administración del catálogo de categorías.
- `/admin/expenses`: administración de gastos y carga de comprobantes.
- `/admin/households`: administración de hogares.
- `/admin/memberships`: administración de integrantes y sus roles dentro de los hogares.

La eliminación de usuarios, categorías y hogares con gastos asociados está restringida por los modelos.

### Crear el administrador inicial

Ejecutar:

```bash
bin/rails console
```

Dentro de la consola, este ejemplo solicita una contraseña sin mostrarla. Reemplazar el nombre y el email de ejemplo por los propios:

```ruby
require "io/console"
password = IO.console.getpass("Contraseña nueva del administrador: "); nil
User.create!(
  name: "Administrador inicial",
  email: "admin@example.com",
  password: password,
  password_confirmation: password,
  role: "admin"
); nil
password = nil
```

No son credenciales preexistentes. La creación desde consola no envía el correo de bienvenida: ese envío ocurre únicamente desde el controlador administrativo.

## API JSON `/api/v1`

Los cuerpos de creación y actualización se envían como JSON plano, sin envolverlos en una clave `expense` o `household`. Usar `Content-Type: application/json`.

### Autenticación

Cualquier usuario existente, tanto `user` como `admin`, puede iniciar sesión en la API:

```bash
curl -i -X POST http://localhost:3000/api/v1/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"TU_EMAIL","password":"TU_CONTRASEÑA"}'
```

Reemplazar los placeholders por las credenciales del usuario. Si son correctas, devuelve `200` con `token` y `user` (`id`, `name`, `email`, `role`). Las credenciales incorrectas devuelven `401`.

El token usa `signed_id` de Rails, tiene propósito `api_v1` y vence a las **24 horas**. Está firmado, no es JWT y no contiene la contraseña ni su hash. Enviar el token recibido en cada petición protegida:

```text
Authorization: Bearer TOKEN
```

Ejemplo, reemplazando el placeholder:

```bash
curl -i http://localhost:3000/api/v1/profile \
  -H 'Authorization: Bearer TOKEN_OBTENIDO_EN_LOGIN'
```

Un token ausente, inválido o vencido devuelve `401`. No hay endpoints de registro público, logout de API ni renovación de tokens.

### Endpoints implementados

| Método | Ruta | Propósito | Bearer token |
| --- | --- | --- | --- |
| POST | `/api/v1/login` | Obtener token y datos básicos del usuario. | No |
| GET | `/api/v1/profile` | Consultar el perfil autenticado. | Sí |
| GET | `/api/v1/dashboard` | Consultar totales, cantidad y agrupación por categoría de los gastos propios. | Sí |
| GET | `/api/v1/expenses` | Listar gastos propios con filtros. | Sí |
| GET | `/api/v1/expenses/:id` | Consultar un gasto propio. | Sí |
| POST | `/api/v1/expenses` | Crear un gasto para el usuario autenticado. | Sí |
| PATCH / PUT | `/api/v1/expenses/:id` | Actualizar un gasto propio. | Sí |
| DELETE | `/api/v1/expenses/:id` | Eliminar un gasto propio. | Sí |
| GET | `/api/v1/categories` | Consultar el catálogo general, ordenado por nombre ascendente. | Sí |
| GET | `/api/v1/households` | Consultar únicamente hogares con membresía del usuario. | Sí |
| GET | `/api/v1/households/:id` | Consultar un hogar propio y sus integrantes. | Sí |
| POST | `/api/v1/households` | Crear un hogar y la membresía `owner` del usuario autenticado. | Sí |

Para comprobar las rutas:

```bash
bin/rails routes -g api/v1
```

### Gastos y filtros

POST y PATCH/PUT de Expenses aceptan `description`, `amount`, `date`, `category_id`, `household_id` y `notes`. `user_id` no se acepta: el propietario se obtiene del token. Para crear un gasto asociado a un hogar o cambiarlo a otro hogar, el usuario debe tener una membresía en ese hogar.

Ejemplo de cuerpo JSON (usar un ID de categoría existente):

```json
{
  "description": "Supermercado",
  "amount": 32500,
  "date": "2026-10-02",
  "category_id": 1,
  "household_id": null,
  "notes": "Compra semanal"
}
```

Las respuestas incluyen `id`, `description`, `amount`, `date`, `notes`, `category` con `id` y `name`, `household` con `id` y `name` o `null`, y `receipt_attached` como booleano.

Filtros combinables de `GET /api/v1/expenses`:

| Parámetro | Efecto |
| --- | --- |
| `from` | Fecha del gasto mayor o igual a la indicada. |
| `to` | Fecha del gasto menor o igual a la indicada. |
| `category_id` | Gastos de la categoría indicada. |
| `household_id` | Gastos del hogar indicado, siempre pertenecientes al usuario autenticado. |

Las fechas se envían como `YYYY-MM-DD`. El orden es fecha descendente y luego ID descendente. Ejemplo: `/api/v1/expenses?from=2026-10-01&to=2026-10-31&category_id=1`.

Las creaciones exitosas devuelven `201`, las consultas/actualizaciones `200` y la eliminación `204` sin cuerpo. Los gastos ajenos o inexistentes devuelven `404`. Los errores de validación devuelven `422` con `errors`; los filtros de fecha inválidos devuelven `400`.

### Hogares y categorías

Categories devuelve únicamente `id`, `name` y `description`; su administración continúa en el back-office.

Households index devuelve `id`, `name` y `description`, o un array vacío si no hay membresías. Show agrega `members`: cada integrante tiene `id` del usuario, `name`, `email` y `role` de su `Membership`. Un hogar ajeno o inexistente devuelve `404`.

POST de Households acepta únicamente `name` y `description`. Crea el hogar y la membresía del usuario autenticado con rol `owner` en una transacción; devuelve `201` con la misma estructura que show. Ante un fallo de validación o guardado cancelado, revierte la operación y responde `422` con `errors`.

### Dashboard

`GET /api/v1/dashboard` admite `from` y `to`, juntos o por separado, con límites inclusivos. Los mismos filtros se aplican a todos los cálculos en PostgreSQL, únicamente sobre los gastos del usuario autenticado, incluso si comparte hogar con otros usuarios.

Devuelve:

- `total_expenses`: suma de importes como string con dos decimales.
- `expenses_count`: cantidad de gastos.
- `expenses_by_category`: categorías (`id`, `name`) y su `total` con dos decimales, ordenadas por total descendente e ID de categoría ascendente ante empates.

Sin gastos en el período devuelve:

```json
{
  "total_expenses": "0.00",
  "expenses_count": 0,
  "expenses_by_category": []
}
```

Ejemplo:

```bash
curl -i -G http://localhost:3000/api/v1/dashboard \
  -H 'Authorization: Bearer TOKEN_OBTENIDO_EN_LOGIN' \
  --data-urlencode 'from=2026-10-01' \
  --data-urlencode 'to=2026-10-31'
```

## Comprobantes con Active Storage

En `/admin/expenses`, crear o editar un gasto y seleccionar una imagen o PDF en **Comprobante (opcional)**. Guardar y abrir el detalle para descargar el archivo mediante el enlace de Active Storage. Seleccionar otro archivo reemplaza el anterior; editar sin elegir uno nuevo conserva el existente.

La configuración utiliza almacenamiento local: `storage/` en development y `tmp/storage/` en tests. PostgreSQL contiene metadatos y relaciones en las tablas de Active Storage, no el contenido del archivo.

La API solo informa `receipt_attached: true/false`; no implementa carga ni descarga de comprobantes mediante endpoints propios.

## Email de bienvenida con Action Mailer

`UserMailer#welcome_email(user)` genera un correo con el nombre del usuario, una bienvenida a GastoHogar y la confirmación de creación de su cuenta, en HTML y texto. No incluye contraseñas, hashes ni tokens.

`Admin::UsersController` llama explícitamente a `deliver_later` después de guardar correctamente un usuario nuevo. No hay callbacks en `User`: no se envía al editar, eliminar, fallar la creación o crear usuarios directamente desde consola.

En development, `delivery_method: :file` guarda el correo en **`tmp/mails`**, sin conectarse a un proveedor externo. Active Job usa el adaptador asíncrono en el proceso de Rails, sin worker separado para este entorno.

Para probarlo:

1. Iniciar Rails y crear un usuario desde `/admin/users/new` con una sesión administrativa.
2. Esperar la ejecución del trabajo y abrir el archivo generado en `tmp/mails` como texto.
3. Para inspeccionar las vistas sin crear usuarios, visitar `http://localhost:3000/rails/mailers/user_mailer/welcome_email`.

En tests se utiliza el método `:test`, que acumula correos en memoria sin enviarlos a Internet.

## Tests

```bash
bin/rails test
```

La suite Minitest incluye modelos, controladores, autenticación, aislamiento de datos por usuario, filtros y agregaciones, adjuntos y correo de bienvenida. Usa una base PostgreSQL de test separada.

## RuboCop

```bash
bin/rubocop
```

El proyecto utiliza la configuración de `rubocop-rails-omakase` definida en `.rubocop.yml`.

## Análisis de seguridad con Brakeman

Ejecutar la versión instalada mediante Bundler:

```bash
bundle exec brakeman --no-pager
```

También puede ejecutarse sin mensajes de progreso:

```bash
bundle exec brakeman --no-pager --quiet
```

El análisis revisado actualmente registra **dos warnings de confianza media**, ambos de `Mass Assignment / PermitAttributes`:

| Archivo | Código señalado | Riesgo potencial |
| --- | --- | --- |
| `app/controllers/admin/users_controller.rb` | `params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)` | Asignar privilegios administrativos mediante `role` sin autorización. |
| `app/controllers/admin/memberships_controller.rb` | `params.require(:membership).permit(:user_id, :household_id, :role)` | Asignar un rol de membresía sin autorización. |

Se revisaron como posibles falsos positivos en el contexto implementado: ambos controladores heredan de `Admin::BaseController`, cuyo filtro exige una sesión de un usuario con rol `admin`. La administración de roles es una función deliberada del back-office. **Los warnings se mantienen visibles; no se agregaron exclusiones ni supresiones.** Brakeman puede finalizar con código distinto de cero por estas advertencias.

`bin/brakeman` agrega `--ensure-latest` y puede detenerse antes de analizar si detecta una versión más nueva. El comando con `bundle exec` permite ejecutar Brakeman 8.0.6 instalado sin actualizar dependencias ni desactivar comprobaciones de seguridad.

## Estructura

```text
/admin   -> back-office HTML tradicional de Rails, con sesión administrativa
/api/v1  -> API JSON para el usuario final, con Bearer token
```

- `app/controllers/admin/` y `app/views/admin/`: controladores y vistas administrativas.
- `app/controllers/api/v1/`: autenticación y endpoints JSON versionados.
- `app/models/`: entidades y relaciones de Active Record.
- `app/mailers/` y `app/views/user_mailer/`: correo de bienvenida.
- `db/migrate/`: migraciones del modelo de datos y Active Storage.
- `test/`: tests y vista previa del correo.

## Estado del proyecto

Trabajo académico correspondiente al **TP N.º 1 de Programación IV**. El backend, el back-office y los endpoints descritos están implementados. No hay frontend público de usuario final ni dashboard HTML, registro público, recuperación de contraseña o invitaciones a hogares. No se documenta un despliegue público; las instrucciones anteriores corresponden a ejecución local.
