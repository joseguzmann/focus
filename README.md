# Focus

Temporizador Pomodoro para la barra de menú de macOS, al estilo de *Be Focused*.

- Ícono en la barra superior; mientras corre muestra el tiempo restante (`24:13`) y el aro del ícono se va vaciando.
- Popover con el anillo de progreso, play/pausa (también con la barra espaciadora) y ✕ para reiniciar la fase.
- Ciclo de enfoque → descanso corto → … → descanso largo cada N pomodoros.
- Tareas: elegís en qué estás trabajando y cada pomodoro completo se le suma.
- «Hoy 3/10»: pomodoros completados hoy contra la meta diaria.
- Notificación y sonido al terminar cada fase.
- Preferencias: duraciones, meta diaria, inicio automático, sonido, tiempo en la barra, abrir al iniciar sesión.
- Sin ícono en el Dock. Todo se guarda en `UserDefaults` local; nada sale de la máquina.

## Requisitos

macOS 14 o superior y Swift 5.10+ (Xcode o Command Line Tools).

## Compilar e instalar

```bash
./scripts/build-app.sh            # arma build/Focus.app
./scripts/build-app.sh --install  # además la copia a /Applications y la abre
```

Si Xcode está instalado pero sin la licencia aceptada, los scripts usan las Command Line Tools solos.

Para desarrollar sin armar el `.app`: `swift run` (ahí no hay notificaciones, porque requieren bundle id).

## Ícono

`Resources/AppIcon.icns` se genera con `./scripts/make-icon.sh` a partir de `scripts/make-icon.swift`.

## Estructura

| Archivo | Qué tiene |
| --- | --- |
| `Sources/Focus/FocusApp.swift` | Punto de entrada, `MenuBarExtra` e ícono de la barra |
| `Sources/Focus/FocusTimer.swift` | Estado: temporizador, fases, tareas, historial, notificaciones |
| `Sources/Focus/PopoverView.swift` | Vistas: temporizador, tareas, preferencias |
| `Sources/Focus/LaunchAtLogin.swift` | Abrir al iniciar sesión (`SMAppService`) |
