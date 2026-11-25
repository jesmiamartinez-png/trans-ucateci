# TransUni UCATECI — publicación en Vercel + Supabase

Esta versión usa Supabase Auth para cuentas reales, una tabla compartida para el estado de la aplicación y Supabase Realtime para avisar a los demás navegadores cuando cambian reservas, votos, horarios o choferes. Ya no guarda usuarios/contraseñas en localStorage.

## 1. Crear el proyecto de base de datos

1. Crea un proyecto en https://supabase.com/.
2. Abre **SQL Editor → New query**.
3. Copia y ejecuta todo el contenido de `supabase/schema.sql`.
4. En **Authentication → Providers → Email**, desactiva **Confirm email**. La app inicia sesión con matrícula + contraseña y genera internamente un correo técnico `matricula@transuni.app`; por eso no debe requerir confirmación de correo.
5. En **Project Settings → API**, copia **Project URL** y **anon / public key**.
6. Pega esos dos valores en `supabase-config.js`. No uses ni compartas la `service_role` key.

## 2. Crear las cuentas del personal

1. Abre la página y registra primero la cuenta que será administradora, usando su matrícula real y una contraseña de al menos 8 caracteres.
2. Registra las cuentas de los choferes del mismo modo.
3. En Supabase → SQL Editor ejecuta estas consultas, sustituyendo las matrículas:

```sql
update public.profiles set rol = 'admin' where lower(matricula) = lower('MATRICULA_ADMIN');
update public.profiles set rol = 'chofer' where lower(matricula) = lower('MATRICULA_CHOFER_DILONE');
update public.profiles set rol = 'chofer' where lower(matricula) = lower('MATRICULA_CHOFER_JORGE');
```

Las demás cuentas se registran como estudiantes. El rol no se puede elegir ni cambiar desde el formulario de registro.

## 3. Publicar en Vercel

1. Sube `index.html`, `supabase-config.js` y la carpeta `supabase/` a un repositorio de GitHub (la carpeta `supabase/` contiene el SQL de configuración; Vercel no necesita ejecutarla).
2. En https://vercel.com/ pulsa **Add New → Project** y conecta ese repositorio.
3. Framework preset: **Other**. Build command y Output directory pueden quedar vacíos; el archivo `vercel.json` sirve la página estática.
4. Pulsa **Deploy**.

También puedes arrastrar la carpeta del proyecto a Vercel si usas su flujo de despliegue manual.

## 4. Comprobación

- Abre el dominio de Vercel en dos navegadores o dispositivos.
- Registra un estudiante y accede con su matrícula y contraseña.
- Haz una reserva desde un navegador; la lista debe actualizarse en el otro.
- Cambia un horario desde una cuenta de chofer/admin y verifica el otro navegador.

## Importante

- El estado compartido y los perfiles están protegidos con RLS. Los estudiantes solo pueden modificar sus propias reservas y votos; choferes y administradores pueden actualizar la configuración operativa.
- Las cuentas de personal se crean primero como cuentas normales y luego se promocionan con las consultas SQL anteriores.
- La clave `anon/public` es pública por diseño y está limitada por las políticas RLS. Nunca publiques una `service_role` key.
- La aplicación necesita conexión a internet para Supabase, Tailwind CDN y Google Fonts.
- Los cambios de horario y los votos se sincronizan mediante eventos realtime. La aplicación sigue necesitando el esquema SQL instalado en Supabase; publicar solo el HTML no crea la base de datos.
