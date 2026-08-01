# Colorscheme de ranger: Tokyo Night de base + acento del wallpaper.
#
# NO es un colorscheme escrito de cero. Hereda del Default de ranger y
# solo repinta tres cosas: la fila del cursor, la ruta de la barra de
# titulo y las barras de progreso. Todo lo demas (directorios en azul,
# ejecutables en verde, enlaces rotos en rojo, permisos, marcadores...)
# se queda como lo definio upstream, que ya esta bien pensado.
#
# La base Tokyo Night no se declara aqui: ranger pinta con los 16 ANSI y
# esos los define kitty.conf. Cambiar el tema de la terminal cambia
# ranger solo. Por eso este archivo no tiene ni un hex a pelo.
#
# El acento si viene de matugen, via ~/.config/ranger/accent, que se
# regenera con cada cambio de wallpaper. Ranger lo recoge al abrirse.

import os

from ranger.colorschemes.default import Default
from ranger.gui.color import reverse


# Ruta del archivo que escribe matugen (ver templates/ranger-accent).
ACCENT_FILE = os.path.expanduser("~/.config/ranger/accent")

# Si el archivo no existe todavia -- primer arranque, o matugen fallo --
# se cae a los ANSI de siempre en vez de dejar la interfaz sin color.
# 6 es cyan y 3 amarillo en la paleta del terminal.
FALLBACK = {"accent": 6, "accent2": 3}


def _nearest_256(red, green, blue):
    """Indice de la paleta xterm-256 mas parecido a un RGB dado.

    Curses no acepta color de 24 bits, asi que hay que aproximar. Se
    buscan candidatos solo entre el 16 y el 255: el cubo de 6x6x6 y la
    rampa de 24 grises. Los indices 0-15 quedan fuera A PROPOSITO --
    esos los redefine kitty a Tokyo Night, asi que su valor real no es
    el que dice el estandar y compararse con ellos daria un acento que
    no se parece al que pidio matugen.
    """
    # Niveles del cubo de color: no son lineales, xterm los define asi.
    levels = (0, 95, 135, 175, 215, 255)

    def closest_level(value):
        return min(range(6), key=lambda i: abs(levels[i] - value))

    r_i, g_i, b_i = (closest_level(c) for c in (red, green, blue))
    cube_index = 16 + 36 * r_i + 6 * g_i + b_i
    cube_dist = (
        (levels[r_i] - red) ** 2
        + (levels[g_i] - green) ** 2
        + (levels[b_i] - blue) ** 2
    )

    # La rampa de grises suele ganar en colores muy desaturados, donde
    # el cubo solo ofrece saltos grandes.
    gray_value = round((red + green + blue) / 3)
    gray_step = min(23, max(0, round((gray_value - 8) / 10)))
    gray_level = 8 + 10 * gray_step
    gray_dist = (
        (gray_level - red) ** 2
        + (gray_level - green) ** 2
        + (gray_level - blue) ** 2
    )

    return 232 + gray_step if gray_dist < cube_dist else cube_index


def _load_accents():
    """Lee el archivo de matugen. Nunca lanza: ranger moriria al arrancar."""
    accents = dict(FALLBACK)
    try:
        with open(ACCENT_FILE, encoding="utf-8") as handle:
            for line in handle:
                parts = line.split()
                # Saltamos comentarios y la cabecera del archivo.
                if len(parts) != 4 or parts[0] not in accents:
                    continue
                accents[parts[0]] = _nearest_256(*(int(p) for p in parts[1:]))
    except (OSError, ValueError):
        pass
    return accents


_ACCENTS = _load_accents()
ACCENT = _ACCENTS["accent"]
ACCENT2 = _ACCENTS["accent2"]


# La clase TIENE que llamarse "Scheme". No es cosmetico.
#
# Cuando el modulo no define ese nombre, ranger recorre el diccionario
# del modulo y se queda con la PRIMERA clase que herede de ColorScheme
# (ranger/gui/colorscheme.py). Y como aqui se importa Default para
# heredar de el, Default entra en el diccionario antes que esta clase y
# gana: ranger cargaba el colorscheme por defecto y el acento no
# aparecia por ningun lado. Con el nombre "Scheme" el cargador lo coge
# directo y se salta ese recorrido.
class Scheme(Default):
    def use(self, context):
        fg, bg, attr = Default.use(self, context)

        # ---- Fila del cursor ----
        # Default la marca con "reverse", que invierte los colores del
        # archivo: el cursor cambia de color segun el tipo de archivo
        # sobre el que este. Aqui se cambia por una barra de acento
        # solida, que es lo que hace que se vea el color del wallpaper
        # de un vistazo.
        #
        # El texto encima va en color0 (el fondo de kitty) y no en
        # blanco fijo: si el wallpaper da un acento claro, un blanco
        # desapareceria. Mismo criterio que on_primary en la plantilla
        # de GTK.
        if context.in_browser and context.selected:
            attr &= ~reverse
            fg, bg = 0, ACCENT

        # ---- Barra de titulo ----
        # El nombre del final, que es el archivo sobre el que esta el
        # cursor (titlebar.py lo anade con el contexto 'file'; los tramos
        # de la ruta van con 'directory').
        #
        # OJO: aqui NO vale usar context.directory. Ranger marca asi cada
        # tramo de la ruta, no "el directorio actual", asi que pinta la
        # linea entera de acento y se pierde la jerarquia en azul. Con
        # 'file' el acento senala lo mismo que la fila del cursor, que es
        # justo la relacion que interesa ver.
        elif context.in_titlebar and context.file:
            fg = ACCENT

        # ---- Pestanas ----
        elif context.in_titlebar and context.tab and context.good:
            fg, bg = 0, ACCENT

        # ---- Barra de progreso (copias, movimientos) ----
        elif context.in_statusbar and context.loaded:
            fg, bg = 0, ACCENT2

        return fg, bg, attr
