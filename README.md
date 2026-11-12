# Mi Banquito

SaaS familiar de educación financiera con moneda virtual. Una familia crea la cuenta del padre y sus perfiles infantiles; cada hogar queda aislado por RLS en Supabase.

## Ejecutar localmente

Requisitos: Node.js 20+ y npm.

```sh
npm install
```

Copia `.env.example` a `.env.local` y conserva la URL y la llave publicable del proyecto **JosiWorld**. Esa llave puede vivir en el navegador; nunca agregues `service_role` a un archivo `VITE_*`.

```sh
npm run dev
```

## Supabase

El MCP del proyecto está fijado a `JosiWorld` mediante `.mcp.json`. Las migraciones de `supabase/migrations` crean perfiles, familias, tareas, recompensas, aprobaciones, ledger balanceado, ahorro, logros, reglas RLS e idempotencia. Las Edge Functions desplegadas son:

- `create-child`: crea la cuenta Auth infantil solo cuando la invoca el padre de esa familia.
- `child-login`: intercambia usuario y contraseña infantiles por una sesión Auth.
- `reset-child-password`: permite al padre restablecer la contraseña de un hijo propio.

Para aplicar migraciones nuevas y publicar cambios de funciones:

```sh
npx supabase login
npx supabase link --project-ref liysgzgorpyotxabryhm
npx supabase db push
npx supabase functions deploy create-child
npx supabase functions deploy child-login --no-verify-jwt
npx supabase functions deploy reset-child-password
```

No se necesita una clave de servicio en el frontend. Supabase expone `SUPABASE_SERVICE_ROLE_KEY` solo dentro del entorno de Edge Functions.

## Primeros pasos

1. Crea una cuenta de mamá o papá con un correo que puedas confirmar.
2. Inicia sesión. Al registrarse, Supabase crea la familia y carga ejemplos editables de tareas y recompensas.
3. En **Mis hijos**, crea los perfiles y entrega a cada niño su usuario y contraseña inicial.
4. En **Rutinas y extras**, configura rutinas con días activos, hora límite, actividades, pagos por actividad o por rutina completa; también crea tareas extra.
5. El niño entra desde **Soy niño o niña**. Ve todas sus rutinas, incluso pausadas y no programadas (atenuadas), envía las actividades juntas antes de la hora límite y reclama extras; el primer reclamo reserva el extra hasta que lo termine o lo libere.
6. En **Aprobaciones**, revisa actividades de rutina, rutinas completas, extras, canjes y solicitudes antiguas. Los pagos aprobados quedan en el mismo ledger financiero.
7. Para verificar el aislamiento, registra una segunda familia con otro correo y comprueba que cada sesión solo ve sus propios perfiles y datos.

La moneda es virtual y no tiene valor monetario real. Un movimiento aprobado se conserva en el ledger; los saldos disponibles y de ahorro se calculan desde sus asientos.

Las rachas se cuentan por días programados con la rutina completa aprobada; los días libres de esa rutina no interrumpen la racha. Las medallas se desbloquean al llegar a 3, 7, 14 y 30 días. La hora límite se aplica en horario de Ciudad de México, también en la base de datos.

En **Configuración → Zona de peligro**, un padre puede retirar monedas del saldo disponible o reiniciar los saldos disponible y de ahorro de un hijo. El reinicio agrega asientos compensatorios al ledger y conserva el historial, la experiencia y las medallas; primero hay que resolver los canjes pendientes.

Los niños pueden editar sus metas de ahorro y retirar una cantidad parcial o todo el dinero de cada meta. Una meta se puede quitar cuando su saldo vuelve a cero; se archiva para conservar sus movimientos financieros.

## Validación local

```sh
npm run build
npm run lint
```

## Pruebas de base de datos

Los guiones en `supabase/tests` prueban el aislamiento de dos familias, el acceso de padres e hijos, aprobaciones, idempotencia, saldos, canjes, ahorro, rutinas y extras. Se pueden ejecutar en el SQL Editor de JosiWorld con una sesión administrativa. Cada guion abre una transacción y termina con `ROLLBACK`, así que sus perfiles y movimientos temporales no quedan guardados.

Ambos guiones se ejecutaron contra JosiWorld durante la implementación. La prueba financiera también cubre el rechazo de fondos insuficientes y de autoaprobación.

La política de Auth del proyecto todavía debe tener habilitada la protección contra contraseñas filtradas. El asesor de seguridad también informa de una función preexistente llamada `rls_auto_enable()` que permite ejecución pública; la app no la usa y no se alteró porque no pertenece a Mi Banquito.
