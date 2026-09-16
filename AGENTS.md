# Instrucciones para trabajar en GastoHogar

## Contexto del proyecto

GastoHogar es un trabajo práctico individual de Programación IV. El backend
está desarrollado con Ruby on Rails 8.1 y PostgreSQL. La aplicación permite
registrar y organizar gastos personales y gastos compartidos dentro de hogares.

El frontend público se desarrollará posteriormente y consumirá una API JSON.
Debe existir un back-office tradicional de Rails bajo `/admin`, mientras que
la API debe estar versionada bajo `/api/v1`.

## Organización del código

- Mantener separados los controllers del back-office y de la API.
- Ubicar los controllers del back-office en `app/controllers/admin/`, bajo el
  namespace `Admin`, con vistas tradicionales de Rails.
- Ubicar los controllers de la API en `app/controllers/api/v1/`, bajo el
  namespace `Api::V1`, con respuestas JSON.
- Mantener las rutas correspondientes bajo `/admin` y `/api/v1`.
- Priorizar código simple, legible y apropiado para un proyecto académico,
  siguiendo las convenciones de Rails y del código existente.

## Modelos y relaciones previstos

Los siguientes modelos y relaciones describen el diseño previsto; no implican
que ya estén implementados ni autorizan su implementación sin una tarea que
lo solicite.

| Modelo | Relaciones previstas |
| --- | --- |
| `User` | Tiene muchos `Expenses` y `Memberships`. Pertenece a muchos `Households` a través de `Memberships`. |
| `Household` | Tiene muchos `Memberships` y `Expenses`. Tiene muchos `Users` a través de `Memberships`. |
| `Membership` | Pertenece a `User` y `Household`. |
| `Category` | Tiene muchos `Expenses`. |
| `Expense` | Pertenece a `User` y `Category`. Puede pertenecer opcionalmente a `Household`. |

Un gasto sin hogar asociado representa un gasto personal. La asociación
`Expense` → `Household` debe ser opcional.

## Reglas de trabajo

- No implementar funcionalidades no solicitadas, incluido el futuro frontend
  público.
- Realizar cambios pequeños e incrementales.
- Antes de cambios importantes, explicar brevemente qué se va a modificar y
  por qué.
- No agregar gems sin justificar su necesidad.
- No modificar varios componentes del sistema cuando la tarea solicite
  solamente uno.
- Crear y mantener tests para las validaciones y la lógica de negocio que se
  agreguen o modifiquen, utilizando la estructura existente en `test/`.
- No realizar commits automáticamente.

## Comprobación y entrega

Ejecutar los comandos desde la raíz de este repositorio, donde están `Gemfile`
y `bin/rails`. Elegir las comprobaciones pertinentes al cambio:

- `bin/rails test test/models/<modelo>_test.rb`: tests del modelo modificado,
  reemplazando `<modelo>` por su nombre real.
- `bin/rails test`: suite de tests.
- `bin/rubocop`: revisión del estilo de Ruby.
- `bin/rails routes`: comprobación de rutas cuando se modifiquen.
- `bin/rails db:migrate`: aplicación de migraciones cuando la tarea las incluya.

Al finalizar cada tarea:

- Resumir el cambio realizado.
- Indicar qué archivos fueron modificados o creados.
- Indicar qué comandos deberían ejecutarse para comprobar el cambio.
- Distinguir las comprobaciones efectivamente ejecutadas de las sugeridas e
  informar cualquier impedimento para verificarlas.
