# 자산 출처 — 모든 자산은 여기 있어야 한다

> 정정 이력: 2026-11-10 — 첫 작성(C1-0).

`scripts/verify.py` '자산 출처' 단계가 `assets/` 의 파일(`.import` 빼고)과 아래 표 첫 칸을 대조한다(CLAUDE.md 13절). 원작 컷 · 원작 그림을 쓴 자산은 아직 없다 — 생기면 원작 위치(`화/컷`)를 적고, 배포 빌드에서는 기본으로 뺀다.

| 파일 | 출처 | 쓰는 곳 |
|---|---|---|
| `fonts/Galmuri11-Bold.ttf` | 외부 — 갈무리(Galmuri) 11 Bold · Lee Minseo(quiple) · SIL Open Font License 1.1 · castle_M3D `assets/fonts/` 에서 복사(2026-11-10) | 모든 글 — `ui/theme.tres` 기본 글꼴 |
| `fonts/LICENSE.txt` | 외부 — 위 글꼴의 OFL 1.1 전문(글꼴과 함께 배포한다) | 글꼴 라이선스 |
| `icon.svg` | 직접 — 밤 바탕 · 흰 성벽 · 붉은 점(원작 그림 아님 · 2026-11-10) | 앱 아이콘 — `project.godot` `config/icon` |
