# Ziito V8: quitar toda la IA y rediseñar la montaña con base de pasto y niebla de progreso

## Qué voy a construir

### 1. Quitar toda la Inteligencia Artificial

- Elimino por completo el tutor Owl/socrático, el chat, la importación de PDFs, el escaneo/OCR, las flashcards, los resúmenes y la sección "Biblioteca".
- Borro también los datos relacionados (fuentes, páginas de apuntes y tarjetas) para que la app quede 100% local y enfocada en el tiempo de estudio.
- El horario seguirá funcionando, pero sin nada de IA.

### 2. Navegación limpia (4 pestañas)

- La barra inferior queda con: **Hoy**, **Horario**, **Montaña** y **Más**.
- Sin rastros de Biblioteca, IA ni Notebook en ningún menú.

### 3. Nuevo Home [Hoy] — Panel limpio

- Arriba: contador de **racha** (llama de fuego) 
- 
- Un botón grande para **iniciar un Micro-Ziito de 25:00** al instante.
- Una vista compacta de tu **próxima actividad** de la agenda.
- Debajo, tus tareas y evaluaciones del día, sin desorden.

### 4. Rediseño de la Montaña — Carousel Engine (V10)

- **Diorama sobre base de madera:** la montaña se asienta en una plataforma circular de madera con borde oscuro, con un faldón de pasto verde abrazando su base y un par de pinos. Cielo azul suave de fondo.
- **Sombreado suave (porcelana mate):** la malla usa normales por vértice promediadas, eliminando las facetas planas; roca gris que transiciona a nieve blanca hacia la cima, con vetas suaves.
- **Gira todo el diorama:** al deslizar de lado, gira el conjunto completo (pasto, altar, pinos y montaña) sobre el eje Y. La cámara queda fija en el suelo, así que el mundo gira frente a ti.
- **Snapping entre materias:** al soltar el swipe, el diorama interpola suavemente y encara exactamente una cara/materia frente a la cámara.
- **Cámara baja anclada al suelo:** la cámara se posa baja sobre el pasto mirando claramente hacia arriba; la montaña se aleja (mismo tamaño, más al fondo) y el suelo se extiende hacia ti para no flotar.
- **Suelo extendido:** un gran campo de pasto plano llega hasta el espectador, así estás parado en el terreno y no flotando sobre una plataforma.
- **Montaña sin senderos:** la ladera queda limpia, sin ninguna ruta pintada ni nodos de hito (todo lo estilo Duolingo se eliminó por completo).
- **Sendero del suelo en 3D:** el único sendero es el camino que cruza el pasto hacia el pie de la montaña, hecho de losas de piedra elevadas con volumen real.
- **Cima despejada:** se retiró la niebla blanca de progreso; el pico queda limpio.
- **Altar visible:** se eliminó el campamento; el altar de banderas se ubica al frente-derecha, dentro del encuadre de la cámara.
- **Doble bandera:** al terminar un temporizador se planta una bandera en la cara activa de la montaña y una réplica aparece en el altar estático de la derecha.

### 5. Progreso por enfoque (sin IA)

- Avanzas en cada materia **acumulando minutos de enfoque** exitosos asignados a esa materia.
- Al terminar un temporizador en 00:00 se planta automáticamente una **bandera blanca con la "Z" verde** en la cara de la montaña, y una réplica en el **Altar de Banderas**.
- Al completar una materia al 100%, emerge un **monumento de piedra** con su nombre.

### 6. Metas (Zenit y Examen)

- **Zenit por materia:** la nota/promedio que quieres lograr, brillando tenue en la cima de cada cara. Si no la defines, se te pide al entrar.
- **Cuenta regresiva de examen:** registras la fecha y nota objetivo, y la app calcula los días restantes.

### 7. Detalles que se mantienen y se pulen

- Horario estilo Google Calendar (bloques de colores por materia).
- La barra del temporizador no tapará botones (empuja el contenido, no se superpone).
- Live Activity y Dynamic Island del temporizador siguen funcionando.
- Todo respeta el área segura para no chocar con la Dynamic Island.

## Plan de entrega

Intentaré todo de una vez. Si el rediseño 3D resulta demasiado pesado, priorizo dejar funcionando la purga de IA, las 4 pestañas y el Home, y luego refino la montaña.