import { Flame, Mountain, Timer, Flag, CalendarDays, TrendingUp } from "lucide-react";

const features = [
  {
    icon: Timer,
    title: "Micro-Ziito de 25:00",
    desc: "Inicia una sesión de enfoque al instante y acumula minutos por materia.",
  },
  {
    icon: Mountain,
    title: "Escala tu montaña",
    desc: "Cada materia es una cara de la montaña que conquistas con tu enfoque.",
  },
  {
    icon: Flag,
    title: "Planta tu bandera",
    desc: "Al terminar un temporizador plantas una bandera con la Z verde en la cima.",
  },
  {
    icon: CalendarDays,
    title: "Horario claro",
    desc: "Bloques de colores por materia, estilo calendario, sin desorden.",
  },
  {
    icon: TrendingUp,
    title: "Metas Zenit",
    desc: "Define la nota que quieres lograr y mira tu avance hacia la cima.",
  },
  {
    icon: Flame,
    title: "Racha diaria",
    desc: "Mantén la llama encendida estudiando todos los días.",
  },
];

const Index = () => {
  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* Header */}
      <header className="mx-auto flex max-w-6xl items-center justify-between px-6 py-6">
        <div className="flex items-center gap-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary text-primary-foreground">
            <Mountain className="h-5 w-5" />
          </div>
          <span className="text-lg font-bold tracking-tight">Ziito</span>
        </div>
        <a
          href="#features"
          className="rounded-full bg-primary px-5 py-2 text-sm font-semibold text-primary-foreground transition hover:opacity-90"
        >
          Empezar
        </a>
      </header>

      {/* Hero */}
      <section className="relative overflow-hidden">
        {/* Sky + mountain backdrop */}
        <div
          className="pointer-events-none absolute inset-0 -z-10"
          style={{
            background:
              "linear-gradient(180deg, hsl(200 70% 92%) 0%, hsl(160 30% 98%) 55%)",
          }}
        />
        <div
          className="pointer-events-none absolute bottom-0 left-1/2 -z-10 h-64 w-[140%] -translate-x-1/2"
          style={{
            clipPath: "polygon(0 100%, 22% 38%, 38% 62%, 55% 16%, 72% 58%, 100% 100%)",
            background: "linear-gradient(180deg, hsl(170 22% 60%) 0%, hsl(158 64% 26%) 100%)",
          }}
        />

        <div className="mx-auto max-w-3xl px-6 pt-16 pb-28 text-center sm:pt-24">
          <span className="inline-flex items-center gap-2 rounded-full bg-secondary px-4 py-1.5 text-sm font-medium text-secondary-foreground">
            <Flame className="h-4 w-4 text-accent" />
            Estudia con enfoque, escala tu montaña
          </span>
          <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight sm:text-6xl">
            Convierte tu estudio en una
            <span className="text-primary"> montaña que conquistas</span>
          </h1>
          <p className="mx-auto mt-5 max-w-xl text-lg text-muted-foreground">
            Ziito transforma cada sesión de enfoque en progreso visible. Acumula minutos,
            planta tus banderas y llega a la cima de cada materia.
          </p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a
              href="#features"
              className="w-full rounded-full bg-primary px-7 py-3 text-base font-semibold text-primary-foreground shadow-lg shadow-primary/20 transition hover:opacity-90 sm:w-auto"
            >
              Descubre cómo funciona
            </a>
            <span className="text-sm text-muted-foreground">Disponible en iPhone</span>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="mx-auto max-w-6xl px-6 py-20">
        <div className="mb-12 text-center">
          <h2 className="text-3xl font-bold tracking-tight">Todo para mantener el enfoque</h2>
          <p className="mt-3 text-muted-foreground">Sin IA, sin ruido. Solo tú y tu progreso.</p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div
              key={f.title}
              className="group rounded-2xl border bg-card p-6 transition hover:-translate-y-1 hover:shadow-xl hover:shadow-primary/5"
            >
              <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-secondary text-primary transition group-hover:bg-primary group-hover:text-primary-foreground">
                <f.icon className="h-5 w-5" />
              </div>
              <h3 className="mt-4 text-lg font-semibold">{f.title}</h3>
              <p className="mt-2 text-sm text-muted-foreground">{f.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="mx-auto max-w-4xl px-6 pb-24">
        <div className="relative overflow-hidden rounded-3xl bg-primary px-8 py-14 text-center text-primary-foreground">
          <Mountain className="mx-auto h-10 w-10 opacity-90" />
          <h2 className="mt-4 text-3xl font-bold">Tu cima te espera</h2>
          <p className="mx-auto mt-3 max-w-md opacity-80">
            Empieza tu primer Micro-Ziito hoy y planta tu primera bandera.
          </p>
          <a
            href="#"
            className="mt-7 inline-flex rounded-full bg-accent px-7 py-3 font-semibold text-accent-foreground transition hover:opacity-90"
          >
            Comenzar a escalar
          </a>
        </div>
      </section>

      <footer className="border-t py-8 text-center text-sm text-muted-foreground">
        Ziito — Enfócate, escala, conquista.
      </footer>
    </div>
  );
};

export default Index;
