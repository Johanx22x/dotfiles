-- =============================================================
--  gaming.lua — ajustes de Hyprland para juegos
--  Cargado desde hyprland.lua con:  require("gaming")
-- =============================================================

---------------------------------------------------------------
-- 1. RENDER: menos capas entre el juego y la pantalla
---------------------------------------------------------------

-- direct scanout: cuando hay UNA sola ventana en pantalla completa,
-- Hyprland deja de componer y manda el buffer del juego directo al
-- monitor. Menos latencia y menos uso de GPU. Antes estaba en 0.
hl.config({ render = { direct_scanout = 1 } })

-- VRR (FreeSync/G-Sync) solo cuando hay algo a pantalla completa.
-- 0 = off, 1 = solo fullscreen, 2 = siempre.
-- Si ves parpadeo en el escritorio, dejalo en 1 (nunca en 2 con NVIDIA).
hl.config({ misc = { vrr = 1 } })

-- Evita el parpadeo tipico de NVIDIA al cambiar de framerate.
hl.config({ opengl = { nvidia_anti_flicker = true } })

-- CURSOR POR HARDWARE. Importante, no lo quites.
-- Con el automatico (2), en NVIDIA acaban desactivados y Hyprland compone el
-- cursor por software en cada frame. Con un juego a pantalla completa exigiendo
-- la GPU, eso hace que el cursor del overlay de Steam se sienta pegado.
--   no_hardware_cursors = 0 -> fuerza el plano de hardware
--   use_cpu_buffer      = 1 -> el driver de NVIDIA necesita buffers mapeados en
--                              CPU para ese plano; sin esto, el 0 de arriba no
--                              sirve de nada.
-- Comprobar con: hyprctl -j monitors | grep hardwareCursorsInUse  (debe ser true)
hl.config({ cursor = { no_hardware_cursors = 0, use_cpu_buffer = 1 } })

-- Tearing: desactivado. Con 165 Hz + VRR no hace falta y da artefactos.
-- Si juegas competitivo y quieres la minima latencia posible, ponlo en
-- true y descomenta la regla "immediate" de mas abajo.
hl.config({ general = { allow_tearing = false } })


---------------------------------------------------------------
-- 2. VARIABLES DE ENTORNO
---------------------------------------------------------------

-- Cache de shaders de NVIDIA persistente entre sesiones.
hl.env("__GL_SHADER_DISK_CACHE", "1")
hl.env("__GL_SHADER_DISK_CACHE_SKIP_CLEANUP", "1")

-- Backend directo para la aceleracion de video de NVIDIA (VA-API).
hl.env("NVD_BACKEND", "direct")

-- NO pongas aqui SDL_VIDEODRIVER=wayland ni QT_QPA_PLATFORM=wayland.
-- Rompen un monton de juegos que usan SDL2 antiguo; que caigan a
-- XWayland es lo correcto, gamescope se encarga del resto.


---------------------------------------------------------------
-- 3. REGLAS DE VENTANA: el fullscreen que nunca falla
---------------------------------------------------------------

-- Clases que consideramos "un juego":
--   gamescope          -> todo lo lanzado con el script `gs`
--   steam_app_<id>     -> juegos de Steam bajo XWayland sin gamescope
--   .exe               -> algunos juegos de Proton se identifican asi
local GAMES = "^(gamescope|steam_app_.*|.*\\.exe|hl2_linux|cs2)$"

hl.window_rule({
    name  = "juegos-pantalla-completa",
    match = { class = GAMES },

    -- SIEMPRE en el monitor horizontal 1440p, nunca en el vertical.
    -- MONITOR_PRINCIPAL lo define hyprland.lua antes de require("gaming");
    -- es una descripcion EDID, no un nombre de conector, porque los nombres
    -- de conector cambian al cambiar de kernel.
    monitor      = MONITOR_PRINCIPAL,
    fullscreen   = true,         -- y siempre a pantalla completa
    border_size  = 0,
    rounding     = 0,
    no_anim      = true,         -- las animaciones estorban al entrar/salir
    idle_inhibit = "fullscreen", -- que no salte el salvapantallas jugando
    content      = "game",       -- pista al compositor: prioriza latencia
})

-- Para competitivo con tearing (requiere allow_tearing = true arriba):
-- hl.window_rule({
--     name  = "juegos-tearing",
--     match = { class = "^(cs2|gamescope)$" },
--     immediate = true,
-- })


---------------------------------------------------------------
-- 4. CLIENTE DE STEAM: quitarle las manias
---------------------------------------------------------------

-- Los menus contextuales de Steam tienen titulo vacio y se cierran solos
-- al perder el foco. Estas dos reglas son el arreglo estandar.
hl.window_rule({
    name  = "steam-menus-contextuales",
    match = { class = "^steam$", title = "^$" },
    stay_focused = true,
    min_size     = "1 1",
})

-- Ventanas secundarias de Steam: que floten en vez de partir el layout.
hl.window_rule({
    name  = "steam-ventanas-sueltas",
    match = { class = "^steam$",
              title = "^(Friends List|Lista de amigos|Steam Settings|Configuraci.n|Special Offers|Steam - News|Steam Guard.*|Iniciar sesi.n en Steam|Sign in to Steam)$" },
    float = true,
})

-- Big Picture: pantalla completa en el monitor principal.
hl.window_rule({
    name  = "steam-big-picture",
    match = { class = "^steam$", title = "^Steam Big Picture Mode$" },
    monitor    = MONITOR_PRINCIPAL,
    fullscreen = true,
})


---------------------------------------------------------------
-- 5. SIN HUECOS CUANDO SOLO HAY UNA VENTANA
---------------------------------------------------------------
-- Asi un juego en ventana maximizada tampoco deja bordes raros.

hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "sin-huecos-fullscreen",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})


---------------------------------------------------------------
-- 6. CAPTURADORA (PS5 / Switch 2 por la NZXT Signal HD60)
---------------------------------------------------------------
-- El script `capturadora` lanza mpv con --wayland-app-id=capturadora,
-- por eso podemos apuntarle una regla sin afectar al resto de mpv.
-- Flotante y a 1920x1080 exactos, que es la resolucion nativa de la
-- capturadora: asi no hay reescalado. La tecla f de mpv alterna a
-- pantalla completa y vuelve a este tamano.

hl.window_rule({
    name  = "capturadora",
    match = { class = "^capturadora$" },

    float        = true,          -- nunca en el tiling
    size         = "1920 1080",   -- 1:1 con la senal, sin reescalar
    center       = true,
    monitor      = MONITOR_PRINCIPAL,
    border_size  = 0,             -- solo video, como en PotPlayer
    rounding     = 0,
    no_anim      = true,
    idle_inhibit = "always",      -- el mando no mueve el raton: sin esto
                                  -- saltaria el salvapantallas jugando
    content      = "game",
})


---------------------------------------------------------------
-- 7. ATAJOS
---------------------------------------------------------------

-- SUPER + F  : forzar pantalla completa de la ventana activa.
--              Tu red de seguridad si un juego se abre en ventanita.
hl.bind("SUPER + F", hl.dsp.window.fullscreen())

-- SUPER + SHIFT + F : pantalla completa "falsa" (el juego cree que sigue
--              en ventana pero ocupa todo). Arregla juegos que se
--              minimizan al hacer alt-tab.
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }))
