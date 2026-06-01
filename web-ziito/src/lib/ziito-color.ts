// Helpers for working with subject hex colors in the UI.

export function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace(/[^0-9a-fA-F]/g, "");
  const v =
    clean.length === 3
      ? clean.split("").map((c) => c + c).join("")
      : clean.padStart(6, "0").slice(0, 6);
  const int = parseInt(v, 16);
  return { r: (int >> 16) & 255, g: (int >> 8) & 255, b: int & 255 };
}

export function colorVar(hex: string): string {
  return `#${hex.replace(/[^0-9a-fA-F]/g, "")}`;
}

export function colorAlpha(hex: string, alpha: number): string {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const PRESET_COLORS: { name: string; hex: string }[] = [
  { name: "Rojo", hex: "FF3B30" },
  { name: "Naranja", hex: "FF9500" },
  { name: "Amarillo", hex: "FFCC00" },
  { name: "Verde", hex: "34C759" },
  { name: "Verde Azulado", hex: "5AC8FA" },
  { name: "Azul", hex: "007AFF" },
  { name: "Índigo", hex: "5856D6" },
  { name: "Morado", hex: "AF52DE" },
  { name: "Rosa", hex: "FF2D55" },
  { name: "Café", hex: "A2845E" },
  { name: "Gris", hex: "8E8E93" },
  { name: "Coral", hex: "FF6B6B" },
];
