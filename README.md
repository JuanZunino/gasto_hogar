# GastoHogar

GastoHogar es un proyecto académico de **Programación IV**, desarrollado en etapas para registrar y analizar gastos personales y compartidos en hogares. Este repositorio contiene el backend Ruby on Rails, con un back-office administrativo HTML y una API JSON autenticada. El **TP1** comprende el backend y el back-office; el **TP2** incorpora el [frontend Angular](https://github.com/JuanZunino/gasto_hogar_frontend) en un repositorio independiente, que consume esta API para autenticación, gastos, categorías y dashboard personal o por hogar. La integración está implementada; esta revisión documental no certifica una ejecución conjunta.

## Funcionalidades principales

- Alta y administración de usuarios desde el back-office, con roles `user` y `admin`.
- Administración de categorías, gastos, hogares y membresías.
- Gastos personales o asociados a un hogar, con categoría, importe, fecha, descripción y notas opcionales.
- API para administrar gastos propios accesibles y consultar los gastos compartidos de los hogares actuales, con filtros combinables.
- Consulta del catálogo de categorías y de los hogares a los que pertenece el usuario.
- Creación de hogares desde la API con una membresía `owner` automática, dentro de una transacción.
- Dashboard JSON con importe total, cantidad de gastos y totales por categoría.
- Un comprobante opcional por gasto mediante Active Storage, cargado desde el back-office.
- Email de bienvenida al crear correctamente un usuario desde el back-office mediante Action Mailer.
- Autenticación administrativa con sesión/cookie y autenticación independiente de API mediante Bearer token.

## Tecnologías

Versiones declaradas en `.ruby-version` y `Gemfile.lock` (sin consultar servicios locales):

| Tecnología | Versión / uso |
| --- | --- |
| Ruby | 4.0.6 |
| Ruby on Rails | 8.1.3.1 |
| PostgreSQL | Servidor requerido; el repositorio no fija su versión |
| Active Record | 8.1.3.1, modelos, relaciones y consultas SQL |
| Active Storage | 8.1.3.1, archivos adjuntos |
| Action Mailer | 8.1.3.1, emails con vistas HTML y texto |
| Active Job | 8.1.3.1, envío diferido de correos |
| Minitest | 6.0.6 |
| RuboCop | 1.91.0, configuración `rubocop-rails-omakase` |
| Brakeman | 8.1.0 |
| Bundler | 4.0.16, según `Gemfile.lock` |

## Modelo de datos

| Modelo | Responsabilidad y relaciones |
| --- | --- |
| `User` | Usuario con nombre, email, contraseña almacenada como hash (`has_secure_password`) y rol global `user` o `admin`. Tiene muchos gastos, categorías privadas y membresías, y pertenece a hogares a través de sus membresías. |
| `Category` | Categoría global (`user_id = NULL`) o privada de un usuario, con nombre obligatorio y descripción opcional. Evita nombres duplicados en el catálogo visible y tiene muchos gastos. |
| `Expense` | Gasto que pertenece obligatoriamente a un usuario y una categoría. Su hogar es opcional. Tiene descripción, importe positivo, fecha, notas opcionales y un comprobante opcional. |
| `Household` | Hogar con nombre y descripción opcional. Tiene gastos y membresías; sus usuarios se obtienen a través de las membresías. |
| `Membership` | Relación entre `User` y `Household`, con rol `owner` o `member`. Cada par usuario/hogar es único. Este rol es independiente del rol global de `User`. |

En `Expense`, `household_id = NULL` representa un gasto personal. Asociar un gasto a un hogar no cambia su propietario: sigue perteneciendo al usuario que lo registró. En la API, todos los integrantes actuales pueden consultar los gastos asociados al hogar, incluidos los de otros autores. Solo el autor puede editarlos o eliminarlos mientras conserve su membresía. Al salir del hogar pierde también acceso a los gastos que registró allí; estos permanecen en el historial para los integrantes actuales. Los gastos personales solo son accesibles por su autor.

`Expense` declara `has_one_attached :receipt`: puede tener un único comprobante opcional mediante Active Storage. El archivo se almacena fuera de la tabla `expenses`.

## Instalación y ejecución conjunta (TP1 y TP2)

Angular se ejecuta en el navegador y solicita JSON a Rails; Rails autentica, autoriza y persiste mediante Active Record en PostgreSQL. El back-office HTML se sirve directamente desde Rails. Angular no se conecta a PostgreSQL.

Los siguientes comandos son instrucciones para una instalación futura: **no se ejecutaron en el Paso 120.18**. Usar una instancia PostgreSQL local nueva, aislada y descartable, con un rol autorizado para crear bases. No usar bases protegidas ni de otras evaluaciones. Los nombres de ejemplo siguientes deben estar libres; si ya existen, elegir otros antes de continuar. No se requiere consultar ni copiar datos existentes.

### 1. Obtener ambos proyectos

Desde un directorio de trabajo elegido:

```bash
git clone https://github.com/JuanZunino/gasto_hogar.git
git clone https://github.com/JuanZunino/gasto_hogar_frontend.git
cd gasto_hogar
```

Las URLs corresponden a los remotos `origin` de las copias inspeccionadas; su disponibilidad y permisos remotos no se comprobaron. Si ya se tienen ambos proyectos, usar esas copias.

### 2. Dependencias

Instalar Ruby **4.0.6**, Bundler **4.0.16**, PostgreSQL y las herramientas de compilación y cabeceras de libpq que necesita la gema `pg`. Para procesamiento de imágenes, la aplicación incluye `image_processing`; el CI instala libvips. No se fija una versión de PostgreSQL ni un instalador del sistema operativo.

Desde la raíz del backend:

```bash
ruby -v
gem install bundler -v 4.0.16
bundle install
```

Para Angular se requieren Node compatible con `^22.22.3 || ^24.15.0 || >=26.0.0` y npm **11.19.1**, según el lockfile y `packageManager` del frontend. En otra terminal:

```bash
cd ../gasto_hogar_frontend
npm ci
```

El `cd` anterior parte del backend; cada terminal debe situarse en la raíz del proyecto correspondiente. No hace falta instalar Angular CLI globalmente.

### 3. Preparar bases nuevas de demostración y test

`config/database.yml` declara `gasto_hogar_development` y `gasto_hogar_test`. Para evitar esas bases, esta guía las sustituye por `DATABASE_URL`, mecanismo previsto en ese archivo. En una terminal del backend, con acceso local ya preparado a la instancia descartable:

```bash
export RAILS_ENV=development
export DATABASE_URL=postgresql:///gasto_hogar_demo_12018
bin/rails db:create db:migrate db:seed
```

La URL no contiene credenciales. Usa la conexión local y el rol predeterminado del sistema; si el entorno requiere otro host/rol, preparar la conexión local de forma privada antes de ejecutar. No guardar secretos en el README ni en Git.

Los comandos crean una base nueva y aplican las migraciones, incluidas las tablas de Active Storage. `db/seeds.rb` crea únicamente las diez categorías globales faltantes: Alimentos, Servicios, Transporte, Salud, Educación, Entretenimiento, Hogar, Mascotas, Indumentaria y Otros. Es idempotente y transaccional; no crea usuarios, hogares ni gastos. Un conflicto con una categoría privada revierte esa ejecución.

La base de tests se prepara por separado, en otra terminal del backend:

```bash
export RAILS_ENV=test
export DATABASE_URL=postgresql:///gasto_hogar_test_demo_12018
bin/rails db:create db:migrate
```

El helper de tests configura ejecución paralela según los procesadores y puede crear bases derivadas para sus workers. Toda esa ejecución debe permanecer en la instancia descartable. Nunca asignar la misma URL a demostración y tests.

### 4. Usuarios y datos de demostración

Conservar `RAILS_ENV=development` y `DATABASE_URL` de la base nueva al abrir la consola para crear el administrador inicial (procedimiento abajo). Después iniciar Rails e ingresar al back-office:

1. En `/admin/users/new`, crear dos usuarios finales con rol `user`, emails distintos elegidos por el evaluador y contraseñas nuevas introducidas en el formulario. No hay credenciales predefinidas ni registro público. Esto también permite demostrar el correo de bienvenida.
2. En `/admin/households/new`, crear un hogar de demostración.
3. En `/admin/memberships/new`, asociar ambos usuarios al mismo hogar, uno como `owner` y otro como `member`. Estos roles no conceden acceso administrativo.
4. Registrar gastos desde Angular con cada usuario: al menos uno personal y otro del hogar. Usar las categorías sembradas o crear una privada desde el formulario Angular.

### 5. Iniciar ambos servidores

Terminal del backend, manteniendo la base de demostración:

```bash
export RAILS_ENV=development
export DATABASE_URL=postgresql:///gasto_hogar_demo_12018
bin/rails server -p 3000
```

Terminal del frontend, desde `gasto_hogar_frontend`:

```bash
npm start
```

- Back-office: `http://localhost:3000/admin/login`.
- Frontend: `http://localhost:4200/login`.
- API: `http://localhost:3000/api/v1` más los endpoints documentados abajo; no hay una página índice en esa ruta ni en `/` de Rails.

`angular.json` carga `proxy.conf.json`: `/api/v1/**` se reenvía a `http://localhost:3000`. Los servicios Angular usan URLs relativas. El proxy de desarrollo permite trabajar sin configurar CORS. El build estático necesita un servidor que resuelva las rutas de la SPA y reenvíe la API; esta guía cubre desarrollo local, no un despliegue de producción.

## Back-office administrativo

Ingresar en `http://localhost:3000/admin/login`. Solamente los usuarios con `role: "admin"` pueden acceder. La sesión administrativa usa cookies y es independiente del Bearer token de la API.

Pantallas disponibles:

- `/admin/users`: alta, consulta, edición y eliminación de usuarios.
- `/admin/categories`: administración de categorías globales. Las predeterminadas permiten editar su descripción, pero no renombrarlas ni eliminarlas; las privadas quedan fuera de este CRUD.
- `/admin/expenses`: administración de gastos y carga de comprobantes.
- `/admin/households`: administración de hogares.
- `/admin/memberships`: administración de integrantes y sus roles dentro de los hogares.

La eliminación de usuarios, categorías y hogares con gastos asociados está restringida por los modelos.

### Crear el administrador inicial

Desde el backend y con las variables de la base aislada de demostración del paso 3, ejecutar:

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

Los cuerpos de creación y actualización de gastos y creación de hogares se envían como JSON plano, sin envolverlos en una clave `expense` o `household`. La creación de categorías privadas requiere la clave raíz `category`, como se muestra más abajo. Usar `Content-Type: application/json`.

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
| GET | `/api/v1/dashboard` | Consultar estadísticas propias accesibles; con `household_id`, las del hogar autorizado. | Sí |
| GET | `/api/v1/expenses` | Listar gastos propios accesibles; con `household_id`, todos los del hogar autorizado. | Sí |
| GET | `/api/v1/expenses/:id` | Consultar un gasto personal propio o compartido de un hogar actual. | Sí |
| POST | `/api/v1/expenses` | Crear un gasto para el usuario autenticado. | Sí |
| PATCH / PUT | `/api/v1/expenses/:id` | Actualizar un gasto propio. | Sí |
| DELETE | `/api/v1/expenses/:id` | Eliminar un gasto propio. | Sí |
| GET | `/api/v1/categories` | Consultar categorías globales y privadas propias, ordenadas por nombre e ID. | Sí |
| POST | `/api/v1/categories` | Crear una categoría privada del usuario autenticado. | Sí |
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

Las respuestas de gastos agregan `author` (`id`, `name`), `can_edit` y `can_delete` calculados por el backend. Angular puede usar estos booleanos para mostrar acciones, pero el servidor siempre comprueba la autorización. No se aceptan permisos ni autoría enviados por el cliente. Se conservan `id`, `description`, `amount`, `date`, `notes`, `category` con `id` y `name`, `household` con `id` y `name` o `null`, y `receipt_attached` como booleano.

Filtros combinables de `GET /api/v1/expenses`:

| Parámetro | Efecto |
| --- | --- |
| `from` | Fecha del gasto mayor o igual a la indicada. |
| `to` | Fecha del gasto menor o igual a la indicada. |
| `category_id` | Gastos de la categoría indicada. |
| `household_id` | Todos los gastos del hogar indicado, previa comprobación de membresía actual; hogar ajeno o inexistente devuelve `404`. |

Las fechas se envían como `YYYY-MM-DD`. El orden es fecha descendente y luego ID descendente. Ejemplo: `/api/v1/expenses?from=2026-10-01&to=2026-10-31&category_id=1`.

Las creaciones exitosas devuelven `201`, las consultas/actualizaciones `200` y la eliminación `204` sin cuerpo. Los gastos inaccesibles o inexistentes devuelven `404`; editar o eliminar gastos ajenos también devuelve `404`, aunque puedan consultarse por compartir hogar. Los errores de validación devuelven `422` con `errors`; los filtros de fecha inválidos devuelven `400`.

### Hogares y categorías

El nombre de una categoría privada del autor es visible dentro de un gasto compartido y en las estadísticas del hogar. Esto no amplía el catálogo de categorías del lector ni permite asignar categorías privadas ajenas al crear o editar gastos. Las estadísticas agrupan por ID de categoría y nombre, conservando separadas las categorías homónimas.

`GET /api/v1/categories` devuelve únicamente `id`, `name` y `description` de las categorías globales y privadas propias, ordenadas por nombre e ID. Incluso un token de administrador solo ve ese catálogo en la API.

`POST /api/v1/categories` crea una categoría privada para el usuario autenticado. Acepta `name` y `description` dentro de `category`; ignora cualquier `user_id` enviado por el cliente. Ejemplo de cuerpo JSON:

```json
{
  "category": {
    "name": "Cursos",
    "description": "Formación personal"
  }
}
```

Devuelve `201` con `id`, `name` y `description`; los errores de validación devuelven `422` con `errors`. Una raíz `category` ausente o vacía devuelve `400`. Estos endpoints requieren Bearer token; sin autenticación válida devuelven `401`. No hay endpoints de consulta individual, edición o eliminación de categorías privadas.

Los nombres se recortan y se comparan sin distinguir mayúsculas ni espacios exteriores. Una privada no puede duplicar otra del mismo usuario ni una global; distintos usuarios pueden tener privadas homónimas. Crear o renombrar una global tampoco puede colisionar con privadas existentes. El propietario de una categoría no puede cambiarse. Las categorías con gastos asociados no pueden eliminarse.

Al crear o editar un gasto, la categoría debe ser global o privada del autor del gasto. Compartir hogar no habilita a usar categorías privadas ajenas. El back-office administra únicamente las globales desde `/admin/categories`.

Households index devuelve `id`, `name` y `description`, o un array vacío si no hay membresías. Show agrega `members`: cada integrante tiene `id` del usuario, `name`, `email` y `role` de su `Membership`. Un hogar ajeno o inexistente devuelve `404`.

POST de Households acepta únicamente `name` y `description`. Crea el hogar y la membresía del usuario autenticado con rol `owner` en una transacción; devuelve `201` con la misma estructura que show. Ante un fallo de validación o guardado cancelado, revierte la operación y responde `422` con `errors`.

### Dashboard

`GET /api/v1/dashboard` admite `from` y `to`, juntos o por separado, con límites inclusivos. Los mismos filtros se aplican a todos los cálculos en PostgreSQL. Sin `household_id`, incluye solo gastos propios accesibles: personales y de hogares donde conserva membresía. Excluye gastos ajenos y de hogares abandonados. Con `household_id=ID`, comprueba la membresía actual y calcula sobre todos los gastos del hogar, independientemente de su autor o de que este haya abandonado el hogar; un hogar ajeno o inexistente devuelve `404`. Cada gasto se cuenta una sola vez.

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

En `/admin/expenses`, crear o editar un gasto y seleccionar una imagen o PDF en **Comprobante (opcional)**. Guardar y abrir el detalle para descargar el archivo mediante el enlace de Active Storage. El selector ofrece imágenes y PDF; el modelo no impone validaciones de tipo ni tamaño. Seleccionar otro archivo reemplaza el anterior; editar sin elegir uno nuevo conserva el existente.

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

## Pruebas y controles de calidad

Desde el backend, después de preparar la base de tests aislada descrita arriba, conservar sus variables en esa terminal:

```bash
export RAILS_ENV=test
export DATABASE_URL=postgresql:///gasto_hogar_test_demo_12018
bin/rails test
bin/rails test:system
```

Minitest cubre modelos, controladores administrativos/API, autenticación, permisos, hogares compartidos, filtros, dashboard, adjuntos, correos, seeds y concurrencia. `test/test_helper.rb` carga fixtures y habilita paralelismo. `CategoryConcurrencyTest` utiliza conexiones independientes y registros confirmados, sin transacciones de fixtures; `CategorySeedsTest` ejecuta los seeds durante sus pruebas. Requieren PostgreSQL real y descartable.

`bin/rails test` no incluye los tests de sistema: `test:system` usa Selenium con Chrome headless según `test/application_system_test_case.rb` y requiere navegador/driver disponibles. Ejecutar solo un archivo o excluir sistema, concurrencia o seeds es una **ejecución parcial**: informar comando exacto, archivos excluidos y motivo.

El README anterior citaba una ejecución histórica del paso 119.12 mediante un helper externo que excluía Selenium. Ese helper no está en el repositorio y sus cifras no acreditan el estado actual ni una ejecución completa. No se encontraron exclusiones explícitas adicionales en los tests inspeccionados; no se dispone aquí del comando de auditoría del Paso 120.17 para certificar sus exclusiones. En el Paso 120.18 no se ejecutó ninguna prueba ni control de calidad; no se publica un resultado vigente de aprobación.

Controles disponibles, desde la raíz del backend:

```bash
bin/rubocop
bundle exec brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```

RuboCop usa `rubocop-rails-omakase`. Brakeman ejecutado con Bundler usa la versión instalada; `bin/brakeman` añade `--ensure-latest` y puede necesitar acceso remoto o fallar por versión desactualizada. Las auditorías de dependencias también pueden necesitar red.

`config/ci.rb` y `.github/workflows/ci.yml` describen los controles automatizados. `bin/ci` también ejecuta setup y `db:seed:replant`; no es una comprobación meramente documental y no debe apuntar a datos que se quieran conservar. El workflow incluye jobs separados para tests Rails y sistema; en `config/ci.rb` el paso de sistema está comentado.

Para el frontend, desde su raíz:

```bash
npm test -- --watch=false
npm run build
```

Consultar su [README](https://github.com/JuanZunino/gasto_hogar_frontend#readme) para alcance y validación manual.

## Recorrido de evaluación conjunta

1. Iniciar sesión administrativa y mostrar usuarios, categorías globales, hogares y membresías.
2. Crear un usuario y comprobar el archivo de bienvenida en `tmp/mails` o la vista previa del mailer.
3. Crear/editar un gasto en el back-office con comprobante y descargarlo desde el detalle.
4. Ingresar con un usuario final en Angular: mostrar perfil, crear, listar, filtrar, editar y eliminar gastos propios; crear una categoría privada desde el formulario.
5. Filtrar por el hogar compartido: mostrar gastos de ambos autores y acciones de edición/eliminación solo sobre los propios. Cambiar de usuario cerrando sesión y demostrar el aislamiento de gastos personales.
6. Abrir el dashboard, alternar Mis gastos/hogar y aplicar un período; comparar total, cantidad y categorías con los gastos correspondientes. Mostrar barras, dona y estado sin resultados.
7. Cerrar sesión y comprobar que las rutas Angular protegidas solicitan autenticación. Los permisos definitivos se aplican en Rails.

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

## Alcance y verificación documental

El backend y el frontend Angular implementan los flujos descritos de TP1/TP2. Angular no ofrece una pantalla de gestión de hogares/membresías: estos se preparan en el back-office; la API también permite crear hogares con membresía `owner`. No hay registro público, recuperación de contraseña ni invitaciones a hogares. El dashboard visual pertenece a Angular, no al back-office.

Esta documentación se contrastó con rutas, modelos, controladores, vistas, configuración, manifests, lockfiles y tests de ambos repositorios. Los comandos de instalación, conexión, preparación de bases, servidores y pruebas se documentan para su ejecución posterior: no se instalaron dependencias ni se arrancaron servicios durante esta revisión. La compatibilidad efectiva del entorno, disponibilidad remota y funcionamiento de extremo a extremo quedan pendientes de ejecución por el evaluador en el entorno aislado.
