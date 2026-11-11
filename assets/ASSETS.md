# 자산 출처 — 모든 자산은 여기 있어야 한다

> 정정 이력: 2026-11-10 — 첫 작성(C1-0). 2026-11-10(C2) — 인물 도트 묶음 `chars/` 세 줄(취호전 시트 내보내기 · 보류 #2 답).

`scripts/verify.py` '자산 출처' 단계가 `assets/` 의 파일(`.import` 빼고)과 아래 표 첫 칸을 대조한다(CLAUDE.md 13절). 원작 컷 · 원작 그림을 쓴 자산은 아직 없다 — 생기면 원작 위치(`화/컷`)를 적고, 배포 빌드에서는 기본으로 뺀다.

| 파일 | 출처 | 쓰는 곳 |
|---|---|---|
| `fonts/Galmuri11-Bold.ttf` | 외부 — 갈무리(Galmuri) 11 Bold · Lee Minseo(quiple) · SIL Open Font License 1.1 · castle_M3D `assets/fonts/` 에서 복사(2026-11-10) | 모든 글 — `ui/theme.tres` 기본 글꼴 |
| `fonts/LICENSE.txt` | 외부 — 위 글꼴의 OFL 1.1 전문(글꼴과 함께 배포한다) | 글꼴 라이선스 |
| `icon.svg` | 직접 — 밤 바탕 · 흰 성벽 · 붉은 점(원작 그림 아님 · 2026-11-10) | 앱 아이콘 — `project.godot` `config/icon` |
| `chars/portraits.png` | 직접(사용자 판 취호전) — 취호전 `tools/export_characters.py` 가 코드로 그린 인물 대화 초상(대표 차림 · 기본 표정 32×32)을 `scripts/import_chars.py` 가 16칸 한 줄로 묶음. 원작 컷 아님(원작 조각 ref 는 읽지 않음). 취호전 커밋은 `chars/index.json` `source.commit` | 간부 카드 · 구역 카드 주둔 · 조직 탭 — `ui/sprites.gd` |
| `chars/figures.png` | 직접(사용자 판 취호전) — 같은 도구의 필드 걸음 시트에서 아래 방향 정지 프레임(24×32)만 같은 칸 순서로 묶음 | 지도 위 내 간부 — `ui/map_view.gd` |
| `chars/index.json` | 직접 — `scripts/import_chars.py` 가 만든 색인(canon id → 칸 · 취호전 커밋 · 외형 없는 명단 인물) | `ui/sprites.gd` · verify '도트 묶음' |
