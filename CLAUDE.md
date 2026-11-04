# CLAUDE.md — task_manager_pdv_windows (PDV Windows)

> Regras globais da workspace estão em `C:\App_Academia\CLAUDE.md`. Em conflito, o pai prevalece.

## Project

**Flutter — PDV (Ponto de Venda) para Windows.**

Frente de caixa desktop do ecossistema App Academia, consumindo o backend `AppAcademia`. Projeto
enxuto e focado: `lib/{core,models,screens,services}` + `main.dart`.

**Core Value:** operação de venda rápida e estável no balcão (Windows), sem o peso das telas de
gestão dos apps contábeis.

## Stack & Plataformas

- **Flutter/Dart**, Material 3 + `google_fonts`.
- **Plataforma única: windows** (desktop). Sem fastlane, sem mobile/web.

## Tema (IDENTIDADE PRÓPRIA — NÃO MISTURAR)

- Tema próprio em `lib/core/theme/app_theme.dart` (`PdvColors`, `PdvTheme`), pensado para uso de balcão.
- **PROIBIDO** importar/copiar tema de outro app da workspace.

## Arquitetura

- Estrutura mínima por responsabilidade (`core/`, `models/`, `screens/`, `services/`). Como é
  desktop-only, não há paridade mobile a manter; otimizar para teclado/leitor de código de balcão.
- Reaproveitar contrato de API e models do backend `AppAcademia` (mesmos endpoints), mas este projeto
  **não** faz parte da tríade de replicação — alterações aqui não precisam espelhar nos apps contábeis,
  e vice-versa, salvo contrato de API compartilhado que mude no backend.

## UI/UX (OBRIGATÓRIO para mudança de layout)

- Mudança de layout/design DEVE envolver agente de UI/UX (`ui-ux-pro-max` / skill `frontend-design`).

## Testes & Code Review (OBRIGATÓRIO)

- **Criar e rodar o teste do cenário (`flutter test` focado) antes de concluir.** Suíte inteira só antes
  de push pra `main`. `analyze` é só apoio.
- **Push para `main` → code review OBRIGATÓRIO.** Branch base: `desenv`. Encoding UTF-8.
