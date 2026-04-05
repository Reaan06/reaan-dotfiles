#!/usr/bin/env python3
"""
Extrae colores dominantes de un wallpaper y genera una paleta para Quickshell.
Uso: extract-colors.py <raw_colors_file> <output_palette_file>
     O: pipe hex colors via stdin
Formato de salida: 8 colores hex separados por espacio:
  pill_bg  accent1  accent2  accent3  accent4  accent5  text  sub
"""
import sys, colorsys, os

FALLBACK = "#1e1e2e #94e2d5 #a6e3a1 #cba6f7 #f9e2af #f38ba8 #cdd6f4 #585b70"

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

def darken(h, factor=0.35):
    r, g, b = hex_to_rgb(h)
    hl, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0.04, l * factor)
    r2, g2, b2 = colorsys.hls_to_rgb(hl, l, s)
    return rgb_to_hex(r2, g2, b2)

def boost(h, sat_factor=1.3, target_lum=0.55):
    """Boost saturation and normalize luminance for accent vibrancy."""
    r, g, b = hex_to_rgb(h)
    hl, l, s = colorsys.rgb_to_hls(r, g, b)
    s = min(1.0, s * sat_factor)
    l = min(0.72, max(0.35, l * 0.5 + target_lum * 0.5))
    r2, g2, b2 = colorsys.hls_to_rgb(hl, l, s)
    return rgb_to_hex(r2, g2, b2)

def desaturate(h, factor=0.25, target_lum=0.35):
    r, g, b = hex_to_rgb(h)
    hl, l, s = colorsys.rgb_to_hls(r, g, b)
    s = s * factor
    l = target_lum
    r2, g2, b2 = colorsys.hls_to_rgb(hl, l, s)
    return rgb_to_hex(r2, g2, b2)

def main():
    # Leer colores desde archivo o stdin
    colors = []
    if len(sys.argv) >= 2 and os.path.isfile(sys.argv[1]):
        with open(sys.argv[1]) as f:
            colors = [l.strip() for l in f if l.strip().startswith('#')]
    else:
        colors = [l.strip() for l in sys.stdin if l.strip().startswith('#')]

    out_path = sys.argv[2] if len(sys.argv) >= 3 else os.path.expanduser('~/.cache/qs-palette')

    if len(colors) < 4:
        palette = FALLBACK
    else:
        # Ordenar por luminancia
        colors.sort(key=luminance)

        darkest = colors[0]
        lightest = colors[-1]

        # Colores intermedios ordenados por saturación (más vibrantes primero)
        mid = sorted(colors[1:-1], key=saturation, reverse=True)
        while len(mid) < 6:
            mid.append(mid[-1] if mid else '#888888')

        # Construir paleta
        pill = darken(darkest, 0.35)
        accents = [boost(c) for c in mid[:5]]

        # Asegurar que el texto sea claro
        if luminance(lightest) < 0.65:
            text = '#cdd6f4'
        else:
            text = lightest

        # Subtexto: desaturado y oscuro
        sub = desaturate(mid[-1], factor=0.2, target_lum=0.38)

        palette = f"{pill} {accents[0]} {accents[1]} {accents[2]} {accents[3]} {accents[4]} {text} {sub}"

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w') as f:
        f.write(palette + '\n')

if __name__ == '__main__':
    main()
