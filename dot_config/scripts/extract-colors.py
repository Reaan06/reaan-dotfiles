#!/usr/bin/env python3
"""
Extrae colores dominantes de un wallpaper y genera una paleta sobria
para Quickshell.
Uso: extract-colors.py <raw_colors_file> <output_palette_file>
     O: pipe hex colors via stdin
Formato de salida: 8 colores hex separados por espacio:
  pill_bg  accent1  accent2  accent3  accent4  accent5  text  sub

Filosofía: usar los colores REALES del wallpaper, desaturados moderadamente
para que sean sobrios pero aún reflejen la imagen. Fondo gris oscuro.
"""
import sys, colorsys, os

FALLBACK = "#2a2a2e #8a9a9e #7a8e85 #9490a0 #a09882 #8a7e7a #c8cad0 #5a5a64"

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return '#{:02x}{:02x}{:02x}'.format(
        max(0, min(255, int(r * 255))),
        max(0, min(255, int(g * 255))),
        max(0, min(255, int(b * 255))))

def luminance(h):
    r, g, b = hex_to_rgb(h)
    return 0.299 * r + 0.587 * g + 0.114 * b

def saturation(h):
    r, g, b = hex_to_rgb(h)
    _, _, s = colorsys.rgb_to_hls(r, g, b)
    return s

def mute(hex_color, sat_factor=0.90, lum_target=0.55):
    """Mantiene el color del wallpaper, solo normaliza luminancia."""
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    s = min(0.85, s * sat_factor)
    l = l * 0.25 + lum_target * 0.75
    l = max(0.35, min(0.72, l))
    r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
    return rgb_to_hex(r2, g2, b2)

def darken_pill(hex_color):
    """Fondo gris oscuro con tinte visible del color."""
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = 0.14
    s = min(s * 0.5, 0.22)
    r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
    return rgb_to_hex(r2, g2, b2)

def make_text(hex_color):
    """Texto claro con tinte del color dominante."""
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r2, g2, b2 = colorsys.hls_to_rgb(h, 0.83, min(s * 0.35, 0.20))
    return rgb_to_hex(r2, g2, b2)

def make_sub(hex_color):
    """Subtexto con tinte reconocible del color."""
    r, g, b = hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r2, g2, b2 = colorsys.hls_to_rgb(h, 0.42, min(s * 0.45, 0.22))
    return rgb_to_hex(r2, g2, b2)

def main():
    colors = []
    if len(sys.argv) >= 2 and os.path.isfile(sys.argv[1]):
        with open(sys.argv[1]) as f:
            colors = [l.strip() for l in f if l.strip().startswith('#')]
    else:
        colors = [l.strip() for l in sys.stdin if l.strip().startswith('#')]

    out_path = sys.argv[2] if len(sys.argv) >= 3 else os.path.expanduser('~/.config/quickshell/.palette')

    if len(colors) < 4:
        palette = FALLBACK
    else:
        # Ordenar por saturación (los más coloridos primero)
        mid = sorted(colors, key=saturation, reverse=True)

        # Filtrar colores muy oscuros o muy claros para los acentos
        usable = [c for c in mid if 0.08 < luminance(c) < 0.85]
        if len(usable) < 5:
            usable = mid  # usar todos si no hay suficientes

        # Rellenar si faltan
        while len(usable) < 6:
            usable.append(usable[-1] if usable else '#888888')

        # Pill: del color más oscuro del wallpaper
        darkest = sorted(colors, key=luminance)[0]
        pill = darken_pill(darkest)

        # 5 acentos: colores reales del wallpaper, moderadamente desaturados
        accents = [mute(usable[i]) for i in range(5)]

        # Texto y sub derivados del acento principal
        text = make_text(usable[0])
        sub  = make_sub(usable[0])

        palette = f"{pill} {accents[0]} {accents[1]} {accents[2]} {accents[3]} {accents[4]} {text} {sub}"

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(palette + '\n')

if __name__ == '__main__':
    main()
